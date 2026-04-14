import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

/// Screen where user enters email to receive a password reset link.
/// Calls API: [ApiUrls.forgotPassword] (POST with email) – backend/Keycloak sends the reset link.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _remoteDataSource = RemoteDataSource();
  bool _isSubmitting = false;
  String _selectedDialCode = '+91';
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;

  int _step = 1; // 1: request OTP, 2: verify OTP, 3: reset password
  String? _fpAuthCode;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _usernameController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final normalizedMobile =
          _normalizeMobileWithCountryCode(_usernameController.text, _selectedDialCode);
      if (_step == 1) {
        // Step 1: Request OTP
        final ok = await _remoteDataSource.requestForgotPasswordOtp(
          username: normalizedMobile,
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (ok) {
          setState(() => _step = 2);
          _startResendTimer();
          _showSuccessSnackBar('OTP is sent. Please check your mobile / email.');
        } else {
          _showErrorSnackBar('Could not send OTP. Please try again.');
        }
      } else if (_step == 2) {
        // Step 2: Verify OTP
        final result = await _remoteDataSource.verifyForgotPasswordOtp(
          username: normalizedMobile,
          otp: _otpController.text.trim(),
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (result.success && result.fpAuthCode != null) {
          _fpAuthCode = result.fpAuthCode;
          setState(() => _step = 3);
          _showSuccessSnackBar('OTP verified. Please set your new password.');
        } else {
          final msg = result.message ?? 'Invalid OTP. Please try again.';
          _showErrorSnackBar(msg);
        }
      } else if (_step == 3) {
        // Step 3: Reset password
        final fpCode = _fpAuthCode;
        if (fpCode == null) {
          setState(() => _isSubmitting = false);
          _showErrorSnackBar('Something went wrong. Please restart the flow.');
          return;
        }
        final ok = await _remoteDataSource.resetForgotPassword(
          username: normalizedMobile,
          fpAuthCode: fpCode,
          password: _passwordController.text,
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (ok) {
          _showSuccessSnackBar(
            'Password reset successful. You can now login with your new password.',
          );
          Navigator.pop(context);
        } else {
          _showErrorSnackBar('Could not reset password. Please try again.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _resendOtp() async {
    if (_isSubmitting) return;
    final mobile = _usernameController.text.trim();
    if (mobile.isEmpty) {
      _showErrorSnackBar('Please enter your mobile number first.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final normalizedMobile =
          _normalizeMobileWithCountryCode(mobile, _selectedDialCode);
      final ok = await _remoteDataSource.requestForgotPasswordOtp(
        username: normalizedMobile,
      );
      if (!mounted) return;
      if (ok) {
        _startResendTimer();
        _showSuccessSnackBar('OTP is sent. Please check your mobile / email.');
      } else {
        _showErrorSnackBar('Could not send OTP. Please try again.');
      }
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar('Could not send OTP. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _primaryActionLabel() {
    if (_isSubmitting) return 'PLEASE WAIT...';
    switch (_step) {
      case 1:
        return 'SEND OTP';
      case 2:
        return 'VERIFY OTP';
      case 3:
        return 'RESET PASSWORD';
      default:
        return 'CONTINUE';
    }
  }

  String _stepTitle(AppLocalizations l10n) {
    switch (_step) {
      case 1:
        return l10n.forgotPassword;
      case 2:
        return 'Verify OTP';
      case 3:
        return 'Set New Password';
      default:
        return l10n.forgotPassword;
    }
  }

  String _stepSubtitle() {
    switch (_step) {
      case 1:
        return 'Enter your registered mobile number to receive an OTP.';
      case 2:
        return 'Enter the OTP sent to your registered mobile number.';
      case 3:
        return 'Create a strong password and confirm it to secure your account.';
      default:
        return '';
    }
  }

  String _normalizeMobileWithCountryCode(String raw, String dialCode) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final countryDigits = dialCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty || countryDigits.isEmpty) return digitsOnly;

    if (digitsOnly.startsWith(countryDigits)) {
      return digitsOnly;
    }
    return '$countryDigits$digitsOnly';
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 59);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining -= 1);
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xffF44336),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 8,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Success',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height + MediaQuery.of(context).padding.top,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xffF44336).withOpacity(0.12),
              const Color(0xffff5722).withOpacity(0.05),
              Colors.white.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12),
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
                            backgroundColor: Colors.white.withOpacity(0.65),
                          ),
                          icon: const Icon(Icons.arrow_back, color: Color(0xff212427)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AuthHeaderLogo(),
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
                          color: Colors.grey.withOpacity(0.12),
                          spreadRadius: 3,
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          spreadRadius: 1,
                          blurRadius: 15,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xffF44336).withOpacity(0.08),
                                  const Color(0xffff5722).withOpacity(0.03),
                                ],
                              ),
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                                    color: const Color(0xffF44336).withOpacity(0.15),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _stepTitle(l10n),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xff212427),
                                              fontSize: 20,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _stepSubtitle(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xff57636C),
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
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildThinField(
                                  context,
                                  title: 'Mobile',
                                  controller: _usernameController,
                                  hintText: 'Enter your mobile number',
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  maxLength: 10,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  prefixWidget: CountryCodePicker(
                                    initialSelection: _selectedDialCode,
                                    favorite: const ['IN'],
                                    showFlagMain: true,
                                    showFlagDialog: true,
                                    alignLeft: false,
                                    textStyle: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.onBackground,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    onChanged: (code) {
                                      setState(() {
                                        _selectedDialCode = code.dialCode ?? '+91';
                                      });
                                    },
                                  ),
                                  onFieldSubmitted: (_) => _handleSubmit(),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Please enter your registered mobile number';
                                    }
                                    if (v.trim().length != 10) {
                                      return 'Please enter valid mobile number';
                                    }
                                    return null;
                                  },
                                ),
                                if (_step == 2) ...[
                                  const SizedBox(height: 16),
                                  _buildThinField(
                                    context,
                                    title: 'OTP',
                                    controller: _otpController,
                                    hintText: 'Enter the OTP',
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _handleSubmit(),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter the OTP you received';
                                      }
                                      if (v.trim().length < 4) {
                                        return 'OTP should be at least 4 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final isResendDisabled =
                                          _isSubmitting || _resendSecondsRemaining > 0;
                                      return Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed:
                                              isResendDisabled ? null : _resendOtp,
                                          style: ButtonStyle(
                                            foregroundColor:
                                                WidgetStateProperty.resolveWith<Color>(
                                              (states) {
                                                if (states.contains(WidgetState.disabled)) {
                                                  return const Color(0xffF44336)
                                                      .withOpacity(0.55);
                                                }
                                                return const Color(0xffF44336);
                                              },
                                            ),
                                          ),
                                          child: Text(
                                            _resendSecondsRemaining > 0
                                                ? 'Resend password in ${_resendSecondsRemaining}s'
                                                : 'Resend password',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                                if (_step == 3) ...[
                                  const SizedBox(height: 16),
                                  _buildThinField(
                                    context,
                                    title: 'New Password',
                                    controller: _passwordController,
                                    hintText: 'Enter new password',
                                    isObscureText: true,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please enter a new password';
                                      }
                                      if (v.length < 8) {
                                        return 'Password should be at least 8 characters';
                                      }
                                      // if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\\d).+$')
                                      //     .hasMatch(v)) {
                                      //   return 'Use a mix of letters and numbers';
                                      // }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildThinField(
                                    context,
                                    title: 'Confirm Password',
                                    controller: _confirmPasswordController,
                                    hintText: 'Re-enter new password',
                                    isObscureText: true,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _handleSubmit(),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please confirm your new password';
                                      }
                                      if (v != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 20),
                                IgnorePointer(
                                  ignoring: _isSubmitting,
                                  child: Opacity(
                                    opacity: _isSubmitting ? 0.7 : 1,
                                    child: Container(
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
                                            color: const Color(0xff212427).withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleSubmit,
                                          borderRadius: BorderRadius.circular(16),
                                          child: Center(
                                            child: Text(
                                              _primaryActionLabel(),
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
  }

  Widget _buildThinField(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required String hintText,
    bool isObscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onFieldSubmitted,
    int maxLength = 499,
    List<TextInputFormatter>? inputFormatters,
    Widget? prefixWidget,
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
          controller: controller,
          cursorColor: const Color(0xffF44336),
          keyboardType: keyboardType ?? TextInputType.text,
          obscureText: isObscureText,
          textInputAction: textInputAction ?? TextInputAction.next,
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
          ),
          maxLength: maxLength,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 15,
            ),
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: prefixWidget,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xffF44336),
                width: 0.8,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xffF44336),
                width: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

}

class _AuthHeaderLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.27,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffF44336).withOpacity(0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/media/images/onegate.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Smart Gate Management',
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
