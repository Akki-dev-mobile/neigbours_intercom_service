import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'interceptors/network_logger_interceptor.dart';
import 'models/network_log.dart';
import 'services/network_log_background_service.dart';
import 'services/network_log_service.dart';
import 'services/network_log_sync_service.dart';

/// Manages network logging functionality
class NetworkLogManager {
  static final NetworkLogManager _instance = NetworkLogManager._internal();

  factory NetworkLogManager() {
    return _instance;
  }

  NetworkLogManager._internal();

  bool _initialized = false;
  final NetworkLogService _logService = NetworkLogService();
  final NetworkLogSyncService _syncService = NetworkLogSyncService();
  final NetworkLogBackgroundService _backgroundService =
      NetworkLogBackgroundService();

  /// Initialize the network log manager
  Future<void> initialize() async {
    if (_initialized || !kDebugMode) return;

    try {
      // Note: Hive is already initialized in main.dart

      // Initialize the log service
      await _logService.init();

      // Initialize the sync service
      await _syncService.initialize();

      // Initialize the background service
      await _backgroundService.initialize();

      _initialized = true;
      dev.log('NetworkLogManager initialized successfully');
    } catch (e) {
      dev.log('Error initializing NetworkLogManager: $e');
    }
  }

  /// Add the network logger interceptor to a Dio instance
  void addInterceptorToDio(Dio dio) {
    if (!kDebugMode) return;

    // Check if the interceptor is already added
    final hasInterceptor =
        dio.interceptors.any((i) => i is NetworkLoggerInterceptor);
    if (!hasInterceptor) {
      dio.interceptors.add(
        NetworkLoggerInterceptor(
          logService: _logService,
          enabled: true,
        ),
      );
    }
  }

  /// Get the network log service
  NetworkLogService get logService => _logService;

  /// Get the network log sync service
  NetworkLogSyncService get syncService => _syncService;

  /// Get the network log background service
  NetworkLogBackgroundService get backgroundService => _backgroundService;

  /// Trigger a manual sync of logs
  Future<bool> triggerManualSync() async {
    if (!kDebugMode) return false;
    return await _backgroundService.triggerManualSync();
  }

  /// Update the gate ID for network logs
  Future<void> updateGateId(String gateId) async {
    if (!kDebugMode) return;
    await _syncService.saveSettings(gateId: gateId);
  }
}
