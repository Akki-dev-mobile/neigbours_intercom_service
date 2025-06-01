import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/five_minute_token_fix.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Specialized debugging tool for investigating 10-minute session expiry
/// Focuses on token refresh behavior and Keycloak session management
class TenMinuteSessionDebug {
  static final TenMinuteSessionDebug _instance = TenMinuteSessionDebug._internal();
  factory TenMinuteSessionDebug() => _instance;
  TenMinuteSessionDebug._internal();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  Timer? _debugTimer;
  bool _isDebugging = false;
  DateTime? _sessionStartTime;
  List<Map<String, dynamic>> _tokenRefreshLog = [];

  /// Start debugging session with detailed token tracking
  Future<void> startDebugging() async {
    if (_isDebugging) return;

    _isDebugging = true;
    _sessionStartTime = DateTime.now();
    _tokenRefreshLog.clear();

    log("🔍 ===== STARTING 10-MINUTE SESSION DEBUG =====");
    log("🕐 Session Start Time: ${_sessionStartTime!.toIso8601String()}");

    // Initial comprehensive check
    await _logInitialTokenState();

    // Start monitoring every 30 seconds
    _debugTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _performPeriodicCheck();
    });

    log("✅ 10-minute session debugging started");
  }

  /// Stop debugging
  void stopDebugging() {
    _debugTimer?.cancel();
    _isDebugging = false;
    log("⏹️ 10-minute session debugging stopped");
  }

  /// Log initial token state
  Future<void> _logInitialTokenState() async {
    try {
      log("📋 ===== INITIAL TOKEN STATE =====");

      // Get tokens from all sources
      final secureAccessToken = await _secureStorage.read(key: 'access_token');
      final secureRefreshToken = await _secureStorage.read(key: 'refresh_token');
      
      final gateStorage = GetIt.I<GateStorage>();
      final gateAccessToken = await gateStorage.getAccessToken();
      final gateRefreshToken = await gateStorage.getRefreshToken();

      log("🔑 Secure Storage Access Token: ${secureAccessToken != null ? 'Present' : 'Missing'}");
      log("🔄 Secure Storage Refresh Token: ${secureRefreshToken != null ? 'Present' : 'Missing'}");
      log("🔑 Gate Storage Access Token: ${gateAccessToken != null ? 'Present' : 'Missing'}");
      log("🔄 Gate Storage Refresh Token: ${gateRefreshToken != null ? 'Present' : 'Missing'}");

      // Analyze access token if available
      if (secureAccessToken != null) {
        await _analyzeToken('ACCESS', secureAccessToken);
      }

      // Analyze refresh token if available
      if (secureRefreshToken != null) {
        await _analyzeToken('REFRESH', secureRefreshToken);
      }

      // Check session overrides
      await _checkSessionOverrides();

      log("📋 ===== END INITIAL STATE =====");
    } catch (e) {
      log("❌ Error logging initial token state: $e");
    }
  }

  /// Analyze a specific token
  Future<void> _analyzeToken(String tokenType, String token) async {
    try {
      log("🔍 Analyzing $tokenType Token:");
      
      final analysis = JwtTokenUtility.getTokenAnalysis(token);
      
      if (analysis.containsKey('error')) {
        log("   ❌ Error: ${analysis['error']}");
        return;
      }

      log("   • Issued At: ${analysis['issuedAt']}");
      log("   • Expires At: ${analysis['expiresAt']}");
      log("   • Lifespan: ${analysis['lifespanMinutes']} minutes");
      log("   • Time Until Expiry: ${analysis['timeUntilExpiryMinutes']} minutes");
      log("   • Should Refresh Now: ${analysis['shouldRefreshNow']}");
      log("   • Refresh Time: ${analysis['refreshTime']}");

      // Check for 10-minute patterns
      final lifespanMinutes = analysis['lifespanMinutes'] as int?;
      if (lifespanMinutes != null && lifespanMinutes >= 9 && lifespanMinutes <= 11) {
        log("   ⚠️ POTENTIAL 10-MINUTE TOKEN DETECTED!");
      }

      // Extract additional claims for refresh token analysis
      if (tokenType == 'REFRESH') {
        await _analyzeRefreshTokenClaims(token);
      }
    } catch (e) {
      log("❌ Error analyzing $tokenType token: $e");
    }
  }

  /// Analyze refresh token specific claims
  Future<void> _analyzeRefreshTokenClaims(String refreshToken) async {
    try {
      // Try to decode refresh token payload
      final payload = JwtTokenUtility.getUserInfoFromToken(refreshToken);
      if (payload != null) {
        log("   🔄 Refresh Token Claims:");
        log("      • Session State: ${payload['session_state']}");
        log("      • Scope: ${payload['scope']}");
        log("      • Client ID: ${payload['client_id']}");
        
        // Check for session-related claims
        if (payload.containsKey('session_state')) {
          log("      • Session State Present: ${payload['session_state']}");
        }
      }
    } catch (e) {
      log("   ⚠️ Could not decode refresh token claims: $e");
    }
  }

  /// Check session override status
  Future<void> _checkSessionOverrides() async {
    try {
      log("⚙️ Session Override Status:");
      
      final prefs = await SharedPreferences.getInstance();
      final fiveMinuteTokenFix = FiveMinuteTokenFix();
      final fixStatus = await fiveMinuteTokenFix.getSessionStatus();

      log("   • 5-Minute Fix Initialized: ${fixStatus['isInitialized']}");
      log("   • Timeout Override Active: ${fixStatus['timeoutOverrideActive']}");
      log("   • Token Logout Disabled: ${prefs.getBool('token_expiration_logout_disabled')}");
      log("   • Auto Logout Disabled: ${prefs.getBool('auto_logout_disabled')}");
    } catch (e) {
      log("❌ Error checking session overrides: $e");
    }
  }

  /// Perform periodic check during debugging
  Future<void> _performPeriodicCheck() async {
    if (!_isDebugging || _sessionStartTime == null) return;

    try {
      final now = DateTime.now();
      final sessionDuration = now.difference(_sessionStartTime!);
      
      log("🕐 ===== PERIODIC CHECK (${sessionDuration.inMinutes}:${(sessionDuration.inSeconds % 60).toString().padLeft(2, '0')}) =====");

      // Check if we're approaching the 10-minute mark
      if (sessionDuration.inMinutes >= 9 && sessionDuration.inMinutes < 11) {
        log("⚠️ APPROACHING 10-MINUTE MARK - CRITICAL MONITORING");
        await _performCriticalCheck();
      }

      // Regular token status check
      await _checkCurrentTokenStatus();

      // Check for recent refresh attempts
      await _checkRecentRefreshAttempts();

      log("🕐 ===== END PERIODIC CHECK =====");
    } catch (e) {
      log("❌ Error during periodic check: $e");
    }
  }

  /// Perform critical check near 10-minute mark
  Future<void> _performCriticalCheck() async {
    try {
      log("🚨 CRITICAL CHECK - MONITORING FOR 10-MINUTE EXPIRY");

      // Force token refresh attempt
      log("🔄 Forcing token refresh attempt...");
      final authService = GetIt.I<AuthService>();
      final refreshed = await authService.refreshToken();
      
      final refreshEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'success': refreshed,
        'sessionDuration': DateTime.now().difference(_sessionStartTime!).inMinutes,
      };
      
      _tokenRefreshLog.add(refreshEntry);
      
      if (refreshed) {
        log("✅ Critical refresh successful");
        await _logTokensAfterRefresh();
      } else {
        log("❌ Critical refresh failed - investigating...");
        await _investigateRefreshFailure();
      }
    } catch (e) {
      log("❌ Error during critical check: $e");
    }
  }

  /// Check current token status
  Future<void> _checkCurrentTokenStatus() async {
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      
      if (accessToken != null) {
        final analysis = JwtTokenUtility.getTokenAnalysis(accessToken);
        log("🎫 Current Token Status:");
        log("   • Time Until Expiry: ${analysis['timeUntilExpiryMinutes']} minutes");
        log("   • Should Refresh: ${analysis['shouldRefreshNow']}");
        log("   • Is Expired: ${await gateStorage.isTokenExpired()}");
      } else {
        log("❌ No access token available");
      }
    } catch (e) {
      log("❌ Error checking current token status: $e");
    }
  }

  /// Check for recent refresh attempts
  Future<void> _checkRecentRefreshAttempts() async {
    try {
      if (_tokenRefreshLog.isNotEmpty) {
        final recentRefreshes = _tokenRefreshLog.where((entry) {
          final timestamp = DateTime.parse(entry['timestamp']);
          return DateTime.now().difference(timestamp).inMinutes < 2;
        }).toList();

        if (recentRefreshes.isNotEmpty) {
          log("🔄 Recent Refresh Attempts (last 2 minutes):");
          for (final refresh in recentRefreshes) {
            log("   • ${refresh['timestamp']}: ${refresh['success'] ? 'SUCCESS' : 'FAILED'}");
          }
        }
      }
    } catch (e) {
      log("❌ Error checking recent refresh attempts: $e");
    }
  }

  /// Log tokens after successful refresh
  Future<void> _logTokensAfterRefresh() async {
    try {
      log("📝 Tokens After Refresh:");
      
      final secureAccessToken = await _secureStorage.read(key: 'access_token');
      if (secureAccessToken != null) {
        final analysis = JwtTokenUtility.getTokenAnalysis(secureAccessToken);
        log("   • New Access Token Lifespan: ${analysis['lifespanMinutes']} minutes");
        log("   • New Expiry Time: ${analysis['expiresAt']}");
      }

      final secureRefreshToken = await _secureStorage.read(key: 'refresh_token');
      if (secureRefreshToken != null) {
        log("   • Refresh Token Updated: Yes");
        await _analyzeToken('REFRESH', secureRefreshToken);
      } else {
        log("   • Refresh Token Updated: No");
      }
    } catch (e) {
      log("❌ Error logging tokens after refresh: $e");
    }
  }

  /// Investigate refresh failure
  Future<void> _investigateRefreshFailure() async {
    try {
      log("🔍 Investigating Refresh Failure:");

      // Check refresh token availability
      final secureRefreshToken = await _secureStorage.read(key: 'refresh_token');
      log("   • Refresh Token Available: ${secureRefreshToken != null}");

      if (secureRefreshToken != null) {
        // Analyze refresh token
        final analysis = JwtTokenUtility.getTokenAnalysis(secureRefreshToken);
        log("   • Refresh Token Expired: ${analysis['isExpired'] ?? 'Unknown'}");
        log("   • Refresh Token Expiry: ${analysis['expiresAt']}");
      }

      // Check network connectivity and Keycloak endpoint
      log("   • Keycloak Token Endpoint: https://stgsso.cubeone.in/realms/fstech/protocol/openid-connect/token");
      log("   • Client ID: flutter-dummy");
    } catch (e) {
      log("❌ Error investigating refresh failure: $e");
    }
  }

  /// Get comprehensive debug report
  Future<String> getDebugReport() async {
    final report = StringBuffer();
    
    report.writeln("🔍 10-MINUTE SESSION DEBUG REPORT");
    report.writeln("=" * 50);
    
    if (_sessionStartTime != null) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      report.writeln("Session Duration: ${sessionDuration.inMinutes}:${(sessionDuration.inSeconds % 60).toString().padLeft(2, '0')}");
    }
    
    report.writeln("Total Refresh Attempts: ${_tokenRefreshLog.length}");
    
    if (_tokenRefreshLog.isNotEmpty) {
      report.writeln("\nRefresh Log:");
      for (final entry in _tokenRefreshLog) {
        report.writeln("  ${entry['timestamp']}: ${entry['success'] ? 'SUCCESS' : 'FAILED'} (${entry['sessionDuration']}min)");
      }
    }
    
    // Add current token status
    try {
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();
      if (accessToken != null) {
        final analysis = JwtTokenUtility.getTokenAnalysis(accessToken);
        report.writeln("\nCurrent Token:");
        report.writeln("  Lifespan: ${analysis['lifespanMinutes']} minutes");
        report.writeln("  Time Until Expiry: ${analysis['timeUntilExpiryMinutes']} minutes");
        report.writeln("  Should Refresh: ${analysis['shouldRefreshNow']}");
      }
    } catch (e) {
      report.writeln("\nError getting current token status: $e");
    }
    
    return report.toString();
  }

  /// Dispose resources
  void dispose() {
    stopDebugging();
    _tokenRefreshLog.clear();
    log("🗑️ 10-minute session debug disposed");
  }
}
