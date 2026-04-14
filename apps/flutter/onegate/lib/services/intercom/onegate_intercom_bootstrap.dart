import 'dart:developer';

import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:intercom_module/intercom_module.dart';

/// App-wide bootstrap for IntercomModule (OneGate).
class OneGateIntercomBootstrap {
  static final EnhancedTokenRefreshManager _tokenManager =
      EnhancedTokenRefreshManager();

  static Future<void> ensureConfigured() async {
    if (IntercomModule.isConfigured) return;

    final gateStorage = GateStorage();
    await _tokenManager.initialize(gateStorage);

    Future<String?> tokenProvider() async =>
        await _tokenManager.getValidAccessToken() ??
        await gateStorage.getAccessToken();

    IntercomModule.configure(
      IntercomModuleConfig.cubeOne(
        authPort: OneGateIntercomAuthPort(
          tokenProvider: tokenProvider,
          tokenManager: _tokenManager,
          gateStorage: gateStorage,
        ),
        contextPort: OneGateIntercomContextPort(gateStorage, tokenProvider),
        appPackageName: 'com.cubeonebiz.gate.flutter_onegate',
      ),
    );

    log('✅ IntercomModule configured for OneGate');
  }
}

class OneGateIntercomAuthPort implements IntercomAuthPort {
  final Future<String?> Function() _tokenProvider;
  final EnhancedTokenRefreshManager _tokenManager;
  final GateStorage _gateStorage;

  OneGateIntercomAuthPort({
    required Future<String?> Function() tokenProvider,
    required EnhancedTokenRefreshManager tokenManager,
    required GateStorage gateStorage,
  })  : _tokenProvider = tokenProvider,
        _tokenManager = tokenManager,
        _gateStorage = gateStorage;

  String _tokenPreview(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 14)
      return '${token.substring(0, token.length)}(len=${token.length})';
    return '${token.substring(0, 8)}...${token.substring(token.length - 6)}(len=${token.length})';
  }

  @override
  Future<IntercomAuthTokens?> getTokens() async {
    final accessToken = await _tokenProvider();
    final refreshToken = await _gateStorage.getRefreshToken();
    final accessExpiry = accessToken != null && accessToken.isNotEmpty
        ? JwtTokenUtility.getTokenExpirationTime(accessToken)
        : null;
    final refreshExpiry = refreshToken != null && refreshToken.isNotEmpty
        ? JwtTokenUtility.getTokenExpirationTime(refreshToken)
        : null;
    log(
      '🔍 [IntercomAuthPort] getTokens access=${_tokenPreview(accessToken)} '
      'refresh=${_tokenPreview(refreshToken)} '
      'accessExp=${accessExpiry?.toIso8601String() ?? 'unknown'} '
      'refreshExp=${refreshExpiry?.toIso8601String() ?? 'unknown'}',
    );
    if (accessToken == null || accessToken.isEmpty) return null;
    return IntercomAuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiry: accessExpiry,
      refreshTokenExpiry: refreshExpiry,
    );
  }

  @override
  Future<IntercomTokenRefreshResult> refreshSession(
      {bool force = false}) async {
    log('🔁 [IntercomAuthPort] refreshSession requested (force=$force)');
    final beforeRefresh = await _gateStorage.getRefreshToken();
    log(
      '🔍 [IntercomAuthPort] backend refresh started '
      'refresh(before)=${_tokenPreview(beforeRefresh)}',
    );

    String _failureMessage({
      required String base,
      Map<String, dynamic>? stats,
      Object? error,
    }) {
      final failureType = stats?['lastFailureType'];
      final failures = stats?['consecutiveFailures'];
      return '$base; failureType=$failureType; consecutiveFailures=$failures; error=$error';
    }

    IntercomRefreshFailureType _mapFailureType(Map<String, dynamic>? stats) {
      final raw = (stats?['lastFailureType'] ?? '').toString();
      switch (raw) {
        case 'RefreshTokenFailureType.refreshTokenRevoked':
          return IntercomRefreshFailureType.unauthorized;
        case 'RefreshTokenFailureType.refreshTokenExpired':
        case 'RefreshTokenFailureType.refreshTokenInvalid':
        case 'RefreshTokenFailureType.missingRefreshToken':
          return IntercomRefreshFailureType.invalidGrant;
        case 'RefreshTokenFailureType.networkTimeout':
        case 'RefreshTokenFailureType.networkUnavailable':
        case 'RefreshTokenFailureType.connectionError':
        case 'RefreshTokenFailureType.serverError':
        case 'RefreshTokenFailureType.serviceUnavailable':
        case 'RefreshTokenFailureType.storageError':
          return IntercomRefreshFailureType.temporary;
        default:
          return IntercomRefreshFailureType.unknown;
      }
    }

    log(
      '🔄 [IntercomAuthPort] invoking OneGate backend refresh path '
      '(EnhancedTokenRefreshManager.refreshTokenIfNeeded)',
    );
    try {
      final refreshed = await _tokenManager.refreshTokenIfNeeded();
      final afterRefresh = await _gateStorage.getRefreshToken();
      final rotated = beforeRefresh != null &&
          afterRefresh != null &&
          beforeRefresh != afterRefresh;

      if (refreshed) {
        log(
          '✅ [IntercomAuthPort] backend refresh success; '
          'refreshRotated=$rotated '
          'before=${_tokenPreview(beforeRefresh)} '
          'after=${_tokenPreview(afterRefresh)}',
        );

        final tokens = await getTokens();
        log(
          '🔍 [IntercomAuthPort] tokens visible through getTokens after refresh: '
          'access=${_tokenPreview(tokens?.accessToken)} '
          'refresh=${_tokenPreview(tokens?.refreshToken)}',
        );
        if (tokens != null) {
          return IntercomTokenRefreshResult.success(tokens: tokens);
        }
        return IntercomTokenRefreshResult.failure(
          failureType: IntercomRefreshFailureType.unknown,
          message: 'refresh succeeded but no access token available',
        );
      }

      final stats = _tokenManager.getRefreshFailureStatistics();
      final mapped = _mapFailureType(stats);
      final message = _failureMessage(
        base: 'backend refresh failed',
        stats: stats,
      );
      log('❌ [IntercomAuthPort] backend refresh failure; $message');
      return IntercomTokenRefreshResult.failure(
        failureType: mapped,
        message: message,
      );
    } catch (e) {
      final stats = _tokenManager.getRefreshFailureStatistics();
      final mapped = _mapFailureType(stats);
      final message = _failureMessage(
        base: 'backend refresh threw exception',
        stats: stats,
        error: e,
      );
      log('❌ [IntercomAuthPort] backend refresh exception; $message');
      return IntercomTokenRefreshResult.failure(
        failureType: mapped,
        message: message,
      );
    }
  }

  @override
  Future<void> onSessionExpired({String? reason}) async {
    log(
      '🚪 [IntercomAuthPort] onSessionExpired invoked; '
      'reason=${reason ?? 'unknown'}',
    );

    try {
      await _tokenManager.clearTokens();
      await _gateStorage.clearTokens();
      log('✅ [IntercomAuthPort] local auth state cleared after session expiry');
    } catch (e) {
      log('❌ [IntercomAuthPort] failed to clear auth state on expiry: $e');
    }
  }
}

class OneGateIntercomContextPort implements IntercomContextPort {
  final GateStorage _gateStorage;
  final Future<String?> Function() _tokenProvider;

  OneGateIntercomContextPort(this._gateStorage, this._tokenProvider);

  @override
  Future<int?> getSelectedSocietyId() async {
    final societyId = await _gateStorage.getSocietyId();
    if (societyId == null || societyId.isEmpty) return null;
    return int.tryParse(societyId);
  }

  @override
  Future<String?> getCurrentUserUuid() async {
    final accessToken = await _tokenProvider();
    if (accessToken == null || accessToken.isEmpty) return null;

    final payload = JwtTokenUtility.parseJwtToken(accessToken);
    final sub = payload?['sub'];
    if (sub is String && sub.trim().isNotEmpty) return sub.trim();
    return null;
  }

  @override
  Future<int?> getCurrentUserNumericId() async {
    final accessToken = await _tokenProvider();
    if (accessToken != null && accessToken.isNotEmpty) {
      final payload = JwtTokenUtility.parseJwtToken(accessToken);

      // Priority: old_gate_user_id > old_sso_user_id > user_id
      final dynamic raw = payload?['old_gate_user_id'] ??
          payload?['old_sso_user_id'] ??
          payload?['user_id'];

      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw);
      if (raw is double) return raw.toInt();
    }

    final storedUserId = await _gateStorage.getUserId();
    if (storedUserId == null || storedUserId.isEmpty) return null;
    return int.tryParse(storedUserId);
  }
}
