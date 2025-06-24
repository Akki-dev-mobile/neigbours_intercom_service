// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

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

  void _submitRequestAccessForm() {
    if (_requestAccessFormKey.currentState?.validate() ?? false) {
      // Form submission logic here
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequestGateAccessBloc, RequestGateAccessState>(
      bloc: requestGateAccessBloc,
      listenWhen: (previous, current) =>
          current is RequestGateAccessActionState,
      buildWhen: (previous, current) =>
          current is! RequestGateAccessActionState,
      listener: (context, state) {
        if (state is RequestAccessButtonPressedState) {}
      },
      builder: (context, state) {
        return Scaffold(
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

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
              minHeight: screenHeight - MediaQuery.of(context).padding.top,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Center(
                  child: Container(
                    width: isTablet ? 600 : double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 16,
                    ),
                    child: Column(
                      children: [
                        // Back Button
                        Padding(
                          padding: EdgeInsets.only(
                            top: isTablet ? 20 : 10,
                            bottom: isTablet ? 20 : 10,
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
                          height: isTablet
                              ? screenHeight * 0.2
                              : (screenHeight * 0.25).clamp(0, 200),
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 20 : 10,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Sign-Up Icon - Changed from fence to person_add
                              Container(
                                width: isTablet ? 120 : 100,
                                height: isTablet ? 120 : 100,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xffF44336),
                                      Color(0xffff5722),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffF44336)
                                          .withOpacity(0.4),
                                      spreadRadius: 0,
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xffF44336)
                                          .withOpacity(0.2),
                                      spreadRadius: 0,
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.person_add,
                                  size: isTablet ? 60 : 50,
                                  color: Colors.white,
                                ),
                              ),

                              SizedBox(height: isTablet ? 20 : 15),

                              // Society Name
                              Text(
                                'OneGate',
                                style: TextStyle(
                                  fontSize: isTablet ? 24 : 20,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xffF44336),
                                  letterSpacing: 1.0,
                                ),
                              ),

                              SizedBox(height: isTablet ? 8 : 5),

                              // Tagline
                              Text(
                                'Smart Gate Management',
                                style: TextStyle(
                                  fontSize: isTablet ? 14 : 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xff57636C),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Enhanced Content Container - Flexible
                        Flexible(
                          child: Container(
                            width: double.infinity,
                            margin: EdgeInsets.symmetric(
                              horizontal: isTablet ? 0 : 0,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 32 : 20,
                              vertical: isTablet ? 32 : 20,
                            ),
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
                                // Enhanced Title Section - Responsive spacing
                                Column(
                                  children: [
                                    Hero(
                                      tag: 'signUpHero',
                  child: Text(
                                        'Ready to Roll?',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                              fontSize: isTablet ? 32 : 28,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xff212427),
                                              height: 1.2,
                  ),
                ),
              ),
                                    SizedBox(height: isTablet ? 12 : 8),
                                    Text(
                                      "Request now & hear from us in 24-48 hours!",
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontSize: isTablet ? 16 : 14,
                                            color: const Color(0xff57636C),
                                            fontWeight: FontWeight.w400,
                                            height: 1.3,
                                          ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: isTablet ? 32 : 20),

                                // Form Section - Responsive
              Form(
                                  key: requestAccessFormKey,
                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomForm.textField(
                                        focusNode: userNameFocusNode,
                      'Your Name',
                      textController: clientNameTextCtrl,
                      hintText: 'Shubham Bane',
                                        textCapitalization:
                                            TextCapitalization.words,
                                        titleColor: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        hintColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                      SizedBox(height: isTablet ? 16 : 12),
                    CustomForm.textField(
                                        focusNode: mobileNumberFocusNode,
                      'Mobile',
                      textController: mobileNumberTextCtrl,
                      hintText: 'Mobile',
                      keyboardType: TextInputType.number,
                                        titleColor: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        hintColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                      length: 10,
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
                    CustomForm.textField(
                      'Society Name',
                      textController: clientSocietyTextCtrl,
                                        focusNode: societyNameFocusNode,
                      hintText: 'Society Name',
                                        textCapitalization:
                                            TextCapitalization.words,
                                        titleColor: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        hintColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                    ),
                  ],
                ),
              ),

                                SizedBox(height: isTablet ? 40 : 24),

                                // Enhanced Submit Button - Responsive
              Container(
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
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 24 : 16),
                      ],
                    ),
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
