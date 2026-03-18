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
        authPort: OneGateIntercomAuthPort(tokenProvider),
        contextPort: OneGateIntercomContextPort(gateStorage, tokenProvider),
        appPackageName: 'com.cubeonebiz.gate.flutter_onegate',
      ),
    );

    log('✅ IntercomModule configured for OneGate');
  }
}

class OneGateIntercomAuthPort implements IntercomAuthPort {
  final Future<String?> Function() _tokenProvider;

  OneGateIntercomAuthPort(this._tokenProvider);

  @override
  Future<IntercomAuthTokens?> getTokens() async {
    final accessToken = await _tokenProvider();
    if (accessToken == null || accessToken.isEmpty) return null;
    return IntercomAuthTokens(accessToken: accessToken);
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
