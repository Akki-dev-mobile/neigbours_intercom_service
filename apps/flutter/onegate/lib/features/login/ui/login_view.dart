// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:lottie/lottie.dart';
import 'package:page_transition/page_transition.dart';
import 'package:ionicons/ionicons.dart';
import '../../request_gate_access/ui/request_gate_access_view.dart';
import '../bloc/login_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

List<String> list = <String>[
  'One',
  'Two',
  'Three',
  'Pratap CHS',
];
List<String> rbac = <String>['Admin', 'GateKeeper'];

class _LoginViewState extends State<LoginView> {
  TextEditingController? textController1;
  TextEditingController? textController2;
  late bool passwordVisibility;
  String dropdownValue = list.first;
  String rbacDDV = rbac.first;

  @override
  void initState() {
    super.initState();
    textController1 = TextEditingController();
    textController2 = TextEditingController();
    passwordVisibility = false;
  }

  int _selectedValue = 1;

  final LoginBloc loginBloc = LoginBloc();
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      bloc: loginBloc,
      listenWhen: (previous, current) => current is LoginActionState,
      buildWhen: (previous, current) => current is! LoginActionState,
      listener: (context, state) {
        if (state is LoginButtonPressedState) {
          _showSelectSocietyBottomSheet(context);
        } else if (state is SignUpButtonPressedState) {
          Navigator.push(
            context,
            PageTransition(
              type: PageTransitionType.rightToLeft,
              child: RequestGateAccess(),
            ),
          );
        } else if (state is ForgotPasswordButtonPressedState) {
        } else if (state is SocietySelectionButtonPressedState) {
          Navigator.pop(context);
          _roleSelectionBottomSheet(context);
        } else if (state is AdminRoleSelectionButtonPressedState) {
          Navigator.pop(context);
          // Navigator.push(
          //   context,
          //   PageTransition(
          //     type: PageTransitionType.rightToLeft,
          //     child: AdminDashboard(),
          //   ),
          // );
        } else if (state is GateKeeperRoleSelectionButtonPressedState) {
          Navigator.pop(context);
          _haveOfflineLoginPopup(context);
        } else if (state is HasOfflineLoginButtonPressedState) {
          Navigator.pop(context);
        } else if (state is NotHasOfflineLoginButtonPressedState) {
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        return MyScrollView(
          hasBackButton: false,
          pageBody: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Lottie.network(
                'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/auth_Animation_fec8c8284d.json?updated_at=2023-08-23T06:28:49.839Z',
                height: 180,
                width: double.infinity,
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(top: 20, bottom: 10),
                title: Text(
                  'Login',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                subtitle: Text(
                  "Welcome back! Let's dive in.",
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              CustomForm.textField(
                'Mobile / Email',
                hintText: 'Mobile / Email',
                textController: textController1,
                textCapitalization: TextCapitalization.words,
                length: 10,
                focusedColor: Theme.of(context).colorScheme.onPrimary,
              ),
              CustomForm.textField(
                'Password',
                hintText: '**********',
                textController: textController2,
                isObscureText: passwordVisibility,
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
                focusedColor: Theme.of(context).colorScheme.onPrimary,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.45,
                      height: 50,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          overlayColor: MaterialStateProperty.all<Color>(
                            Color(0x80FFB080),
                          ),
                          backgroundColor:
                              MaterialStateProperty.all<Color>(Colors.white),
                          elevation: MaterialStateProperty.resolveWith<double>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed)) {
                                return 8;
                              }
                              return 0;
                            },
                          ),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        onPressed: () {
                          loginBloc.add(
                            SignUpButtonPressedEvent(),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            wordSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.45,
                      height: 50,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          overlayColor: MaterialStateProperty.all<Color>(
                            Color(0x80FFB080),
                          ),
                          backgroundColor:
                              MaterialStateProperty.all<Color>(Colors.black),
                          elevation: MaterialStateProperty.resolveWith<double>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed)) {
                                return 8;
                              }
                              return 0;
                            },
                          ),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        onPressed: () {
                          loginBloc.add(
                            LoginButtonPressedEvent(),
                          );
                          // _showBottomSheet(context);
                        },
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            wordSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextButton(
                  onPressed: () {
                    // Navigator.push(
                    //   context,
                    //   PageTransition(
                    //     type: PageTransitionType.rightToLeft,
                    //     child: ResetPasswordView(),
                    //   ),
                    // );
                    loginBloc.add(
                      ForgotPasswordButtonPressedEvent(),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSelectSocietyBottomSheet(BuildContext context) async {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.background,
              ),
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.only(top: 10, bottom: 15),
                    title: Text(
                      'Select Society',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    subtitle: Text(
                      'Kindly, select your society associated with +91-*******101',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  DropdownButtonFormField(
                    enableFeedback: true,
                    onChanged: (String? value) {
                      setState(() {
                        dropdownValue = value!;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 10,
                      ),
                      hintText: 'Select Society',
                      hintStyle: TextStyle(
                        color: Colors.black38,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          style: BorderStyle.solid,
                          color: Colors.black,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          style: BorderStyle.solid,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    items: list.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                          value: value,
                          child: SizedBox(
                            height: 30,
                            child: Row(
                              children: [
                                Icon(Ionicons.home_outline),
                                SizedBox(width: 10),
                                Text(
                                  value,
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ));
                    }).toList(),
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  CustomLargeBtn(
                    text: 'CONFIRM',
                    onPressed: () {
                      loginBloc.add(
                        SocietySelectionButtonEvent(),
                      );
                    },
                  ),
                  SizedBox(height: 50.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _roleSelectionBottomSheet(BuildContext context) async {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.background,
              ),
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.only(top: 10, bottom: 15),
                    title: Text(
                      'Select Role',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RadioListTile<int>(
                                title: Container(
                                  height: 80,
                                  width: 80,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      'https://images.unsplash.com/photo-1507679799987-c73779587ccf?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1171&q=80',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                value: 1,
                                groupValue: _selectedValue,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedValue = value!;
                                  });
                                },
                              ),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RadioListTile<int>(
                                title: Container(
                                  height: 80,
                                  width: 80,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      'https://images.unsplash.com/photo-1552622594-9a37efeec618?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=388&q=80',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                value: 2,
                                groupValue: _selectedValue,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedValue = value!;
                                  });
                                },
                              ),
                              Text(
                                'GateKeeper',
                                style: TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  CustomLargeBtn(
                    text: 'CONFIRM',
                    onPressed: _selectedValue == 1
                        ? () {
                            loginBloc.add(
                              AdminRoleSelectionButtonEvent(),
                            );
                          }
                        : () {
                            loginBloc.add(
                              GateKeeperRoleSelectionButtonEvent(),
                            );
                            // Navigator.pop(context);
                            // _haveOfflineLogin(context);
                          },
                  ),
                  SizedBox(height: 50.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _haveOfflineLoginPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          surfaceTintColor: Theme.of(context).colorScheme.background,
          title: Text(
            'Do you want to allow offline login?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Navigator.push(
                //   context,
                //   PageTransition(
                //     type: PageTransitionType.rightToLeft,
                //     child: GateKeeperDashboard(),
                //   ),
                // );
              },
              child: Text(
                'No',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
              ),
              onPressed: () {
                // Navigator.push(
                //   context,
                //   PageTransition(
                //     type: PageTransitionType.rightToLeft,
                //     child: GateKeeperDashboard(),
                //   ),
                // );
              },
              child: Text(
                'Yes',
                style: Theme.of(context).textTheme.bodyMedium!.merge(
                      const TextStyle(
                        color: Colors.white,
                      ),
                    ),
              ),
            )
          ],
        );
      },
    );
  }
}
