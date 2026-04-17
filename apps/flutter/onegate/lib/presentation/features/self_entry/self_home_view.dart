// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kiosk_mode/flutter_kiosk_mode.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/passcode_entry_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/qr_scanner_self.dart';
import 'package:flutter_onegate/utils/enhanced_toast.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/presentation/widgets/enhanced_video_carousel.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

class SelfHomeView extends StatefulWidget {
  final bool isKioskModeEnabled;

  const SelfHomeView({this.isKioskModeEnabled = true, super.key});

  @override
  State<SelfHomeView> createState() => _SelfHomeViewState();
}

class _SelfHomeViewState extends State<SelfHomeView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String? selectedGateName;

  // Gate storage for mobile number validation
  final GateStorage _gateStorage = GateStorage();
  final _flutterKioskMode = FlutterKioskMode.instance();

  // Animation controllers for tap gesture
  late AnimationController _tapAnimationController;
  late AnimationController _positionAnimationController;
  late Animation<double> _tapAnimation;
  late Animation<double> _positionAnimation;

  // Animation state
  bool _isOnQRCard = true;
  bool _isAnimating = false;

  // Kiosk mode monitoring
  Timer? _kioskModeTimer;

  @override
  void initState() {
    deleteImage();
    getfacerecinfo();
    _getSelectedGate();
    _trackExpressEntryRoute();
    _enableKioskMode();
    _initializeAnimations();
    // Add app lifecycle observer to monitor background/foreground changes
    WidgetsBinding.instance.addObserver(this);
    // Start periodic kiosk mode monitoring
    _startKioskModeMonitoring();
    super.initState();
  }

  // Initialize animation controllers and start the tap gesture animation
  void _initializeAnimations() {
    // Tap animation controller (for the tap gesture effect)
    _tapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Position animation controller (for moving between cards)
    _positionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Tap animation with bounce effect
    _tapAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _tapAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Position animation for smooth transitions
    _positionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _positionAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start the animation loop
    _startAnimationLoop();
  }

  // Start the continuous animation loop
  void _startAnimationLoop() {
    _tapAnimationController.repeat(reverse: true);

    // Timer to alternate between cards: 6s on QR, 6s on Passcode
    Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted && !_isAnimating) {
        _switchToNextCard();
      }
    });
  }

  // Switch to the next card with smooth transition
  void _switchToNextCard() {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    _positionAnimationController.forward().then((_) {
      setState(() {
        _isOnQRCard = !_isOnQRCard;
      });
      _positionAnimationController.reset();
      setState(() {
        _isAnimating = false;
      });
    });
  }

  @override
  void dispose() {
    _tapAnimationController.dispose();
    _positionAnimationController.dispose();
    // Stop kiosk mode monitoring
    _kioskModeTimer?.cancel();
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  // Track that user is on express entry dashboard
  Future<void> _trackExpressEntryRoute() async {
    await RouteTracker.saveCurrentRoute('SelfHomeView', isExpressEntry: true);
  }

  // Monitor app lifecycle to prevent background swapping in kiosk mode
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // App is going to background - re-enforce kiosk mode
        log('📱 App paused - re-enforcing kiosk mode');
        _enforceKioskMode();
        break;
      case AppLifecycleState.resumed:
        // App is returning to foreground - ensure kiosk mode is still active
        log('📱 App resumed - ensuring kiosk mode is active');
        _enforceKioskMode();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning - maintain kiosk mode
        log('📱 App inactive - maintaining kiosk mode');
        _enforceKioskMode();
        break;
      default:
        break;
    }
  }

  // Enforce kiosk mode to prevent user from accessing system UI
  void _enforceKioskMode() async {
    try {
      // Re-apply immersive mode
      enterKioskMode();
      // Express Entry: Do NOT invoke plugin start to avoid system "App is pinned" dialog
      log('🔒 Express Entry - enforcing immersive UI only (no kiosk plugin start)');
    } catch (e) {
      log("Error enforcing kiosk mode: $e");
      // Fallback to immersive UI only
      enterKioskMode();
    }
  }

  // Disable kiosk mode for admin access
  void _disableKioskMode() async {
    try {
      await _flutterKioskMode.stop();
    } catch (e) {
      print("Error stopping kiosk mode: $e");
    }
  }

  // Start periodic monitoring to ensure kiosk mode stays active
  void _startKioskModeMonitoring() {
    _kioskModeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        log('🔒 Periodic kiosk mode check - ensuring mode is active');
        _enforceKioskMode();
      } else {
        timer.cancel();
      }
    });
  }

  // Method to reset dialog flag for testing (can be called from debug menu)
  Future<void> resetKioskDialogFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_seen_pinned_popup');
      log('🔒 Kiosk mode dialog flag reset - dialog will show again on next visit');
    } catch (e) {
      log('❌ Error resetting kiosk mode dialog flag: $e');
    }
  }

  // Method to check dialog flag status for debugging
  Future<bool> getKioskDialogFlagStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenPinnedPopup =
          prefs.getBool('has_seen_pinned_popup') ?? false;
      log('🔒 Kiosk mode dialog flag status: $hasSeenPinnedPopup');
      return hasSeenPinnedPopup;
    } catch (e) {
      log('❌ Error checking kiosk mode dialog flag: $e');
      return false;
    }
  }

  bool facerectoshow = false;
  getfacerecinfo() async {
    final societyid = await GateStorage().getSocietyId();
    final faceRecConfig = await GateStorage().getFaceRecConfig();
    log("fetchAndStoreFaceRecConfig societyid$societyid");

    List<String> allowed = faceRecConfig != null
        ? List<String>.from(faceRecConfig['allowed'] ?? [])
        : [];
    log(
      "fetchAndStoreFaceRecConfig societyid${allowed.contains(societyid.toString())}",
    );

    if (faceRecConfig != null &&
        faceRecConfig['url'] != null &&
        faceRecConfig['url'] != "" &&
        faceRecConfig['allowed'] != null &&
        societyid != null &&
        faceRecConfig['is_enabled'] == true &&
        allowed.contains(societyid.toString())) {
      setState(() {
        facerectoshow = true;
      });
    }
  }

  Future<void> deleteImage() async {
    GateStorage storage = GateStorage();
    await storage.init();
    await storage.removeVisitorImage();
    print("Image successfully removed.");
  }

  void enterKioskMode() {
    // Use immersive mode to prevent user from accessing system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Hide status bar
        systemNavigationBarColor: Colors.transparent, // Hide navigation bar
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _enableKioskMode() async {
    try {
      // Engage system immersive UI first
      enterKioskMode();
      // Express Entry: Do NOT start kiosk plugin to avoid system dialog entirely
      log('🔒 Express Entry - immersive UI enabled, kiosk plugin start skipped');
    } catch (e) {
      log("Error starting kiosk mode: $e");
      // Still ensure immersive UI is applied even if plugin fails
      enterKioskMode();
    }
  }

  // Show kiosk mode information dialog (only once)
  void _showKioskModeInfoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xff2196F3).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xff2196F3),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "App is Pinned",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212427),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              const Text(
                "The app is now running in kiosk mode for a better user experience. This ensures the app stays active and secure.",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Got it Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      // Mark that user has seen the popup
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('has_seen_pinned_popup', true);

                      log('🔒 User dismissed kiosk mode dialog - flag saved');

                      Navigator.of(context).pop(); // Close dialog
                    } catch (e) {
                      log('❌ Error saving kiosk mode dialog flag: $e');
                      Navigator.of(context).pop(); // Close dialog anyway
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    "Got it",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Responsive Express Check-in label with comprehensive scaling
  Widget _buildGatekeeperStyleLabel(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Enhanced responsive breakpoints for better scaling
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeTablet = screenWidth > 900 && screenWidth <= 1200;

    // Enhanced responsive scaling factors for better visibility on large screens
    final scaleFactor = isSmallMobile
        ? 1.0
        : isMediumTablet
            ? 1.4
            : isLargeTablet
                ? 1.8
                : 2.2; // Much more aggressive scaling for desktop

    // Base dimensions (mobile)
    const baseIconSize = 28.0;
    const baseTitleFontSize = 20.0;
    const baseSubtitleFontSize = 14.0;
    const baseHorizontalPadding = 12.0;
    const baseVerticalPadding = 8.0;
    const baseBorderRadius = 12.0;
    const baseSpacing = 16.0;

    // Scaled dimensions
    final iconSize = baseIconSize * scaleFactor;
    final titleFontSize = baseTitleFontSize * scaleFactor;
    final subtitleFontSize = baseSubtitleFontSize * scaleFactor;
    final horizontalPadding = baseHorizontalPadding * scaleFactor;
    final verticalPadding = baseVerticalPadding * scaleFactor;
    final borderRadius = baseBorderRadius * scaleFactor;
    final spacing = baseSpacing * scaleFactor;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        children: [
          // Text content without icon
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('expressCheckInSectionTitle'),
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff212427),
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: spacing * 0.25),
                Text(
                  context.tr('expressCheckInSectionSubtitle'),
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: const Color(0xff57636C),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Right side - Info button with responsive sizing
          InkWell(
            onTap: () => _showSelfCheckInInfo(context),
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              width: iconSize + 20, // Icon size + padding
              height: iconSize + 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: const Color(0xffF44336).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: const Color(0xffF44336),
                size: iconSize * 0.7, // Slightly smaller than main icon
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show Express Check-in Information Dialog with OneGate UI patterns
  void _showSelfCheckInInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced drag handle
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),

              // Enhanced header with gradient background
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
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Compact icon section
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
                        Icons.info_outline_rounded,
                        color: Color(0xffF44336),
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 16),
                    // Simple label section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr('expressCheckInOptionsSheetTitle'),
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
                            context.tr('expressCheckInSectionSubtitle'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
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

              // Enhanced content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        _buildOneGateInfoCard(
                          context: context,
                          isTablet: isTablet,
                          icon: Icons.qr_code_scanner_rounded,
                          title: context.tr('Scan QR Code'),
                          description: context.tr('qrCheckinDescription'),
                          features: [
                            context.tr('Instant check-in'),
                            context.tr('No typing required'),
                            context.tr('Secure access'),
                          ],
                          color: const Color(0xffFF9800),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildOneGateInfoCard(
                          context: context,
                          isTablet: isTablet,
                          icon: Icons.lock_outline_rounded,
                          title: context.tr('Passcode'),
                          description: context.tr(
                            'passcodeCheckinDescription',
                          ),
                          features: [
                            context.tr('No OTP required'),
                            context.tr('Fast check-in process'),
                            context.tr('Secure access'),
                          ],
                          color: const Color(0xff2196F3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Close Button with OneGate styling
              Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF212427), // Black
                        Color(0xFF57636C), // Grey
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 16 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      ),
                    ),
                    child: Text(
                      context.tr('Got it'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 18 : 16,
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
  }

  // Build OneGate Information Card for each option
  Widget _buildOneGateInfoCard({
    required BuildContext context,
    required bool isTablet,
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isTablet ? 15 : 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: isTablet ? 60 : 50,
                    height: isTablet ? 60 : 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.1),
                          color.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: isTablet ? 28 : 24, color: color),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff212427),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: const Color(0xff57636C),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: isTablet ? 20 : 16),

              // Features List
              ...features
                  .map(
                    (feature) => Container(
                      margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16 : 12,
                        vertical: isTablet ? 12 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                        border: Border.all(
                          color: color.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isTablet ? 24 : 20,
                            height: isTablet ? 24 : 20,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                isTablet ? 12 : 6,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: isTablet ? 16 : 14,
                              color: color,
                            ),
                          ),
                          SizedBox(width: isTablet ? 12 : 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: isTablet ? 14 : 12,
                                color: const Color(0xff212427),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced Express Check-in Options with comprehensive responsive layout
  Widget _buildEnhancedSelfCheckInOptions(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Comprehensive responsive breakpoints
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;

    // Responsive spacing
    final cardSpacing = isSmallMobile
        ? 12.0
        : isMediumTablet
            ? 16.0
            : 20.0;

    return Stack(
      children: [
        Column(
          children: [
            // QR Scan Option - Top (Equal height with Passcode)
            Expanded(
              child: _buildGridCard(
                context: context,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon: Icons.qr_code_scanner_rounded,
                title: context.tr('Tap Here To Scan QR Code'),
                subtitle: context.tr('Scan your QR code for quick check-in'),
                backgroundColor: const Color(
                  0xFFF6EEDD,
                ), // Light beige as per requirements
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QRScannerScreen(self_checkin: true),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: cardSpacing),

            // OR Text - Centered between the two options
            _buildOrText(context, screenWidth),

            SizedBox(height: cardSpacing),

            // Passcode Option - Bottom (Equal height with QR Code)
            Expanded(
              child: _buildGridCard(
                context: context,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon: Icons.lock_outline_rounded,
                title: context.tr('Tap Here To Enter Passcode'),
                subtitle:
                    context.tr('Enter your secure passcode for quick check-in'),
                backgroundColor: const Color(
                  0xFFDDE8F7,
                ), // Pale blue as per requirements
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PasscodeEntryView(selfcheckinFlow: true),
                    ),
                  );
                },
              ),
            ),

            // Add responsive spacing below the passcode card
            SizedBox(height: _getResponsiveSpacing(screenWidth, 20, 32)),
          ],
        ),

        // Animated Tap Gesture Overlay
        _buildAnimatedTapGesture(
          context,
          screenWidth,
          screenHeight,
          cardSpacing,
        ),
      ],
    );
  }

  // Build responsive OR text between QR scan and passcode options
  Widget _buildOrText(BuildContext context, double screenWidth) {
    // Responsive breakpoints
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeTablet = screenWidth > 900 && screenWidth <= 1200;

    // Responsive scaling factors
    final scaleFactor = isSmallMobile
        ? 1.0
        : isMediumTablet
            ? 1.4
            : isLargeTablet
                ? 1.8
                : 2.2;

    // Base dimensions (mobile)
    const baseFontSize = 16.0;
    const basePadding = 8.0;
    const baseLineHeight = 20.0;

    // Scaled dimensions
    final fontSize = baseFontSize * scaleFactor;
    final padding = basePadding * scaleFactor;
    final lineHeight = baseLineHeight * scaleFactor;

    return Container(
      padding: EdgeInsets.symmetric(vertical: padding),
      child: Row(
        children: [
          // Left line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF9CA3AF).withOpacity(0.3),
                    const Color(0xFF9CA3AF).withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // OR text with background
          Container(
            margin: EdgeInsets.symmetric(horizontal: padding * 2),
            padding: EdgeInsets.symmetric(
              horizontal: padding * 1.5,
              vertical: padding * 0.5,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(padding * 2),
              border: Border.all(
                color: const Color(0xFF9CA3AF).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              context.tr('separatorOr'),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
                height: lineHeight / fontSize,
              ),
            ),
          ),

          // Right line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9CA3AF).withOpacity(0.6),
                    const Color(0xFF9CA3AF).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build animated tap gesture that alternates between cards
  Widget _buildAnimatedTapGesture(
    BuildContext context,
    double screenWidth,
    double screenHeight,
    double cardSpacing,
  ) {
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;

    // Calculate card dimensions for positioning (approximate the visible column area)
    final cardHeight =
        (screenHeight * 0.4) / 2 - cardSpacing / 2; // Approximate card height

    // Responsive gesture size: 48-56dp on mobile, 72-84dp on tablet
    final gestureSize = isSmallMobile
        ? 48.0
        : isMediumTablet
            ? 72.0
            : 84.0;

    // Top positions for each card area within the Stack
    const double qrCardTop = 0.0;
    final double passcodeCardTop = cardHeight + cardSpacing;

    // Position gesture in bottom-center area of each card
    final double bottomPadding = isSmallMobile
        ? 12.0
        : isMediumTablet
            ? 14.0
            : 16.0; // 12-16dp from bottom
    final double qrCardGestureY =
        qrCardTop + cardHeight - bottomPadding - gestureSize / 2;
    final double passcodeCardGestureY =
        passcodeCardTop + cardHeight - bottomPadding - gestureSize / 2;

    // Animated Y position
    final currentY = _isOnQRCard ? qrCardGestureY : passcodeCardGestureY;

    final targetY = _isOnQRCard ? passcodeCardGestureY : qrCardGestureY;

    final animatedY = _isAnimating
        ? (_isOnQRCard ? qrCardGestureY : passcodeCardGestureY) +
            (targetY - (_isOnQRCard ? qrCardGestureY : passcodeCardGestureY)) *
                _positionAnimation.value
        : currentY;

    // Calculate right alignment position
    final horizontalPadding = _getResponsiveSpacing(screenWidth, 20, 24);
    final rightPosition =
        horizontalPadding + 16; // 16dp from the right edge of the card

    return Positioned(
      right: rightPosition, // right aligned with padding
      top: animatedY,
      child: AnimatedBuilder(
        animation: _tapAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _tapAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple effect
                Container(
                  width: gestureSize * 1.5,
                  height: gestureSize * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffF44336).withOpacity(0.1),
                  ),
                  child: AnimatedBuilder(
                    animation: _tapAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.5 + (_tapAnimationController.value * 0.5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xffF44336).withOpacity(0.2),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Main gesture icon
                Container(
                  width: gestureSize,
                  height: gestureSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xffF44336,
                    ).withOpacity(0.18), // transparent red background
                    border: Border.all(
                      color: const Color(0xffF44336).withOpacity(0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffF44336).withOpacity(0.25),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white,
                    size: gestureSize * 0.55,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Grid card for Express Check-in options with comprehensive responsive sizing
  Widget _buildGridCard({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    // Enhanced responsive breakpoints for better scaling
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeTablet = screenWidth > 900 && screenWidth <= 1200;

    // Enhanced responsive scaling factors for better visibility on large screens
    final scaleFactor = isSmallMobile
        ? 1.0
        : isMediumTablet
            ? 1.8
            : isLargeTablet
                ? 2.5
                : 3.2; // Much more aggressive scaling for desktop

    // Base dimensions (mobile) - Increased for better visibility
    const baseIconSize = 56.0; // Increased from 48.0
    const baseIconContainerSize = 96.0; // Increased from 80.0
    const baseTitleFontSize = 20.0; // Increased from 18.0
    const baseSubtitleFontSize = 16.0; // Increased from 14.0
    const baseHorizontalPadding = 20.0; // Increased from 16.0
    const baseVerticalPadding = 16.0; // Increased from 12.0
    const baseBorderRadius = 24.0; // Increased from 20.0
    const baseSpacing = 24.0; // Increased from 20.0

    // Scaled dimensions
    final iconSize = baseIconSize * scaleFactor;
    final iconContainerSize = baseIconContainerSize * scaleFactor;
    final titleFontSize = baseTitleFontSize * scaleFactor;
    final subtitleFontSize = baseSubtitleFontSize * scaleFactor;
    final horizontalPadding = baseHorizontalPadding * scaleFactor;
    final verticalPadding = baseVerticalPadding * scaleFactor;
    const borderRadius = baseBorderRadius;
    final spacing = baseSpacing * scaleFactor;

    // Ensure minimum touch target size (48dp)
    const minTouchTarget = 48.0;
    final effectiveIconContainerSize =
        iconContainerSize < minTouchTarget ? minTouchTarget : iconContainerSize;

    return Material(
      elevation: isSmallMobile
          ? 2
          : isMediumTablet
              ? 3
              : 4, // Responsive elevation
      borderRadius: BorderRadius.circular(borderRadius),
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: Colors.black.withOpacity(0.1),
        highlightColor: Colors.black.withOpacity(0.05),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            children: [
              // Icon container on the left side with proper touch target
              Container(
                width: effectiveIconContainerSize,
                height: effectiveIconContainerSize,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: const Color(0xFF111827),
                ),
              ),

              SizedBox(width: spacing),

              // Title and subtitle on the right side
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title with responsive font size
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        letterSpacing: 0.3,
                      ),
                    ),

                    SizedBox(height: spacing * 0.3),

                    // Subtitle with responsive font size
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: spacing * 0.25),
                    // Removed old "Tap here" icon/text row for a cleaner card
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show admin mobile number modal with select gate bottom sheet UI design
  void _showAdminMobileModal(BuildContext context) {
    final TextEditingController mobileController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced drag handle
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),

              // Enhanced header with gradient background
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
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Compact icon section
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
                        Icons.admin_panel_settings_rounded,
                        color: Color(0xffF44336),
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Simple label section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr('adminAccessTitle'),
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
                            context.tr('adminAccessSubtitle'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
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

              // Enhanced content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        // Mobile number input field
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Phone icon with background
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xffF44336,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.phone_android_rounded,
                                      color: Color(0xffF44336),
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Input field
                                  Expanded(
                                    child: TextField(
                                      controller: mobileController,
                                      focusNode: focusNode,
                                      keyboardType: TextInputType.phone,
                                      autofocus: true,
                                      maxLength: 10,
                                      cursorColor: const Color(0xffF44336),
                                      decoration: InputDecoration(
                                        hintText: context
                                            .tr('Enter admin mobile number'),
                                        hintStyle: TextStyle(
                                          color: Color(0xff57636C),
                                          fontSize: 16,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        counterText: '',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xff212427),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Switch button
                        Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF212427), // Black
                                Color(0xFF57636C), // Grey
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF212427).withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _validateAndSwitch(
                                context,
                                mobileController.text.trim(),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  context.tr('switchToGatekeeperCta'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Add extra padding at bottom for keyboard
                        SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom + 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Auto-focus the input field when modal opens
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.requestFocus();
      });
    });
  }

  // Validate admin mobile number and switch to Gatekeeper dashboard
  void _validateAndSwitch(BuildContext context, String mobileNumber) async {
    // Reuse the same validation logic from the hidden "Enter Mobile Number" functionality
    final fullMobileNumber = '${91}$mobileNumber';

    try {
      final username = await _gateStorage.getUsername();
      log('Full mobile number: $fullMobileNumber');
      log('Full Username: $username');

      if (mobileNumber.isEmpty) {
        EnhancedToast.error(context, context.tr('mobileNumberIsRequired'));
      } else if (mobileNumber.length != 10) {
        EnhancedToast.error(
          context,
          context.tr('pleaseEnterTenDigitMobileNumber'),
        );
      } else if (!RegExp(r'^[0-9]+$').hasMatch(mobileNumber)) {
        EnhancedToast.error(
          context,
          context.tr('onlyNumbersNoSpacesOrSpecialCharactersMobile'),
        );
      } else if (username == fullMobileNumber) {
        // Valid admin mobile number - show success toast and switch
        EnhancedToast.success(
          context,
          context.tr('accessGrantedSwitchingToGatekeeperDashboard'),
        );

        // Delay navigation to show success toast
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop(); // Close modal
            _disableKioskMode();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => GateDashboardView()),
            );
          }
        });
      } else {
        // Invalid admin mobile number
        EnhancedToast.error(
          context,
          context.tr('invalidAdminCredentialsCheckMobileNumber'),
        );
      }
    } catch (e) {
      log('Error validating mobile number: $e');
      EnhancedToast.error(
        context,
        context.tr('unableToVerifyCredentialsPleaseTryAgain'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // Enhanced responsive breakpoints
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeTablet = screenWidth > 900 && screenWidth <= 1200;

    // Enhanced scaling factors for AppBar elements
    final appBarScaleFactor = isSmallMobile
        ? 1.0
        : isMediumTablet
            ? 1.3
            : isLargeTablet
                ? 1.6
                : 2.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Responsive AppBar with proper alignment
              AppBar(
                automaticallyImplyLeading: false,
                elevation: 2,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.black.withOpacity(0.1),
                toolbarHeight: (isSmallMobile
                        ? 60
                        : isMediumTablet
                            ? 80
                            : isLargeTablet
                                ? 100
                                : 120) *
                    appBarScaleFactor, // Enhanced responsive height
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        (isSmallMobile
                                ? 6
                                : isMediumTablet
                                    ? 8
                                    : isLargeTablet
                                        ? 10
                                        : 12) *
                            appBarScaleFactor,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xffF44336), Color(0xffD32F2F)],
                        ),
                        borderRadius: BorderRadius.circular(
                          (isSmallMobile
                                  ? 8
                                  : isMediumTablet
                                      ? 10
                                      : isLargeTablet
                                          ? 12
                                          : 14) *
                              appBarScaleFactor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffF44336).withOpacity(0.3),
                            blurRadius: 4 * appBarScaleFactor,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.sensor_door_rounded,
                        color: Colors.white,
                        size: (isSmallMobile
                                ? 16
                                : isMediumTablet
                                    ? 20
                                    : isLargeTablet
                                        ? 24
                                        : 28) *
                            appBarScaleFactor,
                      ),
                    ),
                    SizedBox(
                      width: (isSmallMobile
                              ? 10
                              : isMediumTablet
                                  ? 12
                                  : isLargeTablet
                                      ? 14
                                      : 16) *
                          appBarScaleFactor,
                    ),
                    Hero(
                      tag: 'gate_dashboard',
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          color: const Color(0xff212427),
                          fontSize: (isSmallMobile
                                  ? 20
                                  : isMediumTablet
                                      ? 24
                                      : isLargeTablet
                                          ? 28
                                          : 32) *
                              appBarScaleFactor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        child: Text(
                          (selectedGateName ?? 'OneGate')
                              .toString()
                              .split(' ')
                              .map(
                                (word) => word.isNotEmpty
                                    ? word[0].toUpperCase() +
                                        word.substring(1).toLowerCase()
                                    : '',
                              )
                              .join(' '),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Switch to Gatekeeper Dashboard button
                  Container(
                    margin: EdgeInsets.only(
                      right: (isSmallMobile
                              ? 12
                              : isMediumTablet
                                  ? 16
                                  : isLargeTablet
                                      ? 20
                                      : 24) *
                          appBarScaleFactor,
                    ),
                    child: IconButton(
                      onPressed: () => _showAdminMobileModal(context),
                      icon: Container(
                        padding: EdgeInsets.all(
                          (isSmallMobile
                                  ? 6
                                  : isMediumTablet
                                      ? 8
                                      : isLargeTablet
                                          ? 10
                                          : 12) *
                              appBarScaleFactor,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            (isSmallMobile
                                    ? 8
                                    : isMediumTablet
                                        ? 10
                                        : isLargeTablet
                                            ? 12
                                            : 14) *
                                appBarScaleFactor,
                          ),
                          border: Border.all(
                            color: const Color(0xffF44336).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: const Color(0xffF44336),
                          size: (isSmallMobile
                                  ? 18
                                  : isMediumTablet
                                      ? 20
                                      : isLargeTablet
                                          ? 24
                                          : 28) *
                              appBarScaleFactor,
                        ),
                      ),
                      tooltip: context.tr('Switch to Gatekeeper Dashboard'),
                    ),
                  ),
                ],
              ),

              // Ads Carousel - Enhanced responsive height and full-width
              SizedBox(
                height: isSmallMobile
                    ? (screenSize.width < 400
                        ? (screenSize.height * 0.25).clamp(
                            200.0,
                            220.0,
                          ) // Small mobile: 200-220dp
                        : (screenSize.height * 0.28).clamp(
                            240.0,
                            260.0,
                          )) // Large mobile: 240-260dp
                    : isMediumTablet
                        ? (screenSize.height * 0.3).clamp(
                            280.0,
                            320.0,
                          ) // Medium tablet: 280-320dp
                        : isLargeTablet
                            ? (screenSize.height * 0.35).clamp(
                                320.0,
                                380.0,
                              ) // Large tablet: 320-380dp
                            : (screenSize.height * 0.4).clamp(
                                400.0,
                                480.0,
                              ), // Desktop: 400-480dp
                child: _buildAdsCarousel(context),
              ),

              // Responsive spacing between carousel and Express Check-in label
              SizedBox(height: _getResponsiveSpacing(screenSize.width, 20, 24)),

              // Header Section - Express Check-in label with responsive padding
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _getResponsiveSpacing(screenSize.width, 20, 24),
                  vertical: _getResponsiveSpacing(screenSize.width, 8, 12),
                ),
                child: _buildGatekeeperStyleLabel(context),
              ),

              // Responsive spacing between Express Check-in label and options
              SizedBox(height: _getResponsiveSpacing(screenSize.width, 16, 20)),

              // Express Check-in Options - Takes remaining space with responsive constraints
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getResponsiveSpacing(screenSize.width, 20, 24),
                    vertical: _getResponsiveSpacing(screenSize.width, 8, 12),
                  ),
                  child: _buildEnhancedSelfCheckInOptions(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced video carousel with 4 cyberone videos
  Widget _buildAdsCarousel(BuildContext context) {
    return const EnhancedVideoCarousel();
  }

  // Helper method for responsive spacing with enhanced scaling
  double _getResponsiveSpacing(
    double screenWidth,
    double mobileValue,
    double tabletValue,
  ) {
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeTablet = screenWidth > 900 && screenWidth <= 1200;

    if (isSmallMobile) {
      return mobileValue;
    } else if (isMediumTablet) {
      return mobileValue + (tabletValue - mobileValue) * 0.6;
    } else if (isLargeTablet) {
      return mobileValue + (tabletValue - mobileValue) * 0.8;
    } else {
      // Desktop - use tablet value with additional scaling
      return tabletValue * 1.3;
    }
  }
}
