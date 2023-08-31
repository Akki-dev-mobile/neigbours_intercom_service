// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  TextEditingController? clientNameTextCtrl;
  TextEditingController? mobileNumberTextCtrl;
  TextEditingController? clientSocietyTextCtrl;
  final GlobalKey<FormState> _requestAccessFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    clientNameTextCtrl = TextEditingController();
    mobileNumberTextCtrl = TextEditingController();
    clientSocietyTextCtrl = TextEditingController();
    super.initState();
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
              Lottie.network(
                'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/gate_request_bf36d610fe.json?updated_at=2023-08-23T06:28:50.842Z',
                height: 300,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
              ListTile(
                contentPadding: EdgeInsets.only(top: 20, bottom: 10),
                title: Text(
                  'Ready to Roll?',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                subtitle: Text(
                  'Request Now & Hear from Us in 24-48 Hours!',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Form(
                key: _requestAccessFormKey,
                child: Column(
                  children: [
                    CustomForm.textField(
                      'Your Name',
                      textController: clientNameTextCtrl,
                      hintText: 'Shubham Bane',
                      focusedColor: Theme.of(context).colorScheme.onPrimary,
                      textCapitalization: TextCapitalization.words,
                    ),
                    CustomForm.textField(
                      'Mobile',
                      textController: mobileNumberTextCtrl,
                      hintText: 'Mobile',
                      isNumber: true,
                      focusedColor: Theme.of(context).colorScheme.onPrimary,
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
                      hintText: 'Society Name',
                      textCapitalization: TextCapitalization.words,
                      focusedColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
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
                  text: 'REQUEST CALLBACK',
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
