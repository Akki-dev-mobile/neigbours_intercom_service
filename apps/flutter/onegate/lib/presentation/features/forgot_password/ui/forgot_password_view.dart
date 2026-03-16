import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
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

  int _step = 1; // 1: request OTP, 2: verify OTP, 3: reset password
  String? _fpAuthCode;

  @override
  void dispose() {
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
      if (_step == 1) {
        // Step 1: Request OTP
        final ok = await _remoteDataSource.requestForgotPasswordOtp(
          username: _usernameController.text.trim(),
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (ok) {
          setState(() => _step = 2);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent. Please check your mobile/email.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not send OTP. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (_step == 2) {
        // Step 2: Verify OTP
        final result = await _remoteDataSource.verifyForgotPasswordOtp(
          username: _usernameController.text.trim(),
          otp: _otpController.text.trim(),
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (result.success && result.fpAuthCode != null) {
          _fpAuthCode = result.fpAuthCode;
          setState(() => _step = 3);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP verified. Please set your new password.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final msg = result.message ?? 'Invalid OTP. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (_step == 3) {
        // Step 3: Reset password
        final fpCode = _fpAuthCode;
        if (fpCode == null) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Something went wrong. Please restart the flow.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        final ok = await _remoteDataSource.resetForgotPassword(
          username: _usernameController.text.trim(),
          fpAuthCode: fpCode,
          password: _passwordController.text,
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset successful. You can now login with your new password.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not reset password. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
        return 'Enter your registered mobile number or email to receive an OTP.';
      case 2:
        return 'Enter the OTP sent to your registered mobile/email.';
      case 3:
        return 'Create a strong password and confirm it to secure your account.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MyScrollView(
      backButtonPressed: () => Navigator.pop(context),
      hasBackButton: true,
      pageBody: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(bottom: 10),
            title: Text(
              _stepTitle(l10n),
              style: Theme.of(context).textTheme.displayLarge,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _stepSubtitle(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomForm.textField(
                  'Mobile / Email',
                  textController: _usernameController,
                  hintText: 'Enter your registered mobile or email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSubmit(),
                  titleColor: Theme.of(context).colorScheme.onBackground,
                  hintColor: Theme.of(context).colorScheme.onPrimary,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your registered mobile or email';
                    }
                    return null;
                  },
                ),
                if (_step == 2) ...[
                  const SizedBox(height: 16),
                  CustomForm.textField(
                    'OTP',
                    textController: _otpController,
                    hintText: 'Enter the OTP',
                    keyboardType: TextInputType.number,
                    textInputAction: _step == 2 ? TextInputAction.done : TextInputAction.next,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    titleColor: Theme.of(context).colorScheme.onBackground,
                    hintColor: Theme.of(context).colorScheme.onPrimary,
                    validator: (v) {
                      if (_step == 1) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter the OTP you received';
                      }
                      if (v.trim().length < 4) {
                        return 'OTP should be at least 4 digits';
                      }
                      return null;
                    },
                  ),
                ],
                if (_step == 3) ...[
                  const SizedBox(height: 16),
                  CustomForm.textField(
                    'New Password',
                    textController: _passwordController,
                    hintText: 'Enter new password',
                    isObscureText: true,
                    textInputAction: TextInputAction.next,
                    titleColor: Theme.of(context).colorScheme.onBackground,
                    hintColor: Theme.of(context).colorScheme.onPrimary,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (v.length < 8) {
                        return 'Password should be at least 8 characters';
                      }
                      if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(v)) {
                        return 'Use a mix of letters and numbers';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomForm.textField(
                    'Confirm Password',
                    textController: _confirmPasswordController,
                    hintText: 'Re-enter new password',
                    isObscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    titleColor: Theme.of(context).colorScheme.onBackground,
                    hintColor: Theme.of(context).colorScheme.onPrimary,
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
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 24, bottom: 80),
            child: CustomLargeBtn(
              onPressed: _isSubmitting ? null : _handleSubmit,
              text: _primaryActionLabel(),
            ),
          ),
        ],
      ),
    );
  }
}
