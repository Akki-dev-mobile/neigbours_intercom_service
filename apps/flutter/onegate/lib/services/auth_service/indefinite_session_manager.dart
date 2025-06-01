import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';

/// Configuration and management for indefinite user sessions
/// This ensures users never get automatically logged out unless explicitly requested
class IndefiniteSessionManager with WidgetsBindingObserver {
  static final IndefiniteSessionManager _instance =
      IndefiniteSessionManager._internal();
  factory IndefiniteSessionManager() => _instance;
  IndefiniteSessionManager._internal();

  final SecureTokenManager _tokenManager = SecureTokenManager();
  final UnifiedAuthService _authService = UnifiedAuthService();

  // Configuration
  static const Duration _aggressiveRefreshInterval = Duration(minutes: 2);
  static const Duration _fallbackRefreshInterval = Duration(minutes: 5);
  static const Duration _resumeRefreshInterval =
      Duration(seconds: 30); // Quick refresh when app resumes
  static const int _maxRetryAttempts = 5;
  static const Duration _retryBackoffBase = Duration(seconds: 30);

  // State management
  Timer? _backgroundRefreshTimer;
  bool _isEnabled = false;
  int _consecutiveFailures = 0;
  AppLifecycleState? _lastAppState;

  /// Enable indefinite session management
  /// This will aggressively refresh tokens to prevent any automatic logout
  Future<void> enableIndefiniteSessions() async {
    if (_isEnabled) return;

    try {
      log('🔄 Enabling indefinite session management...');

      _isEnabled = true;
      _consecutiveFailures = 0;

      // Register for app lifecycle events
      WidgetsBinding.instance.addObserver(this);

      // Start aggressive background refresh
      await _startBackgroundRefresh();

      log('✅ Indefinite session management enabled');
    } catch (e) {
      log('❌ Error enabling indefinite sessions: $e');
      _isEnabled = false;
    }
  }

  /// Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    log('📱 App lifecycle state changed: ${state.name}');

    if (_lastAppState != null && _lastAppState != state) {
      switch (state) {
        case AppLifecycleState.resumed:
          _onAppResumed();
          break;
        case AppLifecycleState.paused:
          _onAppPaused();
          break;
        case AppLifecycleState.detached:
          _onAppDetached();
          break;
        case AppLifecycleState.inactive:
          // App is transitioning, no action needed
          break;
        case AppLifecycleState.hidden:
          // App is hidden but still running
          break;
      }
    }

    _lastAppState = state;
  }

  /// Handle app resuming from background
  void _onAppResumed() {
    log('🔄 App resumed, checking token validity...');

    if (_isEnabled) {
      // Immediately check and refresh tokens when app resumes
      Timer(_resumeRefreshInterval, () {
        log('⚡ Quick token refresh after app resume');
        _attemptTokenRefresh();
      });
    }
  }

  /// Handle app going to background
  void _onAppPaused() {
    log('⏸️ App paused, background refresh will continue if possible');
    // Background refresh continues automatically
  }

  /// Handle app being detached/terminated
  void _onAppDetached() {
    log('🛑 App detached, background refresh will stop');
    // Background refresh will stop when app is terminated
  }

  /// Disable indefinite session management
  void disableIndefiniteSessions() {
    log('🛑 Disabling indefinite session management...');

    _isEnabled = false;
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = null;
    _consecutiveFailures = 0;

    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    log('✅ Indefinite session management disabled');
  }

  /// Start aggressive background token refresh
  Future<void> _startBackgroundRefresh() async {
    _backgroundRefreshTimer?.cancel();

    if (!_isEnabled) return;

    try {
      // Check if we're authenticated
      final isAuthenticated = await _authService.isAuthenticated();
      if (!isAuthenticated) {
        log('⚠️ User not authenticated, stopping background refresh');
        return;
      }

      // Attempt token refresh
      final refreshSuccess = await _attemptTokenRefresh();

      if (refreshSuccess) {
        _consecutiveFailures = 0;
        // Schedule next refresh with normal interval
        _scheduleNextRefresh(_aggressiveRefreshInterval);
      } else {
        _consecutiveFailures++;
        log('⚠️ Token refresh failed (attempt $_consecutiveFailures/$_maxRetryAttempts)');

        if (_consecutiveFailures >= _maxRetryAttempts) {
          log('❌ Max refresh failures reached, but continuing to try...');
          // Don't give up - keep trying with longer intervals
          _scheduleNextRefresh(_fallbackRefreshInterval);
        } else {
          // Exponential backoff for retries
          final backoffDuration = Duration(
            seconds: _retryBackoffBase.inSeconds * _consecutiveFailures,
          );
          _scheduleNextRefresh(backoffDuration);
        }
      }
    } catch (e) {
      log('❌ Error in background refresh: $e');
      _scheduleNextRefresh(_fallbackRefreshInterval);
    }
  }

  /// Attempt token refresh with enhanced error handling
  Future<bool> _attemptTokenRefresh() async {
    try {
      log('🔄 Attempting background token refresh...');

      // Use the enhanced refresh method from SecureTokenManager
      final success = await _tokenManager.refreshTokens();

      if (success) {
        log('✅ Background token refresh successful');
        return true;
      } else {
        log('⚠️ Background token refresh failed');
        return false;
      }
    } catch (e) {
      log('❌ Background token refresh error: $e');
      return false;
    }
  }

  /// Schedule the next refresh attempt
  void _scheduleNextRefresh(Duration interval) {
    if (!_isEnabled) return;

    _backgroundRefreshTimer?.cancel();

    log('⏰ Scheduling next background refresh in ${interval.inMinutes} minutes');

    _backgroundRefreshTimer = Timer(interval, () {
      _startBackgroundRefresh();
    });
  }

  /// Force immediate token refresh
  Future<bool> forceRefresh() async {
    try {
      log('🚀 Force refreshing tokens...');

      final success = await _attemptTokenRefresh();

      if (success) {
        _consecutiveFailures = 0;
        // Restart the background refresh cycle
        if (_isEnabled) {
          await _startBackgroundRefresh();
        }
      }

      return success;
    } catch (e) {
      log('❌ Force refresh error: $e');
      return false;
    }
  }

  /// Get current session status
  Map<String, dynamic> getSessionStatus() {
    return {
      'indefinite_sessions_enabled': _isEnabled,
      'consecutive_failures': _consecutiveFailures,
      'background_refresh_active': _backgroundRefreshTimer?.isActive ?? false,
      'next_refresh_in_seconds': _backgroundRefreshTimer != null
          ? _aggressiveRefreshInterval.inSeconds
          : null,
    };
  }

  /// Handle authentication state changes
  void onAuthStateChanged(bool isAuthenticated) {
    if (isAuthenticated && _isEnabled) {
      log('🔄 User authenticated, restarting background refresh');
      _startBackgroundRefresh();
    } else if (!isAuthenticated) {
      log('🛑 User not authenticated, stopping background refresh');
      _backgroundRefreshTimer?.cancel();
      _consecutiveFailures = 0;
    }
  }

  /// Dispose resources
  void dispose() {
    disableIndefiniteSessions();
    log('🗑️ IndefiniteSessionManager disposed');
  }
}

/// Enhanced UnifiedAuthService with indefinite session support
/// Uses composition instead of inheritance due to singleton pattern
class EnhancedUnifiedAuthService {
  static final EnhancedUnifiedAuthService _instance =
      EnhancedUnifiedAuthService._internal();
  factory EnhancedUnifiedAuthService() => _instance;
  EnhancedUnifiedAuthService._internal();

  final UnifiedAuthService _authService = UnifiedAuthService();
  final IndefiniteSessionManager _sessionManager = IndefiniteSessionManager();

  bool _isInitialized = false;

  /// Initialize the enhanced auth service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _authService.initialize();

    // Enable indefinite sessions by default
    await _sessionManager.enableIndefiniteSessions();

    // Listen to auth state changes
    _authService.authStateStream.listen((isAuthenticated) {
      _sessionManager.onAuthStateChanged(isAuthenticated);
    });

    _isInitialized = true;
  }

  /// Perform login with indefinite session support
  Future<Map<String, dynamic>?> login() async {
    final result = await _authService.login();

    if (result != null) {
      // Ensure indefinite sessions are enabled after login
      await _sessionManager.enableIndefiniteSessions();
    }

    return result;
  }

  /// Logout and disable indefinite sessions
  Future<void> logout() async {
    // Disable indefinite sessions before logout
    _sessionManager.disableIndefiniteSessions();
    await _authService.logout();
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _authService.isAuthenticated();
  }

  /// Get current user information
  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await _authService.getCurrentUser();
  }

  /// Get a valid access token (will refresh if needed)
  Future<String?> getValidAccessToken() async {
    return await _authService.getValidAccessToken();
  }

  /// Manually refresh tokens
  Future<bool> refreshTokens() async {
    return await _authService.refreshTokens();
  }

  /// Get user roles from token
  Future<List<String>> getUserRoles() async {
    return await _authService.getUserRoles();
  }

  /// Check if user has specific permission/role
  Future<bool> hasRole(String role) async {
    return await _authService.hasRole(role);
  }

  /// Stream of authentication state changes
  Stream<bool> get authStateStream => _authService.authStateStream;

  /// Force immediate token refresh
  Future<bool> forceTokenRefresh() async {
    return await _sessionManager.forceRefresh();
  }

  /// Get session management status
  Map<String, dynamic> getSessionStatus() {
    return _sessionManager.getSessionStatus();
  }

  /// Enable/disable indefinite sessions
  Future<void> setIndefiniteSessionsEnabled(bool enabled) async {
    if (enabled) {
      await _sessionManager.enableIndefiniteSessions();
    } else {
      _sessionManager.disableIndefiniteSessions();
    }
  }

  /// Dispose resources
  void dispose() {
    _sessionManager.dispose();
    _authService.dispose();
  }
}
