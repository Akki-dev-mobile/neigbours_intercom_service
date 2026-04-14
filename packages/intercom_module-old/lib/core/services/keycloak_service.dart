import 'dart:developer' as developer;

import 'package:jwt_decoder/jwt_decoder.dart';

import '../../src/config/intercom_module_config.dart';
import '../../src/ports/intercom_ports.dart';
import 'secure_storage_service.dart';

enum RefreshTokenValidity { valid, expiredOrMissing, unknown }

class KeycloakService {
  static Future<bool>? _refreshFuture;
  static final SecureStorageService _storage = SecureStorageService();

  static String _tokenPreview(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 14)
      return '${token.substring(0, token.length)}(len=${token.length})';
    return '${token.substring(0, 8)}...${token.substring(token.length - 6)}(len=${token.length})';
  }

  static Future<String?> getAccessToken() async {
    try {
      if (!IntercomModule.isConfigured) return null;
      final tokens = await IntercomModule.config.authPort.getTokens();
      final token = tokens?.accessToken;
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (e) {
      developer.log(
        'KeycloakService.getAccessToken error: $e',
        name: 'KeycloakService',
      );
      return null;
    }
  }

  static Future<String?> getIdToken() async {
    final tokens = await IntercomModule.config.authPort.getTokens();
    return tokens?.idToken;
  }

  static Future<String?> getRefreshToken() async {
    if (!IntercomModule.isConfigured) return null;
    final tokens = await IntercomModule.config.authPort.getTokens();
    return tokens?.refreshToken;
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return null;
      return JwtDecoder.decode(token);
    } catch (e) {
      developer.log(
        'KeycloakService.getUserData error: $e',
        name: 'KeycloakService',
      );
      return null;
    }
  }

  /// Backwards-compatible alias used by legacy screens.
  static Future<Map<String, dynamic>?> getUserInfo() => getUserData();

  static Future<bool> _performRefresh() async {
    try {
      if (!IntercomModule.isConfigured) return false;

      final port = IntercomModule.config.authPort;
      final before = await port.getTokens();
      final beforeStoredExpiry = await _storage.getRefreshExpiryMetadata();
      developer.log(
        '🔍 [Keycloak] REFRESH REQUEST: '
        'access=${_tokenPreview(before?.accessToken)} '
        'refresh=${_tokenPreview(before?.refreshToken)} '
        'refreshExpiry(stored)=${beforeStoredExpiry?.toIso8601String() ?? 'null'}',
        name: 'KeycloakService',
      );
      final result = await port.refreshSession(force: true);
      developer.log(
        '🔍 [Keycloak] REFRESH RESPONSE: '
        'refreshed=${result.refreshed} '
        'failureType=${result.failureType} '
        'message=${result.message}',
        name: 'KeycloakService',
      );
      if (result.refreshed) {
        await _storage.saveLastRefreshTime(DateTime.now());
        final refreshExpiry = result.tokens?.refreshTokenExpiry;
        final refreshExpiresInSeconds = refreshExpiry != null
            ? refreshExpiry.difference(DateTime.now()).inSeconds
            : null;
        await _storage.saveRefreshExpiryMetadata(
          refreshExpiresInSeconds:
              (refreshExpiresInSeconds != null && refreshExpiresInSeconds > 0)
              ? refreshExpiresInSeconds
              : null,
        );
        final after = await port.getTokens();
        final afterStoredExpiry = await _storage.getRefreshExpiryMetadata();
        final rotated =
            before?.refreshToken != null &&
            after?.refreshToken != null &&
            before!.refreshToken != after!.refreshToken;
        developer.log(
          '🔍 [Keycloak] REFRESH AFTER SAVE: '
          'refresh(before)=${_tokenPreview(before?.refreshToken)} '
          'refresh(after)=${_tokenPreview(after?.refreshToken)} '
          'rotated=$rotated '
          'refreshExpiry(result)=${refreshExpiry?.toIso8601String() ?? 'null'} '
          'refreshExpiry(stored)=${afterStoredExpiry?.toIso8601String() ?? 'null'}',
          name: 'KeycloakService',
        );
        return true;
      }

      final message = (result.message ?? '').toLowerCase();
      final definitive =
          result.failureType == IntercomRefreshFailureType.invalidGrant ||
          result.failureType == IntercomRefreshFailureType.unauthorized ||
          (message.contains('refresh') && message.contains('expired')) ||
          message.contains('unauthorized');
      if (definitive) {
        developer.log(
          '❌ [Keycloak] Refresh rejected by backend (terminal) - forcing logout',
          name: 'KeycloakService',
        );
        await port.onSessionExpired(
          reason: result.message ?? result.failureType.toString(),
        );
      }

      return false;
    } catch (e) {
      developer.log(
        'KeycloakService._performRefresh error: $e',
        name: 'KeycloakService',
      );
      return false;
    }
  }

  static Future<bool> refreshTokenIfNeeded() async {
    final existing = _refreshFuture;
    if (existing != null) {
      return existing;
    }

    final future = _performRefresh();
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    if (token == null) return false;

    final isExpired = () {
      try {
        return JwtDecoder.isExpired(token);
      } catch (_) {
        return false;
      }
    }();

    if (isExpired) {
      return await refreshTokenIfNeeded();
    }
    return true;
  }

  static Future<RefreshTokenValidity> getRefreshTokenValidity() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        developer.log(
          '[Keycloak] RefreshTokenValidity: missing refresh token',
          name: 'KeycloakService',
        );
        return RefreshTokenValidity.expiredOrMissing;
      }

      final storedExpiry = await _storage.getRefreshExpiryMetadata();
      if (storedExpiry != null) {
        final nowUtc = DateTime.now().toUtc();
        final expiryUtc = storedExpiry.toUtc();

        developer.log(
          '[Keycloak] RefreshTokenValidity via stored expiry: '
          'now=$nowUtc, exp=$expiryUtc',
          name: 'KeycloakService',
        );

        if (nowUtc.isBefore(expiryUtc)) {
          return RefreshTokenValidity.valid;
        }

        developer.log(
          '[Keycloak] RefreshTokenValidity: stored expiry passed -> unknown',
          name: 'KeycloakService',
        );
        return RefreshTokenValidity.unknown;
      }

      try {
        if (!JwtDecoder.isExpired(refreshToken)) {
          return RefreshTokenValidity.valid;
        }
        developer.log(
          '[Keycloak] RefreshTokenValidity: JWT exp passed -> unknown',
          name: 'KeycloakService',
        );
        return RefreshTokenValidity.unknown;
      } catch (_) {
        developer.log(
          '[Keycloak] RefreshTokenValidity: unknown (opaque/non-JWT token)',
          name: 'KeycloakService',
        );
        return RefreshTokenValidity.unknown;
      }
    } catch (e) {
      developer.log(
        '[Keycloak] Error determining refresh token validity: $e',
        name: 'KeycloakService',
      );
      return RefreshTokenValidity.unknown;
    }
  }
}
