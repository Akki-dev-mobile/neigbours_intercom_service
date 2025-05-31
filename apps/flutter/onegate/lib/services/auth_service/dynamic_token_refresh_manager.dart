import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';
import 'package:flutter_onegate/services/auth_service/refresh_token_error_handler.dart';

/// Dynamic token refresh manager that adapts refresh timing based on JWT token lifespan
class DynamicTokenRefreshManager {
  static final DynamicTokenRefreshManager _instance =
      DynamicTokenRefreshManager._internal();
  factory DynamicTokenRefreshManager() => _instance;
  DynamicTokenRefreshManager._internal();

  // Core dependencies
  final EnhancedTokenRefreshManager _tokenManager =
      EnhancedTokenRefreshManager();
  final TokenNotificationService _notificationService =
      TokenNotificationService();

  // Dynamic refresh state
  Timer? _dynamicRefreshTimer;
  Duration? _currentRefreshBuffer;
  DateTime? _nextScheduledRefresh;
  String? _lastAnalyzedToken;
  bool _isInitialized = false;

  // Configuration for dynamic system
  static const Duration _checkInterval =
      Duration(seconds: 30); // More frequent checks
  static const Duration _fallbackBuffer =
      Duration(minutes: 1); // Fallback if analysis fails

  /// Initialize the dynamic token refresh system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Dynamic Token Refresh Manager");

      // Start dynamic refresh monitoring
      await _startDynamicRefreshMonitoring();

      _isInitialized = true;
      log("✅ Dynamic Token Refresh Manager initialized successfully");
    } catch (e) {
      log("❌ Error initializing Dynamic Token Refresh Manager: $e");
      rethrow;
    }
  }

  /// Start dynamic refresh monitoring with intelligent scheduling
  Future<void> _startDynamicRefreshMonitoring() async {
    _dynamicRefreshTimer?.cancel();

    _dynamicRefreshTimer = Timer.periodic(_checkInterval, (timer) async {
      await _performDynamicRefreshCheck();
    });

    log("🔄 Started dynamic token refresh monitoring (every ${_checkInterval.inSeconds} seconds)");
  }

  /// Stop dynamic refresh monitoring
  void stopDynamicRefreshMonitoring() {
    _dynamicRefreshTimer?.cancel();
    _dynamicRefreshTimer = null;
    _nextScheduledRefresh = null;
    log("⏹️ Stopped dynamic token refresh monitoring");
  }

  /// Perform dynamic refresh check with intelligent timing
  Future<void> _performDynamicRefreshCheck() async {
    try {
      // Get current access token
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        log("⚠️ No access token available for dynamic refresh check");
        return;
      }

      // Analyze token if it's new or changed
      if (_lastAnalyzedToken != accessToken) {
        await _analyzeAndScheduleRefresh(accessToken);
        _lastAnalyzedToken = accessToken;
      }

      // Check if it's time for scheduled refresh
      if (_nextScheduledRefresh != null &&
          DateTime.now().isAfter(_nextScheduledRefresh!)) {
        log("⏰ Scheduled refresh time reached, initiating token refresh");
        await _performScheduledRefresh();
      }
    } catch (e) {
      log("❌ Error during dynamic refresh check: $e");
    }
  }

  /// Analyze token and schedule optimal refresh time
  Future<void> _analyzeAndScheduleRefresh(String accessToken) async {
    try {
      log("🔍 Analyzing token for dynamic refresh scheduling");

      // Get comprehensive token analysis
      final analysis = JwtTokenUtility.getTokenAnalysis(accessToken);

      if (analysis.containsKey('error')) {
        log("❌ Token analysis failed: ${analysis['error']}");
        _scheduleWithFallbackBuffer(accessToken);
        return;
      }

      // Extract analysis results
      final lifespanMinutes = analysis['lifespanMinutes'] as int?;
      final refreshBuffer = analysis['refreshBuffer'] as int?;
      final refreshTimeStr = analysis['refreshTime'] as String?;

      if (lifespanMinutes == null ||
          refreshBuffer == null ||
          refreshTimeStr == null) {
        log("⚠️ Incomplete token analysis, using fallback scheduling");
        _scheduleWithFallbackBuffer(accessToken);
        return;
      }

      // Parse refresh time
      final refreshTime = DateTime.parse(refreshTimeStr);

      // Update current state
      _currentRefreshBuffer = Duration(minutes: refreshBuffer);
      _nextScheduledRefresh = refreshTime;

      log("📊 Dynamic refresh scheduled:");
      log("   • Token lifespan: $lifespanMinutes minutes");
      log("   • Refresh buffer: $refreshBuffer minutes");
      log("   • Next refresh: $refreshTime");
      log("   • Time until refresh: ${refreshTime.difference(DateTime.now()).inMinutes} minutes");

      // Show notification for very short-lived tokens
      if (lifespanMinutes < 10) {
        _notificationService
            .showTokenExpirationWarning(Duration(minutes: lifespanMinutes));
      }
    } catch (e) {
      log("❌ Error analyzing token for dynamic refresh: $e");
      _scheduleWithFallbackBuffer(accessToken);
    }
  }

  /// Schedule refresh with fallback buffer when analysis fails
  void _scheduleWithFallbackBuffer(String accessToken) {
    try {
      final expirationTime =
          JwtTokenUtility.getTokenExpirationTime(accessToken);
      if (expirationTime != null) {
        _currentRefreshBuffer = _fallbackBuffer;
        _nextScheduledRefresh = expirationTime.subtract(_fallbackBuffer);

        log("⚠️ Using fallback refresh scheduling:");
        log("   • Fallback buffer: ${_fallbackBuffer.inMinutes} minutes");
        log("   • Next refresh: $_nextScheduledRefresh");
      } else {
        log("❌ Cannot schedule refresh - no expiration time available");
      }
    } catch (e) {
      log("❌ Error scheduling fallback refresh: $e");
    }
  }

  /// Perform scheduled token refresh
  Future<void> _performScheduledRefresh() async {
    try {
      log("🔄 Performing scheduled token refresh");

      final refreshed = await _tokenManager.refreshTokenIfNeeded();

      if (refreshed) {
        log("✅ Scheduled token refresh successful");

        // Analyze new token and reschedule
        final newToken = await _tokenManager.getValidAccessToken();
        if (newToken != null) {
          await _analyzeAndScheduleRefresh(newToken);
          _lastAnalyzedToken = newToken;
        }
      } else {
        log("❌ Scheduled token refresh failed");

        // Handle refresh failure with error handler
        await _handleScheduledRefreshFailure();

        // Retry with shorter interval
        _nextScheduledRefresh = DateTime.now().add(const Duration(minutes: 1));
        log("⏳ Rescheduled refresh retry in 1 minute");
      }
    } catch (e) {
      log("❌ Error during scheduled refresh: $e");

      // Reschedule with fallback
      _nextScheduledRefresh = DateTime.now().add(_fallbackBuffer);
    }
  }

  /// Get dynamic access token with intelligent refresh
  Future<String?> getDynamicValidAccessToken() async {
    try {
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        log("❌ No access token available");
        return null;
      }

      // Check if token should be refreshed based on dynamic analysis
      if (JwtTokenUtility.shouldRefreshTokenNow(accessToken)) {
        log("🔄 Dynamic analysis recommends immediate token refresh");

        final refreshed = await _tokenManager.refreshTokenIfNeeded();
        if (refreshed) {
          final newToken = await _tokenManager.getValidAccessToken();
          if (newToken != null) {
            // Update scheduling for new token
            await _analyzeAndScheduleRefresh(newToken);
            _lastAnalyzedToken = newToken;
          }
          return newToken;
        } else {
          log("❌ Dynamic token refresh failed");
          return null;
        }
      }

      return accessToken;
    } catch (e) {
      log("❌ Error getting dynamic valid access token: $e");
      return null;
    }
  }

  /// Get current dynamic refresh status
  Map<String, dynamic> getDynamicRefreshStatus() {
    try {
      return {
        'isInitialized': _isInitialized,
        'currentRefreshBuffer': _currentRefreshBuffer?.inMinutes,
        'nextScheduledRefresh': _nextScheduledRefresh?.toIso8601String(),
        'hasScheduledRefresh': _nextScheduledRefresh != null,
        'timeUntilNextRefresh':
            _nextScheduledRefresh?.difference(DateTime.now()).inMinutes,
        'checkInterval': _checkInterval.inSeconds,
        'fallbackBuffer': _fallbackBuffer.inMinutes,
        'lastAnalyzedToken': _lastAnalyzedToken?.substring(0, 20),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Force immediate token analysis and refresh scheduling
  Future<void> forceTokenAnalysis() async {
    try {
      log("🔍 Forcing immediate token analysis");

      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken != null) {
        await _analyzeAndScheduleRefresh(accessToken);
        _lastAnalyzedToken = accessToken;
        log("✅ Forced token analysis completed");
      } else {
        log("❌ No token available for forced analysis");
      }
    } catch (e) {
      log("❌ Error during forced token analysis: $e");
    }
  }

  /// Handle app lifecycle changes
  Future<void> handleAppLifecycleChange(bool isAppInForeground) async {
    try {
      if (isAppInForeground) {
        log("📱 App resumed - checking token status");

        // Force immediate analysis when app resumes
        await forceTokenAnalysis();

        // Restart monitoring if stopped
        if (!_isInitialized) {
          await initialize();
        }
      } else {
        log("📱 App backgrounded - maintaining refresh schedule");
        // Keep monitoring active in background for continuous access
      }
    } catch (e) {
      log("❌ Error handling app lifecycle change: $e");
    }
  }

  /// Handle scheduled refresh failure
  Future<void> _handleScheduledRefreshFailure() async {
    try {
      log("🔍 Handling scheduled refresh failure");

      // Analyze the failure and determine if continuous session should be affected
      await RefreshTokenErrorHandler.handleRefreshTokenFailure(
        Exception('Scheduled token refresh failed'),
        1, // First attempt for scheduled refresh
        RefreshTokenFailureType.unknown,
      );
    } catch (e) {
      log("❌ Error handling scheduled refresh failure: $e");
    }
  }

  /// Dispose resources
  void dispose() {
    stopDynamicRefreshMonitoring();
    _currentRefreshBuffer = null;
    _nextScheduledRefresh = null;
    _lastAnalyzedToken = null;
    _isInitialized = false;
    log("🗑️ Dynamic Token Refresh Manager disposed");
  }
}
