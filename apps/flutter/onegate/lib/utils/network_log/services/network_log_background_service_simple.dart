import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network_log_sync_service.dart';

/// A simplified service for managing background sync of network logs
/// This implementation uses a simple Timer instead of WorkManager or AlarmManager
class NetworkLogBackgroundService {
  static const String _backgroundSyncEnabledKey = 'network_log_background_sync_enabled';
  static const Duration _syncInterval = Duration(minutes: 2);
  
  // Singleton instance
  static final NetworkLogBackgroundService _instance = NetworkLogBackgroundService._internal();
  
  factory NetworkLogBackgroundService() {
    return _instance;
  }
  
  NetworkLogBackgroundService._internal();
  
  bool _backgroundSyncEnabled = true;
  Timer? _syncTimer;
  
  /// Initialize the background service
  Future<void> initialize() async {
    if (!kDebugMode) return;
    
    try {
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
      // Cancel any existing timer first
      stopBackgroundSync();
      
      // Schedule a periodic task
      _syncTimer = Timer.periodic(_syncInterval, (_) => _syncCallback());
      
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
      _syncTimer?.cancel();
      _syncTimer = null;
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
  
  /// Callback for background sync
  Future<void> _syncCallback() async {
    try {
      // Initialize sync service
      final syncService = NetworkLogSyncService();
      await syncService.initialize();
      
      // Sync logs
      final success = await syncService.syncLogs();
      
      dev.log('Background sync ${success ? 'completed successfully' : 'failed'}');
    } catch (e) {
      dev.log('Error in background sync: $e');
    }
  }
}
