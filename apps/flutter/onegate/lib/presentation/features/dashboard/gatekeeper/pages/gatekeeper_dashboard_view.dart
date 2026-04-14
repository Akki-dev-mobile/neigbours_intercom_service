// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/modular_features/onegate_feature_host_adapter.dart';
import 'package:flutter_onegate/presentation/features/license_plate_detection/ui/license_plate_detection_page.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/qr_scanner_self.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:vibration/vibration.dart';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:badges/badges.dart' as badges;
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:common_widgets/dashboard_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/commons/ui/dashboard_commons.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/missed_approval_screen.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_log_view.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/utils/network_log/dio_provider.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_screen.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onegate_guard_intercom/onegate_guard_intercom.dart';
import '../../../../../generated/l10n/app_localizations.dart';

import '../../../app_intro/ui/keyclock_login.dart';
import '../../../parcel/ui/parcel_list.dart';
import '../../../settings/pages/settings_home.dart';
import '../../commons/intercom_services_launcher.dart';
import 'id_input_view.dart';

class GateDashboardView extends StatefulWidget {
  const GateDashboardView({Key? key}) : super(key: key);

  @override
  State<GateDashboardView> createState() => _GateDashboardViewState();
}

class _GateDashboardViewState extends State<GateDashboardView>
    with TickerProviderStateMixin {
  List<VisitorLog> cardVisitors = [];
  bool? _visitorCardNumber = false;
  String? selectedGateName;
  bool isLoading = false;
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  bool hasPendingParcels = false; // ✅ New flag to track new parcels

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

  @override
  void initState() {
    super.initState();
    GateStorage().removeComingFrom();
    GateStorage().clearVisitorImage();
    gateDashboardBloc.add(GatekeeperDashboardInitialEvent());
    _loadInitialData();
    getSelectedGate();
    checkForPendingParcels();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadVisitorSettings(),
    ]);
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = _normalizeGateName(prefs.getString('selected_gate'));
    });
  }

  String? _normalizeGateName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return raw;
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded['gate_name'] != null) {
          return decoded['gate_name'].toString();
        }
      } catch (_) {
        // If parsing fails, fall back to raw string.
      }
    }
    return raw;
  }

  Future<void> logout(BuildContext context) async {
    try {
      log("Attempting logout...");
      // Logout using AuthService instead of keycloakWrapper
      final authService = GetIt.instance<AuthService>();
      await authService.logout();
      log("Keycloak session ended.");

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      log("Preferences cleared.");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MyAppLogin()),
        (route) => false,
      );
    } catch (e, st) {
      log("Logout failed: $e\n$st");
    }
  }

  Future<void> _loadVisitorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitorCardNumber = prefs.getBool('visitorCardNumber');
    });
  }

  Future<void> checkForPendingParcels() async {
    try {
      final List parcelList = await _remoteDataSource.fetchParcels();

      // ✅ Check if any parcel has status "pending"
      bool hasPending = parcelList.any((parcel) =>
          parcel['parcel_status'] != null &&
          parcel['parcel_status'].toString().toLowerCase() == 'pending');

      setState(() {
        hasPendingParcels = hasPending; // ✅ Update notification status
      });

      log("🔔 Pending Parcels Status: ${hasPending ? 'YES' : 'NO'}");
    } catch (e) {
      log("❌ Error fetching parcels: $e");
    }
  }

  // Method to make real API requests for network logging
  Future<void> _makeRealApiRequests(BuildContext context) async {
    try {
      // Show a loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.fetchingDataForNetworkLogs)),
        );
      }

      // Make multiple real API requests to generate logs

      // 1. Fetch gates
      await _remoteDataSource.fetchGates();

      // 2. Fetch parcels
      await _remoteDataSource.fetchParcels();

      // 3. Refresh dashboard data
      gateDashboardBloc.add(GatekeeperDashboardInitialEvent());

      // Navigate to the network log screen to show the results
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NetworkLogScreen(),
          ),
        );
      }
    } catch (e) {
      // Show error message if the widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // For backward compatibility with the test API button
  Future<void> _makeTestApiRequest(BuildContext context) async {
    await _makeRealApiRequests(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GatekeeperDashboardBloc, GatekeeperDashboardState>(
      bloc: gateDashboardBloc,
      listenWhen: (previous, current) =>
          current is GatekeeperDashboardActionState,
      buildWhen: (previous, current) =>
          current is! GatekeeperDashboardActionState,
      listener: (context, state) async {
        switch (state.runtimeType) {
          case GDInAndOutButtonPressedState:
            await Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.leftToRight,
                child: VisitorLogView(
                  id: AppLocalizations.of(context).inOutBook,
                  logList: [
                    AppLocalizations.of(context).inOutBook,
                    AppLocalizations.of(context).visitorIn,
                    AppLocalizations.of(context).visitorOut,
                  ],
                ),
              ),
            );
            break;
          case GDVisitorsInButtonPressedState:
            await Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.topToBottom,
                child: VisitorLogView(
                  id: AppLocalizations.of(context).visitorIn,
                  logList: [
                    AppLocalizations.of(context).inOutBook,
                    AppLocalizations.of(context).visitorIn,
                    AppLocalizations.of(context).visitorOut,
                  ],
                ),
              ),
            );
            break;
          case GDVisitorsOutButtonPressedState:
            await Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: VisitorLogView(
                  id: AppLocalizations.of(context).visitorOut,
                  logList: [
                    AppLocalizations.of(context).inOutBook,
                    AppLocalizations.of(context).visitorIn,
                    AppLocalizations.of(context).visitorOut,
                  ],
                ),
              ),
            );
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case GatekeeperDashboardLoadingState:
            return DashboardLoader(
              title: 'Loading Dashboard',
              subtitle: 'Please wait while we prepare your dashboard...',
            );
          case GDInAndOutLoadingState:
            return DashboardLoader(
              title: 'Loading In-Out Book',
              subtitle: 'Preparing visitor logs...',
            );
          case GDVisitorsInLoadingState:
            return DashboardLoader(
              title: 'Loading Visitor-In',
              subtitle: 'Preparing visitor check-in logs...',
            );
          case GDVisitorsOutLoadingState:
            return DashboardLoader(
              title: 'Loading Visitor-Out',
              subtitle: 'Preparing visitor check-out logs...',
            );
          case GatekeeperDashboardSuccessState:
            final successState = state as GatekeeperDashboardSuccessState;
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: _buildEnhancedDashboard(context, successState),
            );
          default:
            return Container();
        }
      },
    );
  }

  // Enhanced Dashboard UI
  Widget _buildEnhancedDashboard(
      BuildContext context, GatekeeperDashboardSuccessState successState) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildEnhancedAppBar(context, isTablet),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 16,
          vertical: isTablet ? 20 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced shortcuts section
            _buildEnhancedShortcuts(context, isTablet),

            SizedBox(height: isTablet ? 24 : 20),

            // Enhanced dashboard blocks
            DashboardBlocks(
              inBook: successState.inBook,
              outBook: successState.outBook,
              bloc: gateDashboardBloc,
            ),

            SizedBox(height: isTablet ? 24 : 20),

            // Enhanced visitor input section
            _buildEnhancedVisitorInput(context, isTablet),

            SizedBox(height: isTablet ? 20 : 16),
          ],
        ),
      ),
    );
  }

  // Enhanced App Bar
  PreferredSizeWidget _buildEnhancedAppBar(
      BuildContext context, bool isTablet) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      automaticallyImplyLeading: false,
      toolbarHeight: isTablet ? 80 : 70,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced gate icon
          Container(
            padding: EdgeInsets.all(isTablet ? 8 : 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xffF44336),
                  const Color(0xffD32F2F),
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
          // Enhanced gate name with animation
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
                selectedGateName
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
        _buildEnhancedActionButton(
          context,
          isTablet,
          icon: Icons.phone_missed_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MissedApprovalsScreen(
                  remoteDataSource: _remoteDataSource,
                ),
              ),
            );
          },
        ),
        SizedBox(width: isTablet ? 8 : 6),
        _buildEnhancedActionButton(
          context,
          isTablet,
          icon: Icons.settings_rounded,
          onTap: () {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: SettingsHome(),
              ),
            );
          },
        ),
        SizedBox(width: isTablet ? 20 : 16),
      ],
    );
  }

  // Enhanced Action Button with distinct styling
  Widget _buildEnhancedActionButton(
    BuildContext context,
    bool isTablet, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: isTablet ? 6 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add haptic feedback
            HapticFeedback.lightImpact();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isTablet ? 14 : 12),
            child: Icon(
              icon,
              color: const Color(0xff57636C),
              size: isTablet ? 24 : 20,
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced Shortcuts with better layout
  Widget _buildEnhancedShortcuts(BuildContext context, bool isTablet) {
    final showCardsShortcut = _visitorCardNumber == true;
    final horizontalPadding = isTablet ? 16.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isTablet ? 8 : 6,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortcutsCount = showCardsShortcut ? 4 : 3;
          final preferredGap = isTablet ? 16.0 : 12.0;
          final maxShortcutWidth = isTablet ? 120.0 : 96.0;

          double shortcutWidth =
              (constraints.maxWidth - (preferredGap * (shortcutsCount + 1))) /
                  shortcutsCount;
          shortcutWidth = shortcutWidth.clamp(48.0, maxShortcutWidth);

          double equalGap =
              (constraints.maxWidth - (shortcutWidth * shortcutsCount)) /
                  (shortcutsCount + 1);

          if (equalGap < 8.0) {
            shortcutWidth =
                ((constraints.maxWidth - (8.0 * (shortcutsCount + 1))) /
                        shortcutsCount)
                    .clamp(48.0, maxShortcutWidth);
            equalGap =
                (constraints.maxWidth - (shortcutWidth * shortcutsCount)) /
                    (shortcutsCount + 1);
          }

          final gapWidth = equalGap.clamp(0.0, 100.0);

          return Row(
            children: [
              SizedBox(width: gapWidth),
              _buildEnhancedShortcut(
                context,
                isTablet,
                width: shortcutWidth,
                icon: Icons.dialer_sip_rounded,
                title: 'Intercom',
                onTap: () {
                  IntercomServicesLauncher.open(context);
                },
              ),
              SizedBox(width: gapWidth),
              _buildEnhancedShortcut(
                context,
                isTablet,
                width: shortcutWidth,
                icon: Icons.inventory_2_rounded,
                title: context.l10n.parcel,
                hasNotification: hasPendingParcels,
                onTap: () async {
                  setState(() => hasPendingParcels = false);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ParcelList()),
                  );
                },
              ),
              SizedBox(width: gapWidth),
              _buildEnhancedShortcut(
                context,
                isTablet,
                width: shortcutWidth,
                icon: Icons.qr_code_scanner_rounded,
                title: context.l10n.scan,
                onTap: () async {
                  final scannedResult = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QRScannerScreen(
                        status: 1,
                        isGatekeeperQRPasscodeEntry: true,
                      ),
                    ),
                  );

                  if (scannedResult != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 12 : 10, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isTablet ? 12 : 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: Colors.white,
                                  size: isTablet ? 28 : 24,
                                ),
                              ),
                              SizedBox(width: isTablet ? 16 : 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: isTablet ? 18 : 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "QR Code Verified",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isTablet ? 16 : 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      scannedResult,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontSize: isTablet ? 14 : 12,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white,
                                  size: isTablet ? 16 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        backgroundColor: Color(0xFF2E7D32), // Rich green color
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: EdgeInsets.all(isTablet ? 20 : 16),
                        duration: const Duration(seconds: 4),
                        elevation: 8,
                      ),
                    );
                  }
                },
              ),
              if (showCardsShortcut) ...[
                SizedBox(width: gapWidth),
                _buildEnhancedShortcut(
                  context,
                  isTablet,
                  width: shortcutWidth,
                  icon: Icons.badge_rounded,
                  title: context.l10n.cards,
                  onTap: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.leftToRight,
                        child: VisitorLogView(
                          id: 'Cards',
                          logList: const [
                            "In Out Book",
                            "Visitor In",
                            "Visitor Out",
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              SizedBox(width: gapWidth),
            ],
          );
        },
      ),
    );
  }

  // Enhanced Shortcut Widget with micro-interactions
  Widget _buildEnhancedShortcut(
    BuildContext context,
    bool isTablet, {
    double? width,
    IconData? icon,
    required String title,
    required VoidCallback onTap,
    bool isPremium = false,
    bool hasNotification = false,
    bool isClickable = true, // New parameter to control clickability
  }) {
    return SizedBox(
      width: width ?? (isTablet ? 100 : 80),
      child: Column(
        children: [
          // Enhanced icon container with visitor details styling
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isTablet ? 72 : 60,
            height: isTablet ? 72 : 60,
            decoration: BoxDecoration(
              color: isClickable
                  ? const Color(0xffF44336).withOpacity(0.1)
                  : Colors.grey.shade200.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isClickable
                    ? () {
                        HapticFeedback.lightImpact();
                        onTap();
                      }
                    : null, // Only allow tap if clickable
                child: Stack(
                  children: [
                    // Enhanced main icon
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: icon == null
                            ? const SizedBox.shrink()
                            : Icon(
                                icon,
                                color: isClickable
                                    ? const Color(0xffF44336)
                                    : Colors.grey.shade500,
                                size: isTablet ? 32 : 26,
                              ),
                      ),
                    ),

                    // Premium badge
                    if (isPremium)
                      Positioned(
                        top: isTablet ? 4 : 2,
                        right: isTablet ? 4 : 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 6 : 4,
                            vertical: isTablet ? 3 : 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isClickable
                                  ? [Colors.purple, Colors.blue]
                                  : [
                                      Colors.grey.shade400,
                                      Colors.grey.shade500
                                    ],
                            ),
                            borderRadius:
                                BorderRadius.circular(isTablet ? 8 : 6),
                          ),
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Notification badge
                    if (hasNotification)
                      Positioned(
                        top: isTablet ? 8 : 6,
                        right: isTablet ? 8 : 6,
                        child: Container(
                          width: isTablet ? 12 : 10,
                          height: isTablet ? 12 : 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: isTablet ? 12 : 8),

          // Enhanced title
          Text(
            title,
            style: TextStyle(
              color:
                  isClickable ? const Color(0xff212427) : Colors.grey.shade600,
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _openIntercom(BuildContext context) async {
    try {
      final host = await createOneGateFeatureHost(
        logger: (String message, {Object? error, StackTrace? stackTrace}) {
          log(message, error: error, stackTrace: stackTrace);
        },
      );

      await startIntercom(context, host: host);
    } catch (e, st) {
      log('Failed to open Guard Intercom', error: e, stackTrace: st);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open Intercom Services: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Enhanced Visitor Input Section - Guest Form Style
  Widget _buildEnhancedVisitorInput(BuildContext context, bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isTablet ? 8 : 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context, _createRoute());
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: isTablet ? 28 : 22,
                offset: Offset(0, isTablet ? 14 : 10),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: isTablet ? 14 : 12,
                offset: Offset(0, isTablet ? 6 : 5),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Header Section
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 14 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        color: const Color(0xffF44336),
                        size: isTablet ? 28 : 24,
                      ),
                    ),
                    SizedBox(width: isTablet ? 20 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.enterVisitorDetails,
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff212427),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isTablet ? 6 : 4),
                          Text(
                            context.l10n.tapToEnterMobileOrId,
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              color: const Color(0xff57636C),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Removed arrow icon as per request
                  ],
                ),
              ),

              // Input Preview Section
              Container(
                margin: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 20,
                  0,
                  isTablet ? 24 : 20,
                  isTablet ? 24 : 20,
                ),
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: const Color(0xffF44336).withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xffF44336).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Input type icon
                        Container(
                          padding: EdgeInsets.all(isTablet ? 10 : 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xffF44336).withOpacity(0.1),
                                const Color(0xffD32F2F).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xffF44336).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: const Color(0xffF44336),
                            size: isTablet ? 20 : 18,
                          ),
                        ),

                        SizedBox(width: isTablet ? 16 : 12),

                        // Animated input examples
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.examples,
                                style: TextStyle(
                                  fontSize: isTablet ? 14 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff57636C),
                                ),
                              ),
                              SizedBox(height: isTablet ? 6 : 4),
                              DefaultTextStyle(
                                style: TextStyle(
                                  color: const Color(0xff212427),
                                  fontWeight: FontWeight.w500,
                                  fontSize: isTablet ? 18 : 16,
                                  letterSpacing: 0.3,
                                ),
                                child: AnimatedTextKit(
                                  repeatForever: true,
                                  animatedTexts: [
                                    TyperAnimatedText(
                                      '9912345678',
                                      speed: const Duration(milliseconds: 100),
                                    ),
                                    TyperAnimatedText(
                                      '390709',
                                      speed: const Duration(milliseconds: 100),
                                    ),
                                  ],
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Microphone icon (visual only)
                        Container(
                          padding: EdgeInsets.all(isTablet ? 8 : 6),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.mic,
                            color: const Color(0xffF44336),
                            size: isTablet ? 18 : 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 14 : 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xffF44336).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: isTablet ? 16 : 14,
                            color: const Color(0xffF44336),
                          ),
                          SizedBox(width: isTablet ? 8 : 6),
                          Expanded(
                            child: Text(
                              'This is an example preview. Tap Enter details to proceed.',
                              style: TextStyle(
                                color: const Color(0xff57636C),
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTablet ? 12 : 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, _createRoute());
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffF44336),
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 14 : 12,
                            vertical: isTablet ? 10 : 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: const Color(0xffF44336).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          'Enter details',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 13,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

// Enhanced Route Animation
Route _createRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => IdInputView(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      var scaleTween = Tween(begin: 0.8, end: 1.0);
      var scaleAnimation = animation.drive(scaleTween);

      var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      );

      return SlideTransition(
        position: offsetAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        ),
      );
    },
  );
}
