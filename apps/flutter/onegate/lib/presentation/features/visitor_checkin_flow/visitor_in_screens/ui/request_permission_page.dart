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
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/data/visitor_info.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:flutter_onegate/services/app_calling/app_to_app.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
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
  final String userId;
  final Visitor visitor;
  final String? logID;
  final VisitorLog? visitorLog;
  List<String>? unitList;
  final String? request;
  final bool? selfcheckinFlow;

  RequestPermissionPage(
      {Key? key,
      required this.visitor,
      required this.userId,
      this.request,
      this.logID,
      this.visitorLog,
      this.unitList,
      this.selfcheckinFlow})
      : super(key: key);

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionPageState();
}

class _RequestPermissionPageState extends State<RequestPermissionPage> {
  String trybuttontext = "Try Again";
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  late SocketService _socketService;
  RequestType _requestType = RequestType.waiting;
  bool _isLoading = true;
  bool _isFetching = false;
  Timer? _timer;
  final TimerService _timerService = TimerService();
  final _stateStreamController = StreamController<RequestType>.broadcast();
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
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json?updated_at=2023-09-21T12:29:40.807Z',
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

    // Get company ID from visitor log or use default
    final companyId = widget.visitorLog?.company_id?.toString() ?? "8191";
    log("🔌 Initializing socket with companyId: $companyId");
    _socketService.initSocket(companyId, "onegate");

    // Listen for socket events
    _socketService.messageStream.listen((message) {
      log("📩 Socket message received: $message");
      if (message['event'] == 'approvalUpdate') {
        _handleApprovalUpdate(message['data']);
      } else if (message['event'] == 'fcmResponse') {
        _handleFcmResponse(message['data']);
      }
    });

    // Store visitor ID in SharedPreferences if available
    _storeVisitorId();

    _startPolling(); // Start API polling as a fallback

    if (widget.logID != null && widget.logID!.isNotEmpty) {
      _initializeTimer(int.parse(widget.logID!));
    }
    log("Visitor log data: ${widget.visitorLog?.toJson().toString()}");
  }

  // Store visitor ID in SharedPreferences
  Future<void> _storeVisitorId() async {
    if (widget.visitor.id != null && widget.visitor.id! > 0) {
      final prefs = await SharedPreferences.getInstance();
      final visitorId = widget.visitor.id.toString();

      await prefs.setString('visitorId', visitorId);
      log("📱 Stored visitor ID in SharedPreferences: $visitorId");
    } else {
      log("⚠️ No valid visitor ID available to store");
    }
  }

  Duration _remainingTime = Duration.zero; // Track remaining time
  bool _isTimeElapsed = false; // To check if the time is over

  Future<void> _initializeTimer(int visitorLogId) async {
    // Store context in local variable to avoid BuildContext across async gaps
    final currentContext = context;

    if (!mounted) return;

    await _timerService.loadTimerState(visitorLogId, currentContext);

    if (!mounted) return;

    if (_timerService.getTimerState(visitorLogId) == null) {
      await _timerService.startTimer(visitorLogId, currentContext);
    }

    if (!mounted) return;

    setState(() {
      _remainingTime = _timerService
              .getTimerState(visitorLogId)
              ?.endTime
              .difference(DateTime.now()) ??
          Duration.zero;

      // Check if timer is already at 00:00 during initialization
      if (_remainingTime.inSeconds <= 0) {
        _isTimeElapsed = true;
        _requestType = RequestType.notRecheable;
        _stateStreamController.add(RequestType.notRecheable);
      } else {
        _isTimeElapsed = false;
      }
    });
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          if (!_isTimeElapsed) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);

            // Check if timer has reached 00:00
            if (_remainingTime.inSeconds <= 0) {
              _isTimeElapsed = true;
              _requestType = RequestType.notRecheable;
              _stateStreamController.add(RequestType.notRecheable);

              // Stop polling since we've reached the time limit
              _stopPolling();

              // Show notification to user
              myFluttertoast(
                msg: "Member not reachable",
                backgroundColor: Colors.orange,
              );
            }
          }
        });

        // Only fetch approvals if time hasn't elapsed
        if (!_isTimeElapsed) {
          _fetchApprovals();
        }
      }
    });
  }

  VisitorInfo? matchingApproval;

  Future<void> _fetchApprovals() async {
    if (_isFetching) return; // Prevent fetching if already in progress

    setState(() {
      _isFetching = true;
    });

    try {
      final approvals =
          await _remoteDataSource.fetchApprovals(logID: widget.logID!);

      if (approvals.isNotEmpty) {
        final approval = approvals.firstWhere(
            (approval) => approval.visitorLogId?.toString() == widget.logID);

        final newRequestType =
            _mapAllowStatusToRequestType(approval.allowStatus);

        // Only update the stream if the status changes
        if (_requestType != newRequestType) {
          setState(() {
            _requestType = newRequestType;

            // If the status is "not reachable" or timer has elapsed, ensure we show the Allow by Gatekeeper button
            if (_isTimeElapsed || newRequestType == RequestType.notRecheable) {
              _stateStreamController.add(RequestType.notRecheable);
            } else {
              _stateStreamController
                  .add(newRequestType); // Push update to stream
            }
          });
        }
      } else if (_isTimeElapsed) {
        // If no approvals found and timer has elapsed, show not reachable state
        setState(() {
          _requestType = RequestType.notRecheable;
          _stateStreamController.add(RequestType.notRecheable);
        });
      }
    } catch (e) {
      log('Error fetching approvals: $e');
      // On error, if timer has elapsed, show not reachable state
      if (_isTimeElapsed) {
        setState(() {
          _requestType = RequestType.notRecheable;
          _stateStreamController.add(RequestType.notRecheable);
        });
      }
    } finally {
      setState(() {
        _isFetching = false;
      });
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
    _socketService.disconnect();
    _stateStreamController.close();
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
  double _uploadProgress = 0; // Keep this for upload progress tracking

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // _navigateToDashboard();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: _buildHeader(),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const GateDashboardView()),
                  );
                },
                child: const Text(
                  "",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        body: StreamBuilder<RequestType>(
          stream: _stateStreamController.stream,
          initialData: _requestType,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            RequestType requestType = snapshot.data!;

            return LoadingOverlay(
              isUploading: _isUploading,
              child: Column(
                children: [
                  // Main scrollable content area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Visitor Profile Section
                            _buildVisitorProfile(),

                            const SizedBox(height: 60),
                            // Animation and Status
                            _buildLottieSection(requestType),
                            const SizedBox(height: 60),
                            // Action Buttons
                            Center(child: _buildStatusText()),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Fixed bottom navigation bar with padding
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 16.0),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.001),
                          offset: Offset(0, -3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: _buildActionButton(requestType),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVisitorProfile() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ✅ Visitor Image
        Column(
          children: [
            ClipOval(
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  // Optional border
                ),
                child: widget.visitor.visitor_image?.isNotEmpty == true
                    ? Image.network(
                        widget.visitor.visitor_image!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 50),
                      )
                    : const Icon(Icons.person, size: 50),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),

        // ✅ Right side content with divider
        Expanded(
          child: Stack(
            children: [
              // Divider line
              Positioned(
                left: 16, // Padding from the image
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1.5,
                  color: Colors.grey.shade400,
                ),
              ),

              // Visitor Details
              Padding(
                padding: const EdgeInsets.only(left: 32), // Space after divider
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${widget.visitor.name}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: Icons.phone_outlined,
                      iconColor: Colors.green,
                      label: "Mobile",
                      value: widget.visitor.mobile ?? "",
                    ),
                    const SizedBox(height: 10),
                    if (widget.visitorLog?.visitor_coming_from != null &&
                        widget.visitorLog!.visitor_coming_from!.isNotEmpty)
                      Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.location_on_outlined,
                            iconColor: Colors.orange,
                            label: "Coming From",
                            value: widget.visitorLog?.visitor_coming_from ??
                                "Not specified",
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    _buildDetailRow(
                      icon: _getPurposeIcon(
                          widget.visitorLog?.visitor_purpose_Category_name),
                      iconColor: Colors.orange,
                      label: "Purpose",
                      value: widget.visitorLog?.visitor_purpose_Category_name ??
                          "Not specified",
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

  IconData _getPurposeIcon(String? category) {
    switch (category?.toUpperCase()) {
      case "DELIVERY":
        return Icons.inventory_2_outlined; // Delivery icon
      case "CABS":
        return Symbols
            .local_taxi; // Cabs icon (make sure `Symbols` is imported or replace with `Icons`)
      case "VENDOR":
        return Symbols
            .storefront; // Vendor icon (ensure `Symbols` is properly imported or use `Icons`)
      default:
        return Icons.person_2_outlined; // Default icon if no match
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // Create a lighter version of the icon color
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLottieSection(RequestType requestType) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Show Lottie animation based on request type
        Center(
          child: SizedBox(
            height: 250,
            child: Lottie.network(
              _lottieAnimations[requestType] ?? "",
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Show status message
        Center(
          child: Shimmer.fromColors(
            baseColor: _requestMessagesColor[requestType]!,
            highlightColor: requestType == RequestType.rejected
                ? Colors.red.shade100
                : Colors.black45,
            child: Text(
              _requestMessages[requestType] ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _requestMessagesColor[requestType],
              ),
            ),
          ),
        ),
        // Display action buttons when time is expired
        // if (requestType == RequestType.notRecheable)
        //   _buildNotRecheableButtons(), // Show buttons for retrying or allowing by gatekeeper
      ],
    );
  }

  Widget _buildActionButton(RequestType requestType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (requestType == RequestType.notRecheable ||
              (_isTimeElapsed && requestType == RequestType.waiting))
            _buildNotReacheableButtons(),
          if (requestType == RequestType.approved ||
              requestType == RequestType.rejected)
            _buildFinishButton(),
          if (requestType == RequestType.leaveAtGate)
            _buildCapturePhotoButton(),
          if (requestType == RequestType.request)
            _buildRequestPermissionButton(),
        ],
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
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                border: Border.all(color: const Color.fromARGB(93, 0, 0, 0)),
                borderRadius: BorderRadius.circular(10)),
            child:
                const Icon(Icons.home_outlined, color: Colors.black, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText() {
    final formattedTime =
        "${_remainingTime.inMinutes.toString().padLeft(2, '0')}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}";

    return Column(
      children: [
        if (_requestType == RequestType.waiting && !_isTimeElapsed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Retry in: $formattedTime",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  // Widget _buildActionButton() {
  //   switch (_requestType) {
  //     case RequestType.notRecheable:
  //       return _buildNotReacheableButtons();
  //     case RequestType.approved:
  //     case RequestType.rejected:
  //       return _buildFinishButton();
  //     case RequestType.leaveAtGate:
  //       return _buildCapturePhotoButton();
  //     case RequestType.request:
  //       return _buildRequestPermissionButton();
  //     case RequestType.waiting:
  //       return Container();
  //     default:
  //       return _buildFinishButton();
  //   }
  // }

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

        // If the status is "not reachable" or timer has elapsed, ensure we show the Allow by Gatekeeper button
        if (newRequestType == RequestType.notRecheable || _isTimeElapsed) {
          _stateStreamController.add(RequestType.notRecheable);
        }
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
        'https://gateapi.cubeone.in/api/visitor/uploadFile',
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
    myFluttertoast(msg: message, backgroundColor: Colors.red);
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    myFluttertoast(msg: message);
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
              _allowByGatekeeper();
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
        const SizedBox(width: 8),

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
        // _showErrorSnackBar("Invalid visitor log ID.");
        return;
      }

      final response = await Dio().patch(
        '${ApiUrls.gateBaseUrl}/visitor/visitorLog/${widget.visitor.id}',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: jsonEncode({"allow_status": "allowed_by_gatekeeper"}),
      );

      if (response.statusCode == 200) {
        log("✅ Visitor allowed by Gatekeeper successfully");
        // _showSuccessSnackBar("Visitor allowed by Gatekeeper.");

        // Check if widget is still mounted before navigating
        if (!mounted) return;

        // Navigate back to Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => RequestPermissionPage2(
              visitor: widget.visitor,
              visitorLog: widget.visitorLog,
            ),
          ),
          (Route<dynamic> route) => false, // This removes all previous routes
        );
      } else {
        log("❌ Failed to allow visitor by Gatekeeper: ${response.statusMessage}");
        // _showErrorSnackBar("Error allowing visitor. Try again.");
      }
    } catch (e) {
      log("❌ Error in _allowByGatekeeper: $e");
      // _showErrorSnackBar("Failed to allow visitor.");
    }
  }

  Future<void> _handleTryAgain() async {
    log("🔄 Retrying approval process...");

    // Show snackbar for notification resend
    if (mounted) {
      myFluttertoast(
        msg: "Notification resent again",
        backgroundColor: Colors.blue,
      );
    }

    setState(() {
      trybuttontext = "Trying...";
      _requestType = RequestType.waiting;
      _isTimeElapsed = false; // Reset the time elapsed flag
      _stateStreamController
          .add(RequestType.waiting); // Update stream with waiting state
    });

    // Restart timer
    int visitorLogId = int.tryParse(widget.logID ?? '0') ?? 0;
    await _timerService.startTimer(visitorLogId, context);

    // Reset remaining time
    setState(() {
      _remainingTime = _timerService
              .getTimerState(visitorLogId)
              ?.endTime
              .difference(DateTime.now()) ??
          Duration.zero;
    });

    // Restart polling if it was stopped
    if (_timer == null) {
      _startPolling();
    }

    // Send notification using socket
    await _sendNotificationViaSocket();

    setState(() {
      trybuttontext = "Try Again";
    });
  }

  Future<void> _sendNotificationViaSocket() async {
    try {
      // Prepare request data
      final requestData = await _prepareSocketRequestData();

      log("📡 Preparing to send notification via socket");

      // Check if socket is connected
      if (_socketService.socket == null || !_socketService.socket!.connected) {
        log("⚠️ Socket not connected, reconnecting...");
        // Reinitialize socket if not connected
        _socketService.disconnect();
        _socketService = SocketService();

        // Get company ID from visitor log
        final companyId = widget.visitorLog?.company_id?.toString() ?? "8191";
        _socketService.initSocket(companyId, "onegate");

        // Wait for connection to establish
        await Future.delayed(const Duration(seconds: 1));

        if (_socketService.socket == null ||
            !_socketService.socket!.connected) {
          log("❌ Socket connection failed, falling back to REST API");
          await _sendFcmNotification(); // Fallback to REST API
          return;
        }
      }

      // Set up listener for response before sending request
      _socketService.socket!.once("fcmResponse", (responseData) async {
        log("📩 Socket Response Received: $responseData");

        // Check if the response is a string containing XML (Twilio response)
        if (responseData is String && responseData.contains("<?xml")) {
          log("📞 Received Twilio XML response via socket");
          // Create a proper response object for the handler
          final twilioResponse = {
            "success": true,
            "data": responseData,
            "message": "Device token not found, call initiated successfully",
            "status_code": 200
          };
          await _handleFcmResponse(twilioResponse);
        } else {
          // Handle normal JSON response
          await _handleFcmResponse(responseData);
        }
      });

      // Send notification via socket
      log("📤 Emitting sendFcmNotification event with data: ${jsonEncode(requestData)}");
      _socketService.socket!.emit("sendFcmNotification", requestData);

      // Show a toast to indicate the request is being processed
      myFluttertoast(
        msg: "Sending notification to member...",
        backgroundColor: Colors.blue,
      );

      // Set a timeout for socket response
      Timer(const Duration(seconds: 5), () {
        // If we haven't received a response after 5 seconds, fall back to REST API
        if (_requestType == RequestType.waiting) {
          log("⏱️ Socket response timeout, falling back to REST API");
          _sendFcmNotification(); // Fallback to REST API
        }
      });
    } catch (e) {
      log("❌ Error in _sendNotificationViaSocket: $e");
      // Fallback to REST API on error
      await _sendFcmNotification();
    }
  }

  Future<Map<String, dynamic>> _prepareSocketRequestData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? visitorLogId = prefs.getString("visitor_log") ?? widget.logID;
    final String visitorId = widget.visitor.id.toString();

    // Fetch member details
    final List<Map<String, String>> selectedMembers =
        await _getMemberDetails(int.parse(visitorLogId ?? '0'));

    if (selectedMembers.isEmpty) {
      throw Exception("No member details found");
    }

    // Use the first member's details
    final String memberId = selectedMembers.first['member_id'] ?? "";
    final String memberMobile = selectedMembers.first['mobile_number'] ?? "";

    // Use the member's user ID from the widget
    final String memberUserId = widget.userId;
    log("👥 Member User ID from widget for socket: $memberUserId");

    // If member userId is missing or invalid, try to get from SharedPreferences as fallback
    final String? sharedPrefUserId = prefs.getString('user_id');

    // Use the best available user ID with fallbacks
    final String effectiveUserId = (memberUserId.isNotEmpty)
        ? memberUserId
        : (sharedPrefUserId != null && sharedPrefUserId.isNotEmpty)
            ? sharedPrefUserId
            : "77525"; // Default user ID as fallback

    log("👥 Effective User ID for socket: $effectiveUserId");

    return {
      'company_id': widget.visitorLog?.company_id.toString() ?? "",
      'name': widget.visitor.name,
      'mobile': widget.visitor.mobile,
      'in_time': formattedInTime,
      'user_id': effectiveUserId,
      'purpose':
          widget.visitorLog?.visitor_purpose_Category_name?.toLowerCase(),
      'visitor_count': widget.visitorLog?.visitor_count.toString() ?? "1",
      'member_mobile_number': memberMobile,
      'visitor_id': visitorId,
      'purpose_category':
          widget.visitorLog?.visitor_purpose_category_id.toString() == "3"
              ? "delivery"
              : widget.visitorLog?.visitor_purpose_category_id.toString(),
      'visitor_log_id': visitorLogId,
      'coming_from': widget.visitorLog?.visitor_coming_from ?? "Bandra",
      'member_id': memberId,
      'company_name': widget.visitorLog?.company_id.toString() ?? "",
      "self_check_in": widget.selfcheckinFlow != null
          ? widget.selfcheckinFlow.toString()
          : "false",
      "socket_request": true, // Add flag to identify socket requests
      "initiate_call":
          true, // Add flag to initiate call instead of just notification
      "retry_attempt": true // Indicate this is a retry attempt
    };
  }

  String formattedInTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  Future<List<Map<String, String>>> _getMemberDetails(int visitorLogId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? memberDetailsJson = prefs.getString('rows');

    log("Member details from SharedPreferences: $memberDetailsJson");

    if (memberDetailsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(memberDetailsJson);

        final memberDetails = decoded
            .map((member) => {
                  'member_id': member['member_ids'].toString(),
                  'mobile_number': member['mobile_number'].toString()
                })
            .where((member) => member['mobile_number']!.isNotEmpty)
            .toSet()
            .toList();

        if (memberDetails.isNotEmpty) {
          return memberDetails;
        }
      } catch (e) {
        log('❌ Error parsing member_details: $e');
      }
    }

    // Fallback: Return Empty List
    return [];
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    myFluttertoast(
      msg: message,
      backgroundColor: isError ? Colors.red : Colors.green,
    );
  }

  Future<void> _sendFcmNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Get visitor log ID from shared preferences or use the one from widget
      final String? visitorLogId =
          prefs.getString("visitor_log") ?? widget.logID;

      final String visitorId = widget.visitor.id.toString();

      if (visitorLogId == null) {
        _showSnackBar("Visitor Log ID is missing.", isError: true);
        return;
      }

      // ✅ Fetch `member_id` & `mobile_number` from `member_details`
      final List<Map<String, String>> selectedMembers =
          await _getMemberDetails(int.parse(visitorLogId));

      if (selectedMembers.isEmpty) {
        _showSnackBar("No member details found.", isError: true);
        return;
      }

      // ✅ Use the first member's details (or handle multiple if needed)
      final String memberId = selectedMembers.first['member_id'] ?? "";
      final String memberMobile = selectedMembers.first['mobile_number'] ?? "";

      // Use the member's user ID from the widget
      final String memberUserId = widget.userId;
      log("👥 Member User ID from widget: $memberUserId");

      // If member userId is missing or invalid, try to get from SharedPreferences as fallback
      final String? sharedPrefUserId = prefs.getString('user_id');

      // Use the best available user ID with fallbacks
      final String effectiveUserId = (memberUserId.isNotEmpty)
          ? memberUserId
          : (sharedPrefUserId != null && sharedPrefUserId.isNotEmpty)
              ? sharedPrefUserId
              : "77525"; // Default user ID as fallback

      log("👥 Effective User ID for REST API: $effectiveUserId");

      final requestData = {
        'company_id': widget.visitorLog?.company_id.toString() ?? "",
        'name': widget.visitor.name,
        'mobile': widget.visitor.mobile,
        'in_time': formattedInTime,
        'user_id': effectiveUserId,
        'purpose':
            widget.visitorLog?.visitor_purpose_Category_name?.toLowerCase(),
        'visitor_count': widget.visitorLog?.visitor_count.toString() ?? "1",
        'member_mobile_number':
            memberMobile, // ✅ Assigned from `member_details`
        'visitor_id': visitorId,
        'purpose_category':
            widget.visitorLog?.visitor_purpose_category_id.toString() == "3"
                ? "delivery"
                : widget.visitorLog?.visitor_purpose_category_id.toString(),
        'visitor_log_id': visitorLogId,
        'coming_from': widget.visitorLog?.visitor_coming_from ?? "Bandra",
        'member_id': memberId, // ✅ Assigned from `member_details`
        'company_name': widget.visitorLog?.company_id.toString() ?? "",
        "self_check_in": widget.selfcheckinFlow != null
            ? widget.selfcheckinFlow.toString()
            : "false",
        "initiate_call":
            true, // Add flag to initiate call instead of just notification
        "retry_attempt": true // Indicate this is a retry attempt
      };
      log("📩 FCM Request Data: $requestData");
      log("📡 Sending FCM Request: ${jsonEncode(requestData)}");

      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("✅ FCM Notification Sent Successfully: ${response.data}");
        _showSuccessSnackBar("Notification sent successfully!");

        // Handle the response
        await _handleFcmResponse(response.data);
      } else {
        log("❌ FCM Notification Failed: ${response.statusMessage}");
        _showErrorSnackBar("Error sending notification.");
      }
    } catch (e) {
      log("❌ Error in _sendFcmNotification: $e");
      _showErrorSnackBar("Failed to send notification.");
    }
  }

  Future<void> _handleFcmResponse(dynamic responseData) async {
    try {
      if (responseData == null) {
        log("❌ FCM Response data is null");
        return;
      }

      log("📩 Full FCM Response: $responseData");

      // Check for XML response which indicates Twilio call
      if (responseData is String && responseData.contains("<?xml")) {
        log("📞 Received Twilio XML response directly");

        setState(() {
          _requestType = RequestType.waiting;
          _stateStreamController.add(RequestType.waiting);
        });

        myFluttertoast(
          msg: "Call initiated to member successfully",
          backgroundColor: Colors.blue,
        );

        return;
      }

      // Check if the response indicates a successful call initiation via Twilio
      final message = responseData["message"]?.toString() ?? "";
      final bool isSuccess = responseData["success"] == true;

      // Check for call initiation in various message formats
      bool isCallInitiated = message.contains("call initiated") ||
          message.contains("twilio") ||
          message.contains("device token not found") ||
          (isSuccess &&
              responseData["data"] is String &&
              responseData["data"].toString().contains("<?xml"));

      if (isCallInitiated) {
        log("✅ Call initiated successfully via Twilio");

        setState(() {
          _requestType = RequestType.waiting;
          _stateStreamController.add(RequestType.waiting);
        });

        // Show a toast to inform the user
        myFluttertoast(
          msg: "Call initiated to member successfully",
          backgroundColor: Colors.blue,
        );

        // Continue polling for approval status since we need to wait for the member's response
        return;
      }

      log("📩 FCM Response message: $message");

      // Update the request type based on the response
      if (message.contains("always_allowed")) {
        setState(() {
          _requestType = RequestType.approved;
          _stateStreamController.add(RequestType.approved);
        });
      } else if (message.contains("denied")) {
        setState(() {
          _requestType = RequestType.rejected;
          _stateStreamController.add(RequestType.rejected);
        });
      } else if (message.contains("leave_at_gate")) {
        setState(() {
          _requestType = RequestType.leaveAtGate;
          _stateStreamController.add(RequestType.leaveAtGate);
        });
      } else {
        // For any other response, keep waiting
        setState(() {
          _requestType = RequestType.waiting;
          _stateStreamController.add(RequestType.waiting);
        });
      }

      // If we got a definitive response, stop polling
      if (_shouldStopPolling(_requestType)) {
        _stopPolling();
      }
    } catch (e) {
      log("❌ Error handling FCM response: $e");
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
      MaterialPageRoute(
          builder: (context) => widget.selfcheckinFlow == true
              ? const SelfHomeView()
              : const GateDashboardView()),
    );
  }

  Widget _buildFinishButton() {
    return CustomLargeBtn(onPressed: _navigateToDashboard, text: "Finish");
  }

  void _navigateToDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => widget.selfcheckinFlow == true
              ? const SelfHomeView()
              : const GateDashboardView()),
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

  const LoadingOverlay({
    Key? key,
    required this.child,
    this.isUploading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isUploading)
          Container(
            color: Colors.black54, // ✅ Background overlay
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 4, // ✅ Thickness of loader
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white), // ✅ Pure white loader
              ),
            ),
          ),
      ],
    );
  }
}
