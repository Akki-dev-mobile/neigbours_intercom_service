// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/request_gate_access_bloc.dart';

class RequestGateAccess extends StatefulWidget {
  const RequestGateAccess({super.key});

  @override
  State<RequestGateAccess> createState() => _RequestGateAccessState();
}

class _RequestGateAccessState extends State<RequestGateAccess> {
  late final FocusNode _userNameFocusNode = FocusNode();
  late final FocusNode _mobileNumberFocusNode = FocusNode();
  late final FocusNode _societyNameFocusNode = FocusNode();
  bool areTextFieldsFocused = false;
  TextEditingController? clientNameTextCtrl;
  TextEditingController? mobileNumberTextCtrl;
  TextEditingController? clientSocietyTextCtrl;
  final GlobalKey<FormState> _requestAccessFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    clientNameTextCtrl = TextEditingController();
    mobileNumberTextCtrl = TextEditingController();
    clientSocietyTextCtrl = TextEditingController();
    _userNameFocusNode.addListener(_onFocusChange);
    _mobileNumberFocusNode.addListener(_onFocusChange);
    _societyNameFocusNode.addListener(_onFocusChange);
    super.initState();
  }

  void _onFocusChange() {
    setState(() {
      areTextFieldsFocused = _userNameFocusNode.hasFocus ||
          _mobileNumberFocusNode.hasFocus ||
          _societyNameFocusNode.hasFocus;
    });
  }

  Future<void> _sendReadyToRollEmail({
    required String name,
    required String mobile,
    required String societyName,
  }) async {
    final subject = Uri.encodeComponent('Ready to Roll - Gate Access Request');
    final body = Uri.encodeComponent(
      'Name: $name\nMobile: $mobile\nSociety Name: $societyName',
    );
    final mailtoUri = Uri.parse(
      'mailto:support@futurescapetech.com?subject=$subject&body=$body',
    );
    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email app could not open. Please email support@futurescapetech.com with your details.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint('Could not launch email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email app could not open. Please email support@futurescapetech.com with your details.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    }
  }

  void _submitRequestAccessForm() {
    if (_requestAccessFormKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      requestGateAccessBloc.add(RequestAccessButtonPressedEvent(
        name: clientNameTextCtrl!.text,
        mobile: mobileNumberTextCtrl!.text,
        societyName: clientSocietyTextCtrl!.text,
      ));
    }
  }

  @override
  void dispose() {
    clientNameTextCtrl?.dispose();
    mobileNumberTextCtrl?.dispose();
    clientSocietyTextCtrl?.dispose();
    super.dispose();
  }

  final RequestGateAccessBloc requestGateAccessBloc = RequestGateAccessBloc();

  Widget _buildThinBorderField({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required Color titleColor,
    required Color hintColor,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    FormFieldValidator<String>? validator,
  }) {
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
          keyboardType: keyboardType ?? TextInputType.text,
          maxLength: maxLength ?? 499,
          textCapitalization: textCapitalization,
          cursorColor: const Color(0xffF44336),
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
          ),
          validator: validator ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$title is required';
                }
                return null;
              },
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 15,
            ),
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: titleColor.withOpacity(0.45),
                width: 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: titleColor.withOpacity(0.45),
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
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequestGateAccessBloc, RequestGateAccessState>(
      bloc: requestGateAccessBloc,
      listenWhen: (previous, current) =>
          current is RequestGateAccessActionState ||
          current is RequestAccessErrorState,
      buildWhen: (previous, current) => true,
      listener: (context, state) {
        if (state is RequestAccessErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
          return;
        }
        if (state is RequestAccessButtonPressedState) {
          _sendReadyToRollEmail(
            name: state.name,
            mobile: state.mobile,
            societyName: state.societyName,
          );
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 3,
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
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
                          top: Radius.circular(24),
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
                              Icons.check_circle_outline,
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
                                  'Request Submitted',
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
                                  'Thank you for your request.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xff57636C),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Our team will reach out within 24–48 hours to verify details and get you started.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xff57636C),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xff212427), Color(0xff57636C)],
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
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const MyAppLogin()),
                                    (route) => false,
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: const Center(
                                  child: Text(
                                    'OK',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            Scaffold(
              body: SignUpContent(
            onSubmitPressed: _submitRequestAccessForm,
            requestAccessFormKey: _requestAccessFormKey,
            clientNameTextCtrl: clientNameTextCtrl!,
            mobileNumberTextCtrl: mobileNumberTextCtrl!,
            clientSocietyTextCtrl: clientSocietyTextCtrl!,
            userNameFocusNode: _userNameFocusNode,
            mobileNumberFocusNode: _mobileNumberFocusNode,
            societyNameFocusNode: _societyNameFocusNode,
          ),
            ),
            if (state is RequestAccessLoadingState)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: DashboardLoaderIcon(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SignUpContent extends StatelessWidget {
  final VoidCallback onSubmitPressed;
  final GlobalKey<FormState> requestAccessFormKey;
  final TextEditingController clientNameTextCtrl;
  final TextEditingController mobileNumberTextCtrl;
  final TextEditingController clientSocietyTextCtrl;
  final FocusNode userNameFocusNode;
  final FocusNode mobileNumberFocusNode;
  final FocusNode societyNameFocusNode;

  const SignUpContent({
    Key? key,
    required this.onSubmitPressed,
    required this.requestAccessFormKey,
    required this.clientNameTextCtrl,
    required this.mobileNumberTextCtrl,
    required this.clientSocietyTextCtrl,
    required this.userNameFocusNode,
    required this.mobileNumberFocusNode,
    required this.societyNameFocusNode,
  }) : super(key: key);

  Widget _buildThinBorderField({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required Color titleColor,
    required Color hintColor,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    FormFieldValidator<String>? validator,
  }) {
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
          keyboardType: keyboardType ?? TextInputType.text,
          maxLength: maxLength ?? 499,
          textCapitalization: textCapitalization,
          cursorColor: const Color(0xffF44336),
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
          ),
          validator: validator ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$title is required';
                }
                return null;
              },
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 15,
            ),
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: titleColor.withOpacity(0.45),
                width: 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: titleColor.withOpacity(0.45),
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
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final padding = mediaQuery.padding;
    final viewInsets = mediaQuery.viewInsets;
    final isTablet = screenWidth > 600;
    // Use viewport height (after safe area) so we never overflow; scale logo on small screens
    final viewportHeight = screenHeight - padding.top - padding.bottom;
    final isSmallScreen = viewportHeight < 600;
    final double logoSize = isSmallScreen ? 96 : 120;
    final bottomPadding = viewInsets.bottom + 16;
    final double loginSectionBottomSpacing =
        (viewportHeight * (isTablet ? 0.04 : 0.03))
            .clamp(isTablet ? 20.0 : 16.0, isTablet ? 36.0 : 28.0)
            .toDouble();
    // Content minHeight must subtract bottom padding so total scroll height never exceeds viewport
    final contentMinHeight = (viewportHeight - bottomPadding).clamp(0.0, double.infinity);

    return Container(
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: contentMinHeight > 0 ? contentMinHeight : viewportHeight,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: bottomPadding,
              ),
              child: Center(
                child: Container(
                  width: isTablet ? 600 : double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Back Button
                        Padding(
                          padding: EdgeInsets.only(
                            top: isSmallScreen ? 8 : (isTablet ? 20 : 10),
                            bottom: isSmallScreen ? 8 : (isTablet ? 20 : 10),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.1),
                                ),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: const Color(0xff212427),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Enhanced Sign-Up Illustration - Responsive
                        Container(
                          height: logoSize + (isSmallScreen ? 24 : (isTablet ? 52 : 40)),
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 8 : (isTablet ? 20 : 10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffF44336)
                                          .withOpacity(0.2),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                  child: Image.asset(
                                    'assets/media/images/onegate.png',
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              SizedBox(height: isTablet ? 12 : 10),
                            ],
                          ),
                        ),

                        // Enhanced Content Container
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(
                            horizontal: isTablet ? 0 : 0,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.28),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                spreadRadius: 3,
                                blurRadius: 30,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.08),
                                spreadRadius: 1,
                                blurRadius: 15,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    isSmallScreen ? 16 : 20,
                                    20,
                                    isSmallScreen ? 14 : 16,
                                  ),
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
                                      top: Radius.circular(24),
                                    ),
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
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xffF44336)
                                                  .withOpacity(0.1),
                                              spreadRadius: 1,
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.rocket_launch_rounded,
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
                                              'Ready to Roll?',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xff212427),
                                                    fontSize: isTablet ? 22 : 20,
                                                  ),
                                            ),
                                            SizedBox(
                                                height: isTablet ? 6 : 4),
                                            Text(
                                              'Request now & hear from us in 24-48 hours!',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color:
                                                        const Color(0xff57636C),
                                                    fontSize: isTablet ? 15 : 14,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: isTablet ? 28 : 20),

                                // Form Section - Responsive
              Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 32 : 20,
                                  ),
                                  child: Form(
                                  key: requestAccessFormKey,
                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThinBorderField(
                                        titleColor: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        hintColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        focusNode: userNameFocusNode,
                      title: 'Your Name',
                      controller: clientNameTextCtrl!,
                      hintText: 'Enter your name',
                                        textCapitalization:
                                            TextCapitalization.words,
                                      ),
                                      SizedBox(height: isTablet ? 16 : 12),
                    _buildThinBorderField(
                                        titleColor: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        hintColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        focusNode: mobileNumberFocusNode,
                      title: 'Mobile',
                      controller: mobileNumberTextCtrl!,
                      hintText: 'Mobile',
                      keyboardType: TextInputType.number,
                                        maxLength: 10,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter mobile number';
                        } else if (value.length < 10) {
                          return 'Please enter valid mobile number';
                        }
                        return null;
                      },
                    ),
                                      SizedBox(height: isTablet ? 16 : 12),
                    _buildThinBorderField(
                                        titleColor: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        hintColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        focusNode: societyNameFocusNode,
                      title: 'Society Name',
                      controller: clientSocietyTextCtrl!,
                      hintText: 'Society Name',
                                        textCapitalization:
                                            TextCapitalization.words,
                    ),
                  ],
                ),
              ),
                                ),

                                SizedBox(height: isTablet ? 40 : 24),

                                // Enhanced Submit Button - Responsive
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 32 : 20,
                                  ),
                                  child: Container(
                                  width: double.infinity,
                                  height: isTablet ? 56 : 50,
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
                                      onTap: onSubmitPressed,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Center(
                                        child: Text(
                                          'Request Callback',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isTablet ? 18 : 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ),

                                SizedBox(height: isTablet ? 24 : 16),

                                // Back to Login Section - Responsive
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      "Already have an account? ",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xff57636C),
                                            fontSize: isTablet ? 16 : 14,
                                          ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.pop(context);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            'Login',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      const Color(0xffF44336),
                                                  fontSize: isTablet ? 16 : 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: loginSectionBottomSpacing),
                            ],
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 12 : (isTablet ? 24 : 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
