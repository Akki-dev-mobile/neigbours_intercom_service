import 'dart:async';
import 'dart:developer';
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
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';

enum RequestType {
  approved,
  rejected,
  leaveAtGate,
  notRecheable,
  request,
  allowByGatekeeper,
  waiting
}

class RequestPermissionPage extends StatefulWidget {
  final Visitor visitor;
  final String? logID;
  final VisitorLog? visitorLog;

  const RequestPermissionPage(
      {Key? key, required this.visitor, this.logID, this.visitorLog})
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
  };

  static const Map<RequestType, String> _requestMessages = {
    RequestType.approved: "Visitor approved",
    RequestType.rejected: "Visitor rejected",
    RequestType.leaveAtGate: "Leave at gate",
    RequestType.notRecheable: "Member not reachable !!",
    RequestType.request: "Request permission from member",
    RequestType.allowByGatekeeper: "Allowed by gatekeeper",
    RequestType.waiting: "Initializing request...",
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

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitleWidget: _buildHeader(),
      hasBackButton: EditableText.debugDeterministicCursor,
      floatingActionButton: _buildActionButton(),
      pageBody: Stack(
        children: [
          _buildContent(),
          // if (_isLoading)
          //   Container(
          //     color: Colors.white.withOpacity(0.8),
          //     child: const Center(
          //       child: CircularProgressIndicator(),
          //     ),
          //   ),
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
          child: const Icon(Icons.home_outlined,
              color: Color(0xffFFB080), size: 30),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildVisitorCard(),
        _buildLottieAnimation(),
        _buildStatusText(),
      ],
    );
  }

  Widget _buildVisitorCard() {
    final unitList = _getUnitList();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(widget.visitor.visitor_image ?? ""),
          radius: MediaQuery.of(context).size.height * 0.05,
        ),
        title: Text(
          widget.visitor.name ?? "",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLileWidget(
              icon: Symbols.call,
              iconColor: Colors.green,
              title: widget.visitor.mobile!,
            ),
            InfoLileWidget(
              icon: Symbols.apartment,
              iconColor: const Color(0xffFFB080),
              title: matchingApproval?.memberInfo.unitId.toString(),
            ),
          ],
        ),
      ),
    );
  }

  String _getUnitList() {
    if (widget.visitorLog?.visitor_building_assignment == null ||
        widget.visitorLog!.visitor_building_assignment!.isEmpty) {
      return '';
    }

    return widget.visitorLog!.visitor_building_assignment!
        .expand((assignment) => assignment.unit_id ?? [])
        .join(', ');
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
        onPressed: () => _navigateToRequestPermission(
              PurposeCategory1(categoryId: 123, categoryName: "categoryName"),
            ),
        text: "Capture photo");
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
      backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
      elevation: MaterialStateProperty.resolveWith<double>(
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
      MaterialPageRoute(
        builder: (context) => RequestPermissionView(
          visitor: Visitor(),
          purposeCategory: purposeCategory,
        ),
      ),
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
