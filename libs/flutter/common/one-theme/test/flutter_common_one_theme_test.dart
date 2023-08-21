import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:one_theme/theme.dart';
import 'package:flutter_test/flutter_test.dart';

late ThemeManager themeManager = ThemeManager();

Future<void> init() async {
  themeManager = ThemeManager();
  await ThemeManager.initializeThemes();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  test('adds one to input values', () async {
    await init();
    debugPrint(ThemeManager.lightTheme.toString());
    ThemeManager.lightTheme;
  });
}
