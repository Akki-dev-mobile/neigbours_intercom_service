import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/missed_approval_screen.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/widgets/info_list_tile_widget.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';

enum RequestType {
  approved,
  rejected,
  leaveAtGate,
  notRecheable,
  request,
  allowByGatekeeper,
  waiting,
  uploading
}

class RequestPermissionPage extends StatefulWidget {
  final Visitor visitor;
  final String? logID;
  final VisitorLog? visitorLog;
  List<String>? unitList;
  RequestPermissionPage(
      {Key? key,
      required this.visitor,
      this.logID,
      this.visitorLog,
      this.unitList})
      : super(key: key);

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionPageState();
}

class _RequestPermissionPageState extends State<RequestPermissionPage> {
  static const double _lottieAnimationSize = 250;
  static const Duration _pollingInterval = Duration(seconds: 5);

  final RemoteDataSource _remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  RequestType _requestType = RequestType.waiting;
  bool _isLoading = true;
  bool _isFetching = false;
  Timer? _timer;

  static const Map<RequestType, String> _lottieAnimations = {
    RequestType.approved:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/accepted_ef4c4982b2.json',
    RequestType.rejected:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/rejected_4bcdedc751.json',
    RequestType.leaveAtGate:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/leave_at_gate_048fedfdb6.json',
    RequestType.notRecheable:
        'https://fstech-cms-db.s3.ap-south-1.amazonaws.com/Animation_1738144371860_6ed19f54ff.json',
    RequestType.request:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/request_permission_b6ef131475.json',
    RequestType.allowByGatekeeper:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json',
    RequestType.waiting:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/waiting_for_approval_07eb42d1d5.json',
    RequestType.uploading:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/uploading_animation.json', // Add this line
  };

  static const Map<RequestType, String> _requestMessages = {
    RequestType.approved: "Visitor approved",
    RequestType.rejected: "Visitor rejected",
    RequestType.leaveAtGate: "Leave at gate",
    RequestType.notRecheable: "Member not reachable !!",
    RequestType.request: "Request permission from member",
    RequestType.allowByGatekeeper: "Allowed by gatekeeper",
    RequestType.waiting: "Initializing request...",
    RequestType.uploading: "Uploading image...",
  };

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(_pollingInterval, (_) {
      if (!_isFetching) {
        _fetchApprovals();
      }
    });
  }

  VisitorInfo? matchingApproval;
  Future<void> _fetchApprovals() async {
    if (widget.logID == null || widget.logID!.isEmpty) {
      log("Invalid logID provided");
      return;
    }

    _isFetching = true;

    try {
      final approvals = await _remoteDataSource.fetchApprovals(widget.logID!);

      if (!mounted) return;

      if (approvals.isEmpty) {
        log("No approvals found for logID: ${widget.logID}");
        return;
      }

      matchingApproval = approvals.firstWhere(
        (approval) => approval.visitorLogId?.toString() == widget.logID,
        orElse: () => throw Exception("No matching approval found"),
      );

      final newRequestType = _mapAllowStatusToRequestType(
          matchingApproval?.allowStatus.toLowerCase());

      setState(() {
        _requestType = newRequestType;
        _isLoading = false;
      });

      if (_shouldStopPolling(newRequestType)) {
        _stopPolling();
      }
    } catch (e) {
      log("Error fetching approvals: $e");
    } finally {
      _isFetching = false;
    }
  }

  bool _shouldStopPolling(RequestType type) {
    return type == RequestType.approved ||
        type == RequestType.rejected ||
        type == RequestType.leaveAtGate;
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  RequestType _mapAllowStatusToRequestType(String? status) {
    switch (status) {
      case "allowed":
        return RequestType.approved;
      case "denied":
        return RequestType.rejected;
      case "leave":
        return RequestType.leaveAtGate;
      case "invalid":
        return RequestType.notRecheable;
      case "request":
        return RequestType.request;
      case "pending":
        return RequestType.waiting;
      case "always_allowed":
        return RequestType.allowByGatekeeper;
      default:
        return RequestType.rejected;
    }
  }

  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isUploading: _isUploading,
      progress: _uploadProgress,
      child: MyScrollView(
        pageTitleWidget: _buildHeader(),
        hasBackButton: EditableText.debugDeterministicCursor,
        floatingActionButton: _buildActionButton(),
        pageBody: Stack(
          children: [
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => _navigateToDashboard(),
          child: const Icon(Icons.home_outlined,
              color: Color(0xffFFB080), size: 30),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildVisitorCard(context),
        _buildLottieAnimation(),
        _buildStatusText(),
      ],
    );
  }

  Widget _buildVisitorCard(BuildContext context) {
    Color colortoshow = const Color(0xffFFB080);
    Size screensize = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.network(
                width: screensize.width * 0.5,
                height: screensize.height * 0.2,
                fit: BoxFit.fill,
                "https://t4.ftcdn.net/jpg/03/64/21/11/360_F_364211147_1qgLVxv1Tcq0Ohz3FawUfrtONzz8nq3e.jpg"),
          ),
        ),
        SizedBox(height: 20),
        Text(
          widget.visitor.name ?? "",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        Container(
          decoration: BoxDecoration(
            color: colortoshow.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
                widget.visitorLog?.purpose_sub_category_name != null
                    ? "${widget.visitorLog?.purpose_sub_category_name}"
                    : "${widget.visitorLog?.visitor_purpose_Category_name}",
                    ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Ionicons.call_outline, color: Colors.green),
                ),
                title: Text(
                  'Phone Number',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),

                  //  TextStyle(
                  //   color: Colors.grey[600],
                  //   fontSize: 14,
                  // ),
                ),
                subtitle: Text(
                  widget.visitor.mobile ?? "",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),

                // trailing: ElevatedButton.icon(
                //   icon: Icon(Icons.call, size: 18, color:Colors.black),
                //   label: Text('Call',style: Theme.of(context).textTheme.bodySmall),
                //   onPressed: () => {},
                //   // _makePhoneCall(widget.visitorLog.visitor!.mobile ?? ""),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: colortoshow,
                //     foregroundColor: Colors.white,
                //     padding:
                //         EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //   ),
                // ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 18.0, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colortoshow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Symbols.apartment,
                        color: colortoshow,
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visiting Unit',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.6,
                          ),
                          child: Text(
                            widget.unitList!.first,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLottieAnimation() {
    return Lottie.network(
      _lottieAnimations[_requestType] ?? "",
      height: _lottieAnimationSize,
      fit: BoxFit.contain,
    );
  }

  Widget _buildStatusText() {
    return Text(
      _requestMessages[_requestType] ?? "",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 25,
        color: _requestType == RequestType.rejected ? Colors.red : Colors.black,
      ),
    );
  }

  Widget _buildActionButton() {
    switch (_requestType) {
      case RequestType.approved:
        return _buildFinishButton();
      case RequestType.rejected:
        return _buildFinishButton();
      case RequestType.leaveAtGate:
        return _buildCapturePhotoButton();
      case RequestType.notRecheable:
        return _buildNotReacheableButtons();
      case RequestType.request:
        return _buildRequestPermissionButton();
      case RequestType.waiting:
        return Container();
      default:
        return _buildFinishButton();
    }
  }
// Inside _RequestPermissionPageState class

  Widget _buildCapturePhotoButton() {
    return CustomLargeBtn(
      onPressed: () => _handleImageCapture(),
      text: "Capture photo",
    );
  }

// Modify the _handleImageCapture method
  Future<void> _handleImageCapture() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) {
        _showErrorSnackBar('No image captured');
        return;
      }

      // Show image preview
      if (!mounted) return;

      final bool? shouldUpload = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ImagePreviewDialog(
            imageFile: File(image.path),
            onConfirm: () => Navigator.pop(context, true),
            onRetake: () => Navigator.pop(context, false),
          );
        },
      );

      if (shouldUpload != true) {
        // User wants to retake the photo
        _handleImageCapture();
        return;
      }

      // Show uploading animation
      setState(() {
        _requestType = RequestType.uploading;
      });

      final String imageUrl = await _uploadImage(File(image.path));

      final success = await _remoteDataSource.uploadParcelImage(
        visitorLogId: int.parse(widget.logID ?? '0'),
        imageUrl: imageUrl,
      );

      if (success) {
        _showSuccessSnackBar('Image uploaded successfully');
        _navigateToRequestPermission(
          PurposeCategory1(categoryId: 123, categoryName: "categoryName"),
        );
      } else {
        _showErrorSnackBar('Failed to upload image');
        setState(() {
          _requestType = RequestType.leaveAtGate;
        });
      }
    } catch (e) {
      log('Error handling image capture: $e');
      _showErrorSnackBar('Error processing image');
      setState(() {
        _requestType = RequestType.leaveAtGate;
      });
    }
  }

// Update the _uploadImage method to show upload progress
  Future<String> _uploadImage(File imageFile) async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

      var data = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: '${widget.visitorLog?.visitor?.mobile}.jpg',
        ),
        'company_id': '${widget.visitorLog?.company_id}',
        'uuid': widget.visitorLog?.visitor?.mobile,
        'path': imageFile.path,
      });

      var dio = Dio();
      var response = await dio.post(
        'http://35.154.173.226:8005/api/visitor/uploadFile',
        data: data,
        options: Options(
          contentType: 'multipart/form-data',
        ),
        onSendProgress: (int sent, int total) {
          setState(() {
            _uploadProgress = sent / total;
          });
        },
      );

      if (response.statusCode == 200) {
        log('Successfully uploaded: ${json.encode(response.data)}');
        var filePath = response.data['data']?['file_path'];
        if (filePath != null && filePath is String) {
          return filePath;
        }
      }
      throw Exception('Upload failed: ${response.statusMessage}');
    } catch (e) {
      log('Error uploading image: $e');
      rethrow;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildNotReacheableButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Allow Button
        Expanded(
          child: ElevatedButton(
            style: _getAllowButtonStyle(),
            onPressed: () {},
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.3,
              height: 60,
              child: const Center(
                  child: Text(
                "Allow",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  wordSpacing: 1.2,
                ),
              )),
            ),
          ),
        ),
        const SizedBox(width: 8), // Add spacing between buttons
        // Try Again Button
        Expanded(
          child: CustomLargeBtn(
              width: MediaQuery.of(context).size.width * 0.45,
              onPressed: () => _navigateToRequestPermission(
                    PurposeCategory1(
                        categoryId: 123, categoryName: "categoryName"),
                  ),
              text: "Try Again"),
        ),
      ],
    );
  }

  Widget _buildRequestPermissionButton() {
    return CustomLargeBtn(
        onPressed: () => _navigateToRequestPermission(
              PurposeCategory1(
                categoryId: widget.visitorLog?.visitor_purpose_category_id ?? 0,
                categoryName:
                    widget.visitorLog?.visitor_purpose_Category_name ?? "",
              ),
            ),
        text: "Request permission");
  }

// Helper methods for button styling and navigation
  ButtonStyle _getAllowButtonStyle() {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all<Color>(
        const Color(0xFF7D7C7C),
      ),
      backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
      elevation: WidgetStateProperty.resolveWith<double>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.pressed)) {
            return 8;
          }
          return 0;
        },
      ),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          side: const BorderSide(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  void _navigateToRequestPermission(PurposeCategory1 purposeCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GateDashboardView()),
    );
  }

  Widget _buildFinishButton() {
    return CustomLargeBtn(onPressed: _navigateToDashboard, text: "Finish");
  }

  void _navigateToDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GateDashboardView()),
    );
  }

  Widget _getbutton(RequestType requestType) {
    switch (requestType) {
      case RequestType.notRecheable:
        return Container(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.all<Color>(
                      const Color(0xFF7D7C7C),
                    ),
                    backgroundColor:
                        WidgetStateProperty.all<Color>(Colors.white),
                    elevation: WidgetStateProperty.resolveWith<double>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.pressed)) {
                          return 8;
                        }
                        return 0;
                      },
                    ),
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.black, width: 1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  onPressed: () {},
                  child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 60,
                      child: const Center(
                          child: Text(
                        "Allow",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          wordSpacing: 1.2,
                          // fontWeight: FontWeight.w500,
                        ),
                      )))),
              // CustomLargeBtn(
              //     width: MediaQuery.of(context).size.width * 0.45,
              //     onPressed: () {
              //       Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //               builder: (context) => RequestPermissionView(
              //                     visitor: Visitor(),
              //                     purposeCategory: PurposeCategory1(
              //                         categoryId: 123,
              //                         categoryName: "categoryName"),
              //                   )));
              //     },
              //     text: "Allow"),

              CustomLargeBtn(
                  width: MediaQuery.of(context).size.width * 0.45,
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RequestPermissionView(
                                  visitor: Visitor(),
                                  purposeCategory: PurposeCategory1(
                                      categoryId: 123,
                                      categoryName: "categoryName"),
                                )));
                  },
                  text: "Try Again"),
            ],
          ),
        );
      case RequestType.approved:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GateDashboardView()));
            },
            text: "Finish");
      case RequestType.leaveAtGate:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: 123, categoryName: "categoryName"),
                          )));
            },
            text: "Capture photo");
      case RequestType.request:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: widget.visitorLog
                                        ?.visitor_purpose_category_id ??
                                    0,
                                categoryName: widget.visitorLog
                                        ?.visitor_purpose_Category_name ??
                                    ""),
                          )));
            },
            text: "Request permission");
      case RequestType.rejected:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: widget.visitorLog
                                        ?.visitor_purpose_category_id ??
                                    0,
                                categoryName: widget.visitorLog
                                        ?.visitor_purpose_Category_name ??
                                    ""),
                          )));
            },
            text: "Finish");
      case RequestType.waiting:
        return Container();
      default:
        {
          return CustomLargeBtn(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => RequestPermissionView(
                              visitor: Visitor(),
                              purposeCategory: PurposeCategory1(
                                  categoryId: widget.visitorLog
                                          ?.visitor_purpose_category_id ??
                                      0,
                                  categoryName: widget.visitorLog
                                          ?.visitor_purpose_Category_name ??
                                      ""),
                            )));
              },
              text: "Finish");
        }
    }
  }
}

class ImagePreviewDialog extends StatelessWidget {
  final File imageFile;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  const ImagePreviewDialog({
    Key? key,
    required this.imageFile,
    required this.onConfirm,
    required this.onRetake,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                imageFile,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onRetake,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isUploading;
  final double progress;

  const LoadingOverlay({
    Key? key,
    required this.child,
    this.isUploading = false,
    this.progress = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isUploading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading... ${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
