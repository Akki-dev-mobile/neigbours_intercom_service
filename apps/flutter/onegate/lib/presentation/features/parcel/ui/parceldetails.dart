import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter_onegate/presentation/features/parcel/ui/parcel_list.dart';
import 'package:intl/intl.dart';

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
  RemoteDataSource remoteDataSource = RemoteDataSource();

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
            // Image.network(parcel['parcel_image']),
            Center(
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(20),
                  ),
                  image: parcel['parcel_image'].isNotEmpty
                      ? DecorationImage(
                          fit: BoxFit.cover,
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
            ),
            const SizedBox(height: 16),
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
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffFFEBE6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      parcel['purpose_sub_category_name'].toString() ?? 'NA',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            _buildSection(
              title: "Contact Information",
              children: [
                _buildInfoTile(
                  icon: Ionicons.call_outline,
                  title: "Phone Number",
                  subtitle: parcel['visitor_mobile'] ?? 'No Number',
                  iconColor: Colors.green,
                  trailing: _buildCallButton(),
                ),
              ],
            ),
            _buildSection(
              title: "Unit Information",
              children: [
                _buildInfoTile(
                  icon: Icons.apartment,
                  title: "Unit Name",
                  subtitle: parcel['unit_name'] ?? 'N/A',
                  iconColor: const Color(0xffFFB080),
                ),
                _buildInfoTile(
                  icon: Icons.location_on,
                  title: "Coming From",
                  subtitle:
                      parcel['purpose_sub_category_name'].toString() ?? 'NA',
                  iconColor: const Color(0xffFFB080),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: "Parcel Timeline",
              children: [
                _buildTimelineTile(
                  "Parcel Check-in",
                  _parseTime(parcel['log_created_at'] ??
                          parcel['log_created_at']) ??
                      DateTime.now(),
                  Icons.login,
                  Colors.green,
                  isFirst: true,
                  isLast: parcel['parcel_status'] == "pending",
                ),
                // if (parcel['parcel_status'] != "pending")
                //   _buildTimelineTile(
                //     "Parcel Picked By",
                //     _parseTime(parcel['log_verified_at'] ??
                //             parcel['log_verified_at']) ??
                //         DateTime.now(),
                //     Symbols.box,
                //     const Color(0xffFFB080),
                //     isFirst: true,
                //     isLast: parcel['parcel_status'] == "pending",
                //   ),
                if (parcel['parcel_status'] != "pending") ...[
                  _buildTimelineTile(
                    "Parcel Picked at",
                    _parseTime(parcel['log_verified_at'] ??
                            parcel['log_verified_at']) ??
                        DateTime.now(),
                    Icons.logout,
                    Colors.red,
                    isFirst: false,
                    isLast: true,
                  ),
                ]
              ],
            ),
            const SizedBox(height: 150),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: parcel['parcel_status'] != "picked"
            ? CustomLargeBtn(
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
                text: 'Mark as Picked',
              )
            : const SizedBox());
  }

  DateTime? _parseTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return null;
    }
    try {
      return DateFormat('yyyy-MM-dd hh:mm:ss a').parse(timeString);
    } catch (e) {
      print('Date parsing failed: $e');
      return null;
    }
  }

  Widget _buildTimelineTile(
    String label,
    DateTime time,
    IconData icon,
    Color color, {
    required bool isFirst,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 12,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.grey.withOpacity(0.3),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(time),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (!isLast) const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.call, size: 16),
      label: const Text('Call'),
      onPressed: () => _makePhoneCall(parcel['visitor_mobile'] ?? ''),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

class OtpBottomSheet extends StatefulWidget {
  final RemoteDataSource remoteDataSource;
  final Map<String, dynamic> parcel;
  final TextEditingController otpController;

  const OtpBottomSheet({
    super.key,
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
  FocusNode focusNode = FocusNode();

  void _startTimer() {
    setState(() {
      _timer = 59;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
  void initState() {
    // TODO: implement initState
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String? errorText;

  void validateOTP(String pin) {
    if (pin.length < 6) {
      setState(() {
        errorText = "OTP must be 6 digits.";
      });
    } else {
      setState(() {
        errorText = null;
      });
      log("Completed: $pin");
    }
  }

  void onSubmit() {
    if (widget.otpController.text.length == 6) {
      log("OTP Submitted: ${widget.otpController.text}");
    } else {
      setState(() {
        errorText = "Please enter a valid 6-digit OTP.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  'Enter OTP',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                    padding: const EdgeInsets.only(bottom: 15),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.cancel,
                      color: Colors.red,
                      size: 20,
                    ))
              ],
            ),
            const SizedBox(height: 1),
            Text(
              'Enter OTP to pick parcel',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.07,
              width: MediaQuery.of(context).size.width * 0.9,
              child: Pinput(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                length: 6,
                onCompleted: validateOTP,
                onChanged: (pin) {
                  if (errorText != null) {
                    setState(() {
                      errorText = null;
                    });
                  }
                },
                focusNode: focusNode,
                controller: widget.otpController,
                submittedPinTheme: PinTheme(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                errorPinTheme: PinTheme(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
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
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            Center(
              child: TextButton(
                onPressed: _timer == 0 ? resendOtp : null,
                child: Text(
                  _timer == 0 ? 'Resend' : 'Resend in $_timer sec',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: submitOtp,

                    child: Text(
                      'Submit',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.surface),
                    ),
                    // icon: Icon(
                    //   Icons.check,
                    //   color: Theme.of(context).colorScheme.surface,
                    // ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }

  void resendOtp() async {
    try {
      await widget.remoteDataSource.getParcelOtp(
        widget.parcel['parcel_id'].toString(),
        "7666755466",
      );
      _startTimer();
      Fluttertoast.showToast(
        msg: 'OTP Resent Successfully',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to Resend OTP',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      log("Failed to resend OTP: $e");
    }
  }

  void submitOtp() async {
    String otp = widget.otpController.text;
    if (otp.length != 6) {
      setState(() {
        errorText = "Please enter a valid 6-digit OTP.";
      });
      return;
    }

    try {
      final result = await widget.remoteDataSource.verifyParcelOtp(
        widget.parcel['parcel_id'].toString(),
        otp,
      );

      Fluttertoast.showToast(
        msg: result['message'],
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      log("OTP verified: $result");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ParcelList()),
        (route) => false, // This removes all previous routes
      );
    } catch (e) {
      setState(() {
        errorText = "Invalid OTP.";
      });

      Fluttertoast.showToast(
        msg: 'Invalid OTP',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      log("OTP verification failed: $e");
    }
  }
}
