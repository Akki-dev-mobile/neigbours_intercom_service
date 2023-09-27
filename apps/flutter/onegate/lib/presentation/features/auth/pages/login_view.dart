// ignore_for_file: prefer_const_constructors
import 'package:country_code_picker/country_code_picker.dart';
import 'package:dio/dio.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';

import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/auth_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/gate_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/gate/gate.dart';
import 'package:flutter_onegate/domain/use_cases/auth_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/gate_usecase.dart';
import 'package:flutter_onegate/presentation/features/reset_password/ui/reset_password_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:libphonenumber/libphonenumber.dart';
import 'package:lottie/lottie.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import '../../dashboard/admin/pages/admin_dashboard_view.dart';
import '../../dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import '../../gate_selection/ui/gate_selection_view.dart';
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
  String selectedCountryCode = 'IN';
  late FocusNode _mobileFocusNode = FocusNode();
  late FocusNode _passwordFocusNode = FocusNode();
  bool areTextFieldsFocused = false;
  TextEditingController? usernameTextCtrl;
  TextEditingController? passwordTextCtrl;
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  late bool passwordVisibility;
  dynamic dropdownValue;
  String rbacDDV = rbac.first;
  bool isMobileFieldFocused = false;
  bool isPasswordFieldFocused = false;
  bool isValid = true;

  bool isEmailMode = false;
  IconData userNameInputIcon = Symbols.alternate_email;

  String? mobileErrorText;
  String? emailErrorText;

  Gate? storedGate, selectedGate;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  final LoginBloc loginBloc = LoginBloc(
      LoginUseCase(
        AuthenticationRepositoryImpl(
          RemoteDataSource(dioInstance),
        ),
      ),
      GateUseCase(
        GateRepositoryImpl(
          RemoteDataSource(dioInstance),
        ),
      ));

  void toggleEmailMode() {
    setState(() {
      isEmailMode = !isEmailMode;
      userNameInputIcon = isEmailMode ? Symbols.phone : Symbols.alternate_email;
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
    storedGate = _preferenceUtils.getSelectedGate();
    selectedGate = storedGate;
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
    }
  }

  Future<void> validateMobileNumber(String input) async {
    final isoCode = selectedCountryCode;
    try {
      final isValidNumber = await PhoneNumberUtil.isValidPhoneNumber(
        phoneNumber: input,
        isoCode: isoCode,
      );
      setState(() {
        if (isValidNumber!) {
          mobileErrorText = null; // Valid mobile number
        } else {
          mobileErrorText = 'Invalid Mobile Number';
        }
      });
    } catch (e) {
      print('Error validating mobile number: $e');
      setState(() {
        mobileErrorText = 'Error validating mobile number';
      });
    }
  }

  void validateEmail(String input) {
    final isEmailValid = EmailValidator.validate(input);
    setState(() {
      if (isEmailValid) {
        emailErrorText = null; // Valid email address
      } else {
        emailErrorText = 'Invalid Email Address';
      }
    });
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
        print(state.runtimeType.toString());
        switch (state.runtimeType) {
          case SocietySelectionState:
            final societyState = state as SocietySelectionState;
            _showSelectSocietyBottomSheet(
              context,
              societyState.companiesWithAccessToGate,
            );
            break;
          case GateSelectionState:
            final gateState = state as GateSelectionState;
            _showGateSelectionBottomSheet(context, gateState.gates);
            break;
          case RoleSelectionState:
            final roleState = state as RoleSelectionState;

            _roleSelectionBottomSheet(context);
            break;
          case LoginErrorState:
            final errorState = state as LoginErrorState;
            Fluttertoast.showToast(
              msg: errorState.message!,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            break;
          case SignUpButtonPressedState:
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => RequestGateAccess(),
            //   ),
            // );
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return const RequestGateAccess();
                },
              ),
            );
            // Navigator.push(
            //   context,
            //   PageTransition(
            //     type: PageTransitionType.leftToRightWithFade,
            //     child: RequestGateAccess(),
            //   ),
            // );
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
            //Navigator.pop(context);
            // Future.delayed(Duration(milliseconds: 100), () {
            Navigator.pushReplacement(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: AdminDashboardView(),
              ),
            );
            //});
            break;
          case NavigateToGatekeeperDashboardState:
            // Navigator.pop(context);
            //Future.delayed(Duration(milliseconds: 100), () {
            Navigator.pushReplacement(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: GateDashboardView(),
              ),
            );
            break;
        }
      },
      builder: (context, state) {
        print(state.runtimeType.toString());

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
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          "Welcome back! Let's dive in.",
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                    Form(
                      key: _loginFormKey,
                      child: Column(
                        children: [
                          CustomForm.textField(
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            focusNode: _mobileFocusNode,
                            isEmailMode ? 'Email Address' : 'Mobile Number',
                            hintText:
                                isEmailMode ? 'Email Address' : 'Mobile Number',
                            textController: usernameTextCtrl,
                            textCapitalization: TextCapitalization.words,
                            keyboardType: isEmailMode
                                ? TextInputType.emailAddress
                                : TextInputType.number,
                            suffixIcon: IconButton(
                              onPressed: () {
                                toggleEmailMode();
                              },
                              icon: Icon(
                                userNameInputIcon,
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            prefixIcon: !isEmailMode
                                ? CountryCodePicker(
                                    initialSelection: 'IN',
                                    favorite: ['IN'],
                                    showFlagMain: true,
                                    showFlagDialog: true,
                                    boxDecoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .background,
                                    ),
                                    barrierColor: Theme.of(context)
                                        .colorScheme
                                        .background
                                        .withOpacity(0.5),
                                    closeIcon: Icon(
                                      Icons.close,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground,
                                    ),
                                    searchDecoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                      ),
                                      hintText: 'Search',
                                      hintStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          style: BorderStyle.solid,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          style: BorderStyle.solid,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground,
                                        ),
                                      ),
                                    ),
                                    textStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground,
                                      fontSize: 18,
                                    ),
                                    dialogTextStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground,
                                    ),
                                    onChanged: (CountryCode countryCode) {
                                      setState(() {
                                        selectedCountryCode = countryCode.code!;
                                      });
                                    },
                                  )
                                : null,
                            validator: (value) {
                              if (!isEmailMode && mobileErrorText != null) {
                                return mobileErrorText;
                              } else if (isEmailMode &&
                                  emailErrorText != null) {
                                return emailErrorText;
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (!isEmailMode) {
                                validateMobileNumber(value);
                              } else {
                                validateEmail(value);
                              }
                            },
                          ),
                          CustomForm.textField(
                            focusNode: _passwordFocusNode,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
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
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    CustomLargeBtn(
                      text: 'Login',
                      onPressed: () {
                        _submitForm();
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextButton(
                        onPressed: () {
                          loginBloc.add(
                            SignUpButtonPressedEvent(),
                          );
                        },
                        child: Hero(
                          tag: 'signUpHero',
                          child: Text(
                            'Sign Up',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium!
                                .copyWith(
                                  fontSize: 20,
                                ),
                          ),
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
                    contentPadding: EdgeInsets.only(top: 0, bottom: 15),
                    title: Text(
                      'Select Society',
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Text(
                        'Kindly, select your society linked with +91-*******101',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
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
                    dropdownColor: Theme.of(context).colorScheme.background,
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 10,
                      ),
                      hintText: 'Select Society',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          style: BorderStyle.solid,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          style: BorderStyle.solid,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          style: BorderStyle.solid,
                          color: Theme.of(context).colorScheme.onBackground,
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
                              Icon(
                                Ionicons.home_outline,
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                              SizedBox(width: 10),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.6,
                                child: Text(
                                  value!.companyName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
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
                    text: 'Confirm',
                    onPressed: () {
                      Navigator.pop(context);

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
              padding: EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.only(top: 0, bottom: 15),
                    title: Text(
                      'Select Role',
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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
                    text: 'Confirm',
                    onPressed: () {
                      print('Confirm button pressed');

                      Navigator.pop(context);
                      Future.delayed(Duration(milliseconds: 200), () {
                        loginBloc.add(
                          RoleSelectionButtonPressedEvent(
                            _selectedRoleValue == 1,
                          ),
                        );
                      });
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

  void _showGateSelectionBottomSheet(
      BuildContext context, List<Gate?> gatesList) async {
    if (storedGate != null && selectedGate != null) {
      if (storedGate!.name == selectedGate!.name) {
        for (var gate in gatesList) {
          if (gate!.name == storedGate!.name) {
            gate.isSelected = true;
            selectedGate = gate;
          }
        }
      } else {
        bool anyGateSelected = gatesList.any((gate) => gate!.isSelected);
        if (!anyGateSelected && gatesList.isNotEmpty) {
          gatesList[0]!.isSelected = true;
          selectedGate = gatesList[0];
        }
      }
    }
    if (storedGate == null) {
      bool anyGateSelected = gatesList.any((gate) => gate!.isSelected);
      if (!anyGateSelected && gatesList.isNotEmpty) {
        gatesList[0]!.isSelected = true;
        selectedGate = gatesList[0];
      }
    }
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Select your gate',
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  ...List.generate(gatesList.length, (index) {
                    return GateSettingListTile(
                      switchValue: gatesList[index]!.isSelected,
                      onChanged: (value) => {
                        setState(() {
                          for (var gate in gatesList) {
                            gate!.isSelected = false;
                            print(gate.isSelected);
                          }
                          gatesList[index]!.isSelected = true;
                          selectedGate = gatesList[index];
                        })
                      },
                      title: gatesList[index]!.name,
                      subtitle: 'Enable/Disable ${gatesList[index]!.name}',
                      // leadingIcon: Ionicons.grid_outline,
                      leadingIcon: Symbols.gate,
                    );
                  }),
                  SizedBox(
                    height: 30,
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      loginBloc.add(
                        GateSelectionButtonPressedEvent(selectedGate!),
                      );
                    },
                  ),
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
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              color: _selectedRoleValue == value
                  ? Color(0x10C08261)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedRoleValue == value
                    ? Color(0xffC08261)
                    : Colors.grey.shade300,
                width: _selectedRoleValue == value ? 3 : 2,
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
            fontWeight:
                _selectedRoleValue == value ? FontWeight.w600 : FontWeight.w400,
            color: _selectedRoleValue == value
                ? Color(0xffC08261)
                : Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
