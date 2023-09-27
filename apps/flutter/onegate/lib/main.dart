// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'dart:js';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/di/di.dart';

import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';

import 'package:one_theme/theme.dart';

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

  await ThemeManager.initializeWithAppId(
    appId,
    context,
  );

  runApp(
    DevicePreview(
        enabled: kDebugMode,
        builder: (context) {
          return const MyApp();
        }),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // startKioskMode();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeManager.lightTheme.copyWith(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      // darkTheme: ThemeManager.darkTheme,
      home: const AdminDashboardView(),
    );
  }
}
