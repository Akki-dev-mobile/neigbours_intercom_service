import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/session_expiry_fix.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Debug utility for session expiry issues
class SessionExpiryDebug {
  static const String _tag = 'SessionExpiryDebug';

  /// Comprehensive debug of current session state
  static Future<void> debugCurrentSessionState() async {
    try {
      log('🔍 [$_tag] ===== COMPREHENSIVE SESSION DEBUG =====');
      
      // Step 1: Check tokens
      await _debugTokens();
      
      // Step 2: Check session configuration
      await _debugSessionConfiguration();
      
      // Step 3: Check session manager state
      await _debugSessionManagerState();
      
      // Step 4: Simulate the 3:10 PM login scenario
      await _simulateLoginScenario();
      
      log('🔍 [$_tag] ===== END SESSION DEBUG =====');
    } catch (e) {
      log('❌ [$_tag] Error during session debug: $e');
    }
  }

  /// Debug current tokens
  static Future<void> _debugTokens() async {
    try {
      log('🎫 [$_tag] TOKEN ANALYSIS:');
      
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      
      if (accessToken == null || refreshToken == null) {
        log('❌ [$_tag] Missing tokens:');
        log('   • Access Token: ${accessToken != null ? "Present" : "MISSING"}');
        log('   • Refresh Token: ${refreshToken != null ? "Present" : "MISSING"}');
        return;
      }
      
      // Analyze both tokens
      final analysis = JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
      
      log('📊 [$_tag] Token Analysis Results:');
      log('   • Session State: ${analysis['sessionState']}');
      log('   • Recommended Action: ${analysis['recommendedAction']}');
      log('   • Access Token Expires: ${analysis['accessTokenExpiresAt']}');
      log('   • Refresh Token Expires: ${analysis['refreshTokenExpiresAt']}');
      log('   • Access Token Time Until Expiry: ${analysis['accessTokenTimeUntilExpiry']}s');
      log('   • Refresh Token Time Until Expiry: ${analysis['refreshTokenTimeUntilExpiry']}s');
      log('   • Next Refresh Time: ${analysis['nextRefreshTime']}');
      log('   • Should Refresh Now: ${analysis['shouldRefreshNow']}');
      
      // Individual token analysis
      final accessAnalysis = JwtTokenUtility.getTokenAnalysis(accessToken);
      log('🔑 [$_tag] Access Token Details:');
      log('   • Lifespan: ${accessAnalysis['lifespanMinutes']} minutes');
      log('   • Refresh Buffer: ${accessAnalysis['refreshBuffer']} minutes');
      log('   • Is Valid: ${accessAnalysis['isValid']}');
      log('   • Is Expired: ${accessAnalysis['isExpired']}');
      
      final refreshAnalysis = JwtTokenUtility.getTokenAnalysis(refreshToken);
      log('🔄 [$_tag] Refresh Token Details:');
      log('   • Lifespan: ${refreshAnalysis['lifespanMinutes']} minutes');
      log('   • Is Valid: ${refreshAnalysis['isValid']}');
      log('   • Is Expired: ${refreshAnalysis['isExpired']}');
      
    } catch (e) {
      log('❌ [$_tag] Error debugging tokens: $e');
    }
  }

  /// Debug session configuration
  static Future<void> _debugSessionConfiguration() async {
    try {
      log('⚙️ [$_tag] SESSION CONFIGURATION:');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Check all session-related flags
      final flags = {
        'token_expiration_logout_disabled': prefs.getBool('token_expiration_logout_disabled') ?? false,
        'auto_logout_disabled': prefs.getBool('auto_logout_disabled') ?? false,
        'continuous_session_active': prefs.getBool('continuous_session_active') ?? false,
        'session_timeout_disabled': prefs.getBool('session_timeout_disabled') ?? false,
        'idle_timeout_disabled': prefs.getBool('idle_timeout_disabled') ?? false,
        'jwt_based_session_management': prefs.getBool('jwt_based_session_management') ?? false,
        'use_jwt_based_expiry': prefs.getBool('use_jwt_based_expiry') ?? false,
        'dynamic_token_refresh_enabled': prefs.getBool('dynamic_token_refresh_enabled') ?? false,
      };
      
      log('🏁 [$_tag] Session Flags:');
      flags.forEach((key, value) {
        log('   • $key: $value');
      });
      
      // Check timeout values
      final sessionTimeoutMs = prefs.getInt('session_timeout_ms');
      final idleTimeoutMs = prefs.getInt('idle_timeout_ms');
      
      log('⏰ [$_tag] Timeout Values:');
      log('   • Session Timeout: ${sessionTimeoutMs != null ? "${Duration(milliseconds: sessionTimeoutMs).inDays} days" : "Not Set"}');
      log('   • Idle Timeout: ${idleTimeoutMs != null ? "${Duration(milliseconds: idleTimeoutMs).inDays} days" : "Not Set"}');
      
      // Determine if session expired modal should show
      final isContinuousSessionMode = flags['token_expiration_logout_disabled']! ||
          flags['auto_logout_disabled']! ||
          flags['continuous_session_active']!;
      
      log('🔒 [$_tag] Session Mode Analysis:');
      log('   • Continuous Session Mode: $isContinuousSessionMode');
      log('   • Should Show Session Expired Modal: ${!isContinuousSessionMode}');
      
    } catch (e) {
      log('❌ [$_tag] Error debugging session configuration: $e');
    }
  }

  /// Debug session manager state
  static Future<void> _debugSessionManagerState() async {
    try {
      log('🔄 [$_tag] SESSION MANAGER STATE:');
      
      final userSessionManager = GetIt.I<UserSessionManager>();
      final currentState = userSessionManager.currentState;
      
      log('📊 [$_tag] Current Session State: $currentState');
      
      // Get session duration
      final sessionDuration = await userSessionManager.getSessionDuration();
      if (sessionDuration != null) {
        log('⏱️ [$_tag] Session Duration: ${sessionDuration.inMinutes} minutes');
      }
      
    } catch (e) {
      log('❌ [$_tag] Error debugging session manager state: $e');
    }
  }

  /// Simulate the 3:10 PM login scenario
  static Future<void> _simulateLoginScenario() async {
    try {
      log('🎭 [$_tag] SIMULATING LOGIN SCENARIO:');
      log('   • Login Time: 3:10 PM');
      log('   • Current Time: ${DateTime.now().toString()}');
      log('   • Expected Issue: Session expired modal at 3:20 PM (10 minutes later)');
      
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      
      if (accessToken == null || refreshToken == null) {
        log('❌ [$_tag] Cannot simulate - missing tokens');
        return;
      }
      
      // Analyze what would happen in 10 minutes
      final accessExpiryTime = JwtTokenUtility.getTokenExpirationTime(accessToken);
      final refreshExpiryTime = JwtTokenUtility.getTokenExpirationTime(refreshToken);
      
      if (accessExpiryTime != null && refreshExpiryTime != null) {
        final now = DateTime.now();
        final tenMinutesLater = now.add(const Duration(minutes: 10));
        
        log('🔮 [$_tag] Prediction for 10 minutes from now:');
        log('   • Time: ${tenMinutesLater.toString()}');
        log('   • Access Token Expired: ${tenMinutesLater.isAfter(accessExpiryTime)}');
        log('   • Refresh Token Expired: ${tenMinutesLater.isAfter(refreshExpiryTime)}');
        
        if (tenMinutesLater.isAfter(refreshExpiryTime)) {
          log('🚨 [$_tag] ISSUE IDENTIFIED: Refresh token will expire in 10 minutes!');
          log('   • This explains why session expired modal appears at 3:20 PM');
          log('   • Refresh token lifespan is too short for continuous session');
          
          final refreshLifespan = refreshExpiryTime.difference(JwtTokenUtility.getTokenIssuedAtTime(refreshToken) ?? now);
          log('   • Refresh Token Lifespan: ${refreshLifespan.inMinutes} minutes');
          
          if (refreshLifespan.inMinutes <= 10) {
            log('💡 [$_tag] SOLUTION: Refresh token lifespan needs to be increased on Keycloak server');
            log('   • Current: ${refreshLifespan.inMinutes} minutes');
            log('   • Recommended: At least 30-60 minutes for continuous session');
          }
        } else if (tenMinutesLater.isAfter(accessExpiryTime)) {
          log('ℹ️ [$_tag] Access token will expire, but refresh token is valid');
          log('   • This should trigger automatic token refresh, not session expiry');
        } else {
          log('✅ [$_tag] Both tokens should be valid in 10 minutes');
        }
      }
      
    } catch (e) {
      log('❌ [$_tag] Error simulating login scenario: $e');
    }
  }

  /// Quick fix for the session expiry issue
  static Future<void> quickFixSessionExpiry() async {
    try {
      log('🚀 [$_tag] APPLYING QUICK FIX FOR SESSION EXPIRY');
      
      // Initialize the session expiry fix
      await SessionExpiryFix.initialize();
      
      // Apply emergency fix
      await SessionExpiryFix.emergencyFixSessionExpiredModal();
      
      // Debug the result
      await debugCurrentSessionState();
      
      log('✅ [$_tag] Quick fix applied successfully');
      log('🔄 [$_tag] Please test by keeping app idle for 20 minutes');
      
    } catch (e) {
      log('❌ [$_tag] Error applying quick fix: $e');
    }
  }

  /// Test token refresh functionality
  static Future<void> testTokenRefresh() async {
    try {
      log('🧪 [$_tag] TESTING TOKEN REFRESH');
      
      // Force refresh if needed
      final refreshed = await SessionExpiryFix.forceRefreshIfNeeded();
      
      if (refreshed) {
        log('✅ [$_tag] Token refresh test successful');
        await _debugTokens();
      } else {
        log('❌ [$_tag] Token refresh test failed');
      }
      
    } catch (e) {
      log('❌ [$_tag] Error testing token refresh: $e');
    }
  }

  /// Monitor session for a specified duration
  static Future<void> monitorSession({Duration duration = const Duration(minutes: 15)}) async {
    try {
      log('👁️ [$_tag] MONITORING SESSION FOR ${duration.inMinutes} MINUTES');
      
      final startTime = DateTime.now();
      final endTime = startTime.add(duration);
      
      while (DateTime.now().isBefore(endTime)) {
        await _debugTokens();
        await Future.delayed(const Duration(minutes: 1));
      }
      
      log('✅ [$_tag] Session monitoring completed');
      
    } catch (e) {
      log('❌ [$_tag] Error during session monitoring: $e');
    }
  }

  /// Get session status for external monitoring
  static Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      return await SessionExpiryFix.getSessionStatus();
    } catch (e) {
      log('❌ [$_tag] Error getting session status: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
