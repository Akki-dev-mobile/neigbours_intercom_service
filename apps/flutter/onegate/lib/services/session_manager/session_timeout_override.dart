import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session timeout override system that disables idle timeouts for continuous sessions
class SessionTimeoutOverride {
  static final SessionTimeoutOverride _instance = SessionTimeoutOverride._internal();
  factory SessionTimeoutOverride() => _instance;
  SessionTimeoutOverride._internal();

  // Override state
  bool _isOverrideActive = false;
  bool _isInitialized = false;
  
  // Original timeout values (for restoration)
  Duration? _originalSessionTimeout;
  Duration? _originalIdleTimeout;
  Duration? _originalTokenRefreshInterval;
  
  // Override configuration
  static const Duration _infiniteTimeout = Duration(days: 365); // Effectively infinite
  static const Duration _continuousRefreshInterval = Duration(minutes: 2); // Frequent refresh
  
  // Storage keys
  static const String _overrideActiveKey = 'session_timeout_override_active';
  static const String _originalSessionTimeoutKey = 'original_session_timeout';
  static const String _originalIdleTimeoutKey = 'original_idle_timeout';
  static const String _originalRefreshIntervalKey = 'original_refresh_interval';

  /// Initialize session timeout override system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Session Timeout Override");
      
      // Check if override was previously active
      await _checkPreviousOverrideState();
      
      _isInitialized = true;
      log("✅ Session Timeout Override initialized");
    } catch (e) {
      log("❌ Error initializing Session Timeout Override: $e");
      rethrow;
    }
  }

  /// Check if override was previously active and restore if needed
  Future<void> _checkPreviousOverrideState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasOverrideActive = prefs.getBool(_overrideActiveKey) ?? false;
      
      if (wasOverrideActive) {
        log("🔍 Found previous timeout override state - restoring");
        await _restoreOverrideState();
      }
    } catch (e) {
      log("❌ Error checking previous override state: $e");
    }
  }

  /// Restore override state from storage
  Future<void> _restoreOverrideState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Restore original timeout values
      final originalSessionTimeout = prefs.getInt(_originalSessionTimeoutKey);
      final originalIdleTimeout = prefs.getInt(_originalIdleTimeoutKey);
      final originalRefreshInterval = prefs.getInt(_originalRefreshIntervalKey);
      
      if (originalSessionTimeout != null) {
        _originalSessionTimeout = Duration(milliseconds: originalSessionTimeout);
      }
      if (originalIdleTimeout != null) {
        _originalIdleTimeout = Duration(milliseconds: originalIdleTimeout);
      }
      if (originalRefreshInterval != null) {
        _originalTokenRefreshInterval = Duration(milliseconds: originalRefreshInterval);
      }
      
      _isOverrideActive = true;
      log("✅ Timeout override state restored");
    } catch (e) {
      log("❌ Error restoring override state: $e");
    }
  }

  /// Activate session timeout override for continuous sessions
  Future<void> activateTimeoutOverride() async {
    if (_isOverrideActive) {
      log("ℹ️ Timeout override already active");
      return;
    }

    try {
      log("⏰ Activating session timeout override");
      
      // Save current timeout values before overriding
      await _saveOriginalTimeoutValues();
      
      // Override session timeouts
      await _overrideSessionTimeouts();
      
      // Override user session manager timeouts
      await _overrideUserSessionManagerTimeouts();
      
      // Override token refresh intervals
      await _overrideTokenRefreshIntervals();
      
      // Override gate storage timeouts
      await _overrideGateStorageTimeouts();
      
      // Mark override as active
      _isOverrideActive = true;
      await _persistOverrideState();
      
      log("✅ Session timeout override activated successfully");
    } catch (e) {
      log("❌ Error activating timeout override: $e");
      rethrow;
    }
  }

  /// Save original timeout values for restoration
  Future<void> _saveOriginalTimeoutValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current timeout values from various sources
      _originalSessionTimeout = await _getCurrentSessionTimeout();
      _originalIdleTimeout = await _getCurrentIdleTimeout();
      _originalTokenRefreshInterval = await _getCurrentTokenRefreshInterval();
      
      // Save to storage
      if (_originalSessionTimeout != null) {
        await prefs.setInt(_originalSessionTimeoutKey, _originalSessionTimeout!.inMilliseconds);
      }
      if (_originalIdleTimeout != null) {
        await prefs.setInt(_originalIdleTimeoutKey, _originalIdleTimeout!.inMilliseconds);
      }
      if (_originalTokenRefreshInterval != null) {
        await prefs.setInt(_originalRefreshIntervalKey, _originalTokenRefreshInterval!.inMilliseconds);
      }
      
      log("💾 Original timeout values saved");
    } catch (e) {
      log("❌ Error saving original timeout values: $e");
    }
  }

  /// Get current session timeout from storage
  Future<Duration?> _getCurrentSessionTimeout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeoutMs = prefs.getInt('session_timeout_ms');
      return timeoutMs != null ? Duration(milliseconds: timeoutMs) : null;
    } catch (e) {
      log("❌ Error getting current session timeout: $e");
      return null;
    }
  }

  /// Get current idle timeout from storage
  Future<Duration?> _getCurrentIdleTimeout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeoutMs = prefs.getInt('idle_timeout_ms');
      return timeoutMs != null ? Duration(milliseconds: timeoutMs) : null;
    } catch (e) {
      log("❌ Error getting current idle timeout: $e");
      return null;
    }
  }

  /// Get current token refresh interval
  Future<Duration?> _getCurrentTokenRefreshInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final intervalMs = prefs.getInt('token_refresh_interval_ms');
      return intervalMs != null ? Duration(milliseconds: intervalMs) : null;
    } catch (e) {
      log("❌ Error getting current token refresh interval: $e");
      return null;
    }
  }

  /// Override session timeouts with infinite values
  Future<void> _overrideSessionTimeouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Set infinite session timeout
      await prefs.setInt('session_timeout_ms', _infiniteTimeout.inMilliseconds);
      await prefs.setBool('session_timeout_disabled', true);
      
      // Set infinite idle timeout
      await prefs.setInt('idle_timeout_ms', _infiniteTimeout.inMilliseconds);
      await prefs.setBool('idle_timeout_disabled', true);
      
      // Disable automatic logout
      await prefs.setBool('auto_logout_disabled', true);
      
      log("⏰ Session timeouts overridden with infinite values");
    } catch (e) {
      log("❌ Error overriding session timeouts: $e");
    }
  }

  /// Override user session manager timeouts
  Future<void> _overrideUserSessionManagerTimeouts() async {
    try {
      // Get user session manager instance
      final userSessionManager = UserSessionManager();
      
      // Override internal timeout mechanisms
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_session_timeout_override', true);
      await prefs.setInt('user_session_max_duration_ms', _infiniteTimeout.inMilliseconds);
      
      log("👤 User session manager timeouts overridden");
    } catch (e) {
      log("❌ Error overriding user session manager timeouts: $e");
    }
  }

  /// Override token refresh intervals for continuous operation
  Future<void> _overrideTokenRefreshIntervals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Set continuous refresh interval
      await prefs.setInt('token_refresh_interval_ms', _continuousRefreshInterval.inMilliseconds);
      await prefs.setBool('continuous_token_refresh', true);
      
      // Disable token expiration checks that might cause logout
      await prefs.setBool('token_expiration_logout_disabled', true);
      
      log("🔄 Token refresh intervals overridden for continuous operation");
    } catch (e) {
      log("❌ Error overriding token refresh intervals: $e");
    }
  }

  /// Override gate storage timeouts
  Future<void> _overrideGateStorageTimeouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Override gate storage session timeouts
      await prefs.setBool('gate_storage_timeout_override', true);
      await prefs.setInt('gate_storage_session_timeout_ms', _infiniteTimeout.inMilliseconds);
      
      // Disable token expiration checks in gate storage
      await prefs.setBool('gate_storage_token_expiration_disabled', true);
      
      log("🏪 Gate storage timeouts overridden");
    } catch (e) {
      log("❌ Error overriding gate storage timeouts: $e");
    }
  }

  /// Persist override state to storage
  Future<void> _persistOverrideState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_overrideActiveKey, _isOverrideActive);
      log("💾 Override state persisted");
    } catch (e) {
      log("❌ Error persisting override state: $e");
    }
  }

  /// Deactivate session timeout override and restore original values
  Future<void> deactivateTimeoutOverride() async {
    if (!_isOverrideActive) {
      log("ℹ️ Timeout override not active");
      return;
    }

    try {
      log("⏰ Deactivating session timeout override");
      
      // Restore original timeout values
      await _restoreOriginalTimeoutValues();
      
      // Clear override flags
      await _clearOverrideFlags();
      
      // Mark override as inactive
      _isOverrideActive = false;
      await _persistOverrideState();
      
      log("✅ Session timeout override deactivated successfully");
    } catch (e) {
      log("❌ Error deactivating timeout override: $e");
      rethrow;
    }
  }

  /// Restore original timeout values
  Future<void> _restoreOriginalTimeoutValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Restore session timeout
      if (_originalSessionTimeout != null) {
        await prefs.setInt('session_timeout_ms', _originalSessionTimeout!.inMilliseconds);
      } else {
        await prefs.remove('session_timeout_ms');
      }
      
      // Restore idle timeout
      if (_originalIdleTimeout != null) {
        await prefs.setInt('idle_timeout_ms', _originalIdleTimeout!.inMilliseconds);
      } else {
        await prefs.remove('idle_timeout_ms');
      }
      
      // Restore token refresh interval
      if (_originalTokenRefreshInterval != null) {
        await prefs.setInt('token_refresh_interval_ms', _originalTokenRefreshInterval!.inMilliseconds);
      } else {
        await prefs.remove('token_refresh_interval_ms');
      }
      
      log("🔄 Original timeout values restored");
    } catch (e) {
      log("❌ Error restoring original timeout values: $e");
    }
  }

  /// Clear all override flags
  Future<void> _clearOverrideFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear session timeout overrides
      await prefs.remove('session_timeout_disabled');
      await prefs.remove('idle_timeout_disabled');
      await prefs.remove('auto_logout_disabled');
      
      // Clear user session manager overrides
      await prefs.remove('user_session_timeout_override');
      await prefs.remove('user_session_max_duration_ms');
      
      // Clear token refresh overrides
      await prefs.remove('continuous_token_refresh');
      await prefs.remove('token_expiration_logout_disabled');
      
      // Clear gate storage overrides
      await prefs.remove('gate_storage_timeout_override');
      await prefs.remove('gate_storage_session_timeout_ms');
      await prefs.remove('gate_storage_token_expiration_disabled');
      
      log("🧹 Override flags cleared");
    } catch (e) {
      log("❌ Error clearing override flags: $e");
    }
  }

  /// Check if timeout override is currently active
  bool get isOverrideActive => _isOverrideActive;

  /// Get current timeout override status
  TimeoutOverrideStatus getOverrideStatus() {
    return TimeoutOverrideStatus(
      isActive: _isOverrideActive,
      isInitialized: _isInitialized,
      originalSessionTimeout: _originalSessionTimeout,
      originalIdleTimeout: _originalIdleTimeout,
      originalTokenRefreshInterval: _originalTokenRefreshInterval,
      currentSessionTimeout: _isOverrideActive ? _infiniteTimeout : _originalSessionTimeout,
      currentIdleTimeout: _isOverrideActive ? _infiniteTimeout : _originalIdleTimeout,
      currentTokenRefreshInterval: _isOverrideActive ? _continuousRefreshInterval : _originalTokenRefreshInterval,
    );
  }

  /// Force check and override any timeout mechanisms that might have been restored
  Future<void> enforceTimeoutOverride() async {
    if (!_isOverrideActive) return;

    try {
      log("🔒 Enforcing timeout override");
      
      // Re-apply all overrides
      await _overrideSessionTimeouts();
      await _overrideUserSessionManagerTimeouts();
      await _overrideTokenRefreshIntervals();
      await _overrideGateStorageTimeouts();
      
      log("✅ Timeout override enforced");
    } catch (e) {
      log("❌ Error enforcing timeout override: $e");
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      log("🗑️ Disposing Session Timeout Override");
      
      _isInitialized = false;
      
      log("✅ Session Timeout Override disposed");
    } catch (e) {
      log("❌ Error disposing Session Timeout Override: $e");
    }
  }
}

/// Timeout override status information
class TimeoutOverrideStatus {
  final bool isActive;
  final bool isInitialized;
  final Duration? originalSessionTimeout;
  final Duration? originalIdleTimeout;
  final Duration? originalTokenRefreshInterval;
  final Duration? currentSessionTimeout;
  final Duration? currentIdleTimeout;
  final Duration? currentTokenRefreshInterval;

  TimeoutOverrideStatus({
    required this.isActive,
    required this.isInitialized,
    this.originalSessionTimeout,
    this.originalIdleTimeout,
    this.originalTokenRefreshInterval,
    this.currentSessionTimeout,
    this.currentIdleTimeout,
    this.currentTokenRefreshInterval,
  });

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'isInitialized': isInitialized,
      'originalSessionTimeout': originalSessionTimeout?.inMinutes,
      'originalIdleTimeout': originalIdleTimeout?.inMinutes,
      'originalTokenRefreshInterval': originalTokenRefreshInterval?.inMinutes,
      'currentSessionTimeout': currentSessionTimeout?.inMinutes,
      'currentIdleTimeout': currentIdleTimeout?.inMinutes,
      'currentTokenRefreshInterval': currentTokenRefreshInterval?.inMinutes,
    };
  }
}
