import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class ThemeHelper {
  static Future<Map<String, dynamic>> loadConfigForApp(String appId) async {
    String jsonString =
        await rootBundle.loadString('assets/onegate/theme.json');
    return json.decode(jsonString);
  }

  static dynamic getThemeHelperValue(Map<String, dynamic> config, String path) {
    List<String> keys = path.split('.');
    dynamic value = config;
    for (String key in keys) {
      value = value[key];
    }
    return value;
  }
}

double getResponsiveFontSize(BuildContext context, double fontSize) {
  double screenWidth = MediaQuery.of(context).size.width;

  if (screenWidth >= 1024) {
    return fontSize * 1.5;
  } else if (screenWidth >= 600) {
    return fontSize * 1.2;
  } else {
    return fontSize;
  }
}
