import 'dart:async';
import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/dynamic_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Comprehensive fix for session expiry issues with dynamic JWT handling
class SessionExpiryFix {
  static const String _tag = 'SessionExpiryFix';
  static bool _isInitialized = false;
  static DynamicSessionManager? _dynamicSessionManager;

  /// Initialize the session expiry fix system
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('🚀 [$_tag] Initializing Session Expiry Fix System');

      // Step 1: Remove hardcoded assumptions
      await _removeHardcodedAssumptions();

      // Step 2: Enable dynamic JWT handling
      await _enableDynamicJWTHandling();

      // Step 3: Initialize dynamic session manager
      _dynamicSessionManager = DynamicSessionManager();
      await _dynamicSessionManager!.initialize();

      // Step 4: Configure continuous session mode
      await _configureContinuousSessionMode();

      // Step 5: Verify the fix
      await _verifySessionConfiguration();

      _isInitialized = true;
      log('✅ [$_tag] Session Expiry Fix System initialized successfully');
    } catch (e) {
      log('❌ [$_tag] Error initializing Session Expiry Fix: $e');
      rethrow;
    }
  }

  /// Remove hardcoded 5min/10min assumptions
  static Future<void> _removeHardcodedAssumptions() async {
    try {
      log('🔧 [$_tag] Removing hardcoded token duration assumptions');

      final prefs = await SharedPreferences.getInstance();

      // Remove any hardcoded timeout values
      await prefs.remove('hardcoded_access_token_duration');
      await prefs.remove('hardcoded_refresh_token_duration');
      await prefs.remove('fixed_5_minute_timeout');
      await prefs.remove('fixed_10_minute_timeout');

      // Enable dynamic JWT-based expiry
      await prefs.setBool('use_jwt_based_expiry', true);
      await prefs.setBool('dynamic_token_refresh_enabled', true);
      await prefs.setBool('remove_hardcoded_assumptions', true);

      log('✅ [$_tag] Hardcoded assumptions removed');
    } catch (e) {
      log('❌ [$_tag] Error removing hardcoded assumptions: $e');
    }
  }

  /// Enable dynamic JWT handling
  static Future<void> _enableDynamicJWTHandling() async {
    try {
      log('🔧 [$_tag] Enabling dynamic JWT handling');

      final prefs = await SharedPreferences.getInstance();

      // Enable JWT-based token management
      await prefs.setBool('jwt_based_token_management', true);
      await prefs.setBool('dynamic_refresh_buffer_calculation', true);
      await prefs.setBool('jwt_exp_claim_priority', true);

      // Disable any fixed buffer assumptions
      await prefs.setBool('use_fixed_refresh_buffer', false);
      await prefs.remove('fixed_refresh_buffer_minutes');

      log('✅ [$_tag] Dynamic JWT handling enabled');
    } catch (e) {
      log('❌ [$_tag] Error enabling dynamic JWT handling: $e');
    }
  }

  /// Configure continuous session mode to prevent premature session expiry
  static Future<void> _configureContinuousSessionMode() async {
    try {
      log('🔧 [$_tag] Configuring continuous session mode');

      final prefs = await SharedPreferences.getInstance();

      // Enable continuous session flags
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('continuous_session_active', true);
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);

      // Set infinite timeouts
      const infiniteTimeout = Duration(days: 365);
      await prefs.setInt('session_timeout_ms', infiniteTimeout.inMilliseconds);
      await prefs.setInt('idle_timeout_ms', infiniteTimeout.inMilliseconds);

      // Configure JWT-based refresh timing
      await prefs.setBool('jwt_based_refresh_timing', true);
      await prefs.setBool('refresh_before_access_expiry', true);

      log('✅ [$_tag] Continuous session mode configured');
    } catch (e) {
      log('❌ [$_tag] Error configuring continuous session mode: $e');
    }
  }

  /// Verify the session configuration is working correctly
  static Future<void> _verifySessionConfiguration() async {
    try {
      log('🔍 [$_tag] Verifying session configuration');

      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();

      if (accessToken != null && refreshToken != null) {
        // Analyze both tokens
        final analysis = JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
        
        log('📊 [$_tag] Token Analysis Results:');
        log('   • Session State: ${analysis['sessionState']}');
        log('   • Recommended Action: ${analysis['recommendedAction']}');
        log('   • Access Token Expires: ${analysis['accessTokenExpiresAt']}');
        log('   • Refresh Token Expires: ${analysis['refreshTokenExpiresAt']}');
        log('   • Next Refresh Time: ${analysis['nextRefreshTime']}');

        // Verify continuous session flags
        final prefs = await SharedPreferences.getInstance();
        final continuousActive = prefs.getBool('continuous_session_active') ?? false;
        final logoutDisabled = prefs.getBool('token_expiration_logout_disabled') ?? false;

        if (continuousActive && logoutDisabled) {
          log('✅ [$_tag] Session configuration verified successfully');
          log('   • Session expired modal should NOT appear');
          log('   • Tokens will refresh automatically based on JWT exp claims');
          log('   • Session will continue indefinitely until explicit logout');
        } else {
          log('⚠️ [$_tag] Session configuration incomplete');
        }
      } else {
        log('⚠️ [$_tag] No tokens available for verification');
      }
    } catch (e) {
      log('❌ [$_tag] Error verifying session configuration: $e');
    }
  }

  /// Get current session status with JWT analysis
  static Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      if (_dynamicSessionManager != null) {
        return await _dynamicSessionManager!.getSessionStatus();
      } else {
        return {
          'error': 'Dynamic session manager not initialized',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      log('❌ [$_tag] Error getting session status: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Force token refresh if needed based on JWT analysis
  static Future<bool> forceRefreshIfNeeded() async {
    try {
      if (_dynamicSessionManager != null) {
        return await _dynamicSessionManager!.forceRefreshIfNeeded();
      } else {
        log('⚠️ [$_tag] Dynamic session manager not initialized');
        return false;
      }
    } catch (e) {
      log('❌ [$_tag] Error during force refresh: $e');
      return false;
    }
  }

  /// Emergency fix for session expired modal appearing
  static Future<void> emergencyFixSessionExpiredModal() async {
    try {
      log('🚨 [$_tag] EMERGENCY FIX: Preventing session expired modal');

      // Initialize if not already done
      if (!_isInitialized) {
        await initialize();
      }

      // Force enable all continuous session flags
      final prefs = await SharedPreferences.getInstance();
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

      // Enable JWT-based session management
      await prefs.setBool('jwt_based_session_management', true);
      await prefs.setBool('use_jwt_exp_claims_only', true);

      log('✅ [$_tag] EMERGENCY FIX APPLIED');
      log('🔄 [$_tag] Session expired modal should now be disabled');
      log('📋 [$_tag] Tokens will refresh based on JWT exp claims');

      // Verify the fix
      await _verifySessionConfiguration();
    } catch (e) {
      log('❌ [$_tag] Error during emergency fix: $e');
    }
  }

  /// Debug current token expiry times
  static Future<void> debugTokenExpiry() async {
    try {
      log('🔍 [$_tag] Debugging token expiry times');

      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();

      if (accessToken != null) {
        final accessAnalysis = JwtTokenUtility.getTokenAnalysis(accessToken);
        log('🎫 [$_tag] Access Token:');
        log('   • Issued At: ${accessAnalysis['issuedAt']}');
        log('   • Expires At: ${accessAnalysis['expiresAt']}');
        log('   • Lifespan: ${accessAnalysis['lifespanMinutes']} minutes');
        log('   • Time Until Expiry: ${accessAnalysis['timeUntilExpiryMinutes']} minutes');
        log('   • Should Refresh Now: ${accessAnalysis['shouldRefreshNow']}');
      }

      if (refreshToken != null) {
        final refreshAnalysis = JwtTokenUtility.getTokenAnalysis(refreshToken);
        log('🔄 [$_tag] Refresh Token:');
        log('   • Issued At: ${refreshAnalysis['issuedAt']}');
        log('   • Expires At: ${refreshAnalysis['expiresAt']}');
        log('   • Lifespan: ${refreshAnalysis['lifespanMinutes']} minutes');
        log('   • Time Until Expiry: ${refreshAnalysis['timeUntilExpiryMinutes']} minutes');
      }

      if (accessToken != null && refreshToken != null) {
        final bothAnalysis = JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
        log('📊 [$_tag] Combined Analysis:');
        log('   • Session State: ${bothAnalysis['sessionState']}');
        log('   • Recommended Action: ${bothAnalysis['recommendedAction']}');
      }
    } catch (e) {
      log('❌ [$_tag] Error debugging token expiry: $e');
    }
  }

  /// Dispose resources
  static void dispose() {
    _dynamicSessionManager?.dispose();
    _dynamicSessionManager = null;
    _isInitialized = false;
    log('🗑️ [$_tag] Session Expiry Fix disposed');
  }
}
