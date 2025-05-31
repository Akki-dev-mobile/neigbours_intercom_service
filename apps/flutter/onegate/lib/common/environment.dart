import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'dart:developer';

class Environment {
  /// Retrieve headers with access token for API requests
  /// Now uses the enhanced authentication system for consistency
  static Future<Map<String, String>> getHeaders() async {
    try {
      // Use the enhanced authentication system
      final authService = GetIt.I<AuthService>();
      final accessToken = await authService.getValidAccessToken();

      if (accessToken == null) {
        log('⚠️ No valid access token available in Environment.getHeaders()');
        throw Exception('Access token not found. Please log in again.');
      }

      log('🔑 Environment.getHeaders() using enhanced auth system');
      return {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
    } catch (e) {
      log('❌ Error in Environment.getHeaders(): $e');
      // Fallback to old method for backward compatibility during transition
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }

      log('🔄 Environment.getHeaders() using fallback method');
      return {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
    }
  }

  /// Fetch environment-specific URL by key
  static String _getEnvUrl(String keyPrefix) {
    final env = dotenv.env['ENV'];
    if (env == null) {
      throw Exception('Environment (ENV) not set.');
    }

    final urlKey = '${env.toUpperCase()}_$keyPrefix';
    final url = dotenv.env[urlKey];

    if (url == null) {
      throw Exception('Environment variable $urlKey not found.');
    }

    return url;
  }

  /// Get Gate Base URL
  static String get gateBaseUrl => _getEnvUrl('GATE_BASE_URL');

  /// Get Auth URL
  static String get authUrl => _getEnvUrl('AUTH_URL');

  /// Get Society URL
  static String get societyUrl => _getEnvUrl('SOCIETY_URL');

  /// Get Media URL
  static String get mediaUrl => _getEnvUrl('MEDIA_URL');
}
