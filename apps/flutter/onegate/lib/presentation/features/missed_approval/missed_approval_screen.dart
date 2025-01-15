import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:onegate_client/onegate_client.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

final ValueNotifier<int> secondsRemainingNotifier = ValueNotifier<int>(120);
final ValueNotifier<bool> isRetryEnabledNotifier = ValueNotifier<bool>(false);

class MissedApprovalsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final staticMissedApprovals = [

      VisitorLog(
        visitor: Visitor(
          name: "John Doe",
          visitor_image: "https://example.com/images/john_doe.jpg", // Placeholder image URL
          mobile: "9876543210", // Static mobile number
        ),
        visitor_building_assignment: [
          BuildingAssignment(unit_id: ["101", "102"], company_id: 001, building_id: 001)
        ],
        visitor_id: 12345,
        visitor_purpose_category_id: 56789,
        visitor_count: 1,
        company_id: 001,
        is_checked_out: false,
      ),
      VisitorLog(
        visitor: Visitor(
          name: "Jane Smith",
          visitor_image: "https://example.com/images/jane_smith.jpg", // Placeholder image URL
          mobile: "8765432109", // Static mobile number
        ),
        visitor_building_assignment: [
          BuildingAssignment(unit_id: ["101", "102"], company_id: 001, building_id: 001)
        ],
        visitor_id: 12345,
        visitor_purpose_category_id: 56789,
        visitor_count: 2,
        company_id: 001,
        is_checked_out: true,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Missed Approvals'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: staticMissedApprovals.length,
        itemBuilder: (context, index) {
          return MissedApprovalItem(
            visitorLog: staticMissedApprovals[index],
          );
        },
      ),
    );
  }
}

class MissedApprovalItem extends StatefulWidget {
  final VisitorLog visitorLog;

  const MissedApprovalItem({
    Key? key,
    required this.visitorLog,
  }) : super(key: key);

  @override
  State<MissedApprovalItem> createState() => _MissedApprovalItemState();
}

class _MissedApprovalItemState extends State<MissedApprovalItem> {
  late Timer _timer;
  final Dio _dio = Dio();
  String? companyId;
  String? companyName;
  String? memberDetailsJson;
  String? memberMobileNo;

  @override
  void initState() {
    super.initState();
    startTimer();
    _fetchCompanyDetails();
  }

  Future<void> _fetchCompanyDetails() async {
    final prefs = await SharedPreferences.getInstance();
    companyId = prefs.getString('society_id');
    companyName = prefs.getString('society_name');
    memberMobileNo =  await prefs.getString('selected_member_mobile_numbers');
    memberDetailsJson= await prefs.getString('member_details');
    print("this is$memberDetailsJson");
  }

  Future<void> _sendFcmNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final formattedInTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final requestData = {
        'company_id': companyId,
        'name': widget.visitorLog.visitor?.name,
        'mobile': widget.visitorLog.visitor?.mobile ?? "",
        'purpose': "meeting",
        'in_time': formattedInTime,
        'user_id': userId,
        'visitor_count': "1",
        "member_mobile_number": "918452060059",
        "visitor_id": 884,
        "purpose_category": widget.visitorLog.visitor_purpose_category_id?.toString() ?? "",
        'purpose_details': "meeting",
        'coming_from': widget.visitorLog.visitor_coming_from ?? "Unknown",
        "member_id": 27,
        "company_name": companyName ?? "",
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
        startTimer(); // Restart the timer after successful notification
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

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
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
                child: Text(
                  widget.visitorLog.visitor!.name.isNotEmpty
                      ? widget.visitorLog.visitor!.name[0]
                      : 'G',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              title: Text(
                widget.visitorLog.visitor!.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  children: [
                    Icon(
                      Symbols.apartment,
                      color: Color(0xffFFB080),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xffFFEBE6),
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
                    onPressed:
                    // isRetryEnabled
                    //     ?
                        () async {
                      await _sendFcmNotification();
                    },
                        // : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRetryEnabled
                          ? Colors.blue
                          : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
                  // Timer display
                  ValueListenableBuilder<int>(
                    valueListenable: secondsRemainingNotifier,
                    builder: (context, secondsRemaining, _) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            SizedBox(width: 8),
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













// class MissedApprovalsScreen extends StatelessWidget {
//   final List<VisitorLog> missedApprovals;
//
//   const MissedApprovalsScreen({
//     Key? key,
//     required this.missedApprovals,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Missed Approvals'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: ListView.builder(
//         padding: EdgeInsets.all(16),
//         itemCount: missedApprovals.length,
//         itemBuilder: (context, index) {
//           return MissedApprovalItem(
//             visitorLog: missedApprovals[index],
//           );
//         },
//       ),
//     );
//   }
// }
//
// class MissedApprovalItem extends StatefulWidget {
//   final VisitorLog visitorLog;
//
//   const MissedApprovalItem({
//     Key? key,
//     required this.visitorLog,
//   }) : super(key: key);
//
//   @override
//   State<MissedApprovalItem> createState() => _MissedApprovalItemState();
// }
//
// class _MissedApprovalItemState extends State<MissedApprovalItem> {
//   late Timer _timer;
//   int _secondsRemaining = 120;
//   bool _isRetryEnabled = false;
//
//   @override
//   void initState() {
//     super.initState();
//     startTimer();
//   }
//
//   void startTimer() {
//     _secondsRemaining = 120;
//     _isRetryEnabled = false;
//     _timer = Timer.periodic(Duration(seconds: 1), (timer) {
//       setState(() {
//         if (_secondsRemaining > 0) {
//           _secondsRemaining--;
//         } else {
//           _timer.cancel();
//           _isRetryEnabled = true;
//         }
//       });
//     });
//   }
//
//   String get formattedTime {
//     int minutes = _secondsRemaining ~/ 60;
//     int seconds = _secondsRemaining % 60;
//     return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
//   }
//
//   @override
//   void dispose() {
//     _timer.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     String unitList = '';
//     if (widget.visitorLog.visitor_building_assignment != null &&
//         widget.visitorLog.visitor_building_assignment!.isNotEmpty) {
//       unitList = widget.visitorLog.visitor_building_assignment!
//           .expand((assignment) => assignment.unit_id ?? [])
//           .map((unit) => unit.toString())
//           .join(', ');
//     }
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Card(
//         elevation: 2,
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             ListTile(
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 2,
//               ),
//               leading: CircleAvatar(
//                 backgroundImage: widget.visitorLog.visitor!.visitor_image.isNotEmpty
//                     ? NetworkImage(widget.visitorLog.visitor!.visitor_image)
//                     : NetworkImage(
//                     'https://images.unsplash.com/photo-1731778572747-315c9089bc69?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
//                 child: widget.visitorLog.visitor!.visitor_image.isEmpty
//                     ? Text(
//                   widget.visitorLog.visitor!.name.isNotEmpty
//                       ? widget.visitorLog.visitor!.name[0]
//                       : 'G',
//                   style: Theme.of(context).textTheme.bodyMedium,
//                 )
//                     : null,
//               ),
//               title: Text(
//                 widget.visitorLog.visitor!.name,
//                 style: Theme.of(context).textTheme.bodyMedium,
//               ),
//               subtitle: Padding(
//                 padding: const EdgeInsets.only(top: 5),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Symbols.apartment,
//                       color: Color(0xffFFB080),
//                     ),
//                     SizedBox(width: 8),
//                     Container(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 7,
//                         vertical: 2,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Color(0xffFFEBE6),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Text(
//                         'Guest',
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontWeight: FontWeight.w500,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Divider(
//               indent: 16,
//               endIndent: 16,
//               color: Colors.grey[200],
//             ),
//             Container(
//               padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   // Timer display
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: _isRetryEnabled ? Colors.red.shade100 : Colors.grey.shade100,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       _isRetryEnabled ? 'Time Expired' : formattedTime,
//                       style: TextStyle(
//                         color: _isRetryEnabled ? Colors.red : Colors.grey[800],
//                         fontWeight: FontWeight.w600,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   // Retry button
//                   ElevatedButton.icon(
//                     onPressed: _isRetryEnabled
//                         ? () {
//                       // Add your retry logic here
//                       startTimer();
//                     }
//                         : null,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: _isRetryEnabled ? Colors.blue : Colors.grey,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     icon: Icon(Icons.refresh, color: Colors.white),
//                     label: Text(
//                       'Retry',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }