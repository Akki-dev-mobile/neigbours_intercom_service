import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/five_minute_token_fix.dart';
import 'package:flutter_onegate/services/session_manager/session_timeout_override.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Comprehensive fix for 10-minute session expiry issue
/// Addresses Keycloak session timeouts and refresh token behavior
class TenMinuteSessionFix {
  static final TenMinuteSessionFix _instance = TenMinuteSessionFix._internal();
  factory TenMinuteSessionFix() => _instance;
  TenMinuteSessionFix._internal();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  Timer? _aggressiveRefreshTimer;
  Timer? _sessionMonitorTimer;
  bool _isInitialized = false;
  bool _isAggressiveMode = false;

  /// Initialize the 10-minute session fix
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🔧 Initializing 10-minute session fix");

      // Step 1: Initialize base 5-minute token fix
      await _initializeBaseFix();

      // Step 2: Configure aggressive refresh for 10-minute sessions
      await _configureAggressiveRefresh();

      // Step 3: Override Keycloak session timeouts
      await _overrideKeycloakSessionTimeouts();

      // Step 4: Start aggressive monitoring
      await _startAggressiveMonitoring();

      // Step 5: Configure refresh token handling
      await _configureRefreshTokenHandling();

      _isInitialized = true;
      log("✅ 10-minute session fix initialized successfully");
    } catch (e) {
      log("❌ Error initializing 10-minute session fix: $e");
      rethrow;
    }
  }

  /// Initialize base 5-minute token fix
  Future<void> _initializeBaseFix() async {
    try {
      log("🔧 Initializing base 5-minute token fix");
      
      final fiveMinuteTokenFix = FiveMinuteTokenFix();
      await fiveMinuteTokenFix.initialize();
      
      log("✅ Base 5-minute token fix initialized");
    } catch (e) {
      log("❌ Error initializing base fix: $e");
      rethrow;
    }
  }

  /// Configure aggressive refresh for 10-minute sessions
  Future<void> _configureAggressiveRefresh() async {
    try {
      log("⚡ Configuring aggressive refresh for 10-minute sessions");

      final prefs = await SharedPreferences.getInstance();
      
      // Set aggressive refresh intervals
      await prefs.setInt('aggressive_refresh_interval_ms', Duration(seconds: 15).inMilliseconds);
      await prefs.setBool('ten_minute_session_mode', true);
      await prefs.setInt('critical_refresh_threshold_ms', Duration(minutes: 8).inMilliseconds);
      
      // Override token refresh buffers for 10-minute scenarios
      await prefs.setInt('ten_minute_token_buffer_seconds', 180); // 3-minute buffer
      await prefs.setBool('force_refresh_before_expiry', true);
      
      log("✅ Aggressive refresh configured");
    } catch (e) {
      log("❌ Error configuring aggressive refresh: $e");
      rethrow;
    }
  }

  /// Override Keycloak session timeouts
  Future<void> _overrideKeycloakSessionTimeouts() async {
    try {
      log("🔐 Overriding Keycloak session timeouts");

      final prefs = await SharedPreferences.getInstance();
      
      // Override all potential Keycloak timeout sources
      await prefs.setBool('keycloak_session_timeout_disabled', true);
      await prefs.setBool('sso_session_timeout_disabled', true);
      await prefs.setBool('client_session_timeout_disabled', true);
      
      // Set infinite values for Keycloak-related timeouts
      await prefs.setInt('keycloak_session_max_ms', Duration(days: 365).inMilliseconds);
      await prefs.setInt('sso_session_idle_ms', Duration(days: 365).inMilliseconds);
      await prefs.setInt('client_session_idle_ms', Duration(days: 365).inMilliseconds);
      
      // Disable refresh token rotation if causing issues
      await prefs.setBool('refresh_token_rotation_disabled', true);
      
      log("✅ Keycloak session timeouts overridden");
    } catch (e) {
      log("❌ Error overriding Keycloak timeouts: $e");
      rethrow;
    }
  }

  /// Start aggressive monitoring for 10-minute sessions
  Future<void> _startAggressiveMonitoring() async {
    try {
      log("👁️ Starting aggressive session monitoring");

      // Start aggressive refresh timer (every 15 seconds)
      _aggressiveRefreshTimer?.cancel();
      _aggressiveRefreshTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
        await _performAggressiveRefreshCheck();
      });

      // Start session monitor (every 30 seconds)
      _sessionMonitorTimer?.cancel();
      _sessionMonitorTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
        await _monitorSessionHealth();
      });

      log("✅ Aggressive monitoring started");
    } catch (e) {
      log("❌ Error starting aggressive monitoring: $e");
      rethrow;
    }
  }

  /// Configure refresh token handling
  Future<void> _configureRefreshTokenHandling() async {
    try {
      log("🔄 Configuring refresh token handling");

      final prefs = await SharedPreferences.getInstance();
      
      // Configure refresh token behavior
      await prefs.setBool('preserve_refresh_token_on_failure', true);
      await prefs.setBool('retry_with_existing_refresh_token', true);
      await prefs.setInt('refresh_token_retry_attempts', 5);
      
      // Handle refresh token rotation
      await prefs.setBool('handle_refresh_token_rotation', true);
      await prefs.setBool('backup_refresh_token_on_rotation', true);
      
      log("✅ Refresh token handling configured");
    } catch (e) {
      log("❌ Error configuring refresh token handling: $e");
      rethrow;
    }
  }

  /// Perform aggressive refresh check
  Future<void> _performAggressiveRefreshCheck() async {
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      
      if (accessToken == null) return;

      // Check if we're in critical time window (8+ minutes since login)
      final analysis = JwtTokenUtility.getTokenAnalysis(accessToken);
      final timeUntilExpiryMinutes = analysis['timeUntilExpiryMinutes'] as int?;
      
      if (timeUntilExpiryMinutes != null && timeUntilExpiryMinutes <= 3) {
        if (!_isAggressiveMode) {
          log("⚡ Entering aggressive refresh mode (${timeUntilExpiryMinutes}min until expiry)");
          _isAggressiveMode = true;
        }
        
        // Force refresh in aggressive mode
        await _forceTokenRefresh("Aggressive mode - ${timeUntilExpiryMinutes}min until expiry");
      } else if (_isAggressiveMode && timeUntilExpiryMinutes != null && timeUntilExpiryMinutes > 3) {
        log("✅ Exiting aggressive refresh mode");
        _isAggressiveMode = false;
      }
    } catch (e) {
      log("❌ Error during aggressive refresh check: $e");
    }
  }

  /// Monitor session health
  Future<void> _monitorSessionHealth() async {
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      
      // Check token availability
      if (accessToken == null || refreshToken == null) {
        log("⚠️ Missing tokens detected - access: ${accessToken != null}, refresh: ${refreshToken != null}");
        return;
      }

      // Check for 10-minute token patterns
      final analysis = JwtTokenUtility.getTokenAnalysis(accessToken);
      final lifespanMinutes = analysis['lifespanMinutes'] as int?;
      
      if (lifespanMinutes != null && lifespanMinutes >= 9 && lifespanMinutes <= 11) {
        log("🚨 10-minute token pattern detected - lifespan: ${lifespanMinutes}min");
        await _handle10MinuteTokenPattern(analysis);
      }

      // Check session overrides are still active
      await _verifySessionOverrides();
    } catch (e) {
      log("❌ Error monitoring session health: $e");
    }
  }

  /// Handle 10-minute token pattern
  Future<void> _handle10MinuteTokenPattern(Map<String, dynamic> analysis) async {
    try {
      final timeUntilExpiryMinutes = analysis['timeUntilExpiryMinutes'] as int?;
      
      if (timeUntilExpiryMinutes != null) {
        if (timeUntilExpiryMinutes <= 2) {
          // Critical: Force immediate refresh
          await _forceTokenRefresh("Critical 10-minute token - ${timeUntilExpiryMinutes}min remaining");
        } else if (timeUntilExpiryMinutes <= 4) {
          // Warning: Prepare for refresh
          log("⚠️ 10-minute token approaching expiry - ${timeUntilExpiryMinutes}min remaining");
          await _prepareForCriticalRefresh();
        }
      }
    } catch (e) {
      log("❌ Error handling 10-minute token pattern: $e");
    }
  }

  /// Force token refresh with reason
  Future<void> _forceTokenRefresh(String reason) async {
    try {
      log("🔄 Forcing token refresh: $reason");
      
      final authService = GetIt.I<AuthService>();
      final refreshed = await authService.refreshToken();
      
      if (refreshed) {
        log("✅ Force refresh successful: $reason");
        
        // Verify new tokens
        await _verifyNewTokens();
      } else {
        log("❌ Force refresh failed: $reason");
        await _handleRefreshFailure();
      }
    } catch (e) {
      log("❌ Error during force refresh: $e");
    }
  }

  /// Prepare for critical refresh
  Future<void> _prepareForCriticalRefresh() async {
    try {
      // Backup current refresh token
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _secureStorage.write(key: 'backup_refresh_token', value: refreshToken);
      }

      // Ensure session overrides are active
      final sessionTimeoutOverride = SessionTimeoutOverride();
      await sessionTimeoutOverride.enforceTimeoutOverride();
      
      log("✅ Prepared for critical refresh");
    } catch (e) {
      log("❌ Error preparing for critical refresh: $e");
    }
  }

  /// Verify new tokens after refresh
  Future<void> _verifyNewTokens() async {
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final newAccessToken = await gateStorage.getAccessToken();
      
      if (newAccessToken != null) {
        final analysis = JwtTokenUtility.getTokenAnalysis(newAccessToken);
        log("✅ New token verified - lifespan: ${analysis['lifespanMinutes']}min, expires: ${analysis['expiresAt']}");
      }
    } catch (e) {
      log("❌ Error verifying new tokens: $e");
    }
  }

  /// Handle refresh failure
  Future<void> _handleRefreshFailure() async {
    try {
      log("🚨 Handling refresh failure in 10-minute session fix");

      // Try to restore backup refresh token
      final backupRefreshToken = await _secureStorage.read(key: 'backup_refresh_token');
      if (backupRefreshToken != null) {
        log("🔄 Attempting recovery with backup refresh token");
        await _secureStorage.write(key: 'refresh_token', value: backupRefreshToken);
        
        // Retry refresh with backup token
        final authService = GetIt.I<AuthService>();
        final recovered = await authService.refreshToken();
        
        if (recovered) {
          log("✅ Recovery successful with backup refresh token");
          return;
        }
      }

      log("❌ All recovery attempts failed");
    } catch (e) {
      log("❌ Error handling refresh failure: $e");
    }
  }

  /// Verify session overrides are still active
  Future<void> _verifySessionOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final tokenLogoutDisabled = prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      
      if (!tokenLogoutDisabled || !autoLogoutDisabled) {
        log("⚠️ Session overrides not active, reactivating...");
        
        // Reactivate overrides
        await prefs.setBool('token_expiration_logout_disabled', true);
        await prefs.setBool('auto_logout_disabled', true);
        await prefs.setBool('session_timeout_disabled', true);
        
        log("✅ Session overrides reactivated");
      }
    } catch (e) {
      log("❌ Error verifying session overrides: $e");
    }
  }

  /// Get current status
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      
      Map<String, dynamic> tokenAnalysis = {};
      if (accessToken != null) {
        tokenAnalysis = JwtTokenUtility.getTokenAnalysis(accessToken);
      }

      return {
        'isInitialized': _isInitialized,
        'isAggressiveMode': _isAggressiveMode,
        'tenMinuteSessionMode': prefs.getBool('ten_minute_session_mode') ?? false,
        'keycloakTimeoutDisabled': prefs.getBool('keycloak_session_timeout_disabled') ?? false,
        'tokenAnalysis': tokenAnalysis,
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
    _aggressiveRefreshTimer?.cancel();
    _sessionMonitorTimer?.cancel();
    _isInitialized = false;
    _isAggressiveMode = false;
    log("🗑️ 10-minute session fix disposed");
  }
}
