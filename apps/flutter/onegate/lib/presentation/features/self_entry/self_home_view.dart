// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

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

class SelfHomeView extends StatefulWidget {
  final bool isKioskModeEnabled;

  const SelfHomeView({
    this.isKioskModeEnabled = true,
    super.key,
  });

  @override
  State<SelfHomeView> createState() => _SelfHomeViewState();
}

class _SelfHomeViewState extends State<SelfHomeView> {
  String? selectedGateName;

  // Gate storage for mobile number validation
  final GateStorage _gateStorage = GateStorage();
  final _flutterKioskMode = FlutterKioskMode.instance();

  @override
  void initState() {
    deleteImage();
    getfacerecinfo();
    _getSelectedGate();
    _trackExpressEntryRoute();
    _enableKioskMode();
    super.initState();
  }

  Future<void> _getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  // Track that user is on express entry dashboard
  Future<void> _trackExpressEntryRoute() async {
    await RouteTracker.saveCurrentRoute(
      'SelfHomeView',
      isExpressEntry: true,
    );
  }

  // Disable kiosk mode for admin access
  void _disableKioskMode() async {
    try {
      await _flutterKioskMode.stop();
    } catch (e) {
      print("Error stopping kiosk mode: $e");
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
    log("fetchAndStoreFaceRecConfig societyid${allowed.contains(societyid.toString())}");

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Hide status bar
      systemNavigationBarColor: Colors.transparent, // Hide navigation bar
    ));
  }

  Future<void> _enableKioskMode() async {
    try {
      // Engage system immersive UI first
      enterKioskMode();
      // Start Android kiosk/lock task mode via plugin
      await _flutterKioskMode.start();
    } catch (e) {
      log("Error starting kiosk mode: $e");
      // Still ensure immersive UI is applied even if plugin fails
      enterKioskMode();
    }
  }

  // Responsive Express Check-in label
  Widget _buildGatekeeperStyleLabel(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 12 : 8,
      ),
      child: Row(
        children: [
          // Left side - Icon and text
          Container(
            padding: EdgeInsets.all(isTablet ? 14 : 12),
            decoration: BoxDecoration(
              color: const Color(0xffF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            ),
            child: Icon(
              Icons.assignment_turned_in_rounded,
              color: const Color(0xffF44336),
              size: isTablet ? 32 : 28,
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Express Check-in',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff212427),
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  'Choose your preferred check-in method',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xff57636C),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Right side - Info button
          InkWell(
            onTap: () => _showSelfCheckInInfo(context),
            borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
            child: Container(
              width: isTablet ? 52 : 48,
              height: isTablet ? 52 : 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                border: Border.all(
                  color: const Color(0xffF44336).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: const Color(0xffF44336),
                size: isTablet ? 24 : 20,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            'Express Check-in Options',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff212427),
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose your preferred check-in method',
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
                          icon: Icons.lock_outline_rounded,
                          title: 'Passcode',
                          description:
                              'Use your passcode for quick and secure check-in without OTP verification.',
                          features: [
                            'No OTP required',
                            'Fast check-in process',
                            'Secure access',
                          ],
                          color: const Color(0xff2196F3),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildOneGateInfoCard(
                          context: context,
                          isTablet: isTablet,
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Scan QR Code',
                          description:
                              'Scan your QR code for instant check-in. Most convenient method for regular visitors.',
                          features: [
                            'Instant check-in',
                            'No typing required',
                            'Works offline',
                          ],
                          color: const Color(0xffFF9800),
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
                      'Got it',
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
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
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
                    child: Icon(
                      icon,
                      size: isTablet ? 28 : 24,
                      color: color,
                    ),
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
                  .map((feature) => Container(
                        margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 12,
                          vertical: isTablet ? 12 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.05),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 12 : 8),
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
                                borderRadius:
                                    BorderRadius.circular(isTablet ? 12 : 6),
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
                      ))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced Express Check-in Options with equal card dimensions and responsive layout
  Widget _buildEnhancedSelfCheckInOptions(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > 600;

    return Column(
      children: [
        // QR Scan Option - Top (Equal height with Passcode)
        Expanded(
          child: _buildGridCard(
            context: context,
            isTablet: isTablet,
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan QR Code',
            subtitle: 'Scan your QR code for quick check-in',
            backgroundColor: const Color(0xFFFFF3E0), // Light yellow
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

        SizedBox(height: isTablet ? 16 : 12),

        // Passcode Option - Bottom (Equal height with QR Code)
        Expanded(
          child: _buildGridCard(
            context: context,
            isTablet: isTablet,
            icon: Icons.lock_outline_rounded,
            title: 'Passcode',
            subtitle: 'Enter your secure passcode for quick check-in',
            backgroundColor: const Color(0xFFE3F2FD), // Light blue
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
      ],
    );
  }

  // Grid card for Express Check-in options with responsive sizing
  Widget _buildGridCard({
    required BuildContext context,
    required bool isTablet,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    // Dynamic sizing based on device type
    final iconSize = isTablet ? 60.0 : 44.0; // 60dp tablet, 44dp mobile
    final iconContainerSize = isTablet ? 100.0 : 80.0;
    final titleFontSize = isTablet ? 22.0 : 18.0; // 22sp tablet, 18sp mobile
    final subtitleFontSize = isTablet ? 16.0 : 14.0; // 16sp tablet, 14sp mobile

    // Responsive padding: 12-14dp mobile, 20-24dp tablet
    final horizontalPadding = isTablet ? 20.0 : 16.0; // Left/Right padding
    final verticalPadding = isTablet ? 16.0 : 12.0; // Top/Bottom padding
    final borderRadius = isTablet ? 20.0 : 16.0;
    final spacing = isTablet ? 24.0 : 20.0;

    return Material(
      elevation: 5, // Material elevation for consistent depth across platforms
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
              // Icon container on the left side
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
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
                    // Title with dynamic font size
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

                    // Subtitle with dynamic font size
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            'Admin Access',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff212427),
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter admin mobile number to access Gatekeeper dashboard',
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
                                      color: const Color(0xffF44336)
                                          .withOpacity(0.1),
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
                                      decoration: const InputDecoration(
                                        hintText: 'Enter admin mobile number',
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
                                child: const Text(
                                  'Switch to Gatekeeper',
                                  style: TextStyle(
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
                            height:
                                MediaQuery.of(context).viewInsets.bottom + 20),
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
        EnhancedToast.error(
          context,
          'Mobile number is required',
        );
      } else if (mobileNumber.length != 10) {
        EnhancedToast.error(
          context,
          'Please enter a 10-digit mobile number',
        );
      } else if (!RegExp(r'^[0-9]+$').hasMatch(mobileNumber)) {
        EnhancedToast.error(
          context,
          'Only numbers are allowed. No spaces or special characters',
        );
      } else if (username == fullMobileNumber) {
        // Valid admin mobile number - show success toast and switch
        EnhancedToast.success(
          context,
          'Access granted! Switching to Gatekeeper dashboard...',
        );

        // Delay navigation to show success toast
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop(); // Close modal
            _disableKioskMode();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GateDashboardView(),
              ),
            );
          }
        });
      } else {
        // Invalid admin mobile number
        EnhancedToast.error(
          context,
          'Invalid admin credentials. Please check your mobile number',
        );
      }
    } catch (e) {
      log('Error validating mobile number: $e');
      EnhancedToast.error(
        context,
        'Unable to verify credentials. Please try again',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

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
                toolbarHeight: isTablet
                    ? 72
                    : 60, // Slightly larger for better touch targets
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 8 : 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xffF44336),
                            Color(0xffD32F2F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffF44336).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.sensor_door_rounded,
                        color: Colors.white,
                        size: isTablet ? 20 : 16,
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 10),
                    Hero(
                      tag: 'gate_dashboard',
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          color: const Color(0xff212427),
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        child: Text(
                          (selectedGateName ?? 'OneGate')
                              .toString()
                              .split(' ')
                              .map((word) => word.isNotEmpty
                                  ? word[0].toUpperCase() +
                                      word.substring(1).toLowerCase()
                                  : '')
                              .join(' '),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Switch to Gatekeeper Dashboard button
                  Container(
                    margin: EdgeInsets.only(right: isTablet ? 16 : 12),
                    child: IconButton(
                      onPressed: () => _showAdminMobileModal(context),
                      icon: Container(
                        padding: EdgeInsets.all(isTablet ? 8 : 6),
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 10 : 8),
                          border: Border.all(
                            color: const Color(0xffF44336).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: const Color(0xffF44336),
                          size: isTablet ? 20 : 18,
                        ),
                      ),
                      tooltip: 'Switch to Gatekeeper Dashboard',
                    ),
                  ),
                ],
              ),

              // Ads Carousel - Responsive height and full-width
              Container(
                height: isTablet
                    ? (screenSize.height * 0.3)
                        .clamp(280.0, 320.0) // Tablet: 280-320dp
                    : screenSize.width < 400
                        ? (screenSize.height * 0.25)
                            .clamp(200.0, 220.0) // Small mobile: 200-220dp
                        : (screenSize.height * 0.28)
                            .clamp(240.0, 260.0), // Large mobile: 240-260dp
                child: _buildAdsCarousel(context),
              ),

              // Spacing between carousel and Express Check-in label
              SizedBox(height: isTablet ? 24 : 20),

              // Header Section - Express Check-in label
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 12 : 8,
                ),
                child: _buildGatekeeperStyleLabel(context),
              ),

              // Spacing between Express Check-in label and options
              SizedBox(height: isTablet ? 20 : 16),

              // Express Check-in Options - Takes remaining space with proper constraints
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 12 : 8,
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
}
