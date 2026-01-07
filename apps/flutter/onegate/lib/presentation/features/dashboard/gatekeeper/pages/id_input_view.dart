// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/purpose/provider/purposeProvider.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toggle_switch/toggle_switch.dart';

import '../../../../../data/datasources/gate_storage.dart';
import '../../../visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';

class IdInputView extends StatefulWidget {
  const IdInputView({Key? key}) : super(key: key);

  @override
  State<IdInputView> createState() => _IdInputViewState();
}

late FocusNode _focusNode;

int _currentIndex = 0;
// Labels will be localized in build method
String? selectedPassAlpha = 'A';
String selectedCountryCode = 'IN';
final isoCode = selectedCountryCode;
Visitor? searchedVisitor;

List<String> listPassAlpha = [
  'G',
  'S',
  'A',
];

class _IdInputViewState extends State<IdInputView> {
  final mobileControllerFormKey = GlobalKey<FormState>();
  final passcodeControllerFormKey = GlobalKey<FormState>();
  TextEditingController mobileController = TextEditingController();
  TextEditingController passcodeController = TextEditingController();
  bool isLoading = false;
  bool checkVisitorLoading = false;
  bool isMobileApiLoading = false; // Controls the spinner for mobile input
  bool hideNextButton = false; // Controls whether to hide the Next button
  bool isPasscodeVerifying = false; // Controls passcode verification loading
  final GateStorage _gateStorage = GateStorage();

  void startLoading() {
    setState(() {
      isLoading = true;
    });
  }

  void stopLoading() {
    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();

    // Clear visitor data when view is initialized
    _clearVisitorData();

    // Request focus after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
      mobileController.clear(); // Clear after the build phase
    });

    loadPurposes();
  }

  /// Clears all visitor-related data to prevent data persistence between check-ins
  Future<void> _clearVisitorData() async {
    try {
      log("🔍 Before clearing visitor data:");
      await _logVisitorDataState();

      await _gateStorage.clearVisitorSessionData();

      // Reset global variables
      searchedVisitor = null;

      // Reset UI state
      setState(() {
        hideNextButton = false;
        isMobileApiLoading = false;
      });

      log("🧹 After clearing visitor data:");
      await _logVisitorDataState();

      log("✅ Visitor data cleared successfully");
    } catch (e) {
      log("❌ Error clearing visitor data: $e");
    }
  }

  final gateDashboardBloc = GatekeeperDashboardBloc(
      VisitorUsecase(
        VisitorRepoImpl(
          RemoteDataSource(),
        ),
      ),
      VisitorLogUsecase(
        VisitorLogRepositoryImpl(
          RemoteDataSource(),
        ),
      ));
  final provider = PurposeProvider();
  RemoteDataSource remoteDataSource = RemoteDataSource();

  @override
  void dispose() {
    _currentIndex = 0;
    // mobileController.dispose();
    mobileController.clear();
    super.dispose();

    mobileController.text = '';
  }

  List<PurposeCategory1> globalSelectedPurposes = [];

  Future<void> loadPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPurposes = prefs.getString('selected_purposes');
      if (savedPurposes != null) {
        final decoded = jsonDecode(savedPurposes) as List;
        globalSelectedPurposes =
            decoded.map((e) => PurposeCategory1.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Failed to load purposes: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Clear data when navigating back to this screen
        if (!didPop) {
          _clearVisitorData();
          log("🧹 Visitor data cleared when returning to ID Input View");
        }
      },
      child: Stack(
        children: [
          BlocConsumer<GatekeeperDashboardBloc, GatekeeperDashboardState>(
            bloc: gateDashboardBloc,
            listenWhen: (previous, current) =>
                current is GatekeeperDashboardActionState,
            buildWhen: (previous, current) =>
                current is! GatekeeperDashboardActionState,
            listener: (context, state) async {
              if (state is OpenPurposeDialogState) {
                if (globalSelectedPurposes.length == 1) {
                  final singlePurpose = globalSelectedPurposes.first;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VisitorsInEntry(
                        searchedVisitor: searchedVisitor,
                        selectedValue: singlePurpose,
                        mobile: mobileController.text,
                      ),
                    ),
                  );
                  return; // Exit early
                }
                if (searchedVisitor?.isStaff == true) {
                  RemoteDataSource().createVisitor(searchedVisitor!);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => RequestPermissionPage2(
                            visitor: searchedVisitor!,
                            selfcheckinFlow: false,
                            isGatekeeperQRPasscodeEntry: false)),
                  );
                } else {
                  showModalBottomSheet(
                    useSafeArea: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    context: context,
                    builder: (context) => ImageGridBottomSheet(
                      purposeCategories: state.purposeCategories!.toList(),
                      gatekeeperDashboardBloc: gateDashboardBloc,
                      mobileNumber:
                          mobileController.text, // Pass mobile number here
                      searchedVisitor:
                          searchedVisitor, // Pass searched visitor details
                    ),
                  );
                }
              }
              debugPrint("state.runtimeType :${state.runtimeType}");

              // Print detailed state information
              if (state is SaveSearchedVisitorState) {
                debugPrint(
                    "SaveSearchedVisitorState - Visitor: ${state.visitor?.toJson()}");
              } else if (state is VisitorAlreadyCheckedInErrorState) {
                debugPrint(
                    "VisitorAlreadyCheckedInErrorState - Message: ${state.message}");
              } else if (state is VisitorApiErrorState) {
                debugPrint(
                    "VisitorApiErrorState - Message: ${state.message}, Status: ${state.statusCode}");
              } else if (state is GatekeeperDashboardErrorState) {
                debugPrint(
                    "GatekeeperDashboardErrorState - Message: ${state.message}");
              } else {
                debugPrint("state response: $state");
              }
              switch (state.runtimeType) {
                case VisitorAlreadyCheckedInErrorState:
                  print("🎯 UI: Handling VisitorAlreadyCheckedInErrorState");
                  // Stop spinner and hide Next button for visitor already checked in error
                  setState(() {
                    isMobileApiLoading = false; // Always stop the spinner
                    hideNextButton =
                        true; // Hide the Next button - visitor already checked in
                    print(
                        "🟠 UI: hideNextButton set to TRUE, isMobileApiLoading set to FALSE - Visitor already checked in");
                  });

                  final visitorCheckedInErrorState =
                      state as VisitorAlreadyCheckedInErrorState;

                  debugPrint(
                      "Visitor already checked in error: ${visitorCheckedInErrorState.message}");

                  _showEnhancedErrorToast(
                    title: "Visitor Already Checked In",
                    message: visitorCheckedInErrorState.message,
                  );
                  break;

                case VisitorApiErrorState:
                  print("🎯 UI: Handling VisitorApiErrorState");
                  // Stop spinner on API error with non-200 status code and hide Next button
                  setState(() {
                    isMobileApiLoading =
                        false; // Always stop the spinner on error
                    hideNextButton = true; // Hide the Next button on error
                    print(
                        "🔴 UI: hideNextButton set to TRUE, isMobileApiLoading set to FALSE - Next button should be hidden");
                  });
                  final apiErrorState = state as VisitorApiErrorState;
                  print(
                      "🎯 UI: Showing snackbar with message: ${apiErrorState.message}");
                  // Show snackbar for API error
                  _showEnhancedErrorToast(
                    title: "API Error",
                    message: apiErrorState.message,
                  );
                  break;

                case GatekeeperDashboardErrorState:
                  // Stop spinner on error
                  if (isMobileApiLoading) {
                    setState(() {
                      isMobileApiLoading = false;
                    });
                  }
                  final errorState = state as GatekeeperDashboardErrorState;
                  myFluttertoast(
                    msg: errorState.message!,
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                  break;

                case SaveSearchedVisitorState:
                  print("🎯 UI: Handling SaveSearchedVisitorState");
                  final saveVisitorState = state as SaveSearchedVisitorState;
                  searchedVisitor = saveVisitorState.visitor;
                  // Stop spinner on success and show Next button
                  setState(() {
                    isMobileApiLoading =
                        false; // Always stop the spinner on success
                    hideNextButton = false; // Show the Next button on success
                    print(
                        "🟢 UI: hideNextButton set to FALSE, isMobileApiLoading set to FALSE - Next button should be visible");
                  });
                  break;

                case InputPutViewNextClickedState:
                  // Example: Set loading state here if needed
                  break;

                case NavigateToVisitorDetailsState:
                  final navigateToVisitorDetailsState =
                      state as NavigateToVisitorDetailsState;
                  // mobileController.text = '';

                  // Retrieve and decode the saved purpose
                  final prefs = await SharedPreferences.getInstance();
                  final jsonString = prefs.getString("dialoguePurpose");
                  PurposeCategory1? selectedPurpose;
                  if (jsonString != null) {
                    final json = jsonDecode(jsonString);
                    selectedPurpose = PurposeCategory1.fromJson(json);
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VisitorsInEntry(
                        searchedVisitor: navigateToVisitorDetailsState.visitor,
                        mobile: mobileController.text,
                        selectedValue: selectedPurpose,
                        isGatekeeperQRPasscodeEntry:
                            false, // This is mobile entry flow
                      ),
                    ),
                  );
                  break;
              }
            },
            builder: (context, state) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.45, 1.0],
                    colors: [
                      const Color(0xffF44336).withOpacity(0.15),
                      const Color(0xffD32F2F).withOpacity(0.08),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Form(
                  key: mobileControllerFormKey,
                  child: MyScrollView(
                    pageTitle: _currentIndex == 0
                        ? AppLocalizations.of(context).enterMobileNumber
                        : AppLocalizations.of(context).enterPasscode,
                    pageBody: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Enhanced Toggle Switch Card
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Mobile Number Tab
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _currentIndex = 0;
                                        });
                                        _clearVisitorData();
                                        mobileController.clear();
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          FocusScope.of(context)
                                              .requestFocus(_focusNode);
                                        });
                                        log("🧹 Visitor data cleared when switching to Mobile tab");
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        decoration: BoxDecoration(
                                          gradient: _currentIndex == 0
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xffF44336),
                                                    Color(0xffD32F2F)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: _currentIndex == 0
                                              ? null
                                              : Colors.white,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            bottomLeft: Radius.circular(8),
                                          ),
                                          border: Border.all(
                                            color: _currentIndex == 0
                                                ? const Color(0xffF44336)
                                                : Colors.grey.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            AppLocalizations.of(context)
                                                .mobileTab,
                                            style: TextStyle(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.w500,
                                              color: _currentIndex == 0
                                                  ? Colors.white
                                                  : const Color(0xff57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Passcode Tab
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _currentIndex = 1;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        decoration: BoxDecoration(
                                          gradient: _currentIndex == 1
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xffF44336),
                                                    Color(0xffD32F2F)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: _currentIndex == 1
                                              ? null
                                              : Colors.white,
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                          border: Border.all(
                                            color: _currentIndex == 1
                                                ? const Color(0xffF44336)
                                                : Colors.grey.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            AppLocalizations.of(context)
                                                .passCodeTab,
                                            style: TextStyle(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.w500,
                                              color: _currentIndex == 1
                                                  ? Colors.white
                                                  : const Color(0xff57636C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Enhanced Form Section
                          Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: _currentIndex == 0
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Enhanced Mobile Number Field Card
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 0),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.03),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            // Header Section with Icon and Title
                                            Container(
                                              padding: const EdgeInsets.all(20),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xffF44336)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Icon(
                                                      Icons.phone,
                                                      color: Color(0xffF44336),
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        RichText(
                                                          text: TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text: AppLocalizations.of(
                                                                        context)
                                                                    .visitorMobileNumber,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                      0xff212427),
                                                                ),
                                                              ),
                                                              const TextSpan(
                                                                text: ' *',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                      0xffF44336),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          AppLocalizations.of(
                                                                  context)
                                                              .enterTheVisitorMobileNumber,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            color: Color(
                                                                0xff57636C),
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Input Field Section
                                            Container(
                                              padding: const EdgeInsets.only(
                                                  left: 20,
                                                  right: 20,
                                                  bottom: 20),
                                              child: TextFormField(
                                                controller: mobileController,
                                                focusNode: _focusNode,
                                                maxLength: 10,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                cursorColor:
                                                    const Color(0xffF44336),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xff212427),
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return AppLocalizations.of(
                                                            context)
                                                        .mobileNumberIsRequired;
                                                  } else if (value.length !=
                                                      10) {
                                                    return 'Please enter a 10-digit number';
                                                  } else if (!RegExp(
                                                          r'^[0-9]+$')
                                                      .hasMatch(value)) {
                                                    return 'No spaces or special characters allowed';
                                                  }
                                                  return null;
                                                },
                                                onChanged: (value) {
                                                  // Reset hideNextButton when user starts typing
                                                  if (value.length < 10 &&
                                                      hideNextButton) {
                                                    setState(() {
                                                      hideNextButton = false;
                                                      print(
                                                          "🔄 UI: hideNextButton reset to FALSE - user typing");
                                                    });
                                                  }

                                                  if (value.length == 10 &&
                                                      !isMobileApiLoading) {
                                                    setState(() {
                                                      isMobileApiLoading = true;
                                                      print(
                                                          "🔄 UI: Starting API call - isMobileApiLoading set to TRUE");
                                                    });
                                                    gateDashboardBloc.add(
                                                      GDOnMobileNumberEnteredEvent(
                                                          mobileController
                                                              .text),
                                                    );
                                                  }
                                                },
                                                decoration: InputDecoration(
                                                  hintText: '0123456789',
                                                  hintStyle: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xff57636C),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      const Color(0xffF44336)
                                                          .withOpacity(0.02),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 16,
                                                    vertical: 16,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    borderSide: BorderSide(
                                                      color: const Color(
                                                              0xffF44336)
                                                          .withOpacity(0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    borderSide: BorderSide(
                                                      color: const Color(
                                                              0xffF44336)
                                                          .withOpacity(0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    borderSide:
                                                        const BorderSide(
                                                      color: Color(0xffF44336),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  counterText: '',
                                                  prefixIcon: CountryCodePicker(
                                                    initialSelection: 'IN',
                                                    favorite: [
                                                      'IN',
                                                      'US',
                                                      'GB',
                                                      'CA',
                                                      'AU'
                                                    ],
                                                    showFlagMain: true,
                                                    showFlagDialog: true,
                                                    flagWidth: 32,
                                                    dialogSize:
                                                        const Size(350, 500),
                                                    boxDecoration:
                                                        BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.1),
                                                          blurRadius: 20,
                                                          offset: const Offset(
                                                              0, 8),
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(
                                                                  0.05),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                              0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    barrierColor: Colors.black
                                                        .withOpacity(0.5),
                                                    closeIcon: const Icon(
                                                      Icons.close,
                                                      color: Color(0xffF44336),
                                                      size: 24,
                                                    ),
                                                    searchDecoration:
                                                        InputDecoration(
                                                      prefixIcon: Container(
                                                        margin: const EdgeInsets
                                                            .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                            colors: [
                                                              const Color(
                                                                      0xffF44336)
                                                                  .withOpacity(
                                                                      0.1),
                                                              const Color(
                                                                      0xffD32F2F)
                                                                  .withOpacity(
                                                                      0.05),
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: const Icon(
                                                          Icons.search,
                                                          color:
                                                              Color(0xffF44336),
                                                          size: 22,
                                                        ),
                                                      ),
                                                      hintText:
                                                          'Search countries...',
                                                      hintStyle:
                                                          const TextStyle(
                                                        color:
                                                            Color(0xff57636C),
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                      filled: true,
                                                      fillColor: const Color(
                                                              0xffF44336)
                                                          .withOpacity(0.02),
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 16,
                                                        vertical: 16,
                                                      ),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        borderSide: BorderSide(
                                                          color: const Color(
                                                                  0xffF44336)
                                                              .withOpacity(0.2),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        borderSide:
                                                            const BorderSide(
                                                          color:
                                                              Color(0xffF44336),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        borderSide: BorderSide(
                                                          color: const Color(
                                                                  0xffF44336)
                                                              .withOpacity(0.2),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                    ),
                                                    textStyle: const TextStyle(
                                                      color: Color(0xff212427),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    dialogTextStyle:
                                                        const TextStyle(
                                                      color: Color(0xff212427),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    emptySearchBuilder:
                                                        (context) => Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              32),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(16),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                      0xffF44336)
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          50),
                                                            ),
                                                            child: const Icon(
                                                              Icons.search_off,
                                                              color: Color(
                                                                  0xffF44336),
                                                              size: 32,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 16),
                                                          const Text(
                                                            'No countries found',
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xff212427),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          const Text(
                                                            'Try searching with a different term',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Color(
                                                                  0xff57636C),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    onChanged: (CountryCode
                                                        countryCode) {
                                                      setState(() {
                                                        selectedCountryCode =
                                                            countryCode.code!;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isMobileApiLoading) ...[
                                        const SizedBox(height: 20),
                                        // Enhanced Loading Card with Green Theme
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.green.withOpacity(0.1),
                                                Colors.green.withOpacity(0.05),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color:
                                                  Colors.green.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Animated Loading Indicator
                                              SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Colors.green,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Loading Text with Animation
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      AppLocalizations.of(
                                                              context)
                                                          .validatingMobileNumber,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Please wait while we check your details',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: const Color(
                                                            0xff57636C),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Animated Dots Loader
                                              Row(
                                                children: [
                                                  for (int i = 0; i < 3; i++)
                                                    Container(
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 2),
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Enhanced Passcode Field Card
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 0),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.03),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            // Header Section with Icon and Title
                                            Container(
                                              padding: const EdgeInsets.all(20),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xffF44336)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Icon(
                                                      Icons.lock,
                                                      color: Color(0xffF44336),
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        RichText(
                                                          text: const TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text:
                                                                    'Visitor Passcode',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                      0xff212427),
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text: ' *',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                      0xffF44336),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        const Text(
                                                          'Enter your 6-digit passcode to continue',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Color(
                                                                0xff57636C),
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Input Field Section
                                            Container(
                                              padding: const EdgeInsets.only(
                                                  left: 20,
                                                  right: 20,
                                                  bottom: 20),
                                              child: Form(
                                                key: passcodeControllerFormKey,
                                                child: TextFormField(
                                                  controller:
                                                      passcodeController,
                                                  maxLength: 6,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  textCapitalization:
                                                      TextCapitalization
                                                          .characters,
                                                  cursorColor:
                                                      const Color(0xffF44336),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xff212427),
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Passcode is required';
                                                    } else if (value.length !=
                                                        6) {
                                                      return 'Please enter a 6-digit passcode';
                                                    }
                                                    return null;
                                                  },
                                                  decoration: InputDecoration(
                                                    hintText: '123456',
                                                    hintStyle: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: Color(0xff57636C),
                                                    ),
                                                    filled: true,
                                                    fillColor:
                                                        const Color(0xffF44336)
                                                            .withOpacity(0.02),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 16,
                                                      vertical: 16,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      borderSide: BorderSide(
                                                        color: const Color(
                                                                0xffF44336)
                                                            .withOpacity(0.2),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      borderSide: BorderSide(
                                                        color: const Color(
                                                                0xffF44336)
                                                            .withOpacity(0.2),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      borderSide:
                                                          const BorderSide(
                                                        color:
                                                            Color(0xffF44336),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    counterText: '',
                                                    suffixIcon: Container(
                                                      margin:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: CircleAvatar(
                                                        backgroundColor: Colors
                                                            .green
                                                            .withOpacity(0.1),
                                                        radius: 20,
                                                        child: IconButton(
                                                          onPressed:
                                                              isPasscodeVerifying
                                                                  ? null
                                                                  : () async {
                                                                      if (passcodeControllerFormKey
                                                                          .currentState!
                                                                          .validate()) {
                                                                        // Trigger passcode verification
                                                                        setState(
                                                                            () {
                                                                          isPasscodeVerifying =
                                                                              true;
                                                                        });

                                                                        // Add haptic feedback
                                                                        HapticFeedback
                                                                            .lightImpact();

                                                                        // Call the verification function
                                                                        await _handlePasscodeVerification();

                                                                        setState(
                                                                            () {
                                                                          isPasscodeVerifying =
                                                                              false;
                                                                        });
                                                                      }
                                                                    },
                                                          icon: isPasscodeVerifying
                                                              ? const SizedBox(
                                                                  width: 20,
                                                                  height: 20,
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    valueColor: AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Color(
                                                                            0xffF44336)),
                                                                  ),
                                                                )
                                                              : const Icon(
                                                                  Symbols
                                                                      .done_rounded,
                                                                  color: Colors
                                                                      .green,
                                                                  size: 20,
                                                                ),
                                                          padding:
                                                              EdgeInsets.zero,
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
                        ],
                      ),
                    ),
                    floatingActionButton: () {
                      final shouldHideButton =
                          (isMobileApiLoading || hideNextButton);
                      print("🔍 UI: FloatingActionButton condition check:");
                      print("   - isMobileApiLoading: $isMobileApiLoading");
                      print("   - hideNextButton: $hideNextButton");
                      print("   - shouldHideButton: $shouldHideButton");

                      return shouldHideButton
                          ? null // Hide Next button during mobile number validation or API errors
                          : Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff212427),
                                      Color(0xff57636C)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: checkVisitorLoading
                                        ? null
                                        : checkVisitor,
                                    child: Center(
                                      child: Text(
                                        checkVisitorLoading
                                            ? 'Processing...'
                                            : 'Next',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                    }(),
                    floatingActionButtonLocation:
                        FloatingActionButtonLocation.centerDocked,
                  ),
                ),
              );
            },
          ),
          if (isLoading)
            DashboardLoader(
              title: 'Loading Visitor Input',
              subtitle: 'Please wait while we process your request...',
            ), // DashboardLoader overlay
        ],
      ),
    );
  }

  void checkVisitor() async {
    checkVisitorLoading = true;
    _focusNode.unfocus();

    if (_currentIndex == 0) {
      // Mobile number validation & processing
      if (mobileControllerFormKey.currentState?.validate() ?? false) {
        gateDashboardBloc.add(InputPutViewNextClickedEvent());
      }
    } else {
      // Passcode verification process
      if (passcodeControllerFormKey.currentState?.validate() ?? false) {
        _handlePasscodeVerification();
      }
    }

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        checkVisitorLoading = false;
      });
    });
  }

  File? _imageFile;
  var visitorData;

  /// ✅ Handles Passcode Verification & Captures Image if Verified
  Future<void> _handlePasscodeVerification() async {
    startLoading(); // Show loading indicator

    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');

      // 🔍 Verify Passcode
      final result = await remoteDataSource.verifyPasscode(
        companyId: companyId ?? "",
        passcode: passcodeController.text,
      );

      stopLoading(); // Hide loading indicator
      print("✅ Verification Result: $result");

      if (result['success'] == true && result['data'] != null) {
        visitorData = result['data'][0]; // Get first visitor entry
        print("visitorData$visitorData");

        final String mobileNumber = visitorData['mobile'];
        final String name = visitorData['name'];

        final int id = visitorData['visitor_id'];

        _showEnhancedSuccessToast(
          title: "Passcode Verified",
          message: "Welcome $name! Proceeding to guest information.",
          icon: Icons.verified_user,
        );

        // ✅ Navigate directly to guest information page (skip camera screen)
        await _navigateToGuestInformationPage(mobileNumber, id.toString());
      } else {
        _showEnhancedErrorToast(
          title: "Invalid Passcode",
          message: "Not a valid passcode",
          icon: Icons.lock_outline,
        );
      }
    } catch (e) {
      stopLoading();

      // Provide more specific error messages based on the error type
      String errorTitle = "Verification Failed";
      String errorMessage = "Unable to verify passcode. Please try again.";
      IconData errorIcon = Icons.error_outline;

      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorTitle = "Network Error";
        errorMessage = "Please check your internet connection and try again.";
        errorIcon = Icons.wifi_off;
      } else if (e.toString().contains('timeout')) {
        errorTitle = "Request Timeout";
        errorMessage = "The request took too long. Please try again.";
        errorIcon = Icons.access_time;
      } else if (e.toString().contains('server')) {
        errorTitle = "Server Error";
        errorMessage =
            "Server is temporarily unavailable. Please try again later.";
        errorIcon = Icons.dns;
      }

      _showEnhancedErrorToast(
        title: errorTitle,
        message: errorMessage,
        icon: errorIcon,
      );
    }
  }

  /// ✅ Navigate directly to guest information page (skip camera screen)
  Future<void> _navigateToGuestInformationPage(
      String mobileNumber, String id) async {
    try {
      // Create visitor and visitor log objects for navigation
      Visitor visitor = Visitor(
        name: visitorData['name'],
        mobile: visitorData['mobile'],
        visitor_image: visitorData['visitor_image'] ?? "",
      );

      // Extract visitor_count from API response, checking both visitor_count and guest_count fields
      final int visitorCount = visitorData['visitor_count'] ?? 
                               visitorData['guest_count'] ?? 
                               1;

      VisitorLog visitorLog = VisitorLog(
        visitor: visitor,
        visitor_coming_from: visitorData['coming_from'],
        visitor_purpose_Category_name: visitorData['category'] ?? "Guest",
        visitor_purpose_category_id: 1,
        visitor_count: visitorCount,
      );

      // Determine the correct purpose category from API response
      final String categoryFromApi =
          visitorData['category']?.toString() ?? "Guest";

      // Fetch the complete purpose data including subcategories
      final PurposeCategory1? completePurpose =
          await _getCompletePurposeData(categoryFromApi);

      // Navigate directly to purpose entry page based on actual entry type (skip camera screen)
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => VisitorsInEntry(
                    selfcheckinFlow: false,
                    comingfrom: visitorData['coming_from'],
                    searchedVisitor: visitor,
                    selectedValue: completePurpose ??
                        PurposeCategory1(categoryId: 1, categoryName: "Guest"),
                    mobile: visitorData['mobile'],
                    guestname: visitorData['name'] ?? "",
                    isFromQRScan:
                        true, // Flag to indicate this is from passcode entry
                    isGatekeeperQRPasscodeEntry:
                        true, // Flag to indicate this is from gatekeeper passcode entry
                    visitorLog: visitorLog,
                  )));
    } catch (e) {
      print("❌ Error navigating to guest information page: $e");
    }
  }

  /// ✅ Requests Camera Permission & Captures Image
  Future<void> _requestCameraPermissionAndCapture(
      String mobileNumber, String id) async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isDenied || status.isRestricted) {
      // Request permission
      status = await Permission.camera.request();

      if (!status.isGranted) {
        print("❌ Camera permission denied!");
        myFluttertoast(
          msg: "Camera permission required to capture an image.",
          backgroundColor: Colors.orange,
        );
        return;
      }
    }

    // ✅ Capture Image if Permission is Granted
    await _captureImageFromCamera(mobileNumber, id);
  }

  /// ✅ Captures Image from Camera & Uploads it
  Future<void> _captureImageFromCamera(String mobileNumber, String id) async {
    final picker = ImagePicker();
    XFile? image;

    try {
      // 📷 Capture image from camera
      image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        print("❌ No image captured");
        return;
      }

      setState(() {
        _imageFile = File(image!.path);
      });

      print("📷 Image captured: ${_imageFile!.path}");

      // ✅ Upload the captured image
      await _uploadCapturedImage(mobileNumber, id);
    } catch (e) {
      log('❌ Error capturing image from camera: $e');
    }
  }

  Future<void> _uploadCapturedImage(String mobileNumber, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');

      if (_imageFile == null) {
        print("❌ No image to upload.");
        return;
      }

      // ✅ Compress Image
      File? compressedImage = await _compressImage(_imageFile!);
      if (compressedImage == null) {
        print("❌ Compression failed, using original file.");
        compressedImage = _imageFile!;
      }

      print("📷 Final Image Size: ${compressedImage.lengthSync()} bytes");

      // ✅ Upload Image to Server
      final response = await remoteDataSource.uploadFile(
        compressedImage,
        mobileNumber,
        int.parse(companyId ?? "0"),
      );

      print("✅ Image uploaded successfully: $response");

      if (response != null) {
        await prefs.setString('uploaded_image_url', response);
        print("🔄 Image URL saved: $response");

        // ✅ Update Visitor Entry with Uploaded Image URL
        await _updateVisitorEntry(mobileNumber, response, id);

        // Create visitor and visitor log objects for navigation
        Visitor visitor = Visitor(
          visitor_image: response,
          name: visitorData['name'],
          mobile: visitorData['mobile'],
        );

        // Extract visitor_count from API response, checking both visitor_count and guest_count fields
        final int visitorCount = visitorData['visitor_count'] ?? 
                                 visitorData['guest_count'] ?? 
                                 1;

        VisitorLog visitorLog = VisitorLog(
          visitor: visitor,
          visitor_coming_from: visitorData['coming_from'],
          visitor_purpose_Category_name: visitorData['category'] ?? "Guest",
          visitor_purpose_category_id: 1,
          visitor_count: visitorCount,
        );

        // Navigate to guest information page (same flow as QR scanner)
        await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => VisitorsInEntry(
                      selfcheckinFlow: false,
                      comingfrom: visitorData['coming_from'],
                      searchedVisitor: visitor,
                      selectedValue: PurposeCategory1(
                          categoryId: 1, categoryName: "Guest"),
                      mobile: visitorData['mobile'],
                      guestname: visitorData['name'] ?? "",
                      isFromQRScan:
                          true, // Flag to indicate this is from passcode entry
                      isGatekeeperQRPasscodeEntry:
                          true, // Flag to indicate this is from gatekeeper passcode entry
                      visitorLog: visitorLog,
                    )));
      }
    } catch (e) {
      print("❌ Error uploading image: $e");
    }
  }

  /// ✅ Compress Image Before Uploading
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
          dir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg");

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Adjust quality (higher = better, but larger file)
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print("❌ Error compressing image: $e");
      return null;
    }
  }

  /// ✅ PATCH Request to Update Visitor Entry
  Future<void> _updateVisitorEntry(
      String mobileNumber, String imageUrl, String id) async {
    try {
      int id1 = int.parse(id);
      final dio = Dio();
      final String apiUrl = "${ApiUrls.gateBaseUrl}/visitor/entry/$id1";
      final comingFrom = await GateStorage().getComingFrom();
      final data = {
        "visitor_image": imageUrl,
        "coming_from": comingFrom,
      };

      final response = await dio.patch(
        apiUrl,
        options: Options(headers: {"Content-Type": "application/json"}),
        data: data,
      );

      if (response.statusCode == 200) {
        print("✅ Visitor entry updated successfully: ${response.data}");
      } else {
        print("❌ Failed to update visitor entry: ${response.statusMessage}");
      }
    } catch (e) {
      print("❌ Error updating visitor entry: $e");
    }

    // ✅ Navigate to Dashboard after successful update
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GateDashboardView(),
      ),
    );
  }

  /// Logs the current state of visitor data for debugging purposes
  Future<void> _logVisitorDataState() async {
    final prefs = await SharedPreferences.getInstance();
    final visitorId = prefs.getString('visitorId');
    final visitorLogId = prefs.getString('visitor_log_id');

    log("📊 Visitor data state:");
    log("  - searchedVisitor: ${searchedVisitor?.toJson()}");
    log("  - visitorId in SharedPreferences: $visitorId");
    log("  - visitorLogId in SharedPreferences: $visitorLogId");
    log("  - hideNextButton: $hideNextButton");
    log("  - isMobileApiLoading: $isMobileApiLoading");
  }

  /// Enhanced error toast with better styling and messages
  void _showEnhancedErrorToast({
    required String title,
    required String message,
    IconData? icon,
  }) {
    // Use a more sophisticated toast with better styling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon ?? Icons.error_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
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
        duration: const Duration(seconds: 4),
        elevation: 8,
      ),
    );

    // Add haptic feedback for error
    HapticFeedback.heavyImpact();
  }

  /// Enhanced success toast
  void _showEnhancedSuccessToast({
    required String title,
    required String message,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon ?? Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );

    // Add haptic feedback for success
    HapticFeedback.lightImpact();
  }

  /// Helper method to get category ID from category name
  int _getCategoryIdFromName(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'STAFF':
        return 2;
      case 'DELIVERY':
        return 3;
      case 'MEMBER STAFF':
        return 4;
      case 'VENDOR':
        return 5;
      case 'CABS':
        return 6;
      case 'GUEST':
      default:
        return 1;
    }
  }

  /// Fetch complete purpose data including subcategories from API
  Future<PurposeCategory1?> _getCompletePurposeData(String categoryName) async {
    try {
      final purposes = await remoteDataSource.fetchPurpose();
      if (purposes != null) {
        // Find the purpose that matches the category name
        for (final purpose in purposes) {
          if (purpose.categoryName.toUpperCase() ==
              categoryName.toUpperCase()) {
            return purpose;
          }
        }
      }
    } catch (e) {
      print("❌ Error fetching complete purpose data: $e");
    }
    return null;
  }
}

class ImageGridBottomSheet extends StatefulWidget {
  final List<PurposeCategory1> purposeCategories;
  final GatekeeperDashboardBloc gatekeeperDashboardBloc;
  final String mobileNumber; // <-- Add this
  Visitor? searchedVisitor;

  ImageGridBottomSheet({
    super.key,
    required this.purposeCategories,
    this.searchedVisitor,
    required this.gatekeeperDashboardBloc,
    required this.mobileNumber, // <-- Add this
  });

  @override
  _ImageGridBottomSheetState createState() => _ImageGridBottomSheetState();
}

class _ImageGridBottomSheetState extends State<ImageGridBottomSheet> {
  int? selectedImageIndex;
  bool isStaffAutoSelected = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedPurposesToGlobal();

    // Auto-select GUEST purpose (index 0 after reordering)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (globalSelectedPurposes.isNotEmpty) {
        setState(() {
          selectedImageIndex = 0; // GUEST is always first after reordering
        });
      } else if (widget.purposeCategories.isNotEmpty) {
        // Reorder widget.purposeCategories and find GUEST index
        final reorderedCategories =
            _reorderPurposeCategories(widget.purposeCategories);
        final guestIndex = reorderedCategories.indexWhere(
            (purpose) => purpose.categoryName.toUpperCase() == 'GUEST');
        setState(() {
          selectedImageIndex = guestIndex != -1 ? guestIndex : 0;
        });
      }
    });
  }

  List<PurposeCategory1> globalSelectedPurposes = [];

  Future<void> _loadSelectedPurposesToGlobal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('selected_purposes');

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final loadedPurposes =
            jsonList.map((json) => PurposeCategory1.fromJson(json)).toList();

        setState(() {
          globalSelectedPurposes = _reorderPurposeCategories(loadedPurposes);
        });
        print(
            "Global selected purposes loaded and reordered: $globalSelectedPurposes");
      } else {
        print("No selected purposes found in SharedPreferences.");
      }
    } catch (e) {
      print("Failed to load selected purposes into global variable: $e");
    }
  }

  /// Reorders purpose categories in the specified order: GUEST, DELIVERY, STAFF, MEMBER STAFF, VENDOR, CABS
  List<PurposeCategory1> _reorderPurposeCategories(
      List<PurposeCategory1> purposes) {
    final reorderedList = <PurposeCategory1>[];
    final orderPriority = [
      'GUEST',
      'DELIVERY',
      'STAFF',
      'MEMBER STAFF',
      'VENDOR',
      'CABS'
    ];

    // Add purposes in the specified order
    for (String categoryName in orderPriority) {
      final matchingPurposes = purposes
          .where((purpose) =>
              purpose.categoryName.toUpperCase() == categoryName.toUpperCase())
          .toList();
      reorderedList.addAll(matchingPurposes);
    }

    // Add any remaining purposes that weren't in the priority list
    final remainingPurposes = purposes
        .where((purpose) => !orderPriority.any((priority) =>
            priority.toUpperCase() == purpose.categoryName.toUpperCase()))
        .toList();
    reorderedList.addAll(remainingPurposes);

    return reorderedList;
  }

  void purposeSelectionBottomSheet() async {
    FocusScope.of(context).unfocus();
    if (selectedImageIndex == null) {
      myFluttertoast(
          msg: AppLocalizations.of(context).pleaseSelectPurpose,
          backgroundColor: Colors.red);
      return;
    }

    if (selectedImageIndex != -1) {
      final selectedValue = globalSelectedPurposes.isEmpty
          ? _reorderPurposeCategories(
              widget.purposeCategories)[selectedImageIndex!]
          : globalSelectedPurposes[selectedImageIndex!];

      Navigator.pop(
        context,
        selectedValue,
      );

      final dialogue = await SharedPreferences.getInstance();
      await dialogue.setString(
        "dialoguePurpose",
        jsonEncode(selectedValue.toJson()),
      );

      widget.gatekeeperDashboardBloc.add(
        PurposeNextButtonClickedEvent(
          selectedValue,
          widget.searchedVisitor,
          widget.mobileNumber,
        ),
      );
    }
  }

  void selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool selectPurposeLoading = false;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.white,
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Purpose Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assignment,
                    color: const Color(0xffF44336),
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).selectPurposeOfVisit,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff212427),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Enhanced Close Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffF44336), Color(0xffD32F2F)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffF44336).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Ionicons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Enhanced Grid Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: globalSelectedPurposes.isEmpty
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount:
                          _reorderPurposeCategories(widget.purposeCategories)
                              .length,
                      itemBuilder: (context, index) {
                        final reorderedPurposes =
                            _reorderPurposeCategories(widget.purposeCategories);
                        final purpose = reorderedPurposes[index];
                        final isSelected = selectedImageIndex == index;

                        return GestureDetector(
                          onTap: () {
                            selectImage(index);
                            HapticFeedback.lightImpact();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xffF44336)
                                    : Colors.grey.withOpacity(0.2),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? const Color(0xffF44336).withOpacity(0.2)
                                      : Colors.black.withOpacity(0.05),
                                  blurRadius: isSelected ? 12 : 6,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Enhanced Image Container
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: purpose.image ?? "",
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.1),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Color(0xffF44336),
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.1),
                                        ),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Color(0xffF44336),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Enhanced Text
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    purpose.categoryName,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xffF44336)
                                          : const Color(0xff212427),
                                    ),
                                  ),
                                ),

                                // Selection Indicator
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: const Color(0xffF44336),
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: globalSelectedPurposes.length,
                      itemBuilder: (context, index) {
                        final purpose = globalSelectedPurposes[index];
                        final isSelected = selectedImageIndex == index;

                        return GestureDetector(
                          onTap: () {
                            if (!isStaffAutoSelected) {
                              selectImage(index);
                              HapticFeedback.lightImpact();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xffF44336)
                                    : Colors.grey.withOpacity(0.2),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? const Color(0xffF44336).withOpacity(0.2)
                                      : Colors.black.withOpacity(0.05),
                                  blurRadius: isSelected ? 12 : 6,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Enhanced Image Container
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: purpose.image ?? "",
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.1),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Color(0xffF44336),
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.1),
                                        ),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Color(0xffF44336),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Enhanced Text
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    purpose.categoryName,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xffF44336)
                                          : const Color(0xff212427),
                                    ),
                                  ),
                                ),

                                // Selection Indicator
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: const Color(0xffF44336),
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Enhanced Action Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff212427), Color(0xff57636C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap:
                      selectPurposeLoading ? null : purposeSelectionBottomSheet,
                  child: Center(
                    child: Text(
                      selectPurposeLoading ? 'Processing...' : 'Select Purpose',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
