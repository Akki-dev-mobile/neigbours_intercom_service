import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter__cubeoneapp/app.dart';
import 'package:flutter_commons_theme_manager/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.initializeWithAppId('cubeoneapp');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    const MyApp(),
  );
}
