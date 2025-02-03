import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/widgets/info_list_tile_widget.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';

class RequestPermissionPage extends StatefulWidget {
  final Visitor visitor;
  final String? logID;

  const RequestPermissionPage({super.key, required this.visitor, this.logID});

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionPageState();
}

class _RequestPermissionPageState extends State<RequestPermissionPage> {
  double lottieAnimationSize = 250;
  RequestType requestType = RequestType.waiting;
  bool isLoading = true;
  Timer? _timer;
  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  @override
  void initState() {
    super.initState();
    _startFetchingApprovals();
  }

  void _startFetchingApprovals() {
    // Run the function every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchApprovals(widget.logID);
    });
  }

  Future<void> _fetchApprovals(String? logID) async {
    try {
      final approvals = await remoteDataSource.fetchApprovals(logID ?? "");
      log("Fetched Approvals: $approvals");

      if (approvals.isEmpty) {
        log("No approvals found for logID: $logID");
        return;
      }

      final matchingApproval = approvals.firstWhere(
        (approval) => approval["visitor_log_id"].toString() == logID,
        orElse: () => null,
      );

      if (matchingApproval == null) {
        log("No matching visitor_log_id found for logID: $logID");
        return;
      }

      if (mounted) {
        setState(() {
          requestType = _mapAllowStatusToRequestType(
              matchingApproval["allow_status"]?.toString().toLowerCase());
          isLoading = false;
        });
      }
    } catch (e) {
      log("Error fetching approvals: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Stop the timer when the widget is disposed
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

  // Lottie Animation Map
  final Map<RequestType, String> _lottieAnimations = {
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

  // Text Label Map
  final Map<RequestType, String> _requestMessages = {
    RequestType.approved: "Visitor approved",
    RequestType.rejected: "Visitor rejected",
    RequestType.leaveAtGate: "Leave at gate",
    RequestType.notRecheable: "Member not reachable !!",
    RequestType.request: "Request permission from member",
    RequestType.allowByGatekeeper: "Allowed by gatekeeper",
    RequestType.waiting: "Initializing request...",
  };

  @override
  Widget build(BuildContext context) {
    Color colortoshow = const Color(0xffFFB080);
    Size screensize = MediaQuery.of(context).size;

    return MyScrollView(
      pageTitleWidget: _buildHeader(colortoshow),
      hasBackButton: EditableText.debugDeterministicCursor,
      floatingActionButton: _getbutton(requestType),
      pageBody: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildVisitorCard(colortoshow, screensize),
                _buildLottieAnimation(),
                _buildStatusText(),
              ],
            ),
    );
  }

  Widget _buildHeader(Color colortoshow) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const GateDashboardView())),
          child: Icon(Icons.home_outlined, color: colortoshow, size: 30),
        ),
      ],
    );
  }

  Widget _buildVisitorCard(Color colortoshow, Size screensize) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(widget.visitor.visitor_image ?? ""),
          radius: screensize.height * 0.05,
        ),
        title: Text(widget.visitor.name ?? "",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLileWidget(
                icon: Symbols.call,
                iconColor: Colors.green,
                title: widget.visitor.mobile!),
            InfoLileWidget(
                icon: Symbols.apartment, iconColor: colortoshow, title: 'N/A'),
          ],
        ),
      ),
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
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: 123, categoryName: "categoryName"),
                          )));
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
                                categoryId: 123, categoryName: "categoryName"),
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
                                categoryId: 123, categoryName: "categoryName"),
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
                                  categoryId: 123,
                                  categoryName: "categoryName"),
                            )));
              },
              text: "Finish");
        }
    }
  }

  Widget _buildLottieAnimation() {
    return Lottie.network(_lottieAnimations[requestType] ?? "",
        height: lottieAnimationSize, fit: BoxFit.contain);
  }

  Widget _buildStatusText() {
    return Text(
      _requestMessages[requestType] ?? "",
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: 25,
          color:
              requestType == RequestType.rejected ? Colors.red : Colors.black),
    );
  }
}
