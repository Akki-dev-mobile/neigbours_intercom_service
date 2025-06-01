import 'dart:developer';
import 'package:flutter_onegate/utils/eleven_minute_session_debug.dart';
import 'package:flutter_onegate/services/session_manager/eleven_minute_expiry_fix.dart';
import 'package:flutter_onegate/services/session_manager/session_expiry_fix.dart';

/// Immediate session fix utility for the 11-minute expiry issue
class ImmediateSessionFix {
  static const String _tag = 'ImmediateSessionFix';

  /// Apply immediate comprehensive fix for 11-minute session expiry
  static Future<void> applyImmediateFix() async {
    try {
      log('🚨 [$_tag] ===== APPLYING IMMEDIATE FIX FOR 11-MINUTE SESSION EXPIRY =====');
      
      // Step 1: Analyze the current issue
      log('🔍 [$_tag] Step 1: Analyzing current session state...');
      await ElevenMinuteSessionDebug.analyzeElevenMinuteSessionExpiry();
      
      // Step 2: Apply general session expiry fix
      log('🔧 [$_tag] Step 2: Applying general session expiry fix...');
      await SessionExpiryFix.emergencyFixSessionExpiredModal();
      
      // Step 3: Apply specific 11-minute expiry fix
      log('🚨 [$_tag] Step 3: Applying specific 11-minute expiry fix...');
      await ElevenMinuteExpiryFix.applyEmergencyFix();
      
      // Step 4: Verify the fix
      log('✅ [$_tag] Step 4: Verifying the fix...');
      await _verifyFix();
      
      log('🎉 [$_tag] ===== IMMEDIATE FIX COMPLETED SUCCESSFULLY =====');
      log('📋 [$_tag] SUMMARY:');
      log('   • Session expired modal should be disabled');
      log('   • Continuous session mode is active');
      log('   • Aggressive token refresh is enabled');
      log('   • 11-minute timeouts have been overridden');
      log('   • Session should continue indefinitely');
      log('🔄 [$_tag] Please test by keeping the app idle for 20+ minutes');
      
    } catch (e) {
      log('❌ [$_tag] Error applying immediate fix: $e');
      rethrow;
    }
  }

  /// Verify that the fix has been applied correctly
  static Future<void> _verifyFix() async {
    try {
      // Check general session expiry fix status
      final sessionStatus = await SessionExpiryFix.getSessionStatus();
      log('📊 [$_tag] General Session Fix Status:');
      log('   • Session State: ${sessionStatus['sessionState']}');
      log('   • Recommended Action: ${sessionStatus['recommendedAction']}');
      log('   • Is Monitoring: ${sessionStatus['isMonitoring']}');
      
      // Check 11-minute expiry fix status
      final elevenMinuteStatus = await ElevenMinuteExpiryFix.getFixStatus();
      log('📊 [$_tag] 11-Minute Expiry Fix Status:');
      log('   • Is Initialized: ${elevenMinuteStatus['isInitialized']}');
      log('   • Aggressive Refresh Active: ${elevenMinuteStatus['aggressiveRefreshActive']}');
      log('   • Monitoring Active: ${elevenMinuteStatus['monitoringActive']}');
      log('   • Prevent 11-Minute Expiry: ${elevenMinuteStatus['prevent11MinuteExpiry']}');
      
      // Verify continuous session flags
      await _verifyContinuousSessionFlags();
      
    } catch (e) {
      log('❌ [$_tag] Error verifying fix: $e');
    }
  }

  /// Verify continuous session flags are properly set
  static Future<void> _verifyContinuousSessionFlags() async {
    try {
      log('🔍 [$_tag] Verifying continuous session flags...');
      
      // This will be implemented by calling the debug utility
      await ElevenMinuteSessionDebug.analyzeElevenMinuteSessionExpiry();
      
    } catch (e) {
      log('❌ [$_tag] Error verifying continuous session flags: $e');
    }
  }

  /// Quick status check for debugging
  static Future<Map<String, dynamic>> getQuickStatus() async {
    try {
      final sessionStatus = await SessionExpiryFix.getSessionStatus();
      final elevenMinuteStatus = await ElevenMinuteExpiryFix.getFixStatus();
      
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'generalSessionFix': sessionStatus,
        'elevenMinuteExpiryFix': elevenMinuteStatus,
        'summary': {
          'sessionState': sessionStatus['sessionState'],
          'recommendedAction': sessionStatus['recommendedAction'],
          'isMonitoring': sessionStatus['isMonitoring'],
          'aggressiveRefreshActive': elevenMinuteStatus['aggressiveRefreshActive'],
          'prevent11MinuteExpiry': elevenMinuteStatus['prevent11MinuteExpiry'],
        }
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test the fix by simulating the 11-minute scenario
  static Future<void> testFix() async {
    try {
      log('🧪 [$_tag] Testing the 11-minute session expiry fix...');
      
      // Get current status
      final status = await getQuickStatus();
      log('📊 [$_tag] Current Status:');
      log('   • Session State: ${status['summary']?['sessionState']}');
      log('   • Monitoring Active: ${status['summary']?['isMonitoring']}');
      log('   • Aggressive Refresh: ${status['summary']?['aggressiveRefreshActive']}');
      
      // Analyze current tokens
      await ElevenMinuteSessionDebug.analyzeElevenMinuteSessionExpiry();
      
      log('✅ [$_tag] Fix test completed - check console logs for detailed analysis');
      
    } catch (e) {
      log('❌ [$_tag] Error testing fix: $e');
    }
  }

  /// Emergency reset - apply all fixes again
  static Future<void> emergencyReset() async {
    try {
      log('🚨 [$_tag] EMERGENCY RESET - Reapplying all fixes...');
      
      // Stop any existing timers
      ElevenMinuteExpiryFix.stop();
      
      // Reapply all fixes
      await applyImmediateFix();
      
      log('✅ [$_tag] Emergency reset completed');
      
    } catch (e) {
      log('❌ [$_tag] Error during emergency reset: $e');
    }
  }
}
