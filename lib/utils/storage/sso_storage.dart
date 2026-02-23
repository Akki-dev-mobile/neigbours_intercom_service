import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../src/config/intercom_module_config.dart';

class SsoStorage {
  static const String _keyUserProfile = 'sso_user_profile_v1';

  static Future<String?> getAccessToken() async {
    final tokens = await IntercomModule.config.authPort.getTokens();
    return tokens?.accessToken;
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    // Optional: host apps can persist an SSO-like profile for UI.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUserProfile);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  static Future<void> setUserProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserProfile, jsonEncode(profile));
  }
}

