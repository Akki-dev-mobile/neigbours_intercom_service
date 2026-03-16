import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:intercom_module/intercom_module.dart';

class IntercomServicesLauncher {
  static Future<void> open(BuildContext context) async {
    try {
      final gateStorage = GateStorage();
      final tokenManager = EnhancedTokenRefreshManager();

      // Prefer the refreshed/valid token from secure storage (used elsewhere in the app).
      // Fall back to GateStorage (shared prefs) only if needed.
      final accessToken = await tokenManager.getValidAccessToken() ??
          await gateStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open Intercom: missing token'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Future<String?> tokenProvider() async =>
          await tokenManager.getValidAccessToken() ??
          await gateStorage.getAccessToken();

      IntercomModule.configure(
        IntercomModuleConfig.cubeOne(
          authPort: _OneGateIntercomAuthPort(tokenProvider),
          contextPort: _OneGateIntercomContextPort(gateStorage, tokenProvider),
        ),
      );

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const IntercomScreen(fromNeighborsCard: true),
        ),
      );
    } catch (e, st) {
      log('Failed to open Intercom', error: e, stackTrace: st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open Intercom: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _OneGateIntercomAuthPort implements IntercomAuthPort {
  final Future<String?> Function() _tokenProvider;

  _OneGateIntercomAuthPort(this._tokenProvider);

  @override
  Future<IntercomAuthTokens?> getTokens() async {
    final accessToken = await _tokenProvider();
    if (accessToken == null || accessToken.isEmpty) return null;
    return IntercomAuthTokens(accessToken: accessToken);
  }
}

class _OneGateIntercomContextPort implements IntercomContextPort {
  final GateStorage _gateStorage;
  final Future<String?> Function() _tokenProvider;

  _OneGateIntercomContextPort(this._gateStorage, this._tokenProvider);

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

      // Align with meet/chat services expectations:
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
