import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'network_log_sync_service.dart';

/// Service for managing background sync of network logs using WorkManager
class NetworkLogBackgroundService {
  static const String _backgroundSyncEnabledKey = 'network_log_background_sync_enabled';
  static const String _syncTaskName = 'networkLogSync';
  static const String _syncTaskUniqueName = 'com.futurescape.onegate.networkLogSync';
  
  // Singleton instance
  static final NetworkLogBackgroundService _instance = NetworkLogBackgroundService._internal();
  
  factory NetworkLogBackgroundService() {
    return _instance;
  }
  
  NetworkLogBackgroundService._internal();
  
  bool _backgroundSyncEnabled = true;
  
  /// Initialize the background service
  Future<void> initialize() async {
    if (!kDebugMode) return;
    
    try {
      // Initialize Workmanager
      Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      
      // Load settings
      await _loadSettings();
      
      // Start background sync if enabled
      if (_backgroundSyncEnabled) {
        await startBackgroundSync();
      }
      
      dev.log('NetworkLogBackgroundService initialized');
    } catch (e) {
      dev.log('Error initializing NetworkLogBackgroundService: $e');
    }
  }
  
  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundSyncEnabled = prefs.getBool(_backgroundSyncEnabledKey) ?? true;
  }
  
  /// Save settings to SharedPreferences
  Future<void> saveSettings({bool? backgroundSyncEnabled}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (backgroundSyncEnabled != null) {
      await prefs.setBool(_backgroundSyncEnabledKey, backgroundSyncEnabled);
      _backgroundSyncEnabled = backgroundSyncEnabled;
      
      // Update background sync based on new setting
      if (_backgroundSyncEnabled) {
        await startBackgroundSync();
      } else {
        await stopBackgroundSync();
      }
    }
  }
  
  /// Check if background sync is enabled
  bool get backgroundSyncEnabled => _backgroundSyncEnabled;
  
  /// Start background sync
  Future<bool> startBackgroundSync() async {
    if (!kDebugMode) return false;
    
    try {
      // Cancel any existing tasks first
      await Workmanager().cancelByUniqueName(_syncTaskUniqueName);
      
      // Schedule a periodic task
      Workmanager().registerPeriodicTask(
        _syncTaskUniqueName,
        _syncTaskName,
        frequency: const Duration(minutes: 15), // Minimum allowed is 15 minutes
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      
      dev.log('Background sync scheduled successfully');
      return true;
    } catch (e) {
      dev.log('Error starting background sync: $e');
      return false;
    }
  }
  
  /// Stop background sync
  Future<bool> stopBackgroundSync() async {
    if (!kDebugMode) return false;
    
    try {
      await Workmanager().cancelByUniqueName(_syncTaskUniqueName);
      dev.log('Background sync stopped successfully');
      return true;
    } catch (e) {
      dev.log('Error stopping background sync: $e');
      return false;
    }
  }
  
  /// Trigger a manual sync
  Future<bool> triggerManualSync() async {
    if (!kDebugMode) return false;
    
    try {
      final syncService = NetworkLogSyncService();
      return await syncService.syncLogs();
    } catch (e) {
      dev.log('Error triggering manual sync: $e');
      return false;
    }
  }
}

/// The callback dispatcher for Workmanager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == NetworkLogBackgroundService._syncTaskName) {
        // Initialize sync service
        final syncService = NetworkLogSyncService();
        await syncService.initialize();
        
        // Sync logs
        final success = await syncService.syncLogs();
        
        dev.log('Background sync ${success ? 'completed successfully' : 'failed'}');
        return success;
      }
      return false;
    } catch (e) {
      dev.log('Error in background sync: $e');
      return false;
    }
  });
}
