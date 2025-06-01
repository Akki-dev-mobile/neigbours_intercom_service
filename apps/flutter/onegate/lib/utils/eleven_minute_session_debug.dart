import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/session_expiry_fix.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Specific debug utility for the 11-minute session expiry issue
class ElevenMinuteSessionDebug {
  static const String _tag = 'ElevenMinuteSessionDebug';

  /// Comprehensive analysis of the 11-minute session expiry issue
  static Future<void> analyzeElevenMinuteSessionExpiry() async {
    try {
      log('🔍 [$_tag] ===== ANALYZING 11-MINUTE SESSION EXPIRY ISSUE =====');
      
      // Step 1: Analyze current tokens and their actual expiry times
      await _analyzeCurrentTokens();
      
      // Step 2: Check if session expiry fix is properly initialized
      await _checkSessionExpiryFixStatus();
      
      // Step 3: Verify continuous session mode configuration
      await _verifyContinuousSessionConfiguration();
      
      // Step 4: Identify potential causes of 11-minute expiry
      await _identifyPotentialCauses();
      
      // Step 5: Check for any remaining hardcoded timeouts
      await _checkForHardcodedTimeouts();
      
      // Step 6: Analyze token refresh patterns
      await _analyzeTokenRefreshPatterns();
      
      // Step 7: Provide specific recommendations
      await _provideRecommendations();
      
      log('🔍 [$_tag] ===== END 11-MINUTE SESSION EXPIRY ANALYSIS =====');
    } catch (e) {
      log('❌ [$_tag] Error during 11-minute session expiry analysis: $e');
    }
  }

  /// Analyze current tokens and their actual expiry times
  static Future<void> _analyzeCurrentTokens() async {
    try {
      log('🎫 [$_tag] ANALYZING CURRENT TOKENS:');
      
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      
      if (accessToken == null || refreshToken == null) {
        log('❌ [$_tag] Missing tokens - cannot analyze');
        return;
      }
      
      // Analyze both tokens
      final analysis = JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
      
      log('📊 [$_tag] Token Analysis Results:');
      log('   • Session State: ${analysis['sessionState']}');
      log('   • Recommended Action: ${analysis['recommendedAction']}');
      
      // Access Token Details
      final accessExpiresAt = analysis['accessTokenExpiresAt'] as String?;
      final accessTimeUntilExpiry = analysis['accessTokenTimeUntilExpiry'] as int?;
      
      if (accessExpiresAt != null && accessTimeUntilExpiry != null) {
        log('🔑 [$_tag] Access Token:');
        log('   • Expires At: $accessExpiresAt');
        log('   • Time Until Expiry: ${(accessTimeUntilExpiry / 60).toStringAsFixed(1)} minutes');
        log('   • Is Expired: ${analysis['accessTokenIsExpired']}');
      }
      
      // Refresh Token Details
      final refreshExpiresAt = analysis['refreshTokenExpiresAt'] as String?;
      final refreshTimeUntilExpiry = analysis['refreshTokenTimeUntilExpiry'] as int?;
      
      if (refreshExpiresAt != null && refreshTimeUntilExpiry != null) {
        log('🔄 [$_tag] Refresh Token:');
        log('   • Expires At: $refreshExpiresAt');
        log('   • Time Until Expiry: ${(refreshTimeUntilExpiry / 60).toStringAsFixed(1)} minutes');
        log('   • Is Expired: ${analysis['refreshTokenIsExpired']}');
        
        // Check if refresh token is causing the 11-minute issue
        final refreshMinutes = refreshTimeUntilExpiry / 60;
        if (refreshMinutes <= 12 && refreshMinutes >= 10) {
          log('🚨 [$_tag] POTENTIAL CAUSE: Refresh token expires in ~11 minutes!');
          log('   • This likely explains the 11-minute session expiry');
          log('   • Refresh token lifespan is too short for continuous session');
        }
      }
      
      // Individual token analysis
      final accessAnalysis = JwtTokenUtility.getTokenAnalysis(accessToken);
      final refreshAnalysis = JwtTokenUtility.getTokenAnalysis(refreshToken);
      
      log('📋 [$_tag] Token Lifespans:');
      log('   • Access Token Lifespan: ${accessAnalysis['lifespanMinutes']} minutes');
      log('   • Refresh Token Lifespan: ${refreshAnalysis['lifespanMinutes']} minutes');
      
    } catch (e) {
      log('❌ [$_tag] Error analyzing current tokens: $e');
    }
  }

  /// Check if session expiry fix is properly initialized
  static Future<void> _checkSessionExpiryFixStatus() async {
    try {
      log('🔧 [$_tag] CHECKING SESSION EXPIRY FIX STATUS:');
      
      // Get session status from the fix
      final status = await SessionExpiryFix.getSessionStatus();
      
      if (status.containsKey('error')) {
        log('❌ [$_tag] Session Expiry Fix Error: ${status['error']}');
        return;
      }
      
      log('📊 [$_tag] Session Expiry Fix Status:');
      log('   • Session State: ${status['sessionState']}');
      log('   • Recommended Action: ${status['recommendedAction']}');
      log('   • Is Monitoring: ${status['isMonitoring']}');
      log('   • Next Scheduled Refresh: ${status['nextScheduledRefresh']}');
      
      if (status['isMonitoring'] != true) {
        log('⚠️ [$_tag] WARNING: Dynamic session monitoring is not active!');
        log('   • This could be causing the session expiry issue');
      }
      
    } catch (e) {
      log('❌ [$_tag] Error checking session expiry fix status: $e');
    }
  }

  /// Verify continuous session mode configuration
  static Future<void> _verifyContinuousSessionConfiguration() async {
    try {
      log('⚙️ [$_tag] VERIFYING CONTINUOUS SESSION CONFIGURATION:');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Check all critical flags
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
      
      log('🏁 [$_tag] Continuous Session Flags:');
      bool allCriticalFlagsSet = true;
      
      flags.forEach((key, value) {
        final status = value ? '✅' : '❌';
        log('   $status $key: $value');
        
        // Check critical flags
        if (['token_expiration_logout_disabled', 'auto_logout_disabled', 'continuous_session_active'].contains(key) && !value) {
          allCriticalFlagsSet = false;
        }
      });
      
      if (!allCriticalFlagsSet) {
        log('🚨 [$_tag] CRITICAL ISSUE: Not all continuous session flags are enabled!');
        log('   • This is likely causing the 11-minute session expiry');
      } else {
        log('✅ [$_tag] All critical continuous session flags are enabled');
      }
      
      // Check timeout values
      final sessionTimeoutMs = prefs.getInt('session_timeout_ms');
      final idleTimeoutMs = prefs.getInt('idle_timeout_ms');
      
      log('⏰ [$_tag] Timeout Values:');
      if (sessionTimeoutMs != null) {
        final sessionTimeoutMinutes = Duration(milliseconds: sessionTimeoutMs).inMinutes;
        log('   • Session Timeout: $sessionTimeoutMinutes minutes');
        
        if (sessionTimeoutMinutes <= 15) {
          log('🚨 [$_tag] POTENTIAL CAUSE: Session timeout is set to $sessionTimeoutMinutes minutes!');
        }
      } else {
        log('   • Session Timeout: Not Set');
      }
      
      if (idleTimeoutMs != null) {
        final idleTimeoutMinutes = Duration(milliseconds: idleTimeoutMs).inMinutes;
        log('   • Idle Timeout: $idleTimeoutMinutes minutes');
        
        if (idleTimeoutMinutes <= 15) {
          log('🚨 [$_tag] POTENTIAL CAUSE: Idle timeout is set to $idleTimeoutMinutes minutes!');
        }
      } else {
        log('   • Idle Timeout: Not Set');
      }
      
    } catch (e) {
      log('❌ [$_tag] Error verifying continuous session configuration: $e');
    }
  }

  /// Identify potential causes of 11-minute expiry
  static Future<void> _identifyPotentialCauses() async {
    try {
      log('🔍 [$_tag] IDENTIFYING POTENTIAL CAUSES OF 11-MINUTE EXPIRY:');
      
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // Look for any 11-minute or 660-second timeouts
      final suspiciousTimeouts = <String, dynamic>{};
      
      for (final key in allKeys) {
        try {
          final value = prefs.get(key);
          
          if (value is int) {
            // Check for 11-minute timeouts (660 seconds or 660000 milliseconds)
            if (value == 660 || value == 660000 || value == 11) {
              suspiciousTimeouts[key] = value;
            }
            
            // Check for values that could represent 11 minutes in different units
            final minutes = value / 60000; // Convert milliseconds to minutes
            if (minutes >= 10.5 && minutes <= 11.5) {
              suspiciousTimeouts[key] = '$value ms (${minutes.toStringAsFixed(1)} min)';
            }
          }
        } catch (e) {
          // Skip keys that can't be read
        }
      }
      
      if (suspiciousTimeouts.isNotEmpty) {
        log('🚨 [$_tag] SUSPICIOUS 11-MINUTE TIMEOUTS FOUND:');
        suspiciousTimeouts.forEach((key, value) {
          log('   • $key: $value');
        });
      } else {
        log('✅ [$_tag] No obvious 11-minute timeouts found in SharedPreferences');
      }
      
      // Check for Keycloak-specific timeout configurations
      await _checkKeycloakTimeouts();
      
    } catch (e) {
      log('❌ [$_tag] Error identifying potential causes: $e');
    }
  }

  /// Check for Keycloak-specific timeout configurations
  static Future<void> _checkKeycloakTimeouts() async {
    try {
      log('🔐 [$_tag] CHECKING KEYCLOAK TIMEOUT CONFIGURATIONS:');
      
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      
      if (accessToken != null && refreshToken != null) {
        // Parse JWT tokens to check for Keycloak-specific claims
        final accessPayload = JwtTokenUtility.parseJwtToken(accessToken);
        final refreshPayload = JwtTokenUtility.parseJwtToken(refreshToken);
        
        if (accessPayload != null) {
          log('🔑 [$_tag] Access Token Claims:');
          log('   • iss (issuer): ${accessPayload['iss']}');
          log('   • aud (audience): ${accessPayload['aud']}');
          log('   • typ (type): ${accessPayload['typ']}');
          
          // Check for session-related claims
          if (accessPayload.containsKey('session_state')) {
            log('   • session_state: ${accessPayload['session_state']}');
          }
          
          if (accessPayload.containsKey('scope')) {
            log('   • scope: ${accessPayload['scope']}');
          }
        }
        
        if (refreshPayload != null) {
          log('🔄 [$_tag] Refresh Token Claims:');
          log('   • typ (type): ${refreshPayload['typ']}');
          
          // Calculate actual token lifespans from JWT claims
          final accessIat = accessPayload?['iat'];
          final accessExp = accessPayload?['exp'];
          final refreshIat = refreshPayload['iat'];
          final refreshExp = refreshPayload['exp'];
          
          if (accessIat != null && accessExp != null) {
            final accessLifespanSeconds = accessExp - accessIat;
            final accessLifespanMinutes = accessLifespanSeconds / 60;
            log('   • Access Token Actual Lifespan: ${accessLifespanMinutes.toStringAsFixed(1)} minutes');
          }
          
          if (refreshIat != null && refreshExp != null) {
            final refreshLifespanSeconds = refreshExp - refreshIat;
            final refreshLifespanMinutes = refreshLifespanSeconds / 60;
            log('   • Refresh Token Actual Lifespan: ${refreshLifespanMinutes.toStringAsFixed(1)} minutes');
            
            if (refreshLifespanMinutes >= 10.5 && refreshLifespanMinutes <= 11.5) {
              log('🚨 [$_tag] FOUND THE ISSUE: Refresh token lifespan is ~11 minutes!');
              log('   • This is configured on the Keycloak server');
              log('   • The refresh token expires at exactly 11 minutes, causing session expiry');
              log('   • Solution: Increase refresh token lifespan on Keycloak server to 30-60 minutes');
            }
          }
        }
      }
      
    } catch (e) {
      log('❌ [$_tag] Error checking Keycloak timeouts: $e');
    }
  }

  /// Check for any remaining hardcoded timeouts
  static Future<void> _checkForHardcodedTimeouts() async {
    try {
      log('⏰ [$_tag] CHECKING FOR HARDCODED TIMEOUTS:');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Check for common hardcoded timeout patterns
      final timeoutKeys = [
        'session_timeout',
        'idle_timeout',
        'token_timeout',
        'auth_timeout',
        'refresh_timeout',
        'expiry_timeout',
        'logout_timeout',
      ];
      
      bool foundHardcodedTimeouts = false;
      
      for (final key in timeoutKeys) {
        final value = prefs.get(key);
        if (value != null) {
          log('   • $key: $value');
          foundHardcodedTimeouts = true;
        }
      }
      
      if (!foundHardcodedTimeouts) {
        log('✅ [$_tag] No obvious hardcoded timeouts found');
      }
      
    } catch (e) {
      log('❌ [$_tag] Error checking for hardcoded timeouts: $e');
    }
  }

  /// Analyze token refresh patterns
  static Future<void> _analyzeTokenRefreshPatterns() async {
    try {
      log('🔄 [$_tag] ANALYZING TOKEN REFRESH PATTERNS:');
      
      // Check if dynamic session manager is running
      final status = await SessionExpiryFix.getSessionStatus();
      
      if (status['isMonitoring'] == true) {
        log('✅ [$_tag] Dynamic session monitoring is active');
        log('   • Next refresh: ${status['nextScheduledRefresh']}');
      } else {
        log('❌ [$_tag] Dynamic session monitoring is NOT active');
        log('   • This could be causing the session expiry issue');
      }
      
      // Check UserSessionManager state
      final userSessionManager = GetIt.I<UserSessionManager>();
      final currentState = userSessionManager.currentState;
      log('📊 [$_tag] UserSessionManager State: $currentState');
      
    } catch (e) {
      log('❌ [$_tag] Error analyzing token refresh patterns: $e');
    }
  }

  /// Provide specific recommendations
  static Future<void> _provideRecommendations() async {
    try {
      log('💡 [$_tag] RECOMMENDATIONS TO FIX 11-MINUTE SESSION EXPIRY:');
      
      log('1. 🔐 KEYCLOAK SERVER CONFIGURATION:');
      log('   • Increase refresh token lifespan from 11 minutes to 30-60 minutes');
      log('   • Check Keycloak realm settings → Tokens → Refresh Token Lifespan');
      log('   • Recommended: Set to at least 30 minutes for continuous session');
      
      log('2. 🔧 APP-SIDE IMMEDIATE FIXES:');
      log('   • Apply emergency session expiry fix');
      log('   • Force enable all continuous session flags');
      log('   • Restart dynamic session monitoring');
      
      log('3. 🔍 MONITORING:');
      log('   • Use session debug widget to monitor token refresh');
      log('   • Check console logs for token refresh failures');
      log('   • Monitor actual JWT exp claims vs configured timeouts');
      
    } catch (e) {
      log('❌ [$_tag] Error providing recommendations: $e');
    }
  }

  /// Apply emergency fix for 11-minute session expiry
  static Future<void> applyEmergencyFixFor11MinuteExpiry() async {
    try {
      log('🚨 [$_tag] APPLYING EMERGENCY FIX FOR 11-MINUTE SESSION EXPIRY');
      
      // Step 1: Apply the general session expiry fix
      await SessionExpiryFix.emergencyFixSessionExpiredModal();
      
      // Step 2: Force enable all continuous session flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('continuous_session_active', true);
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      await prefs.setBool('disable_idle_timeout', true);
      
      // Step 3: Set infinite timeouts to override any 11-minute timeouts
      const infiniteTimeout = Duration(days: 365);
      await prefs.setInt('session_timeout_ms', infiniteTimeout.inMilliseconds);
      await prefs.setInt('idle_timeout_ms', infiniteTimeout.inMilliseconds);
      
      // Step 4: Enable aggressive token refresh
      await prefs.setBool('aggressive_token_refresh', true);
      await prefs.setBool('prevent_11_minute_expiry', true);
      
      // Step 5: Force token refresh if needed
      final refreshed = await SessionExpiryFix.forceRefreshIfNeeded();
      
      log('✅ [$_tag] Emergency fix applied successfully');
      log('   • Continuous session flags: Enabled');
      log('   • Infinite timeouts: Set');
      log('   • Aggressive refresh: Enabled');
      log('   • Token refresh: ${refreshed ? "Successful" : "Not needed"}');
      
      // Step 6: Verify the fix
      await analyzeElevenMinuteSessionExpiry();
      
    } catch (e) {
      log('❌ [$_tag] Error applying emergency fix: $e');
    }
  }
}
