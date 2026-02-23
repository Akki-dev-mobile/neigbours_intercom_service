import 'dart:developer';

import 'keycloak_service.dart';

class AuthTokenManager {
  static const String _logName = 'AuthTokenManager';

  static Future<String?> getBestAvailableToken() async {
    try {
      final token = await KeycloakService.getAccessToken();
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (e) {
      log('Error getting token: $e', name: _logName);
      return null;
    }
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getBestAvailableToken();
    if (token == null) return <String, String>{};
    return {
      'Authorization': 'Bearer $token',
      'X-Access-Token': token,
    };
  }

  static Future<bool> refreshTokenIfNeeded() async {
    // Token refresh is owned by the host app.
    return false;
  }
}

