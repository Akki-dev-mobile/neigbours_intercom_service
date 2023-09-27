// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animated_button/flutter_animated_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:common_widgets/common_widgets.dart';
import '../bloc/request_gate_access_bloc.dart';

class RequestGateAccess extends StatefulWidget {
  const RequestGateAccess({super.key});

  @override
  State<RequestGateAccess> createState() => _RequestGateAccessState();
}

class _RequestGateAccessState extends State<RequestGateAccess> {
  late FocusNode _userNameFocusNode = FocusNode();
  late FocusNode _mobileNumberFocusNode = FocusNode();
  late FocusNode _societyNameFocusNode = FocusNode();
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
      // clientNameTextCtrl!.clear();
      // mobileNumberTextCtrl!.clear();
      // clientSocietyTextCtrl!.clear();
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
        return MyScrollView(
          pageBody: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              areTextFieldsFocused
                  ? SizedBox()
                  : Lottie.network(
                      'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/gate_request_bf36d610fe.json?updated_at=2023-08-23T06:28:50.842Z',
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
              ListTile(
                contentPadding: EdgeInsets.only(top: 20, bottom: 10),
                title: Hero(
                  tag: 'signUpHero',
                  child: Text(
                    'Ready to Roll ?',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Request now & hear from us in 24-48 hours!',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              Form(
                key: _requestAccessFormKey,
                child: Column(
                  children: [
                    CustomForm.textField(
                      focusNode: _userNameFocusNode,
                      'Your Name',
                      textController: clientNameTextCtrl,
                      hintText: 'Shubham Bane',
                      textCapitalization: TextCapitalization.words,
                      titleColor: Theme.of(context).colorScheme.onBackground,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    CustomForm.textField(
                      focusNode: _mobileNumberFocusNode,
                      'Mobile',
                      textController: mobileNumberTextCtrl,
                      hintText: 'Mobile',
                      keyboardType: TextInputType.number,
                      titleColor: Theme.of(context).colorScheme.onBackground,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
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
                    CustomForm.textField(
                      'Society Name',
                      textController: clientSocietyTextCtrl,
                      focusNode: _societyNameFocusNode,
                      hintText: 'Society Name',
                      textCapitalization: TextCapitalization.words,
                      titleColor: Theme.of(context).colorScheme.onBackground,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
              // AnimatedButton(
              //   height: 70,
              //   width: 200,
              //   text: 'SUBMIT',
              //   isReverse: false,
              //   selectedTextColor: Colors.black,
              //   transitionType: TransitionType.LEFT_TO_RIGHT,
              //   backgroundColor: Colors.black,
              //   borderColor: Colors.black54,
              //   borderRadius: 50,
              //   borderWidth: 2,
              //   onPress: () {},
              // ),
              Container(
                margin: EdgeInsets.only(top: 20, bottom: 80),
                child: CustomLargeBtn(
                  onPressed: () {
                    _submitRequestAccessForm();
                    // Navigator.push(
                    //   context,
                    //   PageTransition(
                    //     type: PageTransitionType.rightToLeft,
                    //     child: OtpView(),
                    //   ),
                    // );
                  },
                  text: 'Request Callback',
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
