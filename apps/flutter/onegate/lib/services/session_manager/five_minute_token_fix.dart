import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/session_manager/continuous_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/session_timeout_override.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive fix for 5-minute token session management
/// This class ensures all session management components work together
/// to prevent automatic logout on 5-minute token expiry
class FiveMinuteTokenFix {
  static final FiveMinuteTokenFix _instance = FiveMinuteTokenFix._internal();
  factory FiveMinuteTokenFix() => _instance;
  FiveMinuteTokenFix._internal();

  bool _isInitialized = false;
  Timer? _healthCheckTimer;

  /// Initialize the comprehensive fix for 5-minute tokens
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🔧 Initializing 5-minute token session management fix");

      // Step 1: Activate session timeout overrides
      await _activateSessionTimeoutOverrides();

      // Step 2: Configure enhanced token refresh for short tokens
      await _configureEnhancedTokenRefresh();

      // Step 3: Set up continuous session management
      await _setupContinuousSessionManagement();

      // Step 4: Configure user session manager for short tokens
      await _configureUserSessionManager();

      // Step 5: Start health monitoring
      _startHealthMonitoring();

      _isInitialized = true;
      log("✅ 5-minute token session management fix initialized successfully");
    } catch (e) {
      log("❌ Error initializing 5-minute token fix: $e");
      rethrow;
    }
  }

  /// Activate session timeout overrides to prevent automatic logout
  Future<void> _activateSessionTimeoutOverrides() async {
    try {
      log("⏰ Activating session timeout overrides for 5-minute tokens");

      final timeoutOverride = SessionTimeoutOverride();
      await timeoutOverride.initialize();
      await timeoutOverride.activateTimeoutOverride();

      // Additional overrides specific to 5-minute tokens
      final prefs = await SharedPreferences.getInstance();
      
      // Disable all automatic logout mechanisms
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      
      // Set aggressive refresh intervals for short tokens
      await prefs.setInt('short_token_refresh_interval_ms', Duration(seconds: 30).inMilliseconds);
      await prefs.setBool('aggressive_refresh_enabled', true);

      log("✅ Session timeout overrides activated");
    } catch (e) {
      log("❌ Error activating session timeout overrides: $e");
      rethrow;
    }
  }

  /// Configure enhanced token refresh manager for 5-minute tokens
  Future<void> _configureEnhancedTokenRefresh() async {
    try {
      log("🔄 Configuring enhanced token refresh for 5-minute tokens");

      final prefs = await SharedPreferences.getInstance();
      
      // Set aggressive refresh settings for short-lived tokens
      await prefs.setInt('enhanced_refresh_check_interval_ms', Duration(seconds: 15).inMilliseconds);
      await prefs.setBool('immediate_refresh_on_expiry', true);
      await prefs.setInt('short_token_buffer_seconds', 120); // 2-minute buffer for 5-minute tokens
      
      // Enable continuous refresh mode
      await prefs.setBool('continuous_refresh_mode', true);
      await prefs.setInt('continuous_refresh_interval_ms', Duration(minutes: 1).inMilliseconds);

      log("✅ Enhanced token refresh configured for short tokens");
    } catch (e) {
      log("❌ Error configuring enhanced token refresh: $e");
      rethrow;
    }
  }

  /// Set up continuous session management
  Future<void> _setupContinuousSessionManagement() async {
    try {
      log("🔄 Setting up continuous session management");

      final continuousSession = ContinuousSessionManager();
      await continuousSession.initialize();
      await continuousSession.activateContinuousSession();

      // Configure for 5-minute tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('continuous_session_short_token_mode', true);
      await prefs.setInt('background_refresh_interval_ms', Duration(minutes: 1).inMilliseconds);

      log("✅ Continuous session management configured");
    } catch (e) {
      log("❌ Error setting up continuous session management: $e");
      rethrow;
    }
  }

  /// Configure user session manager for short tokens
  Future<void> _configureUserSessionManager() async {
    try {
      log("👤 Configuring user session manager for 5-minute tokens");

      final userSessionManager = UserSessionManager();
      await userSessionManager.initialize();

      // Override session manager settings for short tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_session_check_interval_ms', Duration(seconds: 30).inMilliseconds);
      await prefs.setBool('user_session_aggressive_refresh', true);

      log("✅ User session manager configured for short tokens");
    } catch (e) {
      log("❌ Error configuring user session manager: $e");
      rethrow;
    }
  }

  /// Start health monitoring to ensure all components are working
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
      await _performHealthCheck();
    });
    log("🏥 Health monitoring started for 5-minute token fix");
  }

  /// Perform comprehensive health check
  Future<void> _performHealthCheck() async {
    try {
      log("🔍 Performing 5-minute token session health check");

      final prefs = await SharedPreferences.getInstance();
      
      // Check if overrides are still active
      final timeoutDisabled = prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      
      if (!timeoutDisabled || !autoLogoutDisabled) {
        log("⚠️ Session overrides not active, reactivating...");
        await _activateSessionTimeoutOverrides();
      }

      // Check token status
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      
      if (accessToken != null) {
        final isExpired = await gateStorage.isTokenExpired();
        if (isExpired) {
          log("🔄 Token expired during health check, triggering refresh");
          final authService = GetIt.I<AuthService>();
          await authService.refreshToken();
        }
      }

      log("✅ Health check completed");
    } catch (e) {
      log("❌ Error during health check: $e");
    }
  }

  /// Force immediate token refresh if needed
  Future<bool> forceTokenRefreshIfNeeded() async {
    try {
      log("🔄 Forcing token refresh check for 5-minute tokens");

      final gateStorage = GetIt.I<GateStorage>();
      final isExpired = await gateStorage.isTokenExpired();
      
      if (isExpired) {
        log("🔄 Token expired, forcing immediate refresh");
        final authService = GetIt.I<AuthService>();
        final refreshed = await authService.refreshToken();
        
        if (refreshed) {
          log("✅ Force refresh successful");
          return true;
        } else {
          log("❌ Force refresh failed");
          return false;
        }
      }
      
      log("ℹ️ Token not expired, no refresh needed");
      return true;
    } catch (e) {
      log("❌ Error during force refresh: $e");
      return false;
    }
  }

  /// Get current session status for debugging
  Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gateStorage = GetIt.I<GateStorage>();
      
      final accessToken = await gateStorage.getAccessToken();
      final isExpired = await gateStorage.isTokenExpired();
      
      return {
        'isInitialized': _isInitialized,
        'hasAccessToken': accessToken != null,
        'isTokenExpired': isExpired,
        'timeoutOverrideActive': prefs.getBool('token_expiration_logout_disabled') ?? false,
        'autoLogoutDisabled': prefs.getBool('auto_logout_disabled') ?? false,
        'continuousRefreshEnabled': prefs.getBool('continuous_refresh_mode') ?? false,
        'aggressiveRefreshEnabled': prefs.getBool('aggressive_refresh_enabled') ?? false,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _isInitialized = false;
    log("🗑️ 5-minute token fix disposed");
  }
}
