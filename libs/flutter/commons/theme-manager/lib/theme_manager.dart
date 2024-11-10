import 'package:flutter/material.dart';

class HexColor extends Color {
  HexColor(String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '').toUpperCase();
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return int.parse(hexColor, radix: 16);
  }

  static Color fromHex(String hexColor) => HexColor(hexColor);
}

class ThemeManagerConfig {
  static dynamic getFontValue(Map<String, dynamic> themeData, String path) {
    return getConfigValue(themeData, path);
  }

  static dynamic getColor(Map<String, dynamic> themeData, String path) {
    return getConfigValue(themeData, path);
  }

  static FontWeight parseFontWeight(String? value) {
    return value == 'bold' ? FontWeight.bold : FontWeight.normal;
  }

  static dynamic getConfigValue(Map<String, dynamic> config, String path) {
    List<String> keys = path.split('.');
    dynamic value = config;

    for (String key in keys) {
      // Check if value is a Map before accessing the key
      if (value is Map<String, dynamic> && value.containsKey(key)) {
        value = value[key];
      } else {
        return null; // Return null if the key is not found or value is not a Map
      }
    }

    return value;
  }
}
