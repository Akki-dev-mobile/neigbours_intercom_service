import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

final ValueNotifier<int> secondsRemainingNotifier = ValueNotifier<int>(120);
final ValueNotifier<bool> isRetryEnabledNotifier = ValueNotifier<bool>(false);

class MissedApprovalsScreen extends StatelessWidget {
  final remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  MissedApprovalsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missed Approvals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: remoteDataSource.fetchApprovals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load approvals: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No missed approvals found.'),
            );
          }

          final missedApprovals =
              snapshot.data!.map((data) => VisitorInfo.fromJson(data)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missedApprovals.length,
            itemBuilder: (context, index) {
              return MissedApprovalItem(
                visitorInfo: missedApprovals[index],
              );
            },
          );
        },
      ),
    );
  }
}

// Define data classes for better type safety
class VisitorInfo {
  final int visitorId;
  final String visitorName;
  final String visitorMobile;
  final String visitorImage;
  final String allowStatus;
  final int visitorLogId;
  final int companyId;
  final String inGate;
  final String logCreatedAt;
  final MemberInfo memberInfo;
  final String? visitorComingFrom;
  final int? visitorPurposeCategoryId;

  VisitorInfo({
    required this.visitorId,
    required this.visitorName,
    required this.visitorMobile,
    required this.visitorImage,
    required this.allowStatus,
    required this.visitorLogId,
    required this.companyId,
    required this.inGate,
    required this.logCreatedAt,
    required this.memberInfo,
    this.visitorComingFrom,
    this.visitorPurposeCategoryId,
  });

  factory VisitorInfo.fromJson(Map<String, dynamic> json) {
    return VisitorInfo(
      visitorId: _parseToInt(json['visitor_id']),
      visitorName: json['visitor_name']?.toString() ?? '',
      visitorMobile: json['visitor_mobile']?.toString() ?? '',
      visitorImage: json['visitor_image']?.toString() ?? '',
      allowStatus: json['allow_status']?.toString() ?? '',
      visitorLogId: _parseToInt(json['visitor_log_id']),
      companyId: _parseToInt(json['company_id']),
      inGate: json['in_gate']?.toString() ?? '',
      logCreatedAt: json['log_created_at']?.toString() ?? '',
      memberInfo: MemberInfo(
        name: json['member_name']?.toString() ?? '',
        mobileNumber: json['memb_mobile_number']?.toString(),
        email: json['memb_email']?.toString(),
        memberId: json['member_id'],
        unitId: _parseToInt(json['unit_id'] ?? "") ?? 0,
      ),
      visitorComingFrom: json['visitor_coming_from']?.toString(),
      visitorPurposeCategoryId:
          _parseToInt(json['visitor_purpose_category_id']),
    );
  }

  // Helper method to safely parse various types to int
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class MemberInfo {
  final String name;
  final String? mobileNumber;
  final String? email;
  final int? unitId;
  final int? memberId;

  MemberInfo({
    required this.name,
    this.mobileNumber,
    this.email,
     this.unitId,
     this.memberId
  });
}

class MissedApprovalItem extends StatefulWidget {
  final VisitorInfo visitorInfo;

  const MissedApprovalItem({
    Key? key,
    required this.visitorInfo,
  }) : super(key: key);

  @override
  State<MissedApprovalItem> createState() => _MissedApprovalItemState();
}

class _MissedApprovalItemState extends State<MissedApprovalItem> {
  late Timer _timer;
  final Dio _dio = Dio();
  String? companyId;
  String? companyName;
  String? memberMobileNo;
  String? memberDetailsJson;

  @override
  void initState() {
    super.initState();
    startTimer();
    _fetchCompanyDetails();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchCompanyDetails() async {
    final prefs = await SharedPreferences.getInstance();
    companyId = prefs.getString('society_id');
    companyName = prefs.getString('society_name');
    memberMobileNo = prefs.getString('selected_member_mobile_numbers');
    memberDetailsJson = prefs.getString('member_details');
    print("rohit ${widget.visitorInfo.memberInfo.memberId.toString()}");
  }

  Future<void> _sendFcmNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final formattedInTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final requestData = {
        'company_id': companyId,
        'name': widget.visitorInfo.visitorName,
        'mobile': widget.visitorInfo.visitorMobile,
        'purpose': "meeting",
        'in_time': formattedInTime,
        'user_id': userId,
        'visitor_count': "1",
        'member_mobile_number': "918452060059",
        'visitor_id': widget.visitorInfo.visitorId,
        'purpose_category':
            widget.visitorInfo.visitorPurposeCategoryId?.toString() ?? "",
        'purpose_details': "meeting",
        'coming_from': widget.visitorInfo.visitorComingFrom ?? "Unknown",
        'company_name': companyName ?? "",
        "member_id": widget.visitorInfo.memberInfo.memberId.toString()
      };

      final response = await _dio.post(
        'https://gateapi.cubeone.in/api/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Notification Resent Successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        startTimer();
      }
    } catch (e) {
      if (e is DioError && e.response?.statusCode == 400) {
        Fluttertoast.showToast(
          msg: "Failed to resend notification",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
      print("Error sending FCM notification: $e");
    }
  }

  void startTimer() {
    if (secondsRemainingNotifier.value == 0 || isRetryEnabledNotifier.value) {
      secondsRemainingNotifier.value = 120;
      isRetryEnabledNotifier.value = false;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemainingNotifier.value > 0) {
        secondsRemainingNotifier.value -= 1;
      } else {
        timer.cancel();
        isRetryEnabledNotifier.value = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 2,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              leading: CircleAvatar(
                backgroundImage: widget.visitorInfo.visitorImage.isNotEmpty
                    ? NetworkImage(widget.visitorInfo.visitorImage)
                    : null,
                child: widget.visitorInfo.visitorImage.isEmpty
                    ? Text(
                        widget.visitorInfo.visitorName.isNotEmpty
                            ? widget.visitorInfo.visitorName[0]
                            : 'G',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : null,
              ),
              title: Text(
                widget.visitorInfo.visitorName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Symbols.apartment,
                        color: Color(0xffFFB080),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffFFEBE6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Guest',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Member: ${widget.visitorInfo.memberInfo.name}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Gate: ${widget.visitorInfo.inGate}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Time: ${DateFormat('hh:mm a').format(DateTime.parse(widget.visitorInfo.logCreatedAt))}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              indent: 16,
              endIndent: 16,
              color: Colors.grey[200],
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: isRetryEnabledNotifier,
                    builder: (context, isRetryEnabled, _) {
                      return ElevatedButton.icon(
                        onPressed: () async {
                          await _sendFcmNotification();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRetryEnabled
                              ? Colors.blue
                              : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: isRetryEnabled ? 2 : 0,
                        ),
                        icon: Icon(
                          isRetryEnabled
                              ? Icons.refresh_rounded
                              : Icons.hourglass_empty_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isRetryEnabled ? 'Retry Now' : 'Processing',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: secondsRemainingNotifier,
                    builder: (context, secondsRemaining, _) {
                      return Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isRetryEnabledNotifier.value
                              ? Colors.red.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRetryEnabledNotifier.value
                                ? Colors.red.shade200
                                : Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isRetryEnabledNotifier.value
                                  ? Icons.timer_off_outlined
                                  : Icons.timer_outlined,
                              size: 20,
                              color: isRetryEnabledNotifier.value
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isRetryEnabledNotifier.value
                                  ? 'Expired'
                                  : '${(secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(secondsRemaining % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: isRetryEnabledNotifier.value
                                    ? Colors.red
                                    : Colors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
