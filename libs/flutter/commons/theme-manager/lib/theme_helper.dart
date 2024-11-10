import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ThemeHelper {
  static const String _cacheKey = 'themeConfig';

  static Future<Map<String, dynamic>> loadConfigForApp(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJsonString = prefs.getString(_cacheKey);

    if (cachedJsonString != null) {
      return jsonDecode(cachedJsonString);
    }

    try {
      final response = await http.get(Uri.parse(
          'https://fstech-cms-db.s3.ap-south-1.amazonaws.com/theme_698083e4d3.json'));
      if (response.statusCode == 200) {
        final jsonString = response.body;
        await prefs.setString(_cacheKey, jsonString);
        return jsonDecode(jsonString);
      } else {
        throw Exception('Failed to load theme configuration');
      }
    } catch (e) {
      throw Exception('Error fetching theme configuration: $e');
    }
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
