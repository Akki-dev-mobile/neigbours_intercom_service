import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/presentation/features/auth/bloc/login_bloc.dart';
import 'package:flutter_onegate/presentation/features/forgot_password/ui/forgot_password_view.dart';
import 'package:flutter_onegate/presentation/features/request_gate_access/ui/request_gate_access_view.dart';

/// User-friendly message for known error patterns.
String _mapErrorMessage(String? raw) {
  if (raw == null || raw.isEmpty) return 'Something went wrong. Please try again.';
  final lower = raw.toLowerCase();
  if (lower.contains('invalid') && (lower.contains('credential') || lower.contains('password'))) {
    return 'Incorrect mobile or password.';
  }
  if (lower.contains('locked') || lower.contains('disabled')) {
    return 'Your account is locked. Contact your administrator.';
  }
  if (lower.contains('timeout') || lower.contains('connection') || lower.contains('network')) {
    return "We're having trouble connecting. Please retry.";
  }
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return 'Incorrect mobile or password.';
  }
  return raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
}

/// Native login form: Mobile/Email, Password, validation, Login button, Sign up & Forgot password.
class NativeLoginForm extends StatefulWidget {
  const NativeLoginForm({Key? key}) : super(key: key);

  @override
  State<NativeLoginForm> createState() => _NativeLoginFormState();
}

class _NativeLoginFormState extends State<NativeLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedDialCode = '+91';

  static const _minPasswordLength = 1;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_handleFieldChange);
    _passwordController.addListener(_handleFieldChange);
  }

  void _handleFieldChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _usernameController.removeListener(_handleFieldChange);
    _passwordController.removeListener(_handleFieldChange);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final u = _usernameController.text.trim();
    final p = _passwordController.text;
    return u.isNotEmpty && p.length >= _minPasswordLength;
  }

  void _submit() {
    if (!_isFormValid) return;
    final normalizedMobile =
        _normalizeMobileWithCountryCode(_usernameController.text, _selectedDialCode);
    context.read<LoginBloc>().add(
          LoginButtonPressedEvent(
            normalizedMobile,
            _passwordController.text,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      buildWhen: (prev, curr) =>
          curr is LoginInitial ||
          curr is LoginLoadingState ||
          curr is LoginErrorState,
      builder: (context, state) {
        final isLoading = state is LoginLoadingState;
        final errorMessage = state is LoginErrorState ? state.message : null;
        final showLoader = isLoading && errorMessage == null;

        return Container(
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
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LoginHeader(),
                    const SizedBox(height: 20),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _LoginFormCard(
                        formKey: _formKey,
                        usernameController: _usernameController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                        errorMessage: errorMessage != null ? _mapErrorMessage(errorMessage) : null,
                        isLoading: isLoading,
                        showLoader: showLoader,
                        isFormValid: _isFormValid,
                        onSubmit: _submit,
                        selectedDialCode: _selectedDialCode,
                        onCountryCodeChanged: (dialCode) {
                          setState(() => _selectedDialCode = dialCode);
                        },
                        onSignUpPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RequestGateAccess(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.32,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
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
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
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

class _LoginFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final String? errorMessage;
  final bool isLoading;
  final bool showLoader;
  final bool isFormValid;
  final VoidCallback onSubmit;
  final String selectedDialCode;
  final ValueChanged<String> onCountryCodeChanged;
  final VoidCallback onSignUpPressed;

  const _LoginFormCard({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.errorMessage,
    required this.isLoading,
    required this.showLoader,
    required this.isFormValid,
    required this.onSubmit,
    required this.selectedDialCode,
    required this.onCountryCodeChanged,
    required this.onSignUpPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: (errorMessage != null ? const Color(0xffF44336) : Colors.grey).withOpacity(0.12),
            spreadRadius: errorMessage != null ? 2 : 3,
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
        key: formKey,
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.login_rounded,
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
                          'Welcome Back!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff212427),
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in with your mobile number',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  if (errorMessage != null) ...[
                    _ErrorBanner(message: errorMessage!),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 4),
                  _buildThinBorderField(
                    context,
                    title: 'Mobile',
                    controller: usernameController,
                    hintText: 'Enter mobile number',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixWidget: CountryCodePicker(
                      initialSelection: selectedDialCode,
                      favorite: const ['IN'],
                      showFlagMain: true,
                      showFlagDialog: true,
                      alignLeft: false,
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (code) {
                        onCountryCodeChanged(code.dialCode ?? '+91');
                      },
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter mobile number';
                      }
                      if (v.trim().length != 10) {
                        return 'Enter valid mobile number';
                      }
                      return null;
                    },
                    onChanged: (_) => (context as Element).markNeedsBuild(),
                  ),
                  const SizedBox(height: 16),
                  _buildThinBorderField(
                    context,
                    title: 'Password',
                    controller: passwordController,
                    hintText: 'Enter password',
                    isObscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _trySubmit(),
                    suffixIcon: IconButton(
                      icon:
                          Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: onToggleObscure,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      return null;
                    },
                    onChanged: (_) => (context as Element).markNeedsBuild(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordView(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: const Color(0xffF44336),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    enabled: isFormValid && !isLoading,
                    label: showLoader ? 'Signing in' : 'Sign in with mobile number',
                    child: IgnorePointer(
                      ignoring: !isFormValid || isLoading,
                      child: Opacity(
                        opacity: (!isFormValid || isLoading) ? 0.6 : 1,
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
                              onTap: _trySubmit,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
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
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xff57636C),
                              fontSize: 15,
                            ),
                      ),
                      InkWell(
                        onTap: onSignUpPressed,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Sign Up',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xffF44336),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _trySubmit() {
    if (formKey.currentState?.validate() ?? false) {
      onSubmit();
    }
  }

  Widget _buildThinBorderField(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required String hintText,
    bool isObscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
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
          onChanged: onChanged,
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

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Error: $message',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xffF44336).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffF44336).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
