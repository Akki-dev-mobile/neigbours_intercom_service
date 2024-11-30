import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/approval_Status.dart';
import 'package:flutter_onegate/presentation/di/di.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/utils/amqp_receiver.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:one_theme/theme.dart';
import 'package:provider/provider.dart'; // Import the provider package

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  String appId = "onegate";
  WidgetsFlutterBinding.ensureInitialized();

  await setupDependencies();
  await setupLocator();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ApprovalStatusProvider>(
            create: (_) => ApprovalStatusProvider(), // Initialize your provider
          ),
        ],
        child: const MyApp(),
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
  late final AmqpReceiver _amqpReceiver;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize and start the AMQP receiver
    _amqpReceiver = AmqpReceiver(navigatorKey);
    _amqpReceiver.startListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Resume listening when the app is reopened
      _amqpReceiver.startListening();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Stop listening when the app is inactive or paused
      _amqpReceiver.stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amqpReceiver.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget initialScreen = const MyAppLogin();
    // LoginView();

    return DevicePreview(
      enabled: !kDebugMode,
      builder: (context) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          useInheritedMediaQuery: true,
          debugShowCheckedModeBanner: false,
          theme: ThemeManager.lightTheme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          home: initialScreen,
        );
      },
    );
  }
}
