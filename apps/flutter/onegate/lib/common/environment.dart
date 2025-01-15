import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Environment {
  /// Retrieve headers with access token for API requests
  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken == null) {
      throw Exception('Access token not found. Please log in again.');
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
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