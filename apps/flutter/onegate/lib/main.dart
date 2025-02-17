import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_onegate/approval_Status.dart';
import 'package:flutter_onegate/common/internet_check_provider.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/no_internet_connection.dart';
import 'package:flutter_onegate/presentation/di/di.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/app_intro_view.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_provider.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_Settings_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/visitorLogProvider.dart';
import 'package:flutter_onegate/purposeProvider.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/timeprovider.dart';
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

void main() async {
  await dotenv.load(fileName: "assets/.env");
  String appId = "onegate";
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  await setupLocator();
  await GateStorage().init();
  await setupDependencies();

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
          ChangeNotifierProvider<ApprovalStatusProvider>(
            create: (_) => ApprovalStatusProvider(),
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
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasInternet = context.watch<InternetCheckProvider>().hasInternet;
    Widget initialScreen = const MyAppLogin();

    return MaterialApp(
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
        child: hasInternet ? const MyAppLogin() : const NoInternetScreen(),
      ),
    );
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
}
