import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/network_log.dart';
import 'network_log_service.dart';

/// Service for syncing network logs to a remote server
class NetworkLogSyncService {
  static const String _gateIdKey = 'network_log_gate_id';
  static const String _syncEnabledKey = 'network_log_sync_enabled';
  static const String _serverUrlKey = 'network_log_server_url';
  static const int _maxLogsPerBatch = 100;

  final NetworkLogService _logService;
  final Dio _dio = Dio();

  String _gateId = 'UNKNOWN_GATE';
  String _environment = 'dev';
  String _serverUrl = 'http://localhost:3000/logs';
  bool _syncEnabled = true;

  // Singleton instance
  static final NetworkLogSyncService _instance =
      NetworkLogSyncService._internal();

  factory NetworkLogSyncService() {
    return _instance;
  }

  NetworkLogSyncService._internal() : _logService = NetworkLogService();

  /// Initialize the sync service
  Future<void> initialize() async {
    if (!kDebugMode) return;

    try {
      await _loadSettings();
      dev.log(
          'NetworkLogSyncService initialized with gateId: $_gateId, environment: $_environment');
    } catch (e) {
      dev.log('Error initializing NetworkLogSyncService: $e');
    }
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _gateId = prefs.getString(_gateIdKey) ?? 'UNKNOWN_GATE';
    _syncEnabled = prefs.getBool(_syncEnabledKey) ?? true;
    _serverUrl = prefs.getString(_serverUrlKey) ?? 'http://localhost:3000/logs';

    // Determine environment based on server URL or other factors
    if (_serverUrl.contains('dev')) {
      _environment = 'dev';
    } else if (_serverUrl.contains('staging')) {
      _environment = 'staging';
    } else if (_serverUrl.contains('prod')) {
      _environment = 'prod';
    }
  }

  /// Save settings to SharedPreferences
  Future<void> saveSettings(
      {String? gateId, bool? syncEnabled, String? serverUrl}) async {
    final prefs = await SharedPreferences.getInstance();

    if (gateId != null) {
      await prefs.setString(_gateIdKey, gateId);
      _gateId = gateId;
    }

    if (syncEnabled != null) {
      await prefs.setBool(_syncEnabledKey, syncEnabled);
      _syncEnabled = syncEnabled;
    }

    if (serverUrl != null) {
      await prefs.setString(_serverUrlKey, serverUrl);
      _serverUrl = serverUrl;

      // Update environment based on new server URL
      if (_serverUrl.contains('dev')) {
        _environment = 'dev';
      } else if (_serverUrl.contains('staging')) {
        _environment = 'staging';
      } else if (_serverUrl.contains('prod')) {
        _environment = 'prod';
      }
    }
  }

  /// Get the current gate ID
  String get gateId => _gateId;

  /// Get the current environment
  String get environment => _environment;

  /// Get the current server URL
  String get serverUrl => _serverUrl;

  /// Check if sync is enabled
  bool get syncEnabled => _syncEnabled;

  /// Sync logs to the server
  Future<bool> syncLogs() async {
    if (!kDebugMode || !_syncEnabled) return false;

    try {
      // Get all unsynced logs
      final unsynced = await getUnsyncedLogs();

      if (unsynced.isEmpty) {
        dev.log('No unsynced logs to sync');
        return true;
      }

      dev.log('Syncing ${unsynced.length} logs to server');

      // Process logs in batches to avoid sending too much data at once
      for (var i = 0; i < unsynced.length; i += _maxLogsPerBatch) {
        final end = (i + _maxLogsPerBatch < unsynced.length)
            ? i + _maxLogsPerBatch
            : unsynced.length;
        final batch = unsynced.sublist(i, end);

        final success = await _sendLogsToServer(batch);
        if (success) {
          // Mark logs as synced
          for (final log in batch) {
            await _logService.updateLog(log.markAsSynced());
          }
        } else {
          // If one batch fails, stop processing
          return false;
        }
      }

      return true;
    } catch (e) {
      dev.log('Error syncing logs: $e');
      return false;
    }
  }

  /// Get all unsynced logs
  Future<List<NetworkLog>> getUnsyncedLogs() async {
    if (!kDebugMode) return [];

    final allLogs = _logService.logs.value;
    return allLogs.where((log) => !log.synced).toList();
  }

  /// Send logs to the server
  Future<bool> _sendLogsToServer(List<NetworkLog> logs) async {
    try {
      // Convert logs to JSON
      final logsJson = logs
          .map((log) => {
                'id': log.id,
                'url': log.url,
                'method': log.method,
                'headers': log.headers,
                'requestBody': log.requestBody,
                'statusCode': log.statusCode,
                'responseBody': log.responseBody,
                'timestamp': log.timestamp.toIso8601String(),
                'duration': log.duration,
                'gateId': log.gateId.isNotEmpty ? log.gateId : _gateId,
                'environment':
                    log.environment.isNotEmpty ? log.environment : _environment,
                'error': log.error,
              })
          .toList();

      // Send logs to server
      final response = await _dio.post(
        _serverUrl,
        data: jsonEncode({'logs': logsJson}),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: 10000,
          receiveTimeout: 10000,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dev.log('Successfully synced ${logs.length} logs to server');
        return true;
      } else {
        dev.log(
            'Failed to sync logs: ${response.statusCode} - ${response.data}');
        return false;
      }
    } catch (e) {
      dev.log('Error sending logs to server: $e');
      return false;
    }
  }
}
