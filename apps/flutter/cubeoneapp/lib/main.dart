import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_commons_theme_manager/theme.dart';
import 'package:flutter_cubeoneapp/src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.initializeWithAppId('cubeoneapp');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    const MyApp(),
  );
}
