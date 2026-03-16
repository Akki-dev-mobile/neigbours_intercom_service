import 'dart:async';
import 'dart:developer';

import 'package:alarm/alarm.dart';
// No background task dependencies needed
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/services/language/language_provider.dart';
import 'package:flutter_onegate/common/internet_check_provider.dart';
import 'package:flutter_onegate/config/gate_config.dart' show GateConfig;
import 'package:flutter_onegate/config/gateconfig_holder.dart'
    show GateConfigHolder;
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/repositories/license_plate_repository.dart';
import 'package:flutter_onegate/presentation/features/license_plate_detection/bloc/license_plate_bloc.dart';
import 'package:flutter_onegate/splash_screen.dart';
import 'package:flutter_onegate/utils/network_log/network_log_manager.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_overlay.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:flutter_onegate/utils/network_log/models/network_log.dart';
import 'package:flutter_onegate/services/crash_reporting/models/crash_models.dart';
import 'package:flutter_onegate/services/crash_reporting/crash_reporter_service.dart';
import 'package:flutter_onegate/services/crash_reporting/analytics_service.dart';
import 'package:flutter_onegate/services/observatory/comprehensive_monitoring_service.dart';
import 'package:flutter_onegate/utils/no_internet_connection.dart';
import 'package:flutter_onegate/presentation/di/di.dart';
import 'package:flutter_onegate/utils/ssl_helper.dart';
import 'package:flutter_onegate/utils/custom_appauth.dart';
import 'package:flutter_onegate/utils/ssl_bypass.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_provider.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/bloc/visitor_log_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_Settings_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/visitorLogProvider.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/purpose/provider/purposeProvider.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/presentation/widgets/session_expired_bottom_sheet.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/widget/time_provider.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:one_theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/session_manager/session_expiry_fix.dart';
import 'package:flutter_onegate/services/session_manager/eleven_minute_expiry_fix.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';

import 'data/datasources/remote_datasource.dart';
import 'data/repositories/visitor_log_repo_impl.dart';
import 'data/repositories/visitor_repo_impl.dart';
import 'domain/use_cases/visitor_log_usecae.dart';
import 'domain/use_cases/visitor_usecase.dart';
import 'presentation/features/missed_approval/missed_approval_screen.dart';
// Debug imports
import 'debug/error_tracking_test.dart';
// Error tracking imports
import 'services/error_tracking/posthog_error_tracking_service.dart';
// Analytics imports
// import 'package:flutter_clarity/flutter_clarity.dart';  // Commented out due to API compatibility issues

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late GateConfig appGateConfig;

/// Microsoft Clarity Analytics
/// Note: Currently disabled due to Flutter package API compatibility issues
/// Project ID s1bnm5i1um is ready to be used when a compatible package is found
/// This will work in BOTH debug and release modes for production analytics
Future<void> _initializeClarityAnalytics() async {
  try {
    log('🔍 Microsoft Clarity Analytics: Package integration pending');
    log('📊 Project ID ready: s1bnm5i1um');
    log('💡 Awaiting compatible Flutter Clarity package for full integration');

    // When package is available, this will track:
    // - Real visitor check-in flows in production
    // - User interactions with gate selection
    // - Performance bottlenecks in visitor management
    // - Mobile app usage patterns

    if (kDebugMode) {
      log('🧪 Running in DEBUG mode - will show detailed logs');
    } else {
      log('🚀 Running in RELEASE mode - production analytics ready');
    }
  } catch (e) {
    log('❌ Failed to initialize Microsoft Clarity Analytics: $e');
  }
}

/// Send a test error to PostHog for verification (debug mode only)
Future<void> _sendTestErrorToPostHog() async {
  try {
    await PostHogErrorTrackingService.instance.captureError(
      error: Exception(
          '🧪 TEST ERROR: OneGate PostHog Error Tracking Verification'),
      stackTrace: StackTrace.current,
      context: 'app_initialization_test',
      errorType: 'TestError',
      isFatal: false,
      additionalProperties: {
        'test_type': 'posthog_verification',
        'test_description':
            'This is a test error sent during app initialization to verify PostHog Error Tracking is working',
        'timestamp': DateTime.now().toIso8601String(),
        'app_startup': true,
      },
    );

    log('🧪 Test error sent to PostHog Error Tracking for verification');
    log('📊 Check dashboard: https://us.posthog.com/project/170509/error_tracking');
  } catch (e) {
    log('❌ Failed to send test error to PostHog: $e');
  }
}

/// Initialize Hive with all required adapters
Future<void> _initializeHive() async {
  try {
    // Initialize Hive
    await Hive.initFlutter();

    // Register all Hive adapters in the correct order
    // NetworkLog adapter (typeId: 1)
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(NetworkLogAdapter());
    }

    // NotificationMessage adapter (typeId: 100)
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(NotificationMessageAdapter());
    }

    // NotificationSubscriber adapter (typeId: 101)
    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(NotificationSubscriberAdapter());
    }

    // CrashReport adapter (typeId: 102)
    if (!Hive.isAdapterRegistered(102)) {
      Hive.registerAdapter(CrashReportAdapter());
    }

    // AnalyticsEvent adapter (typeId: 103)
    if (!Hive.isAdapterRegistered(103)) {
      Hive.registerAdapter(AnalyticsEventAdapter());
    }

    // UserSession adapter (typeId: 104)
    if (!Hive.isAdapterRegistered(104)) {
      Hive.registerAdapter(UserSessionAdapter());
    }

    log('Hive initialized successfully with all adapters');
  } catch (e) {
    log('Error initializing Hive: $e');
    rethrow;
  }
}

void main() async {
  // Initialize SSL helper to bypass certificate validation
  SSLHelper.initialize();

  // Initialize SSL bypass for Android to handle certificate validation
  initializeSSLBypass();

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive first with all adapters
  await _initializeHive();

  // Initialize NetworkLogManager for debug logging early (DEBUG ONLY)
  if (kDebugMode) {
    await NetworkLogManager().initialize();
  }

  // Initialize Crash Reporting, Analytics, and Comprehensive Monitoring (DEBUG ONLY)
  if (kDebugMode) {
    await CrashReporterService().initialize();
    await AnalyticsService().initialize();
    await ComprehensiveMonitoringService.instance.initialize();
  }

  // Initialize PostHog Error Tracking (DEBUG ONLY)
  if (kDebugMode) {
    await PostHogErrorTrackingService.instance.initialize();

    // Send a test error to verify PostHog Error Tracking (only in debug mode)
    await _sendTestErrorToPostHog();
  }

  // Initialize Microsoft Clarity Analytics (ALL MODES)
  // Note: Unlike other debug services, Clarity should work in production
  // to track real user behavior and provide valuable insights
  await _initializeClarityAnalytics();

  // Configure AppAuth to allow insecure connections
  await CustomAppAuth.configureAppAuth();

  RemoteDataSource remoteDataSource = RemoteDataSource();
  await dotenv.load(fileName: "assets/.env");
  String appId = "onegate";

  final gateConfig = await remoteDataSource.fetchGateBaseDomain();
  GateConfigHolder.setConfig(gateConfig);

  await Alarm.init();
  // Workmanager is initialized in NetworkLogBackgroundService
  await setupLocator();
  await GateStorage().init();
  await setupDependencies();

  // Configure TokenNotificationService to hide snackbar notifications
  // This disables the "refreshing token", "token refreshed successfully", and "login again" snackbars
  final tokenNotificationService = TokenNotificationService();
  tokenNotificationService.setShowNotifications(false);
  log('🔧 Token refresh snackbar notifications disabled');

  // Initialize ONLY UserSessionManager - single unified session management system
  try {
    final userSessionManager = GetIt.I<UserSessionManager>();
    await userSessionManager.initialize();
    log('✅ Unified Session Management initialized successfully');
  } catch (e) {
    log('❌ Error initializing Unified Session Management: $e');
  }

  // Initialize Session Expiry Fix for dynamic JWT handling
  try {
    await SessionExpiryFix.initialize();
    log('✅ Session Expiry Fix with dynamic JWT handling initialized successfully');
  } catch (e) {
    log('❌ Error initializing Session Expiry Fix: $e');
  }

  // Initialize 11-Minute Expiry Fix for specific session expiry issue
  try {
    await ElevenMinuteExpiryFix.initialize();
    log('✅ 11-Minute Session Expiry Fix initialized successfully');
  } catch (e) {
    log('❌ Error initializing 11-Minute Expiry Fix: $e');
  }

  // Initialize Session Management Coordinator to prevent conflicts
  try {
    await SessionManagementCoordinator.initialize();
    log('✅ Session Management Coordinator initialized successfully');

    // Apply emergency fix for login screen session expired modal issue
    await SessionManagementCoordinator.applyEmergencyLoginFix();
    log('✅ Emergency login fix applied successfully');
  } catch (e) {
    log('❌ Error initializing Session Management Coordinator: $e');
  }

  // Initialize NetworkLogManager and add interceptor to Dio (DEBUG ONLY)
  if (kDebugMode) {
    final networkLogManager = NetworkLogManager();
    await networkLogManager.initialize();

    // Set the gate ID for network logs
    await networkLogManager.updateGateId('MAIN_GATE');

    // Add network logger interceptor to the Dio instance
    final dio = GetIt.I<Dio>();
    networkLogManager.addInterceptorToDio(dio);

    print('NetworkLogManager initialized and interceptor added to Dio');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ),
  );
  await ThemeManager.initializeWithAppId(appId);

  runApp(
    ScreenUtilInit(
      fontSizeResolver: (num size, ScreenUtil _) => 0.5,
      enableScaleText: () => true,
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => MultiProvider(
        providers: [
          // Language provider for multilingual support
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider()..initialize(),
          ),
          ChangeNotifierProvider<PurposeProvider>(
            create: (_) => PurposeProvider(),
          ),
          ChangeNotifierProvider<VisitorLogsProvider>(
            create: (_) => VisitorLogsProvider(),
          ),
          ChangeNotifierProvider<VisitorSettingsProvider>(
            create: (_) => VisitorSettingsProvider(),
          ),
          ChangeNotifierProvider<LoginProvider>(
            create: (_) => LoginProvider(authService: GetIt.I<AuthService>()),
          ),
          ChangeNotifierProvider<GateProvider>(
            create: (_) => GateProvider(),
          ),
          ChangeNotifierProvider(create: (_) => InternetCheckProvider()),
          ChangeNotifierProvider<CameraSettingsProvider>(
            create: (_) => CameraSettingsProvider(),
          ),
          ChangeNotifierProvider<VisitorApprovalTimeProvider>(
            create: (_) => VisitorApprovalTimeProvider(),
          ),
          ChangeNotifierProvider(create: (context) => TimerService()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => ParcelBloc(RemoteDataSource())),
            BlocProvider(
                create: (context) =>
                    LicensePlateBloc(LicensePlateRepository())),
            BlocProvider<GatekeeperDashboardBloc>(
              create: (context) => GatekeeperDashboardBloc(
                VisitorUsecase(
                  VisitorRepoImpl(RemoteDataSource()), // Pass dependencies
                ),
                VisitorLogUsecase(
                  VisitorLogRepositoryImpl(
                    RemoteDataSource(),
                  ),
                ),
              ),
            ),
            BlocProvider<VisitorLogBloc>(
              create: (context) => VisitorLogBloc(
                VisitorLogUsecase(
                  VisitorLogRepositoryImpl(
                    RemoteDataSource(),
                  ),
                ),
              ),
            ),
          ],
          child: const MyApp(),
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final PreferenceUtils preferenceUtils = GetIt.I<PreferenceUtils>();

  // Track previous connectivity status to detect changes.
  bool prevHasInternet = true;

  // Track app resume state to prevent false connectivity loss detection
  bool _isAppResuming = false;
  DateTime? _lastAppPauseTime;

  // Session management
  UserSessionManager? _sessionManager;
  StreamSubscription<UserSessionState>? _sessionStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize session state listener
    _initializeSessionStateListener();

    // Perform an initial internet check after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<InternetCheckProvider>(context, listen: false);
      provider.checkInternetAccess();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        log('📱 App resumed from background/sleep');
        _isAppResuming = true;
        // When app resumes, check internet with a delay to avoid false positives
        // This prevents showing "no internet" page when waking from sleep
        _handleAppResume();
        break;
      case AppLifecycleState.paused:
        log('📱 App paused (going to background/sleep)');
        _lastAppPauseTime = DateTime.now();
        _isAppResuming = false;
        // Save current state when going to background
        _saveCurrentAppState();
        break;
      case AppLifecycleState.inactive:
        log('📱 App inactive');
        break;
      case AppLifecycleState.detached:
        log('📱 App detached');
        break;
      case AppLifecycleState.hidden:
        log('📱 App hidden');
        break;
    }
  }

  /// Save current app state when going to background/sleep
  void _saveCurrentAppState() async {
    try {
      final currentRoute =
          ModalRoute.of(navigatorKey.currentContext!)?.settings.name;
      log('💾 Saving app state - current route: $currentRoute');

      // Save the current route and context
      await RouteTracker.saveCurrentRoute(
        currentRoute ?? 'unknown',
        isExpressEntry: _isExpressEntryRoute(currentRoute),
      );
    } catch (e) {
      log('❌ Error saving app state: $e');
    }
  }

  /// Check if current route is express entry related
  bool _isExpressEntryRoute(String? route) {
    if (route == null) return false;

    return route.contains('SelfHomeView') ||
        route.contains('self_entry') ||
        route.contains('SelfEntryView') ||
        route.contains('SelfEntryFacerecView') ||
        route.contains('RequestPermissionPage2') ||
        route.contains('qr_scanner_self') ||
        route.contains('passcode_entry_view') ||
        route.contains('visitor_in_entry') ||
        route.contains('unit_selection_view') ||
        route.contains('visitor_checkin_flow');
  }

  /// Handle app resume from sleep/background
  void _handleAppResume() async {
    try {
      log('📱 Handling app resume - checking internet with delay');
      // Use delayed internet check to avoid false positives when resuming from sleep
      final provider =
          Provider.of<InternetCheckProvider>(context, listen: false);
      await provider.checkInternetAccessWithDelay(
          delay: const Duration(seconds: 2));

      // Reset the app resuming flag after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _isAppResuming = false;
        log('📱 App resume flag reset');
      });
    } catch (e) {
      log('❌ Error handling app resume: $e');
    }
  }

  /// Handle internet loss intelligently
  void _handleInternetLoss() async {
    try {
      // Check if this is happening during app resume from sleep
      if (_isAppResuming) {
        log('📱 Internet loss detected during app resume - ignoring to prevent false positive');
        return;
      }

      // Check if this happened shortly after app pause (likely sleep/wake cycle)
      if (_lastAppPauseTime != null) {
        final timeSincePause = DateTime.now().difference(_lastAppPauseTime!);
        if (timeSincePause.inSeconds < 10) {
          log('📱 Internet loss detected shortly after app pause (${timeSincePause.inSeconds}s) - likely sleep/wake cycle, ignoring');
          return;
        }
      }

      log('🌐 Real internet loss detected - proceeding with no internet page');

      // Save the current route information before showing no internet page
      _saveCurrentAppState();

      // Wait a moment to see if internet comes back quickly (common when resuming from sleep)
      await Future.delayed(const Duration(seconds: 2));

      // Check if internet is still lost after the delay
      final provider =
          Provider.of<InternetCheckProvider>(context, listen: false);
      await provider.checkInternetAccess();

      // Only show no internet page if internet is still actually lost
      if (!provider.hasInternet && mounted) {
        log('🌐 Internet is still lost, showing no internet page');
        Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ErrorNoInternetPage(),
          ),
          (route) => false,
        );
      } else {
        log('🌐 Internet connection restored, staying on current page');
      }
    } catch (e) {
      log('❌ Error handling internet loss: $e');
      // Fallback: show no internet page if there's an error
      if (mounted) {
        Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ErrorNoInternetPage(),
          ),
          (route) => false,
        );
      }
    }
  }

  /// Initialize session state listener to handle token expiration
  void _initializeSessionStateListener() {
    try {
      _sessionManager = GetIt.I<UserSessionManager>();

      // Listen to session state changes
      _sessionStateSubscription =
          _sessionManager!.sessionStateStream.listen((state) {
        if (mounted) {
          _handleSessionStateChange(state);
        }
      });

      log('✅ Session state listener initialized');
    } catch (e) {
      log('❌ Error initializing session state listener: $e');
    }
  }

  /// Handle session state changes
  void _handleSessionStateChange(UserSessionState state) async {
    log('🔄 Session state changed to: $state');

    // Use coordinator to check if session expired modal should be shown
    final shouldShowModal =
        await SessionManagementCoordinator.shouldShowSessionExpiredModal();
    if (!shouldShowModal) {
      log('📱 Session Management Coordinator blocking session expired modal');
      return;
    }

    switch (state) {
      case UserSessionState.tokenExpired:
        log('⏰ Token expired - checking if should show session expired modal');
        // Check if continuous session mode is active before showing modal
        final shouldShow = await _shouldShowSessionExpiredModal();
        if (shouldShow) {
          log('🔒 Showing session expired modal (continuous session not active)');
          _showSessionExpiredModal();
        } else {
          log('🔒 Continuous session active - not showing session expired modal');
        }
        break;
      case UserSessionState.unauthenticated:
        log('🚪 User unauthenticated - navigating to login');
        SessionManagementCoordinator.setNavigatingToLogin(true);
        _navigateToLogin();
        break;
      case UserSessionState.authenticated:
        log('✅ User authenticated');
        break;
      case UserSessionState.error:
        log('❌ Session error detected');
        break;
      case UserSessionState.unknown:
        log('❓ Session state unknown');
        break;
    }
  }

  /// Check if session expired modal should be shown
  Future<bool> _shouldShowSessionExpiredModal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if continuous session mode is active
      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;

      final isContinuousSessionMode = tokenExpirationLogoutDisabled ||
          autoLogoutDisabled ||
          continuousSessionActive;

      log('🔍 Session Modal Check:');
      log('   • Token Expiration Logout Disabled: $tokenExpirationLogoutDisabled');
      log('   • Auto Logout Disabled: $autoLogoutDisabled');
      log('   • Continuous Session Active: $continuousSessionActive');
      log('   • Continuous Session Mode: $isContinuousSessionMode');

      // Should NOT show modal if continuous session mode is active
      return !isContinuousSessionMode;
    } catch (e) {
      log('❌ Error checking if should show session expired modal: $e');
      // Default to showing modal if we can't determine the state
      return true;
    }
  }

  /// Show session expired modal
  void _showSessionExpiredModal() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showSessionExpiredBottomSheet(
        errorMessage:
            'Your session has expired. Please log in again to continue.',
        onLoginComplete: () {
          log('✅ Session expired modal login completed');
        },
      );
    } else {
      log('⚠️ No context available for session expired modal');
      // Fallback to direct navigation
      _navigateToLogin();
    }
  }

  /// Navigate to login screen
  void _navigateToLogin() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to internet status changes.
    final internetProvider = context.watch<InternetCheckProvider>();
    final hasInternet = internetProvider.hasInternet;

    // Handle internet restoration with proper route redirection
    void handleInternetRestoration() async {
      final wasExpressEntry = await RouteTracker.wasExpressEntryRoute();
      final lastRoute = await RouteTracker.getLastRoute();

      // Debug logging
      print(
          '🔍 [DEBUG] Internet restoration - wasExpressEntry: $wasExpressEntry');
      print('🔍 [DEBUG] Internet restoration - lastRoute: $lastRoute');

      if (wasExpressEntry) {
        // User was on express entry flow, redirect back to express entry dashboard
        print(
            '🔍 [DEBUG] Redirecting to SelfHomeView (Express Entry Dashboard)');

        // Add a small delay to ensure smooth transition
        await Future.delayed(const Duration(milliseconds: 500));

        // Ensure we have a valid context before navigating
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const SelfHomeView(),
            ),
            (route) => false,
          );
          // Clear the saved route after successful navigation
          await RouteTracker.clearSavedRoute();
        } else {
          print('🔍 [DEBUG] Context not available for navigation, retrying...');
          // Retry after a longer delay if context is not available
          await Future.delayed(const Duration(milliseconds: 1000));
          final retryContext = navigatorKey.currentContext;
          if (retryContext != null && retryContext.mounted) {
            Navigator.of(retryContext).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const SelfHomeView(),
              ),
              (route) => false,
            );
            await RouteTracker.clearSavedRoute();
          }
        }
      } else {
        // User was on gatekeeper dashboard or other routes, redirect to gatekeeper dashboard
        print('🔍 [DEBUG] Redirecting to GateDashboardView (Gatekeeper/Other)');

        // Add a small delay to ensure smooth transition
        await Future.delayed(const Duration(milliseconds: 500));

        // Ensure we have a valid context before navigating
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const GateDashboardView(),
            ),
            (route) => false,
          );
          // Clear the saved route after successful navigation
          await RouteTracker.clearSavedRoute();
        } else {
          print('🔍 [DEBUG] Context not available for navigation, retrying...');
          // Retry after a longer delay if context is not available
          await Future.delayed(const Duration(milliseconds: 1000));
          final retryContext = navigatorKey.currentContext;
          if (retryContext != null && retryContext.mounted) {
            Navigator.of(retryContext).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const GateDashboardView(),
              ),
              (route) => false,
            );
            await RouteTracker.clearSavedRoute();
          }
        }
      }
    }

    // If connectivity has changed, schedule a navigation update.
    if (prevHasInternet != hasInternet) {
      prevHasInternet = hasInternet;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // When internet is lost, save current route and replace with NoInternetScreen.
        if (!hasInternet) {
          // Only show no internet page if we're not just resuming from sleep
          // Check if this is a real connectivity loss vs app resume
          _handleInternetLoss();
        } else {
          // When internet is restored, check where user was before and redirect appropriately
          handleInternetRestoration();
        }
      });
    }

    // Use NetworkLogOverlay in debug mode, otherwise just return the app
    final languageProvider = context.watch<LanguageProvider>();
    Widget app = MaterialApp(
      key: ValueKey(
          'app_${languageProvider.currentLanguageCode}_${languageProvider.rebuildKey}'),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      // Localization configuration
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
        Locale('mr'), // Marathi
      ],
      locale: languageProvider.currentLocale,
      localeResolutionCallback: (locale, supportedLocales) {
        // Check if the current device locale is supported
        for (var supportedLocale in supportedLocales) {
          if (locale?.languageCode == supportedLocale.languageCode) {
            return supportedLocale;
          }
        }
        // If the device locale is not supported, return English as default
        return const Locale('en');
      },
      theme: ThemeManager.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      // Add routes
      routes: {
        if (kDebugMode)
          '/error-tracking-test': (context) => const ErrorTrackingTestWidget(),
        '/self-entry': (context) => const SelfHomeView(),
        '/login': (context) => const MyAppLogin(),
      },
      home: WillPopScope(
        onWillPop: () async {
          final currentContext = navigatorKey.currentContext;
          if (currentContext != null) {
            final shouldExit = await showExitConfirmationDialog(currentContext);
            return shouldExit ?? false;
          }
          return false; // Don't exit if no context available
        },
        // Initially show the correct screen based on connectivity.
        child: hasInternet ? const SplashView() : const ErrorNoInternetPage(),
      ),
    );

    // In debug mode, wrap with NetworkLogOverlay
    if (kDebugMode) {
      return NetworkLogOverlay(child: app);
    } else {
      return app;
    }
  }

  Future<bool?> showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.exit_to_app, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).exitApp,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context).exitAppConfirmation,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).cancel,
                  style: const TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context).exitApp,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionStateSubscription?.cancel();
    super.dispose();
  }
}
