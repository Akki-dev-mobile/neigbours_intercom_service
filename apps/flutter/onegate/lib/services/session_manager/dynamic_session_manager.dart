import 'dart:async';
import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Dynamic Session Manager that handles JWT-based token expiry without hardcoded assumptions
class DynamicSessionManager {
  static final DynamicSessionManager _instance = DynamicSessionManager._internal();
  factory DynamicSessionManager() => _instance;
  DynamicSessionManager._internal();

  // Dependencies
  late final AuthService _authService;
  late final GateStorage _gateStorage;

  // State management
  bool _isInitialized = false;
  Timer? _dynamicRefreshTimer;
  DateTime? _nextScheduledRefresh;
  String? _currentAccessToken;
  String? _currentRefreshToken;

  // Configuration
  static const Duration _checkInterval = Duration(seconds: 30); // Check every 30 seconds
  static const String _tag = 'DynamicSessionManager';

  /// Initialize the dynamic session manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _authService = GetIt.I<AuthService>();
      _gateStorage = GetIt.I<GateStorage>();

      // Load current tokens
      await _loadCurrentTokens();

      // Start dynamic monitoring
      await _startDynamicMonitoring();

      _isInitialized = true;
      log('✅ [$_tag] Dynamic Session Manager initialized');
    } catch (e) {
      log('❌ [$_tag] Error initializing: $e');
      rethrow;
    }
  }

  /// Load current tokens from storage
  Future<void> _loadCurrentTokens() async {
    try {
      _currentAccessToken = await _gateStorage.getAccessToken();
      _currentRefreshToken = await _gateStorage.getRefreshToken();
      
      log('📋 [$_tag] Loaded tokens:');
      log('   • Access Token: ${_currentAccessToken != null ? "Present" : "Missing"}');
      log('   • Refresh Token: ${_currentRefreshToken != null ? "Present" : "Missing"}');
    } catch (e) {
      log('❌ [$_tag] Error loading tokens: $e');
    }
  }

  /// Start dynamic monitoring based on JWT expiry times
  Future<void> _startDynamicMonitoring() async {
    _dynamicRefreshTimer?.cancel();

    _dynamicRefreshTimer = Timer.periodic(_checkInterval, (timer) async {
      await _performDynamicCheck();
    });

    log('🔄 [$_tag] Started dynamic monitoring (every ${_checkInterval.inSeconds}s)');
  }

  /// Perform dynamic check based on actual JWT expiry times
  Future<void> _performDynamicCheck() async {
    try {
      // Reload tokens in case they were updated
      await _loadCurrentTokens();

      if (_currentAccessToken == null || _currentRefreshToken == null) {
        log('⚠️ [$_tag] Missing tokens, skipping dynamic check');
        return;
      }

      // Analyze both tokens
      final analysis = JwtTokenUtility.analyzeBothTokens(_currentAccessToken, _currentRefreshToken);
      
      final sessionState = analysis['sessionState'] as String?;
      final recommendedAction = analysis['recommendedAction'] as String?;
      final shouldRefreshNow = analysis['shouldRefreshNow'] as bool? ?? false;

      log('🔍 [$_tag] Dynamic Check Results:');
      log('   • Session State: $sessionState');
      log('   • Recommended Action: $recommendedAction');
      log('   • Should Refresh Now: $shouldRefreshNow');

      // Handle different scenarios
      switch (recommendedAction) {
        case 'refreshAccessToken':
          if (shouldRefreshNow) {
            log('🔄 [$_tag] Performing scheduled token refresh');
            await _performTokenRefresh();
          } else {
            _scheduleNextRefresh(analysis);
          }
          break;
        case 'reauthenticate':
          await _handleSessionExpired();
          break;
        case 'none':
          _scheduleNextRefresh(analysis);
          break;
        default:
          log('⚠️ [$_tag] Unknown recommended action: $recommendedAction');
      }
    } catch (e) {
      log('❌ [$_tag] Error during dynamic check: $e');
    }
  }

  /// Schedule next refresh based on JWT analysis
  void _scheduleNextRefresh(Map<String, dynamic> analysis) {
    try {
      final nextRefreshTimeStr = analysis['nextRefreshTime'] as String?;
      if (nextRefreshTimeStr != null) {
        _nextScheduledRefresh = DateTime.parse(nextRefreshTimeStr);
        final timeUntilRefresh = _nextScheduledRefresh!.difference(DateTime.now());
        
        log('⏰ [$_tag] Next refresh scheduled for: $_nextScheduledRefresh');
        log('   • Time until refresh: ${timeUntilRefresh.inMinutes}min ${timeUntilRefresh.inSeconds % 60}s');
      }
    } catch (e) {
      log('❌ [$_tag] Error scheduling next refresh: $e');
    }
  }

  /// Perform token refresh using AuthService
  Future<bool> _performTokenRefresh() async {
    try {
      log('🔄 [$_tag] Starting token refresh...');
      
      final refreshed = await _authService.refreshToken();
      
      if (refreshed) {
        log('✅ [$_tag] Token refresh successful');
        
        // Reload tokens after refresh
        await _loadCurrentTokens();
        
        // Log new token details
        if (_currentAccessToken != null) {
          final newAnalysis = JwtTokenUtility.getTokenAnalysis(_currentAccessToken!);
          log('📊 [$_tag] New token details:');
          log('   • Expires At: ${newAnalysis['expiresAt']}');
          log('   • Lifespan: ${newAnalysis['lifespanMinutes']} minutes');
          log('   • Next Refresh: ${newAnalysis['refreshTime']}');
        }
        
        return true;
      } else {
        log('❌ [$_tag] Token refresh failed');
        return false;
      }
    } catch (e) {
      log('❌ [$_tag] Error during token refresh: $e');
      return false;
    }
  }

  /// Handle session expired scenario
  Future<void> _handleSessionExpired() async {
    try {
      log('⚠️ [$_tag] Session expired - both tokens are invalid');
      
      // Check if continuous session mode is active
      final prefs = await SharedPreferences.getInstance();
      final continuousSessionActive = prefs.getBool('continuous_session_active') ?? false;
      final tokenExpirationLogoutDisabled = prefs.getBool('token_expiration_logout_disabled') ?? false;
      
      if (continuousSessionActive || tokenExpirationLogoutDisabled) {
        log('🔒 [$_tag] Continuous session mode active - not triggering logout');
        return;
      }
      
      log('🚪 [$_tag] Triggering session expired handling');
      // The session expired modal will be handled by the existing UserSessionManager
      
    } catch (e) {
      log('❌ [$_tag] Error handling session expired: $e');
    }
  }

  /// Get current session status
  Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      await _loadCurrentTokens();
      
      if (_currentAccessToken == null || _currentRefreshToken == null) {
        return {
          'status': 'no_tokens',
          'hasAccessToken': _currentAccessToken != null,
          'hasRefreshToken': _currentRefreshToken != null,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      final analysis = JwtTokenUtility.analyzeBothTokens(_currentAccessToken, _currentRefreshToken);
      analysis['nextScheduledRefresh'] = _nextScheduledRefresh?.toIso8601String();
      analysis['isMonitoring'] = _dynamicRefreshTimer?.isActive ?? false;
      
      return analysis;
    } catch (e) {
      log('❌ [$_tag] Error getting session status: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Force immediate token refresh if needed
  Future<bool> forceRefreshIfNeeded() async {
    try {
      log('🔄 [$_tag] Force refresh check requested');
      
      await _loadCurrentTokens();
      
      if (_currentAccessToken == null || _currentRefreshToken == null) {
        log('❌ [$_tag] Cannot force refresh - missing tokens');
        return false;
      }

      final analysis = JwtTokenUtility.analyzeBothTokens(_currentAccessToken, _currentRefreshToken);
      final recommendedAction = analysis['recommendedAction'] as String?;
      
      if (recommendedAction == 'refreshAccessToken') {
        return await _performTokenRefresh();
      } else if (recommendedAction == 'reauthenticate') {
        log('⚠️ [$_tag] Cannot refresh - refresh token expired');
        await _handleSessionExpired();
        return false;
      } else {
        log('ℹ️ [$_tag] No refresh needed');
        return true;
      }
    } catch (e) {
      log('❌ [$_tag] Error during force refresh: $e');
      return false;
    }
  }

  /// Stop dynamic monitoring
  void stop() {
    _dynamicRefreshTimer?.cancel();
    _dynamicRefreshTimer = null;
    _nextScheduledRefresh = null;
    _isInitialized = false;
    log('⏹️ [$_tag] Dynamic session monitoring stopped');
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}
