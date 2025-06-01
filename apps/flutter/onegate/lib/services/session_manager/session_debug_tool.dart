import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/continuous_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/session_timeout_override.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/five_minute_token_fix.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive debugging tool for session management issues
/// Helps investigate why sessions expire unexpectedly
class SessionDebugTool {
  static final SessionDebugTool _instance = SessionDebugTool._internal();
  factory SessionDebugTool() => _instance;
  SessionDebugTool._internal();

  Timer? _debugTimer;
  bool _isDebugging = false;

  /// Start comprehensive session debugging
  Future<void> startDebugging({Duration interval = const Duration(minutes: 1)}) async {
    if (_isDebugging) return;

    _isDebugging = true;
    log("🔍 Starting session debugging tool");

    // Initial comprehensive check
    await performComprehensiveCheck();

    // Start periodic monitoring
    _debugTimer = Timer.periodic(interval, (timer) async {
      await performComprehensiveCheck();
    });

    log("✅ Session debugging started (checking every ${interval.inMinutes} minutes)");
  }

  /// Stop debugging
  void stopDebugging() {
    _debugTimer?.cancel();
    _isDebugging = false;
    log("⏹️ Session debugging stopped");
  }

  /// Perform comprehensive session status check
  Future<Map<String, dynamic>> performComprehensiveCheck() async {
    final timestamp = DateTime.now();
    log("🔍 ===== COMPREHENSIVE SESSION CHECK (${timestamp.toIso8601String()}) =====");

    final results = <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'checks': {},
    };

    try {
      // 1. Check 5-minute token fix status
      results['checks']['fiveMinuteTokenFix'] = await _checkFiveMinuteTokenFix();

      // 2. Check session timeout overrides
      results['checks']['sessionTimeoutOverrides'] = await _checkSessionTimeoutOverrides();

      // 3. Check token status and refresh timing
      results['checks']['tokenStatus'] = await _checkTokenStatus();

      // 4. Check user session manager
      results['checks']['userSessionManager'] = await _checkUserSessionManager();

      // 5. Check continuous session manager
      results['checks']['continuousSessionManager'] = await _checkContinuousSessionManager();

      // 6. Check enhanced token refresh manager
      results['checks']['enhancedTokenRefreshManager'] = await _checkEnhancedTokenRefreshManager();

      // 7. Check for potential 10-minute timeout sources
      results['checks']['potentialTimeoutSources'] = await _checkPotentialTimeoutSources();

      // 8. Check Keycloak configuration
      results['checks']['keycloakConfig'] = await _checkKeycloakConfig();

      log("✅ Comprehensive check completed");
    } catch (e) {
      log("❌ Error during comprehensive check: $e");
      results['error'] = e.toString();
    }

    return results;
  }

  /// Check 5-minute token fix status
  Future<Map<String, dynamic>> _checkFiveMinuteTokenFix() async {
    try {
      final fiveMinuteTokenFix = FiveMinuteTokenFix();
      final status = await fiveMinuteTokenFix.getSessionStatus();
      
      log("🔧 5-Minute Token Fix Status:");
      log("   • Initialized: ${status['isInitialized']}");
      log("   • Timeout Override Active: ${status['timeoutOverrideActive']}");
      log("   • Auto Logout Disabled: ${status['autoLogoutDisabled']}");
      log("   • Aggressive Refresh Enabled: ${status['aggressiveRefreshEnabled']}");

      return status;
    } catch (e) {
      log("❌ Error checking 5-minute token fix: $e");
      return {'error': e.toString()};
    }
  }

  /// Check session timeout overrides
  Future<Map<String, dynamic>> _checkSessionTimeoutOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final overrides = {
        'token_expiration_logout_disabled': prefs.getBool('token_expiration_logout_disabled'),
        'auto_logout_disabled': prefs.getBool('auto_logout_disabled'),
        'session_timeout_disabled': prefs.getBool('session_timeout_disabled'),
        'idle_timeout_disabled': prefs.getBool('idle_timeout_disabled'),
        'gate_storage_token_expiration_disabled': prefs.getBool('gate_storage_token_expiration_disabled'),
        'user_session_timeout_override': prefs.getBool('user_session_timeout_override'),
        'session_timeout_ms': prefs.getInt('session_timeout_ms'),
        'idle_timeout_ms': prefs.getInt('idle_timeout_ms'),
        'user_session_max_duration_ms': prefs.getInt('user_session_max_duration_ms'),
      };

      log("⏰ Session Timeout Overrides:");
      overrides.forEach((key, value) {
        log("   • $key: $value");
      });

      return overrides;
    } catch (e) {
      log("❌ Error checking session timeout overrides: $e");
      return {'error': e.toString()};
    }
  }

  /// Check current token status and refresh timing
  Future<Map<String, dynamic>> _checkTokenStatus() async {
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      
      if (accessToken == null) {
        log("❌ No access token found");
        return {'error': 'No access token'};
      }

      // Get token analysis
      final tokenAnalysis = JwtTokenUtility.getTokenAnalysis(accessToken);
      final isExpired = await gateStorage.isTokenExpired();
      
      log("🎫 Token Status:");
      log("   • Has Access Token: ${accessToken != null}");
      log("   • Has Refresh Token: ${refreshToken != null}");
      log("   • Is Expired (GateStorage): $isExpired");
      log("   • Token Lifespan: ${tokenAnalysis['lifespanMinutes']} minutes");
      log("   • Refresh Buffer: ${tokenAnalysis['refreshBuffer']} minutes");
      log("   • Should Refresh Now: ${tokenAnalysis['shouldRefreshNow']}");
      log("   • Time Until Expiry: ${tokenAnalysis['timeUntilExpiryMinutes']} minutes");
      log("   • Expires At: ${tokenAnalysis['expiresAt']}");
      log("   • Refresh Time: ${tokenAnalysis['refreshTime']}");

      return {
        'hasAccessToken': accessToken != null,
        'hasRefreshToken': refreshToken != null,
        'isExpired': isExpired,
        'tokenAnalysis': tokenAnalysis,
      };
    } catch (e) {
      log("❌ Error checking token status: $e");
      return {'error': e.toString()};
    }
  }

  /// Check user session manager status
  Future<Map<String, dynamic>> _checkUserSessionManager() async {
    try {
      final userSessionManager = UserSessionManager();
      final currentState = userSessionManager.currentState;
      final sessionDuration = await userSessionManager.getSessionDuration();

      log("👤 User Session Manager:");
      log("   • Current State: $currentState");
      log("   • Session Duration: ${sessionDuration?.inMinutes} minutes");

      return {
        'currentState': currentState.toString(),
        'sessionDurationMinutes': sessionDuration?.inMinutes,
      };
    } catch (e) {
      log("❌ Error checking user session manager: $e");
      return {'error': e.toString()};
    }
  }

  /// Check continuous session manager status
  Future<Map<String, dynamic>> _checkContinuousSessionManager() async {
    try {
      final continuousSession = ContinuousSessionManager();
      // Note: We'd need to add getter methods to ContinuousSessionManager to check its status
      
      log("🔄 Continuous Session Manager:");
      log("   • Status: Checking...");

      return {
        'status': 'active', // This would need actual status from the manager
      };
    } catch (e) {
      log("❌ Error checking continuous session manager: $e");
      return {'error': e.toString()};
    }
  }

  /// Check enhanced token refresh manager status
  Future<Map<String, dynamic>> _checkEnhancedTokenRefreshManager() async {
    try {
      final authService = GetIt.I<AuthService>();
      final tokenRefreshManager = authService.tokenRefreshManager;
      
      log("🔄 Enhanced Token Refresh Manager:");
      log("   • Manager Available: ${tokenRefreshManager != null}");

      return {
        'managerAvailable': tokenRefreshManager != null,
      };
    } catch (e) {
      log("❌ Error checking enhanced token refresh manager: $e");
      return {'error': e.toString()};
    }
  }

  /// Check for potential 10-minute timeout sources
  Future<Map<String, dynamic>> _checkPotentialTimeoutSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Look for any 10-minute (600000ms) timeout values
      final allKeys = prefs.getKeys();
      final potentialTimeouts = <String, dynamic>{};
      
      for (final key in allKeys) {
        final value = prefs.get(key);
        if (value is int) {
          final minutes = value / (1000 * 60);
          if (minutes >= 9 && minutes <= 11) { // Around 10 minutes
            potentialTimeouts[key] = {
              'value': value,
              'minutes': minutes,
            };
          }
        }
      }

      log("⚠️ Potential 10-minute timeout sources:");
      if (potentialTimeouts.isEmpty) {
        log("   • None found in SharedPreferences");
      } else {
        potentialTimeouts.forEach((key, value) {
          log("   • $key: ${value['minutes']} minutes (${value['value']}ms)");
        });
      }

      return potentialTimeouts;
    } catch (e) {
      log("❌ Error checking potential timeout sources: $e");
      return {'error': e.toString()};
    }
  }

  /// Check Keycloak configuration
  Future<Map<String, dynamic>> _checkKeycloakConfig() async {
    try {
      log("🔐 Keycloak Configuration:");
      log("   • Client ID: flutter-dummy");
      log("   • Frontend URL: https://stgsso.cubeone.in");
      log("   • Realm: fstech");
      log("   • Note: Check server-side token lifespans and session settings");

      return {
        'clientId': 'flutter-dummy',
        'frontendUrl': 'https://stgsso.cubeone.in',
        'realm': 'fstech',
      };
    } catch (e) {
      log("❌ Error checking Keycloak config: $e");
      return {'error': e.toString()};
    }
  }

  /// Force immediate token refresh for testing
  Future<bool> forceTokenRefresh() async {
    try {
      log("🔄 Forcing immediate token refresh for debugging");
      
      final authService = GetIt.I<AuthService>();
      final refreshed = await authService.refreshToken();
      
      if (refreshed) {
        log("✅ Force refresh successful");
        await performComprehensiveCheck(); // Check status after refresh
      } else {
        log("❌ Force refresh failed");
      }
      
      return refreshed;
    } catch (e) {
      log("❌ Error during force refresh: $e");
      return false;
    }
  }

  /// Get debugging summary for the last 10 minutes
  Future<String> getDebuggingSummary() async {
    final status = await performComprehensiveCheck();
    
    final summary = StringBuffer();
    summary.writeln("🔍 SESSION DEBUGGING SUMMARY");
    summary.writeln("=" * 50);
    summary.writeln("Timestamp: ${status['timestamp']}");
    summary.writeln("");
    
    final checks = status['checks'] as Map<String, dynamic>;
    
    checks.forEach((checkName, checkResult) {
      summary.writeln("$checkName:");
      if (checkResult is Map) {
        checkResult.forEach((key, value) {
          summary.writeln("  • $key: $value");
        });
      } else {
        summary.writeln("  • $checkResult");
      }
      summary.writeln("");
    });
    
    return summary.toString();
  }

  /// Dispose resources
  void dispose() {
    stopDebugging();
    log("🗑️ Session debug tool disposed");
  }
}
