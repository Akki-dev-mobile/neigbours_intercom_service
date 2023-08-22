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
