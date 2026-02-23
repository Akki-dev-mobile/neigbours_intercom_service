import 'dart:developer' as developer;

import 'package:jwt_decoder/jwt_decoder.dart';

import '../../src/config/intercom_module_config.dart';

class KeycloakService {
  static Future<String?> getAccessToken() async {
    final tokens = await IntercomModule.config.authPort.getTokens();
    return tokens?.accessToken;
  }

  static Future<String?> getIdToken() async {
    final tokens = await IntercomModule.config.authPort.getTokens();
    return tokens?.idToken;
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return null;
      return JwtDecoder.decode(token);
    } catch (e) {
      developer.log('KeycloakService.getUserData error: $e',
          name: 'KeycloakService');
      return null;
    }
  }

  /// Backwards-compatible alias used by legacy screens.
  static Future<Map<String, dynamic>?> getUserInfo() => getUserData();
}
