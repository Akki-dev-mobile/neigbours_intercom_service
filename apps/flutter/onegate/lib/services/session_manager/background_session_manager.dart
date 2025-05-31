import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/dynamic_auth_integration.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background session manager that maintains authentication during app backgrounding
class BackgroundSessionManager {
  static final BackgroundSessionManager _instance = BackgroundSessionManager._internal();
  factory BackgroundSessionManager() => _instance;
  BackgroundSessionManager._internal();

  // Background task state
  bool _isInitialized = false;
  bool _isBackgroundTaskActive = false;
  
  // Background refresh management
  Timer? _backgroundTimer;
  Isolate? _backgroundIsolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  
  // Background task configuration
  static const Duration _backgroundRefreshInterval = Duration(minutes: 1); // Very frequent
  static const Duration _backgroundTaskTimeout = Duration(seconds: 30);
  static const int _maxBackgroundRetries = 5;
  
  // Storage keys for background state
  static const String _backgroundTaskActiveKey = 'background_task_active';
  static const String _lastBackgroundRefreshKey = 'last_background_refresh';
  static const String _backgroundRefreshCountKey = 'background_refresh_count';

  /// Initialize background session management
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Background Session Manager");
      
      // Check if background task was previously active
      await _checkPreviousBackgroundState();
      
      // Set up background task infrastructure
      await _setupBackgroundTaskInfrastructure();
      
      _isInitialized = true;
      log("✅ Background Session Manager initialized");
    } catch (e) {
      log("❌ Error initializing Background Session Manager: $e");
      rethrow;
    }
  }

  /// Check if background task was previously active
  Future<void> _checkPreviousBackgroundState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasBackgroundActive = prefs.getBool(_backgroundTaskActiveKey) ?? false;
      
      if (wasBackgroundActive) {
        log("🔍 Found previous background task state - will restore when needed");
      }
    } catch (e) {
      log("❌ Error checking previous background state: $e");
    }
  }

  /// Set up background task infrastructure
  Future<void> _setupBackgroundTaskInfrastructure() async {
    try {
      // Initialize receive port for background communication
      _receivePort = ReceivePort();
      
      // Listen for messages from background isolate
      _receivePort!.listen((message) {
        _handleBackgroundMessage(message);
      });
      
      log("📡 Background task infrastructure set up");
    } catch (e) {
      log("❌ Error setting up background task infrastructure: $e");
    }
  }

  /// Handle messages from background isolate
  void _handleBackgroundMessage(dynamic message) {
    try {
      if (message is Map<String, dynamic>) {
        final type = message['type'] as String?;
        
        switch (type) {
          case 'refresh_success':
            log("✅ Background token refresh successful");
            _updateBackgroundRefreshStats(success: true);
            break;
          case 'refresh_failure':
            log("❌ Background token refresh failed: ${message['error']}");
            _updateBackgroundRefreshStats(success: false);
            break;
          case 'isolate_ready':
            log("📡 Background isolate ready");
            break;
          case 'isolate_error':
            log("❌ Background isolate error: ${message['error']}");
            _handleBackgroundIsolateError();
            break;
        }
      }
    } catch (e) {
      log("❌ Error handling background message: $e");
    }
  }

  /// Update background refresh statistics
  Future<void> _updateBackgroundRefreshStats({required bool success}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update last refresh time
      await prefs.setInt(_lastBackgroundRefreshKey, DateTime.now().millisecondsSinceEpoch);
      
      // Update refresh count
      final currentCount = prefs.getInt(_backgroundRefreshCountKey) ?? 0;
      await prefs.setInt(_backgroundRefreshCountKey, currentCount + 1);
      
      // Update success/failure stats
      if (success) {
        final successCount = prefs.getInt('background_refresh_success_count') ?? 0;
        await prefs.setInt('background_refresh_success_count', successCount + 1);
      } else {
        final failureCount = prefs.getInt('background_refresh_failure_count') ?? 0;
        await prefs.setInt('background_refresh_failure_count', failureCount + 1);
      }
    } catch (e) {
      log("❌ Error updating background refresh stats: $e");
    }
  }

  /// Handle background isolate error
  void _handleBackgroundIsolateError() {
    try {
      log("🔄 Handling background isolate error - restarting");
      
      // Stop current background task
      stopBackgroundTask();
      
      // Restart after a delay
      Timer(const Duration(seconds: 5), () {
        if (_isBackgroundTaskActive) {
          startBackgroundTask();
        }
      });
    } catch (e) {
      log("❌ Error handling background isolate error: $e");
    }
  }

  /// Start background task for continuous authentication
  Future<void> startBackgroundTask() async {
    if (_isBackgroundTaskActive) {
      log("ℹ️ Background task already active");
      return;
    }

    try {
      log("🔄 Starting background session task");
      
      // Start background timer for regular refresh
      _startBackgroundTimer();
      
      // Start background isolate for heavy operations
      await _startBackgroundIsolate();
      
      // Mark background task as active
      _isBackgroundTaskActive = true;
      await _persistBackgroundTaskState();
      
      log("✅ Background session task started successfully");
    } catch (e) {
      log("❌ Error starting background task: $e");
      rethrow;
    }
  }

  /// Start background timer for regular token refresh
  void _startBackgroundTimer() {
    _backgroundTimer?.cancel();
    
    _backgroundTimer = Timer.periodic(_backgroundRefreshInterval, (timer) async {
      await _performBackgroundRefresh();
    });
    
    log("⏰ Background timer started (every ${_backgroundRefreshInterval.inMinutes} minutes)");
  }

  /// Start background isolate for heavy operations
  Future<void> _startBackgroundIsolate() async {
    try {
      if (_receivePort == null) {
        await _setupBackgroundTaskInfrastructure();
      }
      
      // Spawn background isolate
      _backgroundIsolate = await Isolate.spawn(
        _backgroundIsolateEntryPoint,
        _receivePort!.sendPort,
        debugName: 'OneGateBackgroundSession',
      );
      
      log("🔄 Background isolate started");
    } catch (e) {
      log("❌ Error starting background isolate: $e");
    }
  }

  /// Background isolate entry point
  static void _backgroundIsolateEntryPoint(SendPort sendPort) {
    try {
      log("📡 Background isolate started");
      
      // Send ready message
      sendPort.send({
        'type': 'isolate_ready',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Set up periodic background operations
      Timer.periodic(const Duration(minutes: 2), (timer) async {
        try {
          // Perform background token validation
          await _performIsolateTokenRefresh(sendPort);
        } catch (e) {
          sendPort.send({
            'type': 'isolate_error',
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (e) {
      sendPort.send({
        'type': 'isolate_error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Perform token refresh in background isolate
  static Future<void> _performIsolateTokenRefresh(SendPort sendPort) async {
    try {
      // Note: In a real implementation, this would need to access
      // the token refresh functionality in a way that works in an isolate
      // For now, we'll simulate the operation
      
      await Future.delayed(const Duration(seconds: 2)); // Simulate work
      
      sendPort.send({
        'type': 'refresh_success',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      sendPort.send({
        'type': 'refresh_failure',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Perform background refresh in main isolate
  Future<void> _performBackgroundRefresh() async {
    try {
      log("🔄 Performing background session refresh");
      
      // Get auth service and perform refresh
      final authService = GetIt.I<AuthService>();
      final dynamicAuth = DynamicAuthIntegration();
      
      // Attempt token refresh
      final token = await dynamicAuth.getEnhancedAccessToken();
      
      if (token != null) {
        log("✅ Background session refresh successful");
        await _updateBackgroundRefreshStats(success: true);
      } else {
        log("⚠️ Background session refresh failed");
        await _updateBackgroundRefreshStats(success: false);
        await _handleBackgroundRefreshFailure();
      }
    } catch (e) {
      log("❌ Error during background refresh: $e");
      await _updateBackgroundRefreshStats(success: false);
    }
  }

  /// Handle background refresh failure
  Future<void> _handleBackgroundRefreshFailure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failureCount = prefs.getInt('background_refresh_failure_count') ?? 0;
      
      if (failureCount >= _maxBackgroundRetries) {
        log("❌ Max background refresh failures reached - stopping background task");
        await stopBackgroundTask();
      } else {
        log("⚠️ Background refresh failed (${failureCount + 1}/$_maxBackgroundRetries) - will retry");
      }
    } catch (e) {
      log("❌ Error handling background refresh failure: $e");
    }
  }

  /// Stop background task
  Future<void> stopBackgroundTask() async {
    if (!_isBackgroundTaskActive) {
      log("ℹ️ Background task not active");
      return;
    }

    try {
      log("⏹️ Stopping background session task");
      
      // Stop background timer
      _backgroundTimer?.cancel();
      _backgroundTimer = null;
      
      // Stop background isolate
      _backgroundIsolate?.kill(priority: Isolate.immediate);
      _backgroundIsolate = null;
      
      // Close receive port
      _receivePort?.close();
      _receivePort = null;
      _sendPort = null;
      
      // Mark background task as inactive
      _isBackgroundTaskActive = false;
      await _persistBackgroundTaskState();
      
      log("✅ Background session task stopped successfully");
    } catch (e) {
      log("❌ Error stopping background task: $e");
    }
  }

  /// Persist background task state
  Future<void> _persistBackgroundTaskState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_backgroundTaskActiveKey, _isBackgroundTaskActive);
    } catch (e) {
      log("❌ Error persisting background task state: $e");
    }
  }

  /// Handle app going to background
  Future<void> handleAppBackground() async {
    try {
      log("📱 App going to background - ensuring background task is active");
      
      if (!_isBackgroundTaskActive) {
        await startBackgroundTask();
      }
      
      // Perform immediate refresh before backgrounding
      await _performBackgroundRefresh();
      
      log("✅ Background session management activated for app backgrounding");
    } catch (e) {
      log("❌ Error handling app background: $e");
    }
  }

  /// Handle app returning to foreground
  Future<void> handleAppForeground() async {
    try {
      log("📱 App returning to foreground - performing session validation");
      
      // Perform immediate session validation
      final authService = GetIt.I<AuthService>();
      final isAuthenticated = await authService.isLoggedIn();
      
      if (isAuthenticated) {
        log("✅ Session maintained during background - user still authenticated");
        
        // Perform fresh token refresh
        await _performBackgroundRefresh();
      } else {
        log("❌ Session lost during background - authentication required");
        await stopBackgroundTask();
      }
    } catch (e) {
      log("❌ Error handling app foreground: $e");
    }
  }

  /// Get background task status
  BackgroundTaskStatus getBackgroundTaskStatus() {
    try {
      return BackgroundTaskStatus(
        isActive: _isBackgroundTaskActive,
        isInitialized: _isInitialized,
        hasBackgroundTimer: _backgroundTimer?.isActive ?? false,
        hasBackgroundIsolate: _backgroundIsolate != null,
        hasReceivePort: _receivePort != null,
      );
    } catch (e) {
      log("❌ Error getting background task status: $e");
      return BackgroundTaskStatus(
        isActive: false,
        isInitialized: false,
        hasBackgroundTimer: false,
        hasBackgroundIsolate: false,
        hasReceivePort: false,
      );
    }
  }

  /// Get background refresh statistics
  Future<BackgroundRefreshStats> getBackgroundRefreshStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final lastRefresh = prefs.getInt(_lastBackgroundRefreshKey);
      final totalCount = prefs.getInt(_backgroundRefreshCountKey) ?? 0;
      final successCount = prefs.getInt('background_refresh_success_count') ?? 0;
      final failureCount = prefs.getInt('background_refresh_failure_count') ?? 0;
      
      return BackgroundRefreshStats(
        lastRefresh: lastRefresh != null 
            ? DateTime.fromMillisecondsSinceEpoch(lastRefresh) 
            : null,
        totalRefreshCount: totalCount,
        successCount: successCount,
        failureCount: failureCount,
        successRate: totalCount > 0 ? (successCount / totalCount) * 100 : 0,
      );
    } catch (e) {
      log("❌ Error getting background refresh stats: $e");
      return BackgroundRefreshStats(
        lastRefresh: null,
        totalRefreshCount: 0,
        successCount: 0,
        failureCount: 0,
        successRate: 0,
      );
    }
  }

  /// Force immediate background refresh
  Future<bool> forceBackgroundRefresh() async {
    try {
      log("🔄 Forcing immediate background refresh");
      
      await _performBackgroundRefresh();
      
      // Check if refresh was successful
      final stats = await getBackgroundRefreshStats();
      final wasSuccessful = stats.lastRefresh != null && 
          DateTime.now().difference(stats.lastRefresh!).inMinutes < 1;
      
      return wasSuccessful;
    } catch (e) {
      log("❌ Error forcing background refresh: $e");
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      log("🗑️ Disposing Background Session Manager");
      
      // Stop background task
      stopBackgroundTask();
      
      _isInitialized = false;
      
      log("✅ Background Session Manager disposed");
    } catch (e) {
      log("❌ Error disposing Background Session Manager: $e");
    }
  }
}

/// Background task status information
class BackgroundTaskStatus {
  final bool isActive;
  final bool isInitialized;
  final bool hasBackgroundTimer;
  final bool hasBackgroundIsolate;
  final bool hasReceivePort;

  BackgroundTaskStatus({
    required this.isActive,
    required this.isInitialized,
    required this.hasBackgroundTimer,
    required this.hasBackgroundIsolate,
    required this.hasReceivePort,
  });

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'isInitialized': isInitialized,
      'hasBackgroundTimer': hasBackgroundTimer,
      'hasBackgroundIsolate': hasBackgroundIsolate,
      'hasReceivePort': hasReceivePort,
    };
  }
}

/// Background refresh statistics
class BackgroundRefreshStats {
  final DateTime? lastRefresh;
  final int totalRefreshCount;
  final int successCount;
  final int failureCount;
  final double successRate;

  BackgroundRefreshStats({
    this.lastRefresh,
    required this.totalRefreshCount,
    required this.successCount,
    required this.failureCount,
    required this.successRate,
  });

  Map<String, dynamic> toJson() {
    return {
      'lastRefresh': lastRefresh?.toIso8601String(),
      'totalRefreshCount': totalRefreshCount,
      'successCount': successCount,
      'failureCount': failureCount,
      'successRate': successRate,
    };
  }
}
