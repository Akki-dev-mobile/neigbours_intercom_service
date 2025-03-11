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
      appBar: AppBar(title: const Text('Enter Passcode')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Form(
              key: passcodeControllerFormKey,
              child: CustomForm.textField(
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Passcode is required';
                  } else if (value.length != 6) {
                    return 'Please enter a 6-digit passcode';
                  }
                  return null;
                },
                titleColor: Theme.of(context).colorScheme.onSurface,
                hintColor: Theme.of(context).colorScheme.onPrimary,
                "Visitor Passcode",
                hintText: '123456',
                textController: passcodeController,
                textCapitalization: TextCapitalization.characters,
                length: 6,
                keyboardType: TextInputType.number,
                // prefixIcon: Padding(
                //   padding: const EdgeInsets.only(left: 10, right: 20),
                //   child: CircleAvatar(
                //     backgroundColor: const Color(0xffFFEBE6),
                //     child: Text(
                //       selectedPassAlpha,
                //       style: const TextStyle(
                //         color: Colors.black,
                //         fontWeight: FontWeight.bold,
                //       ),
                //     ),
                //   ),
                // ),
                suffixIcon: IconButton(
                  onPressed: () {
                    if (passcodeControllerFormKey.currentState!.validate()) {
                      // Optionally handle immediate validation
                    }
                  },
                  icon: Icon(
                    Symbols.done_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ChipsChoice<String>.single(
            //   padding: const EdgeInsets.symmetric(horizontal: 20),
            //   spacing: 20,
            //   choiceStyle: C2ChipStyle.outlined(
            //     borderWidth: 1,
            //     color: Colors.grey,
            //     selectedStyle: C2ChipStyle.outlined(
            //       overlayColor: const Color(0x90C08261),
            //       color: const Color(0xff0c08261),
            //     ),
            //   ),
            //   choiceCheckmark: true,
            //   value: selectedPassAlpha,
            //   scrollPhysics: const BouncingScrollPhysics(),
            //   onChanged: (value) {
            //     setState(() {
            //       selectedPassAlpha = value;
            //     });
            //   },
            //   choiceItems: C2Choice.listFrom<String, String>(
            //     source: listPassAlpha,
            //     value: (i, v) => v,
            //     label: (i, v) => v,
            //   ),
            // ),
            const SizedBox(height: 30),
            CustomLargeBtn(
              text: isLoading ? 'Verifying...' : 'Next',
              onPressed: () async {
                if (passcodeControllerFormKey.currentState?.validate() ??
                    false) {
                  startLoading();

                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final companyId = prefs.getString('company_id');

                    final result = await remoteDataSource.verifyPasscode(
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
                        MaterialPageRoute(builder: (_) => const SelfHomeView()),
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
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
