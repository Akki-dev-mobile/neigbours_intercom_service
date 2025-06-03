import 'dart:async';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Coordinates multiple session management systems to prevent conflicts
/// and ensures session expired modals don't appear during login navigation
class SessionManagementCoordinator {
  static const String _tag = 'SessionCoordinator';
  static SessionManagementCoordinator? _instance;
  static bool _isInitialized = false;

  // State tracking
  bool _isOnLoginScreen = false;
  bool _isNavigatingToLogin = false;
  Timer? _loginStateCheckTimer;

  // Private constructor for singleton
  SessionManagementCoordinator._();

  /// Get singleton instance
  static SessionManagementCoordinator get instance {
    _instance ??= SessionManagementCoordinator._();
    return _instance!;
  }

  /// Initialize the coordinator
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('🎯 [$_tag] Initializing Session Management Coordinator');

      final coordinator = SessionManagementCoordinator.instance;
      await coordinator._setupLoginStateMonitoring();
      await coordinator._configureSessionSystems();

      _isInitialized = true;
      log('✅ [$_tag] Session Management Coordinator initialized successfully');
    } catch (e) {
      log('❌ [$_tag] Error initializing coordinator: $e');
      rethrow;
    }
  }

  /// Setup login state monitoring
  Future<void> _setupLoginStateMonitoring() async {
    try {
      // Check initial login state immediately
      _isOnLoginScreen = await _determineIfOnLoginScreen();
      await _handleLoginStateChange();

      // Start periodic check for login state
      _loginStateCheckTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkLoginState(),
      );

      log('🔍 [$_tag] Login state monitoring started (initial state: $_isOnLoginScreen)');
    } catch (e) {
      log('❌ [$_tag] Error setting up login state monitoring: $e');
    }
  }

  /// Configure session systems to work together
  Future<void> _configureSessionSystems() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Enable coordinated session management
      await prefs.setBool('coordinated_session_management', true);
      await prefs.setBool('login_screen_aware_session_management', true);

      // Prevent session expired modals during login
      await prefs.setBool('prevent_session_modal_during_login', true);

      log('⚙️ [$_tag] Session systems configured for coordination');
    } catch (e) {
      log('❌ [$_tag] Error configuring session systems: $e');
    }
  }

  /// Check current login state
  Future<void> _checkLoginState() async {
    try {
      final wasOnLoginScreen = _isOnLoginScreen;
      _isOnLoginScreen = await _determineIfOnLoginScreen();

      if (wasOnLoginScreen != _isOnLoginScreen) {
        log('📱 [$_tag] Login state changed: $wasOnLoginScreen → $_isOnLoginScreen');
        await _handleLoginStateChange();
      }
    } catch (e) {
      log('❌ [$_tag] Error checking login state: $e');
    }
  }

  /// Determine if currently on login screen
  Future<bool> _determineIfOnLoginScreen() async {
    try {
      // Check if we have no valid tokens (primary indicator)
      final gateStorage = GetIt.I<GateStorage>();
      final accessToken = await gateStorage.getAccessToken();

      if (accessToken == null) {
        log('🔍 [$_tag] No access token - user is on login screen');
        return true;
      }

      // Check if tokens are expired (secondary indicator)
      final isExpired = await gateStorage.isTokenExpired();
      if (isExpired) {
        log('🔍 [$_tag] Token expired - user should be on login screen');
        return true;
      }

      log('🔍 [$_tag] Valid token found - user is authenticated');
      return false;
    } catch (e) {
      log('❌ [$_tag] Error determining login screen state: $e');
      // Default to login screen state on error for safety
      return true;
    }
  }

  /// Handle login state changes
  Future<void> _handleLoginStateChange() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_isOnLoginScreen) {
        log('🚪 [$_tag] Entering login state - disabling session checks');

        // Disable session monitoring during login
        await prefs.setBool('session_monitoring_paused', true);
        await prefs.setBool('token_refresh_paused', true);

        // Prevent session expired modals
        await prefs.setBool('session_expired_modal_disabled', true);
      } else {
        log('✅ [$_tag] Exiting login state - re-enabling session checks');

        // Re-enable session monitoring after login
        await prefs.setBool('session_monitoring_paused', false);
        await prefs.setBool('token_refresh_paused', false);

        // Allow session expired modals again
        await prefs.setBool('session_expired_modal_disabled', false);
      }
    } catch (e) {
      log('❌ [$_tag] Error handling login state change: $e');
    }
  }

  /// Check if session expired modal should be shown
  static Future<bool> shouldShowSessionExpiredModal() async {
    try {
      final coordinator = SessionManagementCoordinator.instance;

      // Never show modal if on login screen
      if (coordinator._isOnLoginScreen || coordinator._isNavigatingToLogin) {
        log('📱 [$_tag] On login screen - blocking session expired modal');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      // Check if modals are disabled
      final modalDisabled =
          prefs.getBool('session_expired_modal_disabled') ?? false;
      if (modalDisabled) {
        log('🚫 [$_tag] Session expired modal disabled');
        return false;
      }

      // Check if continuous session mode is active
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;
      if (continuousSessionActive) {
        log('🔒 [$_tag] Continuous session active - blocking modal');
        return false;
      }

      return true;
    } catch (e) {
      log('❌ [$_tag] Error checking if should show session expired modal: $e');
      return false;
    }
  }

  /// Check if session monitoring should be paused
  static Future<bool> shouldPauseSessionMonitoring() async {
    try {
      final coordinator = SessionManagementCoordinator.instance;

      // Pause if on login screen
      if (coordinator._isOnLoginScreen || coordinator._isNavigatingToLogin) {
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('session_monitoring_paused') ?? false;
    } catch (e) {
      log('❌ [$_tag] Error checking if should pause session monitoring: $e');
      return false;
    }
  }

  /// Set navigation to login state
  static void setNavigatingToLogin(bool navigating) {
    final coordinator = SessionManagementCoordinator.instance;
    coordinator._isNavigatingToLogin = navigating;
    log('🔄 [$_tag] Navigation to login: $navigating');
  }

  /// Get current login screen state
  static bool get isOnLoginScreen {
    return SessionManagementCoordinator.instance._isOnLoginScreen;
  }

  /// Apply emergency fix for session expired modal during login
  static Future<void> applyEmergencyLoginFix() async {
    try {
      log('🚨 [$_tag] APPLYING EMERGENCY LOGIN FIX');

      final prefs = await SharedPreferences.getInstance();

      // Immediately disable session expired modals
      await prefs.setBool('session_expired_modal_disabled', true);
      await prefs.setBool('session_monitoring_paused', true);
      await prefs.setBool('token_refresh_paused', true);

      // Enable login screen awareness
      await prefs.setBool('login_screen_aware_session_management', true);
      await prefs.setBool('prevent_session_modal_during_login', true);

      log('✅ [$_tag] Emergency login fix applied');
    } catch (e) {
      log('❌ [$_tag] Error applying emergency login fix: $e');
    }
  }

  /// Dispose resources
  static void dispose() {
    try {
      final coordinator = SessionManagementCoordinator.instance;
      coordinator._loginStateCheckTimer?.cancel();
      coordinator._loginStateCheckTimer = null;

      _instance = null;
      _isInitialized = false;

      log('🗑️ [$_tag] Session Management Coordinator disposed');
    } catch (e) {
      log('❌ [$_tag] Error disposing coordinator: $e');
    }
  }
}
