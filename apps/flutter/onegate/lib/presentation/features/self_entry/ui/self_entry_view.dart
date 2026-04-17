// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kiosk_mode/flutter_kiosk_mode.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';
import 'package:flutter_onegate/presentation/widgets/custom_numpad.dart';
import 'package:flutter_onegate/presentation/widgets/enhanced_input_field.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/presentation/widgets/enhanced_toast.dart';
import 'package:flutter_onegate/presentation/widgets/enhanced_video_carousel.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';

import '../../../../data/datasources/gate_storage.dart';

class SelfEntryView extends StatefulWidget {
  const SelfEntryView({super.key});

  @override
  State<SelfEntryView> createState() => _SelfEntryViewState();
}

class _SelfEntryViewState extends State<SelfEntryView>
    with TickerProviderStateMixin {
  // Variables for current step and country code.
  int activeStep = 0;
  String code = "";
  String selectedCountryCodeSE = 'IN';
  String? selectedGateName;

  // Create an instance of RemoteDataSource.
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  final GateStorage _gateStorage = GateStorage();

  // Text controllers.
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();

  final FocusNode _mobileFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _locationFocusNode = FocusNode();
  final FocusNode _purposeFocusNode = FocusNode();
  final FocusNode _hostFocusNode = FocusNode();
  final _flutterKioskMode = FlutterKioskMode.instance();

  late Timer _timer = Timer(Duration.zero, () {});
  int _start = 10;

  // Resend OTP functionality
  Timer? _resendTimer;
  int _resendCountdown = 30;
  bool _canResendOtp = false;

  late TabController _tabController;

  int? _visitorId;

  bool isProcessing = false;

  /// Get the appropriate title based on the current tab
  String get _currentPageTitle {
    switch (_tabController.index) {
      case 0:
        return context.tr('Enter Mobile Number');
      case 1:
        return context.tr('Enter OTP');
      default:
        return context.tr('Enter Mobile Number');
    }
  }

  /// Start the resend OTP countdown timer
  void _startResendCountdown() {
    _canResendOtp = false;
    _resendCountdown = 30;

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResendOtp = true;
        });
        timer.cancel();
      }
    });
  }

  /// Resend OTP to the mobile number
  Future<void> _resendOtp() async {
    if (!_canResendOtp) return;

    try {
      final mobileNumber = _mobileController.text;
      if (mobileNumber.isNotEmpty) {
        await selfCheckInOtp(mobileNumber);
        showEnhancedToast(
          context,
          title: context.tr('Success'),
          message: context.tr("OTP has been resent successfully"),
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
        _startResendCountdown();
      }
    } catch (e) {
      showEnhancedToast(
        context,
        title: context.tr('Error'),
        message: context.tr("Failed to resend OTP. Please try again."),
        backgroundColor: const Color(0xffF44336),
        icon: Icons.error_outline,
      );
    }
  }

  // Track that user is in express entry flow
  Future<void> _trackExpressEntryRoute() async {
    await RouteTracker.saveCurrentRoute(
      'SelfEntryView',
      isExpressEntry: true,
    );
  }

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
    _getSelectedGate();
    _trackExpressEntryRoute();

    // Add tab change listener to auto-focus appropriate field and update title
    _tabController.addListener(() {
      // Update the UI to reflect the new title
      setState(() {});

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_tabController.index == 0) {
            // Mobile number tab
            FocusScope.of(context).requestFocus(_mobileFocusNode);
          } else if (_tabController.index == 1) {
            // OTP tab
            FocusScope.of(context).requestFocus(_otpFocusNode);
            // Start resend countdown when OTP tab becomes active
            _startResendCountdown();
          }
        }
      });
    });

    // Auto-focus on mobile number input field when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_mobileFocusNode);
      }
    });
  }

  Future<void> _getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  void _disableKioskMode() async {
    try {
      await _flutterKioskMode.stop();
    } catch (e) {
      print("Error stopping kiosk mode: $e");
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _resendTimer?.cancel();
    _mobileController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _purposeController.dispose();
    _hostController.dispose();
    _mobileFocusNode.dispose();
    _otpFocusNode.dispose();
    _nameFocusNode.dispose();
    _locationFocusNode.dispose();
    _purposeFocusNode.dispose();
    _hostFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Enhanced video carousel with 4 cyberone videos
  Widget _buildAdsCarousel(BuildContext context) {
    return const EnhancedVideoCarousel();
  }

  /// Starts a countdown timer.
  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  var comingfrom;
  final GateStorage gateStorage = GateStorage();

  /// Sends an OTP for self-checkin.
  Future<void> selfCheckInOtp(String mobileNumber) async {
    loadPurposes();
    try {
      final result =
          await _remoteDataSource.sendOtpForSelfCheckIn(mobileNumber);
      if (result['message'] == 'Visitor is already verified') {
        comingfrom = result['data']['coming_from'];
        final visitorData = result['data'];
        final visitor = Visitor(
          id: visitorData['id'],
          name: visitorData['name'] ?? '',
          mobile: visitorData['mobile'] ?? '',
          visitor_image: visitorData['visitor_image'],
        );

        // For existing visitors in Express Entry flow, ALWAYS require member approval
        // Load purposes to get default purpose
        await loadPurposes();

        // Determine default purpose (first available or fallback to Guest)
        PurposeCategory1 defaultPurpose;
        if (globalSelectedPurposes.isNotEmpty) {
          defaultPurpose = globalSelectedPurposes.first;
        } else {
          // Fallback to default Guest purpose
          defaultPurpose = PurposeCategory1(
            categoryId: 1,
            categoryName: "Guest",
            image: null,
          );
        }

        print(
            "DEBUG: Existing visitor detected in Express Entry flow, proceeding with member approval: ${defaultPurpose.categoryName}");

        // Navigate to visitor information form - approval will be required
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisitorsInEntry(
              selfcheckinFlow: true,
              comingfrom: comingfrom,
              searchedVisitor: visitor,
              selectedValue: defaultPurpose,
              mobile: _mobileController.text,
              isGatekeeperQRPasscodeEntry: false, // This is self-entry flow
            ),
          ),
        );

        return;
      }
      // comingfrom = result['data']['coming_from'];
      _tabController.animateTo(1);
      _start = 10; // Default timer value
      startTimer();

      // Show OTP success toast only for new visitors (not existing ones)
      showEnhancedToast(
        context,
        title: context.tr('Success'),
        message: context.tr("OTP sent successfully"),
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline,
      );
    } catch (e) {
      log('Error sending OTP: $e');
      myFluttertoast(
          msg: AppLocalizations.of(context).errorSendingOTPPleaseTryAgain,
          backgroundColor: Colors.red);
    }
  }

  /// Verifies the self-checkin OTP.

  Future<void> verifySelfCheckin(String mobileNumber, String otp) async {
    try {
      final result = await _remoteDataSource.verifySelfCheckin(
        mobileNumber: mobileNumber,
        otp: otp,
      );
      log('OTP verification response: $result');

      log("Result message: ${result['message']}");
      log("Result data: ${result['data']}");

      if (result['data'] != null && result['data'] is Map<String, dynamic>) {
        final dynamic idValue = result['data']['id'];
        if (idValue is int) {
          _visitorId = idValue;
        } else if (idValue is String) {
          _visitorId = int.tryParse(idValue);
        }
        log("Visitor id set to: $_visitorId");
      }

      if (result['message'] == 'Visitor is already verified') {
        final prefs = await SharedPreferences.getInstance();
        final visitorId = prefs.getString('visitorId');
        log(visitorId.toString());

        // Visitor is already verified - handle purpose selection with verification flag
        await _handlePurposeSelection(isVisitorVerified: true);
        return;
      }
      // _captureImageFromCamera(); // Commented out to skip camera capture

      // Show success toast message first
      showEnhancedToast(
        context,
        title: context.tr('Success'),
        message: AppLocalizations.of(context).otpVerifiedSuccessfully,
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline,
      );

      // Wait for toast to be visible, then handle purpose selection
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _handlePurposeSelection(isVisitorVerified: false);
        }
      });
    } catch (e) {
      log('Error during OTP verification: $e');
      showEnhancedToast(
        context,
        title: context.tr('Error'),
        message:
            context.tr("Incorrect OTP Entered. Please check and try again"),
        backgroundColor: const Color(0xffF44336),
        icon: Icons.error_outline,
      );
    }
  }

  /// Handles purpose selection logic based on enabled purposes and visitor verification status
  Future<void> _handlePurposeSelection({bool isVisitorVerified = false}) async {
    print(
        "DEBUG: _handlePurposeSelection called - isVisitorVerified: $isVisitorVerified");

    // Load purposes for selection
    await loadPurposes();

    // Check if visitor is already verified with OTP
    if (isVisitorVerified) {
      print("DEBUG: Visitor is already verified, skipping purpose selection");
      await _proceedWithDefaultPurpose();
      return;
    }

    // Check number of enabled purposes
    if (globalSelectedPurposes.isEmpty) {
      print("DEBUG: No purposes available, using default");
      await _proceedWithDefaultPurpose();
      return;
    }

    if (globalSelectedPurposes.length == 1) {
      print(
          "DEBUG: Single purpose enabled (${globalSelectedPurposes.first.categoryName}), auto-assigning");
      await _proceedWithDefaultPurpose();
      return;
    }

    // Multiple purposes enabled and visitor not verified - show bottom sheet
    print(
        "DEBUG: Multiple purposes enabled, showing purpose selection bottom sheet");
    await _showPurposeSelectionBottomSheet();
  }

  /// Proceeds with the default purpose (single purpose or first available)
  Future<void> _proceedWithDefaultPurpose() async {
    print("DEBUG: _proceedWithDefaultPurpose called");

    // Get visitor data
    final prefs = await SharedPreferences.getInstance();
    final visitorId = prefs.getString('visitorId');

    // Determine default purpose
    PurposeCategory1 defaultPurpose;
    if (globalSelectedPurposes.isNotEmpty) {
      defaultPurpose = globalSelectedPurposes.first;
    } else {
      // Fallback to default Guest purpose
      defaultPurpose = PurposeCategory1(
        categoryId: 1,
        categoryName: "Guest",
        image: null,
      );
    }

    print("DEBUG: Using default purpose: ${defaultPurpose.categoryName}");

    // Create visitor object
    final visitor = Visitor(
      id: int.parse(visitorId ?? "0"),
      name: "",
      mobile: _mobileController.text,
      visitor_image: null,
    );

    // Navigate directly to visitor information page
    await _navigateToVisitorInformation(visitor, defaultPurpose);
  }

  /// Navigates to visitor information page with selected purpose
  Future<void> _navigateToVisitorInformation(
      Visitor visitor, PurposeCategory1 purpose) async {
    print(
        "DEBUG: _navigateToVisitorInformation called with purpose: ${purpose.categoryName}");

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisitorsInEntry(
          selfcheckinFlow: true,
          comingfrom: comingfrom,
          searchedVisitor: visitor,
          selectedValue: purpose,
          mobile: _mobileController.text,
          isGatekeeperQRPasscodeEntry: false, // This is self-entry flow
        ),
      ),
    );
  }

  /// Shows the purpose selection bottom sheet directly after OTP verification
  /// without requiring camera capture
  Future<void> _showPurposeSelectionBottomSheet() async {
    print("DEBUG: _showPurposeSelectionBottomSheet called - OneGate UI");

    // Get visitor data for the bottom sheet
    final prefs = await SharedPreferences.getInstance();
    final visitorId = prefs.getString('visitorId');

    // Create visitor object without image (since camera is skipped)
    final visitor = Visitor(
      id: int.parse(visitorId ?? "0"),
      name: "",
      mobile: _mobileController.text,
      visitor_image: null, // No image since camera is skipped
    );

    // Show the purpose selection bottom sheet with OneGate app UI
    print("DEBUG: Showing OneGate app UI bottom sheet");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows for height adjustment
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
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
                                  Icons.close,
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
                          ? _buildPurposeGrid(setState, context,
                              category: "GUEST")
                          : _buildPurposeGrid(setState, context),
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
                          onTap: isProcessing
                              ? null
                              : () async {
                                  if (isProcessing) return;
                                  setState(() => isProcessing = true);

                                  // Get selected purpose
                                  final selectedPurpose =
                                      globalSelectedPurposes[
                                          selectedImageIndex ?? 0];

                                  // Navigate using the new method
                                  await _navigateToVisitorInformation(
                                      visitor, selectedPurpose);

                                  setState(() => isProcessing = false);
                                },
                          child: Center(
                            child: Text(
                              isProcessing
                                  ? context.tr('Processing')
                                  : context.tr('Select Purpose'),
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
          },
        );
      },
    );
  }

  List<PurposeCategory1> globalSelectedPurposes = [];
  int? selectedImageIndex;

  void selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  Future<void> loadPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPurposes = prefs.getString('selected_purposes');
      if (savedPurposes != null) {
        final decoded = jsonDecode(savedPurposes) as List;
        globalSelectedPurposes =
            decoded.map((e) => PurposeCategory1.fromJson(e)).toList();
      }
      log(globalSelectedPurposes.first.categoryName);
    } catch (e) {
      debugPrint("Failed to load purposes: $e");
    }
  }

  Widget _buildPurposeGrid(StateSetter setState, BuildContext context,
      {String? category}) {
    final filteredPurposes = category == null
        ? globalSelectedPurposes
        : globalSelectedPurposes
            .where((purpose) => purpose.categoryName == category)
            .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filteredPurposes.length,
      itemBuilder: (context, index) {
        final purpose = filteredPurposes[index];
        final isSelected = selectedImageIndex == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedImageIndex = index; // Update selection
            });
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
                          color: const Color(0xffF44336).withOpacity(0.1),
                        ),
                        child: const Center(
                          child: DashboardLoaderIcon(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xffF44336),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    context.trPurposeCategory(purpose.categoryName),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
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
    );
  }

  Future<File?> getImage() async {
    GateStorage storage = GateStorage();
    await storage.init();
    File? imageFile = await storage.getVisitorImageBase64();

    if (imageFile != null && await imageFile.exists()) {
      print("Image retrieved: ${imageFile.path}");
      return imageFile;
    } else {
      print("No image found.");
    }
    return null;
  }

  XFile? image;

  /// Converts a purpose category string (JSON or numeric ID) into a PurposeCategory1 instance.
  PurposeCategory1 getPurposeCategory1(String? categoryStr) {
    if (categoryStr != null && categoryStr.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonData = json.decode(categoryStr);
        return PurposeCategory1.fromJson(jsonData);
      } catch (e) {
        int catId = int.tryParse(categoryStr) ?? 1;
        return PurposeCategory1(
            categoryId: catId, categoryName: "Category $catId");
      }
    }
    return PurposeCategory1(
        categoryId: 1,
        categoryName: AppLocalizations.of(context).defaultCategory);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside.
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: const Color(0xff212427),
              size: MediaQuery.of(context).size.width > 600
                  ? 28
                  : 24, // Responsive icon size
            ),
            onPressed: () {
              if (_tabController.index == 0) {
                // On Enter Mobile Number page, go back to previous page in navigation stack
                Navigator.pop(context);
              } else {
                // On Enter OTP page, navigate back to Enter Mobile Number page (tab 0)
                _tabController.animateTo(0);
              }
            },
          ),
          title: Text(
            _currentPageTitle,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600
                  ? 24
                  : 20, // Responsive font size
              fontWeight: FontWeight.w700,
              color: const Color(0xff212427),
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: false,
        ),
        body: Container(
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
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Content Area
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    // Tab 1: Mobile Number Entry
                    SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.of(context).size.width > 600 ? 40 : 20,
                          vertical: MediaQuery.of(context).size.width > 600
                              ? 32
                              : 24),
                      child: Column(
                        children: [
                          // Mobile Number Input Section (matching gatekeeper design)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Input Label
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF44336)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.phone_rounded,
                                        color: const Color(0xffF44336),
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            context.tr('Enter Mobile Number'),
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width >
                                                      600
                                                  ? 22
                                                  : 18,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xff212427),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context
                                                .tr('Enter your mobile number'),
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width >
                                                      600
                                                  ? 16
                                                  : 14,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xff6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Enhanced input field
                                EnhancedInputField(
                                  controller: _mobileController,
                                  focusNode: _mobileFocusNode,
                                  isMobileField: true,
                                  label: AppLocalizations.of(context)
                                      .visitorMobileNumber,
                                  hint: context.tr('0123456789'),
                                  suppressKeyboard:
                                      true, // Suppress mobile keyboard
                                  maxLength: 10,
                                  prefixWidget: CountryCodePicker(
                                    initialSelection: 'IN',
                                    headerText: context.tr('Select Country'),
                                    favorite: ['IN', 'US', 'GB', 'CA', 'AU'],
                                    showFlagMain: true,
                                    showFlagDialog: true,
                                    flagWidth: 32,
                                    dialogSize: const Size(350, 500),
                                    boxDecoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    barrierColor: Colors.black.withOpacity(0.5),
                                    closeIcon: const Icon(
                                      Icons.close,
                                      color: Color(0xffF44336),
                                      size: 24,
                                    ),
                                    searchDecoration: InputDecoration(
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xffF44336)
                                                  .withOpacity(0.1),
                                              const Color(0xffD32F2F)
                                                  .withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.search,
                                          color: Color(0xffF44336),
                                          size: 22,
                                        ),
                                      ),
                                      hintText:
                                          context.tr('Search countries...'),
                                      hintStyle: const TextStyle(
                                        color: Color(0xff57636C),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xffF44336)
                                          .withOpacity(0.02),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xffF44336),
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Color(0xff212427),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    dialogTextStyle: const TextStyle(
                                      color: Color(0xff212427),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    onChanged: (CountryCode countryCode) {
                                      setState(() {
                                        selectedCountryCodeSE =
                                            countryCode.code!;
                                      });
                                    },
                                  ),
                                  onClear: () {
                                    setState(() {
                                      _mobileController.clear();
                                    });
                                  },
                                  isTablet:
                                      MediaQuery.of(context).size.width > 600,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Ads Carousel
                          _buildAdsCarousel(context),

                          const SizedBox(height: 24),

                          // Enhanced numpad
                          EnhancedNumPad(
                            isTablet: MediaQuery.of(context).size.width > 600,
                            buttonSize: MediaQuery.of(context).size.width > 600
                                ? 56
                                : 48,
                            onType: (value) {
                              if (value == '-') {
                                // Handle backspace
                                if (_mobileController.text.isNotEmpty) {
                                  setState(() {
                                    _mobileController.text =
                                        _mobileController.text.substring(0,
                                            _mobileController.text.length - 1);
                                  });
                                }
                              } else if (_mobileController.text.length < 10) {
                                setState(() {
                                  _mobileController.text += value;
                                });
                              }
                            },
                            numberStyle: TextStyle(
                              fontSize: MediaQuery.of(context).size.width > 600
                                  ? 36
                                  : 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            rightWidget: EnhancedSubmitButton(
                              onPressed: () async {
                                final mobileNumber = _mobileController.text;
                                final fullMobileNumber = '${91}$mobileNumber';

                                final username =
                                    await _gateStorage.getUsername();
                                log('Full mobile number: $fullMobileNumber');
                                log('Full Username: $username');

                                if (mobileNumber.isEmpty) {
                                  showEnhancedToast(
                                    context,
                                    title: context.tr('Error'),
                                    message: AppLocalizations.of(context)
                                        .mobileNumberIsRequired,
                                    backgroundColor: const Color(0xffF44336),
                                    icon: Icons.error_outline,
                                  );
                                } else if (mobileNumber.length != 10) {
                                  showEnhancedToast(
                                    context,
                                    title: context.tr('Error'),
                                    message: context.tr(
                                        "Please enter 10 digit mobile number"),
                                    backgroundColor: const Color(0xffF44336),
                                    icon: Icons.error_outline,
                                  );
                                } else if (!RegExp(r'^[0-9]+$')
                                    .hasMatch(mobileNumber)) {
                                  showEnhancedToast(
                                    context,
                                    title: context.tr('Error'),
                                    message: AppLocalizations.of(context)
                                        .noSpacesOrSpecialCharactersAllowed,
                                    backgroundColor: const Color(0xffF44336),
                                    icon: Icons.error_outline,
                                  );
                                } else if (username == fullMobileNumber) {
                                  _disableKioskMode();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            GateDashboardView()),
                                  );
                                } else {
                                  await selfCheckInOtp(mobileNumber);
                                  // Only show OTP success toast if visitor is not already verified
                                  // (existing visitors will be handled in selfCheckInOtp method)
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                    // Tab 2: OTP Entry
                    SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.of(context).size.width > 600 ? 40 : 20,
                          vertical: MediaQuery.of(context).size.width > 600
                              ? 32
                              : 24),
                      child: Column(
                        children: [
                          // OTP Input Section (matching gatekeeper design)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Input Label
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF44336)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.security_rounded,
                                        color: const Color(0xffF44336),
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            context.tr('Enter OTP'),
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width >
                                                      600
                                                  ? 22
                                                  : 18,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xff212427),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context.tr(
                                              'Enter the OTP received on your phone',
                                            ),
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width >
                                                      600
                                                  ? 16
                                                  : 14,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xff6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Enhanced input field
                                EnhancedInputField(
                                  controller: _otpController,
                                  focusNode: _otpFocusNode,
                                  isMobileField: false,
                                  label: AppLocalizations.of(context)
                                      .enterOTPSentToYourMobileNumber,
                                  hint: context.tr('123456'),
                                  maxLength: 6,
                                  suppressKeyboard:
                                      true, // Suppress mobile keyboard
                                  onClear: () {
                                    setState(() {
                                      _otpController.clear();
                                    });
                                  },
                                  isTablet:
                                      MediaQuery.of(context).size.width > 600,
                                ),

                                const SizedBox(height: 12),

                                // Resend OTP button inside the card
                                Center(
                                  child: TextButton(
                                    onPressed:
                                        _canResendOtp ? _resendOtp : null,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: Text(
                                      _canResendOtp
                                          ? context.tr('Resend OTP')
                                          : context.tr(
                                              'Resend OTP ({seconds}s)',
                                              params: {
                                                'seconds': '$_resendCountdown',
                                              },
                                            ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _canResendOtp
                                            ? const Color(0xffF44336)
                                            : const Color(0xff9CA3AF),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Enhanced numpad
                          EnhancedNumPad(
                            isTablet: MediaQuery.of(context).size.width > 600,
                            buttonSize: MediaQuery.of(context).size.width > 600
                                ? 56
                                : 48,
                            onType: (value) {
                              if (value == '-') {
                                // Handle backspace
                                if (_otpController.text.isNotEmpty) {
                                  setState(() {
                                    _otpController.text = _otpController.text
                                        .substring(
                                            0, _otpController.text.length - 1);
                                  });
                                }
                              } else if (_otpController.text.length < 6) {
                                setState(() {
                                  _otpController.text += value;
                                });
                              }
                            },
                            numberStyle: TextStyle(
                              fontSize: MediaQuery.of(context).size.width > 600
                                  ? 36
                                  : 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            rightWidget: EnhancedSubmitButton(
                              onPressed: () async {
                                await verifySelfCheckin(_mobileController.text,
                                    _otpController.text);
                                // if (_locationController.text.isNotEmpty) {
                                // }
                              },
                            ),
                          )
                        ],
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
}

class SelfEntryAd extends StatelessWidget {
  const SelfEntryAd({
    required this.bgImage,
    required this.title,
    required this.subTitle,
    super.key,
  });

  final String bgImage;
  final String title;
  final String subTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300.0,
      width: double.infinity,
      margin: EdgeInsets.all(0),
      child: Stack(
        children: [
          ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.transparent],
              ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
            },
            blendMode: BlendMode.dstIn,
            child: Image.network(
              bgImage,
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 25),
                  child: Text(
                    subTitle,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
