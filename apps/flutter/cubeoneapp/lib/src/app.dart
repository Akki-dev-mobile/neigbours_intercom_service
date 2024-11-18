import 'package:flutter/material.dart';
import 'package:flutter_cubeoneapp/temp_dashboard.dart';
import 'package:flutter_commons_theme_manager/theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeManager.darkTheme,
        home: const TempDashboard(),
      ),
    );
  }
}
