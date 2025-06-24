import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasscodeEntryView extends StatefulWidget {
  final bool selfcheckinFlow;

  const PasscodeEntryView({super.key, this.selfcheckinFlow = false});

  @override
  State<PasscodeEntryView> createState() => _PasscodeEntryViewState();
}

class _PasscodeEntryViewState extends State<PasscodeEntryView> {
  final passcodeController = TextEditingController();
  final passcodeControllerFormKey = GlobalKey<FormState>();
  bool isLoading = false;
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  List<String> listPassAlpha = ['G', 'S', 'A'];
  String selectedPassAlpha = 'A';

  void startLoading() => setState(() => isLoading = true);

  void stopLoading() => setState(() => isLoading = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Enter Passcode'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xff212427),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Enhanced Passcode Field Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header Section with Icon and Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Visitor Passcode',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff212427),
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xffF44336),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Enter your 6-digit passcode to continue',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xff57636C),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Input Field Section
                  Container(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: Form(
                      key: passcodeControllerFormKey,
                      child: TextFormField(
                        controller: passcodeController,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.characters,
                        cursorColor: Colors.black,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff212427),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Passcode is required';
                          } else if (value.length != 6) {
                            return 'Please enter a 6-digit passcode';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: '123456',
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xff57636C),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF44336).withOpacity(0.02),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: const Color(0xffF44336).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: const Color(0xffF44336).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xffF44336),
                              width: 2,
                            ),
                          ),
                          counterText: '',
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            child: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              radius: 20,
                              child: IconButton(
                                onPressed: () {
                                  if (passcodeControllerFormKey.currentState!
                                      .validate()) {
                                    // Optionally handle immediate validation
                                  }
                                },
                                icon: const Icon(
                                  Symbols.done_rounded,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Enhanced Next Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              width: MediaQuery.of(context).size.width * 0.85,
              height: 60,
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all<Color>(Colors.transparent),
                  elevation: WidgetStateProperty.all<double>(0),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (passcodeControllerFormKey.currentState
                                ?.validate() ??
                            false) {
                          startLoading();

                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final companyId = prefs.getString('company_id');

                            final result =
                                await remoteDataSource.verifyPasscode(
                              companyId: companyId ?? "",
                              passcode: passcodeController.text,
                            );

                            stopLoading();

                            if (result['success'] == true) {
                              myFluttertoast(
                                msg: "Passcode verified successfully!",
                                backgroundColor: Colors.green,
                              );

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SelfHomeView()),
                              );
                            } else {
                              myFluttertoast(
                                msg: "Invalid passcode. Try again.",
                                backgroundColor: Colors.red,
                              );
                            }
                          } catch (e) {
                            stopLoading();
                            myFluttertoast(
                              msg: "Error verifying passcode: $e",
                              backgroundColor: Colors.red,
                            );
                          }
                        }
                      },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff212427), Color(0xff57636C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              wordSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
