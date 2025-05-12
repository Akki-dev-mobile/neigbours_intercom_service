import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/network_log.dart';

class NetworkLogService {
  static const String _boxName = 'network_logs';
  late Box<NetworkLog> _logsBox;
  final ValueNotifier<List<NetworkLog>> logs =
      ValueNotifier<List<NetworkLog>>([]);

  // Maximum number of logs to keep
  static const int _maxLogs = 100;

  // Singleton instance
  static final NetworkLogService _instance = NetworkLogService._internal();

  factory NetworkLogService() {
    return _instance;
  }

  NetworkLogService._internal();

  Future<void> init() async {
    if (!kDebugMode) return;

    try {
      // Register the adapter if not already registered
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(NetworkLogAdapter());
      }

      // Open the box
      _logsBox = await Hive.openBox<NetworkLog>(_boxName);

      // Load existing logs
      _loadLogs();

      dev.log('NetworkLogService initialized successfully');
    } catch (e) {
      dev.log('Error initializing NetworkLogService: $e');
    }
  }

  void _loadLogs() {
    if (!kDebugMode) return;

    try {
      final loadedLogs = _logsBox.values.toList();
      loadedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      logs.value = loadedLogs;
    } catch (e) {
      dev.log('Error loading logs: $e');
    }
  }

  Future<void> addLog(NetworkLog log) async {
    if (!kDebugMode) return;

    try {
      await _logsBox.put(log.id, log);

      // Update the value notifier
      final updatedLogs = [...logs.value];
      updatedLogs.insert(0, log);
      logs.value = updatedLogs;

      // Trim logs if needed
      _trimLogs();
    } catch (e) {
      dev.log('Error adding log: $e');
    }
  }

  Future<void> updateLog(NetworkLog log) async {
    if (!kDebugMode) return;

    try {
      await _logsBox.put(log.id, log);

      // Update the value notifier
      final index = logs.value.indexWhere((l) => l.id == log.id);
      if (index != -1) {
        final updatedLogs = [...logs.value];
        updatedLogs[index] = log;
        logs.value = updatedLogs;
      }
    } catch (e) {
      dev.log('Error updating log: $e');
    }
  }

  NetworkLog? getLogById(String id) {
    if (!kDebugMode) return null;

    try {
      return _logsBox.get(id);
    } catch (e) {
      dev.log('Error getting log by ID: $e');
      return null;
    }
  }

  Future<void> clearLogs() async {
    if (!kDebugMode) return;

    try {
      await _logsBox.clear();
      logs.value = [];
    } catch (e) {
      dev.log('Error clearing logs: $e');
    }
  }

  void _trimLogs() {
    if (_logsBox.length > _maxLogs) {
      final allLogs = _logsBox.values.toList();
      allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final logsToDelete = allLogs.sublist(_maxLogs);
      for (final log in logsToDelete) {
        _logsBox.delete(log.id);
      }

      logs.value = allLogs.sublist(0, _maxLogs);
    }
  }

  List<NetworkLog> getFilteredLogs({
    String? method,
    int? statusCode,
    bool? hasError,
  }) {
    if (!kDebugMode) return [];

    return logs.value.where((log) {
      bool matchesMethod = method == null || log.method == method;
      bool matchesStatusCode =
          statusCode == null || log.statusCode == statusCode;
      bool matchesError = hasError == null ||
          (hasError && log.error != null) ||
          (!hasError && log.error == null);

      return matchesMethod && matchesStatusCode && matchesError;
    }).toList();
  }
}

// Note: We're using the generated NetworkLogAdapter from network_log.g.dart
