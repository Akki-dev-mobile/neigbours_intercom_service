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
import 'package:flutter_onegate/presentation/features/missed_approval/widget/time_provider.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:one_theme/theme.dart';
import 'package:provider/provider.dart';

import 'data/datasources/remote_datasource.dart';
import 'data/repositories/visitor_log_repo_impl.dart';
import 'data/repositories/visitor_repo_impl.dart';
import 'domain/use_cases/visitor_log_usecae.dart';
import 'domain/use_cases/visitor_usecase.dart';
import 'presentation/features/missed_approval/missed_approval_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late GateConfig appGateConfig;

void main() async {
  // Initialize SSL helper to bypass certificate validation
  SSLHelper.initialize();

  // Initialize SSL bypass for Android to handle certificate validation
  initializeSSLBypass();

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize NetworkLogManager for debug logging early
  await NetworkLogManager().initialize();

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Perform an initial internet check after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<InternetCheckProvider>(context, listen: false);
      provider.checkInternetAccess();
    });
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
          final shouldExit = await showExitConfirmationDialog(context);
          return shouldExit ?? false;
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
    super.dispose();
  }
}
