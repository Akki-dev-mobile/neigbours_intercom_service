// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/presentation/di/di.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:one_theme/theme.dart';

import 'presentation/features/app_intro/ui/app_intro_view.dart';

void main() async {
  String appId = "onegate";
  WidgetsFlutterBinding.ensureInitialized();

  setupDependencies();
  setupLocator();
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
  // startKioskMode();
  runApp(
    ScreenUtilInit(
      fontSizeResolver: (num size, ScreenUtil _) => 0.5,
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (!_preferenceUtils.getIsAppIntroShown()!) {
      initialScreen = AppIntroView();
    } else {
      if (_preferenceUtils.getIsLogin()!) {
        if (_preferenceUtils.getIsAdmin()!) {
          initialScreen = AdminDashboardView();
        } else {
          initialScreen = _preferenceUtils.getIsSelfTapIn()!
              ? SelfHomeView()
              : GateDashboardView();
        }
      } else {
        initialScreen = LoginView();
      }
    }
    return DevicePreview(
        enabled: !kDebugMode,
        builder: (context) {
          return MaterialApp(
            useInheritedMediaQuery: true,
            debugShowCheckedModeBanner: false,
            theme: ThemeManager.lightTheme.copyWith(
              pageTransitionsTheme: PageTransitionsTheme(
                builders: const <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.android: ZoomPageTransitionsBuilder(),
                },
              ),
            ),
            home: initialScreen,
            // home: VisitorsInEntry(
            //   selectedValue: 'GUEST',
            // ),
          );
        });
  }
}
