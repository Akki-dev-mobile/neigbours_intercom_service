// ignore_for_file: prefer_const_constructors

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';

import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/auth_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/company.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:flutter_onegate/presentation/features/reset_password/ui/reset_password_view.dart';
import 'package:lottie/lottie.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import '../../dashboard/admin/pages/admin_dashboard_view.dart';
import '../../dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import '../../request_gate_access/ui/request_gate_access_view.dart';
import '../bloc/login_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

List<String> rbac = <String>['Admin', 'GateKeeper'];

class _LoginViewState extends State<LoginView> {
  late FocusNode _mobileFocusNode = FocusNode();
  late FocusNode _passwordFocusNode = FocusNode();
  bool areTextFieldsFocused = false;
  TextEditingController? usernameTextCtrl;
  TextEditingController? passwordTextCtrl;
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  late bool passwordVisibility;
  dynamic dropdownValue;
  String rbacDDV = rbac.first;
  final LoginBloc loginBloc = LoginBloc(
    LoginUseCase(
      AuthenticationRepositoryImpl(
        RemoteDataSource(dioInstance),
      ),
    ),
  );
  bool isMobileFieldFocused = false;
  bool isPasswordFieldFocused = false;

  bool isEmailMode = false;
  IconData userNameInputIcon = Symbols.abc_rounded;

  void toggleEmailMode() {
    setState(() {
      isEmailMode = !isEmailMode;
      userNameInputIcon = isEmailMode ? Symbols.phone : Symbols.abc_rounded;
      usernameTextCtrl!.clear();
      _mobileFocusNode.unfocus();
      Future.delayed(Duration(milliseconds: 100), () {
        FocusScope.of(context).requestFocus(_mobileFocusNode);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    usernameTextCtrl = TextEditingController();
    passwordTextCtrl = TextEditingController();
    _mobileFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
    passwordVisibility = true;
    loginBloc.add(LoginInitialEvent());
  }

  void _onFocusChange() {
    setState(() {
      areTextFieldsFocused =
          _mobileFocusNode.hasFocus || _passwordFocusNode.hasFocus;
    });
  }

  void _submitForm() {
    if (_loginFormKey.currentState?.validate() ?? false) {
      loginBloc.add(
        LoginButtonPressedEvent(usernameTextCtrl!.text, passwordTextCtrl!.text),
      );
      usernameTextCtrl!.clear();
      passwordTextCtrl!.clear();
    }
  }

  @override
  void dispose() {
    usernameTextCtrl?.dispose();
    passwordTextCtrl?.dispose();
    loginBloc.close();
    super.dispose();
  }

  int _selectedRoleValue = 1;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      bloc: loginBloc,
      listenWhen: (previous, current) => current is LoginActionState,
      buildWhen: (previous, current) => current is! LoginActionState,
      listener: (context, state) {
        switch (state.runtimeType) {
          case SocietySelectionState:
            final societyState = state as SocietySelectionState;
            _showSelectSocietyBottomSheet(
              context,
              societyState.companiesWithAccessToGate,
            );
            break;
          case RoleSelectionState:
            final roleState = state as RoleSelectionState;

            _roleSelectionBottomSheet(context);
            break;
          case LoginErrorState:
            final errorState = state as LoginErrorState;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorState.message!),
              ),
            );
            break;
          case SignUpButtonPressedState:
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.leftToRightWithFade,
                child: RequestGateAccess(),
              ),
            );
            break;
          case ForgotPasswordButtonPressedState:
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.bottomToTop,
                child: ResetPasswordView(),
              ),
            );
            break;
          case NavigateToAdminDashboardState:
            Navigator.pop(context);
            Future.delayed(Duration(milliseconds: 100), () {
              Navigator.pushReplacement(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: AdminDashboardView(),
                ),
              );
            });
            break;
          case NavigateToGatekeeperDashboardState:
            Navigator.pop(context);
            Future.delayed(Duration(milliseconds: 100), () {
              Navigator.pushReplacement(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: GateDashboardView(),
                ),
              );
            });
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case LoginLoadingState:
            return LoaderView();
          default:
            return MyScrollView(
              hasBackButton: false,
              pageBody: GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    areTextFieldsFocused
                        ? SizedBox()
                        : Lottie.network(
                            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/auth_Animation_fec8c8284d.json?updated_at=2023-08-23T06:28:49.839Z',
                            height: 180,
                            width: double.infinity,
                          ),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(top: 20, bottom: 10),
                      title: Text(
                        'Login',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      subtitle: Text(
                        "Welcome back! Let's dive in.",
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Form(
                      key: _loginFormKey,
                      child: Column(
                        children: [
                          CustomForm.textField(
                            focusNode: _mobileFocusNode,
                            isEmailMode ? 'Email Address' : 'Mobile Number',
                            hintText:
                                isEmailMode ? 'Email Address' : 'Mobile Number',
                            textController: usernameTextCtrl,
                            textCapitalization: TextCapitalization.words,
                            length: 10,
                            focusedColor:
                                Theme.of(context).colorScheme.onPrimary,
                            keyboardType: isEmailMode
                                ? TextInputType.emailAddress
                                : TextInputType.number,
                            suffixIcon: IconButton(
                              onPressed: () {
                                toggleEmailMode();
                              },
                              icon: Icon(
                                userNameInputIcon,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          CustomForm.textField(
                            focusNode: _passwordFocusNode,
                            'Password',
                            hintText: '**********',
                            keyboardType: TextInputType.visiblePassword,
                            textController: passwordTextCtrl,
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
                            focusedColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                        ],
                      ),
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
                                    MaterialStateProperty.all<Color>(
                                        Colors.white),
                                elevation:
                                    MaterialStateProperty.resolveWith<double>(
                                  (Set<MaterialState> states) {
                                    if (states
                                        .contains(MaterialState.pressed)) {
                                      return 8;
                                    }
                                    return 0;
                                  },
                                ),
                                shape: MaterialStateProperty.all<
                                    RoundedRectangleBorder>(
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
                                    MaterialStateProperty.all<Color>(
                                        Colors.black),
                                elevation:
                                    MaterialStateProperty.resolveWith<double>(
                                  (Set<MaterialState> states) {
                                    if (states
                                        .contains(MaterialState.pressed)) {
                                      return 8;
                                    }
                                    return 0;
                                  },
                                ),
                                shape: MaterialStateProperty.all<
                                    RoundedRectangleBorder>(
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
                                _submitForm();
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
              ),
            );
        }
      },
    );
  }

  void _showSelectSocietyBottomSheet(
      BuildContext context, List<Company?> companiesWithAccessToGate) async {
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
                  DropdownButtonFormField<Company>(
                    enableFeedback: true,
                    onChanged: (Company? value) {
                      setState(() {
                        dropdownValue = value;
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
                    items: companiesWithAccessToGate
                        .map<DropdownMenuItem<Company>>(
                      (Company? value) {
                        return DropdownMenuItem<Company>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(Ionicons.home_outline),
                              SizedBox(width: 10),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.6,
                                child: Text(
                                  value!.companyName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ).toList(),
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  CustomLargeBtn(
                    text: 'CONFIRM',
                    onPressed: () {
                      loginBloc.add(
                        SocietySelectionButtonEvent(dropdownValue),
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
                  Container(
                    // fit: BoxFit.scaleDown,
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        _buildRoleOption(
                          image:
                              'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/admin_7307678f4d.png?updated_at=2023-08-31T12:10:09.789Z',
                          label: 'Admin',
                          value: 1,
                        ),
                        _buildRoleOption(
                          image:
                              'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/gatekeeper_691f3ec552.png?updated_at=2023-08-31T12:10:09.840Z',
                          label: 'GateKeeper',
                          value: 2,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  CustomLargeBtn(
                    text: 'CONFIRM',
                    onPressed: () {
                      loginBloc.add(
                        RoleSelectionButtonPressedEvent(
                          _selectedRoleValue == 1,
                        ),
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

  Widget _buildRoleOption({
    required String image,
    required String label,
    required int value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedRoleValue = value;
            });
            Navigator.pop(context); // Close the bottom sheet
            _roleSelectionBottomSheet(context);
          },
          child: Container(
            padding: EdgeInsets.all(8),
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedRoleValue == value
                    ? Colors.blue
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                image,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            color: _selectedRoleValue == value ? Colors.blue : Colors.black,
          ),
        ),
      ],
    );
  }
}
