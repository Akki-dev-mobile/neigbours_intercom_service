import 'dart:developer';

import 'package:jwt_decoder/jwt_decoder.dart';

import '../../src/config/intercom_module_config.dart';
import 'keycloak_service.dart';

class AuthTokenManager {
  static const String _logName = 'AuthTokenManager';

  static bool _isTokenValid(String token) {
    if (token.isEmpty) return false;
    // Do not treat local access-token expiry as invalid here.
    // Refresh flow is the source of truth for session continuity.
    return true;
  }

  static Future<String?> getBestAvailableToken() async {
    try {
      if (!IntercomModule.isConfigured) return null;

      final port = IntercomModule.config.authPort;
      final tokens = await port.getTokens();
      if (tokens == null || !_isTokenValid(tokens.accessToken)) {
        return null;
      }
      // Do not refresh here. The 401 interceptor path owns refresh.
      return tokens.accessToken;
    } catch (e) {
      log('Error getting token: $e', name: _logName);
      return null;
    }
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getBestAvailableToken();
    if (token == null) return <String, String>{};
    return {'Authorization': 'Bearer $token', 'X-Access-Token': token};
  }

  static Future<String?> getCurrentAccessTokenNoRefresh() async {
    if (!IntercomModule.isConfigured) return null;
    final tokens = await IntercomModule.config.authPort.getTokens();
    final token = tokens?.accessToken;
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<Map<String, String>> getAuthHeadersNoRefresh() async {
    final token = await getCurrentAccessTokenNoRefresh();
    if (token == null) return <String, String>{};
    return {'Authorization': 'Bearer $token', 'X-Access-Token': token};
  }

  static Future<bool> refreshTokenIfNeeded({
    bool force = false,
    String source = 'unknown',
  }) async {
    // Deprecated: refresh is owned by KeycloakService only
    return false;
  }

  static Future<bool> isSessionActive() async {
    try {
      if (!IntercomModule.isConfigured) return false;
      final port = IntercomModule.config.authPort;
      final tokens = await port.getTokens();
      if (tokens == null) return false;

      final accessToken = tokens.accessToken;
      if (accessToken.isNotEmpty) {
        try {
          if (!JwtDecoder.isExpired(accessToken)) {
            return true;
          }
        } catch (_) {
          // Opaque token: allow it.
          return true;
        }
      }

      if (tokens.refreshToken == null || tokens.refreshToken!.isEmpty) {
        return false;
      }
      return await KeycloakService.refreshTokenIfNeeded();
    } catch (e) {
      log('isSessionActive failed: $e', name: _logName);
      return false;
    }
  }
}
