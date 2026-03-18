import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/intercom/onegate_intercom_bootstrap.dart';
import 'package:intercom_module/intercom_module.dart';

class IntercomServicesLauncher {
  static Future<void> open(BuildContext context) async {
    try {
      final tokenManager = EnhancedTokenRefreshManager();
      final gateStorage = GateStorage();

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

      await OneGateIntercomBootstrap.ensureConfigured();

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
