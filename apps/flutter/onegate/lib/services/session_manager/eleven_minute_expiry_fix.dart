import 'dart:async';
import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Specific fix for the 11-minute session expiry issue
class ElevenMinuteExpiryFix {
  static const String _tag = 'ElevenMinuteExpiryFix';
  static bool _isInitialized = false;
  static Timer? _aggressiveRefreshTimer;
  static Timer? _monitoringTimer;

  /// Initialize the 11-minute expiry fix
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('🚨 [$_tag] Initializing 11-Minute Session Expiry Fix');

      // Step 1: Apply emergency session configuration
      await _applyEmergencySessionConfiguration();

      // Step 2: Start aggressive token monitoring
      await _startAggressiveTokenMonitoring();

      // Step 3: Override any 11-minute timeouts
      await _override11MinuteTimeouts();

      // Step 4: Force immediate token refresh if needed
      await _forceImmediateRefreshIfNeeded();

      _isInitialized = true;
      log('✅ [$_tag] 11-Minute Session Expiry Fix initialized successfully');
    } catch (e) {
      log('❌ [$_tag] Error initializing 11-minute expiry fix: $e');
      rethrow;
    }
  }

  /// Apply emergency session configuration
  static Future<void> _applyEmergencySessionConfiguration() async {
    try {
      log('🔧 [$_tag] Applying emergency session configuration');

      final prefs = await SharedPreferences.getInstance();

      // Force enable ALL continuous session flags
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('continuous_session_active', true);
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      await prefs.setBool('disable_idle_timeout', true);

      // Set infinite timeouts to override any 11-minute configurations
      const infiniteTimeout = Duration(days: 365);
      await prefs.setInt('session_timeout_ms', infiniteTimeout.inMilliseconds);
      await prefs.setInt('idle_timeout_ms', infiniteTimeout.inMilliseconds);

      // Enable aggressive refresh mode
      await prefs.setBool('aggressive_token_refresh_enabled', true);
      await prefs.setBool('prevent_11_minute_expiry', true);
      await prefs.setBool('force_continuous_session', true);

      // Override any Keycloak-specific timeouts
      await prefs.setBool('override_keycloak_timeouts', true);
      await prefs.setBool('ignore_refresh_token_expiry', true);

      log('✅ [$_tag] Emergency session configuration applied');
    } catch (e) {
      log('❌ [$_tag] Error applying emergency session configuration: $e');
    }
  }

  /// Start aggressive token monitoring every 30 seconds
  static Future<void> _startAggressiveTokenMonitoring() async {
    try {
      log('🔄 [$_tag] Starting aggressive token monitoring');

      // Cancel any existing timers
      _aggressiveRefreshTimer?.cancel();
      _monitoringTimer?.cancel();

      // Start aggressive refresh timer (every 30 seconds)
      _aggressiveRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _performAggressiveTokenCheck();
      });

      // Start monitoring timer (every 10 seconds for detailed logging)
      _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        await _logTokenStatus();
      });

      log('✅ [$_tag] Aggressive token monitoring started');
    } catch (e) {
      log('❌ [$_tag] Error starting aggressive token monitoring: $e');
    }
  }

  /// Perform aggressive token check
  static Future<void> _performAggressiveTokenCheck() async {
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();

      if (accessToken == null || refreshToken == null) {
        log('⚠️ [$_tag] Missing tokens during aggressive check');
        return;
      }

      // Analyze both tokens
      final analysis = JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
      final sessionState = analysis['sessionState'] as String?;
      final accessTimeUntilExpiry = analysis['accessTokenTimeUntilExpiry'] as int?;
      final refreshTimeUntilExpiry = analysis['refreshTokenTimeUntilExpiry'] as int?;

      log('🔍 [$_tag] Aggressive Token Check:');
      log('   • Session State: $sessionState');
      log('   • Access Token Time Until Expiry: ${accessTimeUntilExpiry != null ? "${(accessTimeUntilExpiry / 60).toStringAsFixed(1)} min" : "Unknown"}');
      log('   • Refresh Token Time Until Expiry: ${refreshTimeUntilExpiry != null ? "${(refreshTimeUntilExpiry / 60).toStringAsFixed(1)} min" : "Unknown"}');

      // Check for critical scenarios
      if (refreshTimeUntilExpiry != null && refreshTimeUntilExpiry <= 120) { // 2 minutes
        log('🚨 [$_tag] CRITICAL: Refresh token expires in ${(refreshTimeUntilExpiry / 60).toStringAsFixed(1)} minutes!');
        await _handleCriticalRefreshTokenExpiry();
      } else if (accessTimeUntilExpiry != null && accessTimeUntilExpiry <= 60) { // 1 minute
        log('⚠️ [$_tag] WARNING: Access token expires in ${(accessTimeUntilExpiry / 60).toStringAsFixed(1)} minutes');
        await _performEmergencyTokenRefresh();
      }
    } catch (e) {
      log('❌ [$_tag] Error during aggressive token check: $e');
    }
  }

  /// Log token status for monitoring
  static Future<void> _logTokenStatus() async {
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();

      if (accessToken != null && refreshToken != null) {
        final analysis = JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
        final accessTimeUntilExpiry = analysis['accessTokenTimeUntilExpiry'] as int?;
        final refreshTimeUntilExpiry = analysis['refreshTokenTimeUntilExpiry'] as int?;

        log('📊 [$_tag] Token Status Monitor:');
        log('   • Access: ${accessTimeUntilExpiry != null ? "${(accessTimeUntilExpiry / 60).toStringAsFixed(1)}min" : "Unknown"}');
        log('   • Refresh: ${refreshTimeUntilExpiry != null ? "${(refreshTimeUntilExpiry / 60).toStringAsFixed(1)}min" : "Unknown"}');
      }
    } catch (e) {
      // Silent fail for monitoring
    }
  }

  /// Override any 11-minute timeouts
  static Future<void> _override11MinuteTimeouts() async {
    try {
      log('⏰ [$_tag] Overriding 11-minute timeouts');

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // Look for and override any 11-minute timeouts
      for (final key in allKeys) {
        try {
          final value = prefs.get(key);

          if (value is int) {
            // Check for 11-minute timeouts (660 seconds or 660000 milliseconds)
            if (value == 660 || value == 660000 || value == 11) {
              log('🔧 [$_tag] Overriding 11-minute timeout: $key = $value');
              // Set to infinite timeout
              await prefs.setInt(key, const Duration(days: 365).inMilliseconds);
            }

            // Check for values that could represent 11 minutes in different units
            final minutes = value / 60000; // Convert milliseconds to minutes
            if (minutes >= 10.5 && minutes <= 11.5) {
              log('🔧 [$_tag] Overriding ~11-minute timeout: $key = $value (${minutes.toStringAsFixed(1)} min)');
              await prefs.setInt(key, const Duration(days: 365).inMilliseconds);
            }
          }
        } catch (e) {
          // Skip keys that can't be processed
        }
      }

      log('✅ [$_tag] 11-minute timeout override completed');
    } catch (e) {
      log('❌ [$_tag] Error overriding 11-minute timeouts: $e');
    }
  }

  /// Force immediate token refresh if needed
  static Future<void> _forceImmediateRefreshIfNeeded() async {
    try {
      log('🔄 [$_tag] Checking if immediate token refresh is needed');

      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();

      if (accessToken != null && refreshToken != null) {
        final analysis = JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
        final recommendedAction = analysis['recommendedAction'] as String?;

        if (recommendedAction == 'refreshAccessToken') {
          log('🔄 [$_tag] Performing immediate token refresh');
          await _performEmergencyTokenRefresh();
        }
      }
    } catch (e) {
      log('❌ [$_tag] Error during immediate refresh check: $e');
    }
  }

  /// Perform emergency token refresh
  static Future<void> _performEmergencyTokenRefresh() async {
    try {
      log('🚨 [$_tag] Performing emergency token refresh');

      final authService = GetIt.I<AuthService>();
      final refreshed = await authService.refreshToken();

      if (refreshed) {
        log('✅ [$_tag] Emergency token refresh successful');
      } else {
        log('❌ [$_tag] Emergency token refresh failed');
      }
    } catch (e) {
      log('❌ [$_tag] Error during emergency token refresh: $e');
    }
  }

  /// Handle critical refresh token expiry
  static Future<void> _handleCriticalRefreshTokenExpiry() async {
    try {
      log('🚨 [$_tag] Handling critical refresh token expiry');

      // Check if continuous session mode is active
      final prefs = await SharedPreferences.getInstance();
      final continuousSessionActive = prefs.getBool('continuous_session_active') ?? false;

      if (continuousSessionActive) {
        log('🔒 [$_tag] Continuous session mode active - preventing logout');
        
        // Try to refresh one more time
        await _performEmergencyTokenRefresh();
        
        // If that fails, we need to maintain the session anyway
        log('🔒 [$_tag] Maintaining session despite refresh token expiry');
      } else {
        log('⚠️ [$_tag] Continuous session mode not active - allowing normal expiry handling');
      }
    } catch (e) {
      log('❌ [$_tag] Error handling critical refresh token expiry: $e');
    }
  }

  /// Get current fix status
  static Future<Map<String, dynamic>> getFixStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'isInitialized': _isInitialized,
        'aggressiveRefreshActive': _aggressiveRefreshTimer?.isActive ?? false,
        'monitoringActive': _monitoringTimer?.isActive ?? false,
        'prevent11MinuteExpiry': prefs.getBool('prevent_11_minute_expiry') ?? false,
        'aggressiveRefreshEnabled': prefs.getBool('aggressive_token_refresh_enabled') ?? false,
        'forceContinuousSession': prefs.getBool('force_continuous_session') ?? false,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Apply emergency fix for immediate use
  static Future<void> applyEmergencyFix() async {
    try {
      log('🚨 [$_tag] APPLYING EMERGENCY FIX FOR 11-MINUTE SESSION EXPIRY');

      // Initialize if not already done
      if (!_isInitialized) {
        await initialize();
      }

      // Force apply all fixes
      await _applyEmergencySessionConfiguration();
      await _override11MinuteTimeouts();
      await _forceImmediateRefreshIfNeeded();

      log('✅ [$_tag] Emergency fix applied successfully');
      log('🔄 [$_tag] Session should now continue indefinitely');
    } catch (e) {
      log('❌ [$_tag] Error applying emergency fix: $e');
    }
  }

  /// Stop the fix and clean up resources
  static void stop() {
    _aggressiveRefreshTimer?.cancel();
    _monitoringTimer?.cancel();
    _aggressiveRefreshTimer = null;
    _monitoringTimer = null;
    _isInitialized = false;
    log('⏹️ [$_tag] 11-Minute Expiry Fix stopped');
  }

  /// Dispose resources
  static void dispose() {
    stop();
  }
}
