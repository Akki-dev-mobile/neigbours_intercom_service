import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_onegate/approval_Status.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/di/di.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/app_intro_view.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_Settings_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/visitorLogProvider.dart';
import 'package:flutter_onegate/purposeProvider.dart';
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
  await GateStorage().init();
  await setupDependencies();
  await setupLocator();
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
          ChangeNotifierProvider<GateProvider>(
            create: (_) => GateProvider(),
          ),
          ChangeNotifierProvider<CameraSettingsProvider>(
            create: (_) => CameraSettingsProvider(),
          ),
          ChangeNotifierProvider<VisitorApprovalTimeProvider>(
            create: (_) => VisitorApprovalTimeProvider(),
          ),
          ChangeNotifierProvider(create: (context) => TimerService()),
          // BlocProvider<ParcelBloc>(
          //   create: (context) => ParcelBloc(
          //     RemoteDataSource(
          //       DioSingleton.instance1,
          //       DioSingleton.instance2,
          //       DioSingleton.instance3,
          //     ),
          //   ),
          // ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<GatekeeperDashboardBloc>(
              create: (context) => GatekeeperDashboardBloc(
                VisitorUsecase(
                  VisitorRepoImpl(RemoteDataSource(
                    DioSingleton.instance1,
                    DioSingleton.instance2,
                    DioSingleton.instance3,
                  )), // Pass dependencies
                ),
                VisitorLogUsecase(
                  VisitorLogRepositoryImpl(
                    RemoteDataSource(
                      DioSingleton.instance1,
                      DioSingleton.instance2,
                      DioSingleton.instance3,
                    ),
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
  // late final AmqpReceiver _amqpReceiver;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // isLoggedIn();
    // Initialize and start the AMQP receiver
    // _amqpReceiver = AmqpReceiver();
    // _amqpReceiver.startListening();
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);

  //   if (state == AppLifecycleState.resumed) {
  //     // Resume listening when the app is reopened
  //     _amqpReceiver.startListening();
  //   } else if (state == AppLifecycleState.inactive ||
  //       state == AppLifecycleState.paused) {
  //     // Stop listening when the app is inactive or paused
  //     _amqpReceiver.stopListening();
  //   }
  // }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // _amqpReceiver.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget initialScreen = MyAppLogin();
    // LoginView();

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
            debugPrint('Exit confirmation result: $shouldExit'); // Debug log
            return shouldExit ?? false;
          },
          child: initialScreen),
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
          title: Row(
            children: const [
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
              onPressed: () => Navigator.of(context).pop(false), // Cancel exit
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirm exit
              child: const Text('Exit', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
