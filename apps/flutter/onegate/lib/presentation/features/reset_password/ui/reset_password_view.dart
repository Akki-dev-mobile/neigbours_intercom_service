// ignore_for_file: prefer_const_constructors

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/presentation/features/reset_password/bloc/reset_password_bloc.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:lottie/lottie.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  late final FocusNode _newPasswordFocusNode = FocusNode();
  late final FocusNode _confirmPasswordFocusNode = FocusNode();
  bool areTextFieldsFocused = false;
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
    _newPasswordFocusNode.addListener(_onFocusChange);
    _confirmPasswordFocusNode.addListener(_onFocusChange);
    passwordVisibility = true;
    confirmPasswordVisibility = true;
  }

  void _onFocusChange() {
    setState(() {
      areTextFieldsFocused =
          _newPasswordFocusNode.hasFocus || _confirmPasswordFocusNode.hasFocus;
    });
  }

  void _submitResetPasswordForm() {
    if (_resetPasswordFormKey.currentState?.validate() ?? false) {
      passwordTextCtrl!.clear();
      confirmPasswordTextCtrl!.clear();
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
        return Scaffold(
          backgroundColor: Colors.white,
          body: Container(
            height: MediaQuery.of(context).size.height +
                MediaQuery.of(context).padding.top,
            width: double.infinity,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.arrow_back,
                                  color: Color(0xff212427)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _ResetHeaderLogo(),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.28),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.18),
                              spreadRadius: 4,
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.12),
                              spreadRadius: 1,
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _resetPasswordFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xffF44336).withOpacity(0.08),
                                      const Color(0xffff5722).withOpacity(0.03),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(24)),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.25),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF44336)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.lock_reset_rounded,
                                        color: Color(0xffF44336),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            context.tr('Set New Password'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xff212427),
                                                  fontSize: 20,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            context.tr(
                                              'resetPasswordSubtitleCreateStrongPassword',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      const Color(0xff57636C),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildThinField(
                                      context,
                                      title: context.tr('Password'),
                                      controller: passwordTextCtrl!,
                                      hintText: context.tr('**********'),
                                      focusNode: _newPasswordFocusNode,
                                      isObscureText: passwordVisibility,
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            passwordVisibility =
                                                !passwordVisibility;
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
                                    const SizedBox(height: 16),
                                    _buildThinField(
                                      context,
                                      title: context.tr('Confirm Password'),
                                      controller: confirmPasswordTextCtrl!,
                                      hintText: context.tr('**********'),
                                      focusNode: _confirmPasswordFocusNode,
                                      isObscureText: confirmPasswordVisibility,
                                      keyboardType:
                                          TextInputType.visiblePassword,
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
                                    const SizedBox(height: 20),
                                    Container(
                                      width: double.infinity,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xff212427),
                                            Color(0xff57636C),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xff212427)
                                                .withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            _submitResetPasswordForm();
                                            Navigator.pop(context);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Center(
                                            child: Text(
                                              context.tr('RESET PASSWORD'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThinField(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required String hintText,
    FocusNode? focusNode,
    bool isObscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    final titleColor = Theme.of(context).colorScheme.onBackground;
    final hintColor = Theme.of(context).colorScheme.onPrimary;
    final borderColor = Colors.grey.withOpacity(0.45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          focusNode: focusNode,
          controller: controller,
          cursorColor: const Color(0xffF44336),
          keyboardType: keyboardType ?? TextInputType.text,
          obscureText: isObscureText,
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 15,
            ),
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: borderColor,
                width: 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: borderColor,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xffF44336),
                width: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetHeaderLogo extends StatelessWidget {
  const _ResetHeaderLogo();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = (screenWidth * 0.4).clamp(156.0, 210.0);
    final logoPadding = (logoSize * 0.06).clamp(6.0, 12.0);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.27,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xffE0E3E7),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff212427).withOpacity(0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xffF44336).withOpacity(0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(logoPadding),
                child: Image.asset(
                  'assets/media/images/onegate.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('smartGateManagementTagline'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xff57636C),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
