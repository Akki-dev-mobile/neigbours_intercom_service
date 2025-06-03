import 'dart:async';
import 'dart:convert' show json;
import 'dart:developer';

import 'package:alarm/alarm.dart';
// No background task dependencies needed
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_onegate/approval_Status.dart';
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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:flutter_onegate/utils/network_log/models/network_log.dart';
import 'package:flutter_onegate/services/crash_reporting/models/crash_models.dart';
import 'package:flutter_onegate/services/crash_reporting/crash_reporter_service.dart';
import 'package:flutter_onegate/services/crash_reporting/analytics_service.dart';
import 'package:flutter_onegate/utils/no_internet_connection.dart';
import 'package:flutter_onegate/presentation/di/di.dart';
import 'package:flutter_onegate/utils/ssl_helper.dart';
import 'package:flutter_onegate/utils/custom_appauth.dart';
import 'package:flutter_onegate/utils/ssl_bypass.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_provider.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late GateConfig appGateConfig;

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

  // Initialize NetworkLogManager for debug logging early
  await NetworkLogManager().initialize();

  // Initialize Crash Reporting and Analytics
  await CrashReporterService().initialize();
  await AnalyticsService().initialize();

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

  // Initialize NetworkLogManager and add interceptor to Dio
  final networkLogManager = NetworkLogManager();
  await networkLogManager.initialize();

  // Set the gate ID for network logs
  await networkLogManager.updateGateId('MAIN_GATE');

  // Add network logger interceptor to the Dio instance
  final dio = GetIt.I<Dio>();
  networkLogManager.addInterceptorToDio(dio);

  if (kDebugMode) {
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

    // If connectivity has changed, schedule a navigation update.
    if (prevHasInternet != hasInternet) {
      prevHasInternet = hasInternet;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // When internet is lost, replace the current route with NoInternetScreen.
        if (!hasInternet) {
          Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ErrorNoInternetPage(),
            ),
            (route) => false,
          );
        } else {
          // When internet is restored, return to the main login screen.
          Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MyAppLogin(),
            ),
            (route) => false,
          );
        }
      });
    }

    // Use NetworkLogOverlay in debug mode, otherwise just return the app
    Widget app = MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeManager.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
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
        child: hasInternet ? const SplashView() : ErrorNoInternetPage(),
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
          title: const Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Exit App',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to exit the app?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit', style: TextStyle(color: Colors.red)),
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
