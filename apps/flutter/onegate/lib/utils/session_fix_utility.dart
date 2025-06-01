import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Utility to debug and fix session management configuration
class SessionFixUtility {
  static const String _tag = 'SessionFixUtility';

  /// Debug current session configuration and fix any issues
  static Future<void> debugAndFixSessionConfiguration() async {
    try {
      log('🔧 [$_tag] Starting comprehensive session configuration debug and fix');

      final prefs = await SharedPreferences.getInstance();
      final gateStorage = GetIt.I<GateStorage>();
      final userSessionManager = GetIt.I<UserSessionManager>();

      // Step 1: Check current configuration
      await _checkCurrentConfiguration(prefs);

      // Step 2: Force enable all continuous session flags
      await _forceEnableContinuousSession(prefs);

      // Step 3: Verify token status
      await _checkTokenStatus(gateStorage);

      // Step 4: Check session manager state
      await _checkSessionManagerState(userSessionManager);

      // Step 5: Verify the fix worked
      await _verifySessionConfiguration(prefs);

      log('✅ [$_tag] Session configuration debug and fix completed');
    } catch (e) {
      log('❌ [$_tag] Error during session configuration debug and fix: $e');
    }
  }

  /// Check current session configuration
  static Future<void> _checkCurrentConfiguration(
      SharedPreferences prefs) async {
    try {
      log('📊 [$_tag] Current Session Configuration:');

      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;
      final sessionTimeoutDisabled =
          prefs.getBool('session_timeout_disabled') ?? false;
      final idleTimeoutDisabled =
          prefs.getBool('idle_timeout_disabled') ?? false;
      final disableIdleTimeout = prefs.getBool('disable_idle_timeout') ?? false;

      log('   • token_expiration_logout_disabled: $tokenExpirationLogoutDisabled');
      log('   • auto_logout_disabled: $autoLogoutDisabled');
      log('   • continuous_session_active: $continuousSessionActive');
      log('   • session_timeout_disabled: $sessionTimeoutDisabled');
      log('   • idle_timeout_disabled: $idleTimeoutDisabled');
      log('   • disable_idle_timeout: $disableIdleTimeout');

      final sessionTimeoutMs = prefs.getInt('session_timeout_ms');
      final idleTimeoutMs = prefs.getInt('idle_timeout_ms');

      log('   • session_timeout_ms: $sessionTimeoutMs');
      log('   • idle_timeout_ms: $idleTimeoutMs');

      final isContinuousSessionMode = tokenExpirationLogoutDisabled ||
          autoLogoutDisabled ||
          continuousSessionActive;

      log('   • Is Continuous Session Mode: $isContinuousSessionMode');
    } catch (e) {
      log('❌ [$_tag] Error checking current configuration: $e');
    }
  }

  /// Force enable all continuous session flags
  static Future<void> _forceEnableContinuousSession(
      SharedPreferences prefs) async {
    try {
      log('🔧 [$_tag] Force enabling all continuous session flags');

      // Core continuous session flags
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('continuous_session_active', true);

      // Additional timeout overrides
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      await prefs.setBool('disable_idle_timeout', true);

      // Set infinite timeout values (365 days)
      const infiniteTimeout = Duration(days: 365);
      await prefs.setInt('session_timeout_ms', infiniteTimeout.inMilliseconds);
      await prefs.setInt('idle_timeout_ms', infiniteTimeout.inMilliseconds);

      // Additional safety flags
      await prefs.setBool('continuous_token_refresh', true);
      await prefs.setInt('token_refresh_interval_ms',
          const Duration(minutes: 2).inMilliseconds);

      log('✅ [$_tag] All continuous session flags enabled');
    } catch (e) {
      log('❌ [$_tag] Error enabling continuous session flags: $e');
    }
  }

  /// Check token status
  static Future<void> _checkTokenStatus(GateStorage gateStorage) async {
    try {
      log('🎫 [$_tag] Checking token status');

      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      final isTokenExpired = await gateStorage.isTokenExpired();

      log('   • Has Access Token: ${accessToken != null}');
      log('   • Has Refresh Token: ${refreshToken != null}');
      log('   • Is Token Expired: $isTokenExpired');

      if (accessToken != null) {
        log('   • Access Token Length: ${accessToken.length}');
      }

      if (refreshToken != null) {
        log('   • Refresh Token Length: ${refreshToken.length}');
      }
    } catch (e) {
      log('❌ [$_tag] Error checking token status: $e');
    }
  }

  /// Check session manager state
  static Future<void> _checkSessionManagerState(
      UserSessionManager userSessionManager) async {
    try {
      log('🔄 [$_tag] Checking session manager state');

      final currentState = userSessionManager.currentState;
      log('   • Current Session State: $currentState');

      // Force refresh session to ensure it's in the correct state
      await userSessionManager.refreshSession();

      final newState = userSessionManager.currentState;
      log('   • Session State After Refresh: $newState');
    } catch (e) {
      log('❌ [$_tag] Error checking session manager state: $e');
    }
  }

  /// Verify session configuration is working
  static Future<void> _verifySessionConfiguration(
      SharedPreferences prefs) async {
    try {
      log('✅ [$_tag] Verifying session configuration');

      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;

      final isContinuousSessionMode = tokenExpirationLogoutDisabled &&
          autoLogoutDisabled &&
          continuousSessionActive;

      if (isContinuousSessionMode) {
        log('✅ [$_tag] Continuous session mode is properly configured');
        log('   • Session expired modal should NOT appear');
        log('   • Background token refresh should continue indefinitely');
        log('   • No automatic logout should occur');
      } else {
        log('❌ [$_tag] Continuous session mode is NOT properly configured');
        log('   • Session expired modal may still appear');
        log('   • Manual intervention required');
      }
    } catch (e) {
      log('❌ [$_tag] Error verifying session configuration: $e');
    }
  }

  /// Quick fix for session expired modal appearing
  static Future<void> quickFixSessionExpiredModal() async {
    try {
      log('🚀 [$_tag] Quick fix for session expired modal');

      final prefs = await SharedPreferences.getInstance();

      // Force enable the three main flags that prevent session expired modal
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('continuous_session_active', true);

      log('✅ [$_tag] Quick fix applied - session expired modal should be disabled');
    } catch (e) {
      log('❌ [$_tag] Error applying quick fix: $e');
    }
  }

  /// Check if session expired modal should show (for debugging)
  static Future<bool> shouldShowSessionExpiredModal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gateStorage = GetIt.I<GateStorage>();
      final userSessionManager = GetIt.I<UserSessionManager>();

      // Check if continuous session mode is active
      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;

      final isContinuousSessionMode = tokenExpirationLogoutDisabled ||
          autoLogoutDisabled ||
          continuousSessionActive;

      // Check if token is expired
      final isTokenExpired = await gateStorage.isTokenExpired();

      // Check current session state
      final currentState = userSessionManager.currentState;

      log('🔍 [$_tag] Session Expired Modal Check:');
      log('   • Token Expiration Logout Disabled: $tokenExpirationLogoutDisabled');
      log('   • Auto Logout Disabled: $autoLogoutDisabled');
      log('   • Continuous Session Active: $continuousSessionActive');
      log('   • Continuous Session Mode: $isContinuousSessionMode');
      log('   • Token Expired: $isTokenExpired');
      log('   • Current State: $currentState');

      // Should show modal if:
      // 1. Not in continuous session mode AND
      // 2. Token is expired OR current state is tokenExpired
      final shouldShow = !isContinuousSessionMode &&
          (isTokenExpired || currentState == UserSessionState.tokenExpired);

      log('   • Should Show Modal: $shouldShow');

      return shouldShow;
    } catch (e) {
      log('❌ [$_tag] Error checking if should show session expired modal: $e');
      return false;
    }
  }
}
