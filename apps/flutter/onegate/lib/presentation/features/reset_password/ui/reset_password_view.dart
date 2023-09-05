// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/presentation/features/reset_password/bloc/reset_password_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:page_transition/page_transition.dart';
import 'package:common_widgets/common_widgets.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  TextEditingController? passwordTextCtrl;
  TextEditingController? confirmPasswordTextCtrl;
  final GlobalKey<FormState> _resetPasswordFormKey = GlobalKey<FormState>();
  late bool passwordVisibility;
  late bool confirmPasswordVisibility;

  @override
  void initState() {
    super.initState();
    passwordTextCtrl = TextEditingController();
    confirmPasswordTextCtrl = TextEditingController();
    passwordVisibility = true;
    confirmPasswordVisibility = true;
  }

  void _submitResetPasswordForm() {
    if (_resetPasswordFormKey.currentState?.validate() ?? false) {
      // passwordTextCtrl!.clear();
      // confirmPasswordTextCtrl!.clear();
      // passwordTextCtrl!.clear();
      // confirmPasswordTextCtrl!.clear();      // passwordTextCtrl!.clear();
      // confirmPasswordTextCtrl!.clear();
    }
  }

  @override
  void dispose() {
    passwordTextCtrl?.dispose();
    confirmPasswordTextCtrl?.dispose();
    super.dispose();
  }

  final ResetPasswordBloc resetPasswordBloc = ResetPasswordBloc();
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ResetPasswordBloc, ResetPasswordState>(
      bloc: resetPasswordBloc,
      listenWhen: (previous, current) => current is ResetPasswordActionState,
      buildWhen: (previous, current) => current is! ResetPasswordActionState,
      listener: (context, state) {
        if (state is ResetPasswordButtonPressedState) {}
      },
      builder: (context, state) {
        return MyScrollView(
          hasBackButton: true,
          pageBody: Column(
            children: [
              Lottie.network(
                'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/reset_Password_Animation_87a0052bcd.json?updated_at=2023-08-23T06:28:52.178Z',
                height: 200,
                width: double.infinity,
              ),
              ListTile(
                contentPadding: EdgeInsets.only(bottom: 10),
                title: Text(
                  'Create \nNew Password',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
              Form(
                key: _resetPasswordFormKey,
                child: Column(
                  children: [
                    CustomForm.textField(
                      textController: passwordTextCtrl,
                      focusedColor: Theme.of(context).colorScheme.onPrimary,
                      'Password',
                      hintText: '**********',
                      isObscureText: passwordVisibility,
                      keyboardType: TextInputType.visiblePassword,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            passwordVisibility = !passwordVisibility;
                          });
                        },
                        icon: Icon(
                          passwordVisibility
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                    CustomForm.textField(
                      textController: confirmPasswordTextCtrl,
                      focusedColor: Theme.of(context).colorScheme.onPrimary,
                      'Confirm Password',
                      hintText: '**********',
                      isObscureText: confirmPasswordVisibility,
                      keyboardType: TextInputType.visiblePassword,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            confirmPasswordVisibility =
                                !confirmPasswordVisibility;
                          });
                        },
                        icon: Icon(
                          confirmPasswordVisibility
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(top: 20, bottom: 80),
                child: CustomLargeBtn(
                  onPressed: () {
                    _submitResetPasswordForm();
                    // Navigator.push(
                    //   context,
                    //   PageTransition(
                    //     type: PageTransitionType.rightToLeft,
                    //     child: LoginInView(),
                    //   ),
                    // );
                  },
                  text: 'RESET PASSWORD',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
