import 'package:flutter/material.dart';
import 'theme.dart';

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static Color fromHex(String hexColor) {
    return HexColor(hexColor);
  }
}

class ThemeManagerConfig {
  static dynamic getFontValue(Map<String, dynamic> themeData, String path) {
    debugPrint('getFontValue: ${getConfigValue(themeData, '$path')}');
    return getConfigValue(themeData, '$path');
  }

  static dynamic getColor(Map<String, dynamic> themeData, String path) {
    debugPrint('getColorValue: ${getConfigValue(themeData, '$path')}');
    return getConfigValue(themeData, '$path');
  }

  static FontWeight parseFontWeight(String value) {
    switch (value) {
      case 'bold':
        return FontWeight.bold;
      case 'normal':
      default:
        return FontWeight.normal;
    }
  }

  static dynamic getConfigValue(Map<String, dynamic> config, String path) {
    List<String> keys = path.split('.');
    dynamic value = config;
    for (String key in keys) {
      value = value[key];
    }
    return value;
  }
}
