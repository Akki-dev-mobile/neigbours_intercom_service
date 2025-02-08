import 'dart:async';
import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/widgets/info_list_tile_widget.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../dio_setup.dart';

class ParcelDetails extends StatelessWidget {
  final Map<String, dynamic> parcel;

  ParcelDetails({Key? key, required this.parcel}) : super(key: key);
  RemoteDataSource remoteDataSource = RemoteDataSource(

  );

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
        pageTitle: 'Parcel Details',
        pageBody: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.maxFinite,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: const BorderRadius.all(
                  Radius.circular(20),
                ),
                image: parcel['parcel_image'].isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(
                          parcel['parcel_image'],
                        ),
                      )
                    : null,
              ),
              // parcel['parcel_image'].isNotEmpty
              //     ? NetworkImage(
              //         parcel['parcel_image'],
              //         height: MediaQuery.of(context).size.height * 0.4,
              //         width: double.maxFinite,
              //         fit: BoxFit.contain,
              //       )
              //     : Center(
              //         child: CircleAvatar(
              //           radius: 80,
              //           backgroundColor: Theme.of(context).colorScheme.primary,
              //           child: Text(
              //             parcel['visitor_image'],
              //             style: const TextStyle(
              //               fontSize: 60,
              //               color: Colors.white,
              //               fontWeight: FontWeight.bold,
              //             ),
              //           ),
              //         ),
              //       ),
            ),
            SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                parcel['member_name'] ?? 'No Name',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xffFFEBE6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        parcel['purpose_sub_category_name'].toString() ?? 'NA'),
                  ),
                ],
              ),
            ),
            InfoListTileWidget(
              icon: Ionicons.call_outline,
              iconColor: Colors.green,
              title: 'Phone Number',
              subtitle: parcel['visitor_mobile'] ?? 'No Number',
              trailing: ElevatedButton.icon(
                icon: Icon(Icons.call, size: 18),
                label: const Text('Call'),
                onPressed: () => _makePhoneCall(parcel['visitor_mobile'] ?? ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            InfoListTileWidget(
              icon: Ionicons.calendar_outline,
              iconColor: Colors.green,
              title: 'Unit Name',
              subtitle: parcel['unit_name'] ?? 'N/A',
            ),
            InfoListTileWidget(
              icon: Ionicons.time_outline,
              iconColor: Colors.green,
              title: 'Check In',
              subtitle: parcel['log_created_at'] ?? 'No Time',
              subTitleStyle: TextStyle(color: Colors.green),
            ),
            InfoListTileWidget(
              icon: Ionicons.time_outline,
              iconColor: Colors.red,
              title: 'Parcel Picked AT',
              subtitle: parcel['log_veified_at'] ?? 'No Time',
              subTitleStyle: TextStyle(color: Colors.red),
            ),
            InfoListTileWidget(
              icon: Symbols.delivery_truck_speed,
              iconColor: parcel['parcel_status'] == 'picked'
                  ? Colors.green
                  : Colors.red,
              title: 'Parcel Status',
              subtitle: parcel['parcel_status'] ?? 'N/A',
              subTitleStyle: TextStyle(
                  color: parcel['parcel_status'] == 'picked'
                      ? Colors.green
                      : Colors.red),
            ),
            const SizedBox(height: 150),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: CustomLargeBtn(
          onPressed: () {
            TextEditingController otpController = TextEditingController();
            remoteDataSource.getParcelOtp(
              parcel['parcel_id'].toString(),
              parcel['memb_mobile_number'].toString(),
            );
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext context) {
                return OtpBottomSheet(
                  remoteDataSource: remoteDataSource,
                  parcel: parcel,
                  otpController: otpController,
                );
              },
            );
          },
          text: 'Mark as Delivered',
        ));
  }
}

Widget _buildDetailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
              ),
        ),
      ],
    ),
  );
}

class OtpBottomSheet extends StatefulWidget {
  final RemoteDataSource remoteDataSource;
  final Map<String, dynamic> parcel;
  final TextEditingController otpController;

  OtpBottomSheet({
    required this.remoteDataSource,
    required this.parcel,
    required this.otpController,
  });

  @override
  _OtpBottomSheetState createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<OtpBottomSheet> {
  int _timer = 0;
  Timer? _countdownTimer;

  void _startTimer() {
    setState(() {
      _timer = 5;
    });
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timer > 0) {
        setState(() {
          _timer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enter OTP',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Container(
              height: MediaQuery.of(context).size.height * 0.07,
              width: MediaQuery.of(context).size.width * 0.9,
              child: Pinput(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                length: 6,
                onCompleted: (String pin) {
                  print("Completed: $pin");
                },
                focusNode: FocusNode(),
                controller: widget.otpController,
                submittedPinTheme: PinTheme(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                followingPinTheme: PinTheme(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _timer == 0
                      ? () {
                          widget.remoteDataSource.getParcelOtp(
                            widget.parcel['parcel_id'].toString(),
                            widget.parcel['memb_mobile_number'].toString(),
                          );
                          _startTimer();
                        }
                      : null,
                  child: Text(
                    _timer == 0 ? 'Resend' : 'Resend in $_timer sec',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      String otp = widget.otpController.text;
                      try {
                        final result =
                            await widget.remoteDataSource.verifyParcelOtp(
                          widget.parcel['parcel_id'].toString(),
                          otp,
                        );
                        Fluttertoast.showToast(
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                          fontSize: 16.0,
                          msg: result['message'],
                        );
                        log("OTP verified: $result");
                      } catch (e) {
                        log("OTP verification failed: $e");
                        Fluttertoast.showToast(
                          msg: 'Invalid OTP',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                      }
                      Navigator.of(context).pop();
                    },
                    label: Text(
                      'Submit',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.surface),
                    ),
                    icon: Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
