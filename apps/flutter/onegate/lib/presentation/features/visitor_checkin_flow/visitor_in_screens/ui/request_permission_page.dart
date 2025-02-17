import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/missed_approval_screen.dart';
import 'package:flutter_onegate/services/app_calling/app_to_app.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

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
  String trybuttontext = "Try Again";
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  late SocketService _socketService; // Declare SocketService instance
  RequestType _requestType = RequestType.waiting;
  bool _isLoading = true;
  bool _isFetching = false;
  Timer? _timer;
  final TimerService _timerService = TimerService();

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
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/accepted_ef4c4982b2.json',
    RequestType.waiting:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/waiting_for_approval_07eb42d1d5.json',
    RequestType.uploading:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/uploading_animation.json',
    // Add this line
  };

  static const Map<RequestType, String> _requestMessages = {
    RequestType.approved: "Visitor approved",
    RequestType.rejected: "Visitor rejected",
    RequestType.leaveAtGate: "Leave at gate",
    RequestType.notRecheable: "Member not reachable !!",
    RequestType.request: "Request permission from member",
    RequestType.allowByGatekeeper: "Visitor approved",
    RequestType.waiting: "Initializing request...",
    RequestType.uploading: "Uploading image...",
  };

  static const Map<RequestType, Color> _requestMessagesColor = {
    RequestType.approved: Colors.green,
    RequestType.rejected: Colors.red,
    RequestType.leaveAtGate: Colors.black,
    RequestType.notRecheable: Color.fromARGB(255, 165, 165, 1),
    RequestType.request: Colors.black,
    RequestType.allowByGatekeeper: Colors.black,
    RequestType.waiting: Colors.black,
    RequestType.uploading: Colors.black,
  };

  @override
  void initState() {
    super.initState();
    _socketService = SocketService(); // Initialize WebSocket service
    _socketService.initSocket("8191", "onegate"); // Pass companyId & appId

    _socketService.messageStream.listen((message) {
      if (message['event'] == 'approvalUpdate') {
        _handleApprovalUpdate(message['data']);
      }
    });

    _startPolling(); // Start API polling as a fallback

    if (widget.logID != null && widget.logID!.isNotEmpty) {
      _initializeTimer(int.parse(widget.logID!));
    }
  }

  Future<void> _initializeTimer(int visitorLogId) async {
    await _timerService.loadTimerState(visitorLogId, context);

    if (_timerService.getTimerState(visitorLogId) == null) {
      await _timerService.startTimer(visitorLogId, context);
    }

    setState(() {});
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
      log("❌ Invalid logID provided");
      return;
    }

    _isFetching = true;

    try {
      final approvals = await _remoteDataSource.fetchApprovals(widget.logID!);

      if (!mounted) return;

      if (approvals.isEmpty) {
        log("⚠️ No approvals found for logID: ${widget.logID}");
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
      log("❌ Error fetching approvals: $e");
    } finally {
      _isFetching = false;
    }
  }

  void _showLoadingIndicator(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
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
    _socketService.disconnect(); // Disconnect WebSocket when page is closed
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
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: const Color.fromARGB(93, 0, 0, 0)),
                borderRadius: BorderRadius.circular(10)),
            child:
                const Icon(Icons.home_outlined, color: Colors.grey, size: 30),
          ),
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
        const SizedBox(
          height: 120,
        )
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
                width: screensize.width * 0.37,
                height: screensize.height * 0.15,
                fit: BoxFit.fill,
                widget.visitor.visitor_image!),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(
            left: 25.0,
          ),
          child: Text(
            widget.visitor.name ?? "",
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 25.0),
          child: Container(
            decoration: BoxDecoration(
              color: colortoshow.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                widget.visitorLog?.visitor_purpose_Category_name ?? "",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 16, right: 16),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Ionicons.call_outline, color: Colors.green),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colortoshow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Symbols.apartment,
                        color: colortoshow,
                      ),
                    ),
                    const SizedBox(width: 12),
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
      width: double.infinity,
      _lottieAnimations[_requestType] ?? "",
      height: _lottieAnimationSize,
      fit: BoxFit.contain,
    );
  }

  Widget _buildStatusText() {
    final int visitorLogId = int.tryParse(widget.logID ?? '0') ?? 0;
    final timerState = _timerService.getTimerState(visitorLogId);
    final now = DateTime.now();
    final remaining = timerState?.endTime.difference(now) ?? Duration.zero;
    final isTimeElapsed = remaining.isNegative;

    // If timer expires, update the request type to "not reachable"
    if (isTimeElapsed && _requestType == RequestType.waiting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _requestType = RequestType.notRecheable;
        });
      });
    }

    return Column(
      children: [
        Shimmer.fromColors(
          baseColor: _requestMessagesColor[_requestType]!,
          highlightColor: _requestType == RequestType.rejected
              ? Colors.red.shade100
              : Colors.black45,
          child: Text(
            _requestMessages[_requestType] ?? "",
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: _requestMessagesColor[_requestType]),
          ),
        ),

        // Display countdown timer if request is still waiting
        if (_requestType == RequestType.waiting && !isTimeElapsed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Retry in: ${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton() {
    switch (_requestType) {
      case RequestType.notRecheable:
        return _buildNotReacheableButtons();
      case RequestType.approved:
      case RequestType.rejected:
        return _buildFinishButton();
      case RequestType.leaveAtGate:
        return _buildCapturePhotoButton();
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

  void _handleApprovalUpdate(Map<String, dynamic> data) {
    if (widget.logID == null || widget.logID!.isEmpty) return;

    final visitorLogId = data['visitorLogId']?.toString();
    if (visitorLogId == widget.logID) {
      final newRequestType =
          _mapAllowStatusToRequestType(data['allowStatus'].toLowerCase());

      setState(() {
        _requestType = newRequestType;
        _isLoading = false;
      });

      if (_shouldStopPolling(newRequestType)) {
        _stopPolling();
      }
    }
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
        // Allow by Gatekeeper Button
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: ElevatedButton(
            style: _getAllowButtonStyle(),
            onPressed: () async {
              await _allowByGatekeeper();
            },
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.3,
              height: 60,
              child: const Center(
                child: Text(
                  "Allow by Gatekeeper",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    wordSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8), // Add spacing between buttons

        // Try Again Button
        Expanded(
          child: CustomLargeBtn(
            width: MediaQuery.of(context).size.width * 0.45,
            onPressed: () async {
              setState(() {
                trybuttontext = "Trying...";
              });
              await _handleTryAgain();
            },
            text: trybuttontext,
          ),
        ),
      ],
    );
  }

  Future<void> _allowByGatekeeper() async {
    try {
      if (widget.logID == null) {
        _showErrorSnackBar("Invalid visitor log ID.");
        return;
      }

      final response = await Dio().patch(
        '${ApiUrls.gateBaseUrl}/visitor/visitorLog/${widget.visitor.id}',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: jsonEncode({"allow_status": "allowed_by_gatekeeper"}),
      );

      if (response.statusCode == 200) {
        log("✅ Visitor allowed by Gatekeeper successfully");
        _showSuccessSnackBar("Visitor allowed by Gatekeeper.");

        // Navigate back to Dashboard

        _navigateToDashboard();
      } else {
        log("❌ Failed to allow visitor by Gatekeeper: ${response.statusMessage}");
        _showErrorSnackBar("Error allowing visitor. Try again.");
      }
    } catch (e) {
      log("❌ Error in _allowByGatekeeper: $e");
      _showErrorSnackBar("Failed to allow visitor.");
    }
  }

  Future<void> _handleTryAgain() async {
    log("🔄 Retrying approval process...");

    // Show snackbar for notification resend
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Notification resent again"),
          backgroundColor: Colors.blue,
        ),
      );
    }

    setState(() {
      trybuttontext = "Trying...";
      _requestType = RequestType.waiting;
    });

    // Restart timer
    int visitorLogId = int.tryParse(widget.logID ?? '0') ?? 0;
    await _timerService.startTimer(visitorLogId, context);

    // Send FCM notification again
    await _sendFcmNotification();

    // Wait 3 seconds before fetching approvals
    await Future.delayed(const Duration(seconds: 3));

    _fetchApprovals(); // Start polling for approval again

    setState(() {
      trybuttontext = "Try Again"; // Restore button text
    });
  }

  String formattedInTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());


  Future<List<String>> _getMobileNumbersFromMemberDetails(
      int visitorLogId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? memberDetailsJson = prefs.getString('member_details');

    if (memberDetailsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(memberDetailsJson);
        final mobileNumbers = decoded
            .map((member) => member['mobile_number'].toString())
            .where((mobile) => mobile.isNotEmpty)
            .toSet()
            .toList();

        if (mobileNumbers.isNotEmpty) {
          return mobileNumbers;
        }
      } catch (e) {
        log('❌ Error parsing member_details: $e');
      }
    }

    // Fallback: Empty List
    return [];
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _sendFcmNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('visitorId');
      final String? visitorLogId = prefs.getString("visitor_log");
      final String visitorId = widget.visitor.id.toString();
      // ✅ Fetch from `member_details`
      final selectedMobileNumbers = await _getMobileNumbersFromMemberDetails(
          int.parse(visitorLogId.toString()));

      if (selectedMobileNumbers.isEmpty) {
        _showSnackBar("No mobile number found for the selected member.",
            isError: true);
        return;
      }
      final requestData = {
        'company_id': widget.visitorLog?.company_id.toString() ?? "",
        'name': widget.visitor.name,
        'mobile': widget.visitor.mobile,
        'purpose': "Guest",
        'in_time': formattedInTime,
        'user_id': (int.tryParse(userId ?? "0") == null ||
                int.tryParse(userId ?? "0") == 0)
            ? "234567"
            : int.parse(userId!).toString(),
        'visitor_count': widget.visitorLog?.visitor_count.toString() ?? "1",
        'member_mobile_number': selectedMobileNumbers.first,
        'visitor_id': visitorId ?? "",
        'purpose_category':
            widget.visitorLog?.visitor_purpose_category_id.toString() == "3"
                ? "delivery"
                : widget.visitorLog?.visitor_purpose_category_id.toString(),
        'visitor_log_id': visitorLogId ?? "",
        'coming_from': widget.visitorLog?.visitor_coming_from ?? "Bandra",
        'member_id': "232",
        'company_name': widget.visitorLog?.company_id.toString() ?? "",
      };

      log("📡 Sending FCM Request: ${jsonEncode(requestData)}");

      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("✅ FCM Notification Sent Successfully: ${response.data}");
        _showSuccessSnackBar("Notification sent successfully!");
      } else {
        log("❌ FCM Notification Failed: ${response.statusMessage}");
        _showErrorSnackBar("Error sending notification.");
      }
    } catch (e) {
      log("❌ Error in _sendFcmNotification: $e");
      _showErrorSnackBar("Failed to send notification.");
    }
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
      foregroundColor: WidgetStateProperty.all<Color>(
        const Color(0xFF7D7C7C),
      ),
      backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
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
    );
  }

  void _navigateToRequestPermission(PurposeCategory1 purposeCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GateDashboardView()),
    );
  }

  Widget _buildFinishButton() {
    return CustomLargeBtn(onPressed: _navigateToDashboard, text: "Finish");
  }

  void _navigateToDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GateDashboardView()),
    );
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
