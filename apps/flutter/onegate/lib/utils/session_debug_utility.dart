import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';

/// Debug utility for the unified session management system
class SessionDebugUtility {
  static const String _tag = 'UnifiedSessionDebug';

  /// Check all session-related settings and log them
  static Future<void> debugSessionState() async {
    try {
      log('🔍 [$_tag] Starting unified session state debug check');

      final prefs = await SharedPreferences.getInstance();
      final gateStorage = GetIt.I<GateStorage>();
      final userSessionManager = GetIt.I<UserSessionManager>();

      // Check unified session management status
      await _checkUnifiedSessionStatus(prefs);

      // Check token expiration settings
      await _checkTokenExpirationSettings(prefs, gateStorage);

      // Check session manager state
      await _checkSessionManagerState(userSessionManager);

      // Check token storage
      await _checkTokenStorage(gateStorage);

      // Verify no session expired modal should appear
      final shouldShow = await shouldShowSessionExpiredModal();
      log('🎯 [$_tag] Should show session expired modal: $shouldShow');

      log('✅ [$_tag] Unified session state debug check completed');
    } catch (e) {
      log('❌ [$_tag] Error during session debug: $e');
    }
  }

  /// Check unified session management status
  static Future<void> _checkUnifiedSessionStatus(
      SharedPreferences prefs) async {
    log('🔒 [$_tag] Unified Session Management Status:');
    log('   • token_expiration_logout_disabled: ${prefs.getBool('token_expiration_logout_disabled')}');
    log('   • auto_logout_disabled: ${prefs.getBool('auto_logout_disabled')}');
    log('   • session_timeout_disabled: ${prefs.getBool('session_timeout_disabled')}');
    log('   • idle_timeout_disabled: ${prefs.getBool('idle_timeout_disabled')}');
    log('   • continuous_session_active: ${prefs.getBool('continuous_session_active')}');

    // Check if all required flags are set
    final allFlagsSet =
        (prefs.getBool('token_expiration_logout_disabled') ?? false) &&
            (prefs.getBool('auto_logout_disabled') ?? false) &&
            (prefs.getBool('continuous_session_active') ?? false);

    log('   • All unified session flags set: $allFlagsSet');
  }

  /// Check token expiration settings
  static Future<void> _checkTokenExpirationSettings(
      SharedPreferences prefs, GateStorage gateStorage) async {
    log('⏰ [$_tag] Token Expiration Settings:');

    final accessToken = await gateStorage.getAccessToken();
    final refreshToken = await gateStorage.getRefreshToken();
    final isExpired = await gateStorage.isTokenExpired();

    log('   • Has Access Token: ${accessToken != null}');
    log('   • Has Refresh Token: ${refreshToken != null}');
    log('   • Is Token Expired: $isExpired');

    if (accessToken != null) {
      log('   • Access Token Length: ${accessToken.length}');
      log('   • Access Token Preview: ${accessToken.substring(0, 20)}...');
    }
  }

  /// Check session manager state
  static Future<void> _checkSessionManagerState(
      UserSessionManager sessionManager) async {
    log('📊 [$_tag] Session Manager State:');
    log('   • Current State: ${sessionManager.currentState}');

    try {
      final userSession = await sessionManager.getCurrentUserSession();
      log('   • Has User Session: ${userSession != null}');

      final roles = await sessionManager.getUserPermissions();
      log('   • User Permissions Count: ${roles.length}');
    } catch (e) {
      log('   • Error getting session info: $e');
    }
  }

  /// Check token storage
  static Future<void> _checkTokenStorage(GateStorage gateStorage) async {
    log('💾 [$_tag] Token Storage:');

    try {
      final sessionTimestamp = await gateStorage.getSessionTimestamp();
      log('   • Session Timestamp: $sessionTimestamp');

      if (sessionTimestamp != null) {
        final sessionDuration = DateTime.now().difference(sessionTimestamp);
        log('   • Session Duration: ${sessionDuration.inMinutes} minutes');
      }

      final userId = await gateStorage.getUserId();
      final username = await gateStorage.getUsername();
      final userEmail = await gateStorage.getUserEmail();

      log('   • User ID: $userId');
      log('   • Username: $username');
      log('   • User Email: $userEmail');
    } catch (e) {
      log('   • Error checking token storage: $e');
    }
  }

  /// Force check if session expired modal should be shown
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

  /// Debug and fix session management configuration
  static Future<void> debugAndFixSessionManagement() async {
    try {
      log('🔧 [$_tag] Starting session management debug and fix');

      final prefs = await SharedPreferences.getInstance();

      // Check current flags
      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;

      log('📊 Current Session Flags:');
      log('   • token_expiration_logout_disabled: $tokenExpirationLogoutDisabled');
      log('   • auto_logout_disabled: $autoLogoutDisabled');
      log('   • continuous_session_active: $continuousSessionActive');

      // Force enable all continuous session flags
      if (!tokenExpirationLogoutDisabled) {
        await prefs.setBool('token_expiration_logout_disabled', true);
        log('✅ Enabled token_expiration_logout_disabled');
      }

      if (!autoLogoutDisabled) {
        await prefs.setBool('auto_logout_disabled', true);
        log('✅ Enabled auto_logout_disabled');
      }

      if (!continuousSessionActive) {
        await prefs.setBool('continuous_session_active', true);
        log('✅ Enabled continuous_session_active');
      }

      // Additional session timeout overrides
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      await prefs.setBool('disable_idle_timeout', true);
      await prefs.setInt(
          'session_timeout_ms', const Duration(days: 365).inMilliseconds);
      await prefs.setInt(
          'idle_timeout_ms', const Duration(days: 365).inMilliseconds);

      log('✅ All session management flags configured for continuous session');

      // Verify the fix
      await shouldShowSessionExpiredModal();
    } catch (e) {
      log('❌ [$_tag] Error during session management debug and fix: $e');
    }
  }

  /// Test token refresh functionality
  static Future<void> testTokenRefresh() async {
    try {
      log('🔄 [$_tag] Testing token refresh...');

      final userSessionManager = GetIt.I<UserSessionManager>();
      await userSessionManager.refreshSession();

      log('✅ [$_tag] Token refresh test completed');
    } catch (e) {
      log('❌ [$_tag] Error during token refresh test: $e');
    }
  }

  /// Emergency fix for session expired modal appearing
  static Future<void> emergencyFixSessionExpiredModal() async {
    try {
      log('🚨 [$_tag] EMERGENCY FIX: Disabling session expired modal');

      final prefs = await SharedPreferences.getInstance();

      // Force enable ALL flags that prevent session expired modal
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('continuous_session_active', true);
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      await prefs.setBool('disable_idle_timeout', true);

      // Set infinite timeouts
      const infiniteTimeout = Duration(days: 365);
      await prefs.setInt('session_timeout_ms', infiniteTimeout.inMilliseconds);
      await prefs.setInt('idle_timeout_ms', infiniteTimeout.inMilliseconds);

      log('✅ [$_tag] EMERGENCY FIX APPLIED - Session expired modal should be disabled');
      log('🔄 [$_tag] Please restart the app for changes to take full effect');

      // Verify the fix
      await shouldShowSessionExpiredModal();
    } catch (e) {
      log('❌ [$_tag] Error during emergency fix: $e');
    }
  }

  /// Specific fix for 10-minute refresh token expiration
  static Future<void> fix10MinuteRefreshTokenExpiration() async {
    try {
      log('🚨 [$_tag] SPECIFIC FIX: 10-Minute Refresh Token Expiration');

      final prefs = await SharedPreferences.getInstance();

      // Enable all continuous session flags
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('continuous_session_active', true);
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      await prefs.setBool('disable_idle_timeout', true);

      // Enable specific 10-minute refresh token override
      await prefs.setBool('ten_minute_refresh_token_override', true);
      await prefs.setBool('short_refresh_token_override', true);

      // Set infinite timeouts
      const infiniteTimeout = Duration(days: 365);
      await prefs.setInt('session_timeout_ms', infiniteTimeout.inMilliseconds);
      await prefs.setInt('idle_timeout_ms', infiniteTimeout.inMilliseconds);

      // Configure aggressive token refresh for short refresh tokens
      await prefs.setInt('token_refresh_interval_ms',
          const Duration(minutes: 1).inMilliseconds);
      await prefs.setBool('aggressive_token_refresh_enabled', true);

      log('✅ [$_tag] 10-MINUTE REFRESH TOKEN FIX APPLIED');
      log('   • Continuous session flags enabled');
      log('   • 10-minute refresh token override enabled');
      log('   • Aggressive token refresh configured');
      log('   • Session expired modal should be disabled');
      log('🔄 [$_tag] App restart recommended for full effect');

      // Verify the fix
      await shouldShowSessionExpiredModal();
    } catch (e) {
      log('❌ [$_tag] Error during 10-minute refresh token fix: $e');
    }
  }
}
