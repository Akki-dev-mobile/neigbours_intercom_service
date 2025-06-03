import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User session manager with automatic token refresh and session monitoring
class UserSessionManager {
  static final UserSessionManager _instance = UserSessionManager._internal();

  factory UserSessionManager() {
    return _instance;
  }

  UserSessionManager._internal();

  late final GateStorage _gateStorage;
  late final AuthService _authService;

  Timer? _sessionMonitorTimer;
  Timer? _tokenRefreshTimer;

  final StreamController<UserSessionState> _sessionStateController =
      StreamController<UserSessionState>.broadcast();

  bool _isInitialized = false;
  UserSessionState _currentState = UserSessionState.unknown;

  /// Stream of session state changes
  Stream<UserSessionState> get sessionStateStream =>
      _sessionStateController.stream;

  /// Current session state
  UserSessionState get currentState => _currentState;

  /// Initialize the session manager with unified session management
  Future<void> initialize() async {
    if (_isInitialized) return;

    _gateStorage = GetIt.I<GateStorage>();
    _authService = GetIt.I<AuthService>();

    // Enable continuous session management by default
    await _enableContinuousSessionManagement();

    // Check initial session state
    await _checkSessionState();

    // Start session monitoring with more frequent checks
    _startSessionMonitoring();

    // Start token refresh monitoring with intelligent timing
    _startTokenRefreshMonitoring();

    _isInitialized = true;
    log("✅ Unified Session Manager initialized with continuous session support");
  }

  /// Enable continuous session management
  Future<void> _enableContinuousSessionManagement() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Set all necessary flags for continuous session
      await prefs.setBool('token_expiration_logout_disabled', true);
      await prefs.setBool('auto_logout_disabled', true);
      await prefs.setBool('session_timeout_disabled', true);
      await prefs.setBool('idle_timeout_disabled', true);
      await prefs.setBool('continuous_session_active', true);

      // Set infinite timeout values
      final infiniteTimeout = const Duration(days: 365).inMilliseconds;
      await prefs.setInt('session_timeout_ms', infiniteTimeout);
      await prefs.setInt('idle_timeout_ms', infiniteTimeout);

      log("🔒 Continuous session management enabled");
    } catch (e) {
      log("❌ Error enabling continuous session management: $e");
    }
  }

  /// Start session monitoring
  void _startSessionMonitoring() {
    _sessionMonitorTimer?.cancel();
    _sessionMonitorTimer = Timer.periodic(
      const Duration(minutes: 1), // Check every minute
      (_) => _checkSessionState(),
    );
  }

  /// Start token refresh monitoring
  void _startTokenRefreshMonitoring() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 1), // Check every 1 minute for short-lived tokens
      (_) => _checkAndRefreshToken(),
    );
  }

  /// Check current session state
  Future<void> _checkSessionState() async {
    try {
      final isAuthenticated = await _authService.isAuthenticated();

      if (isAuthenticated) {
        final sessionData = await _authService.getCurrentUserSession();
        if (sessionData != null) {
          _updateSessionState(UserSessionState.authenticated);
        } else {
          _updateSessionState(UserSessionState.unauthenticated);
        }
      } else {
        _updateSessionState(UserSessionState.unauthenticated);
      }
    } catch (e) {
      log("❌ Error checking session state: $e");
      _updateSessionState(UserSessionState.error);
    }
  }

  /// Check and refresh token if needed using dynamic JWT analysis
  Future<void> _checkAndRefreshToken() async {
    try {
      // Check if we're currently on login screen - skip token checks if so
      if (await _isOnLoginScreen()) {
        log("📱 Currently on login screen - skipping token check");
        return;
      }

      // Check if token expiration logout is disabled (continuous session mode)
      final prefs = await SharedPreferences.getInstance();
      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;
      final jwtBasedSessionManagement =
          prefs.getBool('jwt_based_session_management') ?? false;

      // Check if any continuous session mechanism is active
      final isContinuousSessionMode = tokenExpirationLogoutDisabled ||
          autoLogoutDisabled ||
          continuousSessionActive;

      // Use JWT-based analysis if enabled
      if (jwtBasedSessionManagement) {
        await _performJWTBasedTokenCheck(isContinuousSessionMode);
      } else {
        // Fallback to legacy token expiry check
        await _performLegacyTokenCheck(isContinuousSessionMode);
      }
    } catch (e) {
      log("❌ Error checking/refreshing token: $e");
    }
  }

  /// Check if currently on login screen or navigating to it
  Future<bool> _isOnLoginScreen() async {
    try {
      // Use the coordinator to check if session monitoring should be paused
      final shouldPause =
          await SessionManagementCoordinator.shouldPauseSessionMonitoring();
      if (shouldPause) {
        log('🔍 Session Management Coordinator indicates login state');
        return true;
      }

      // Fallback: Check if we have no valid tokens
      final accessToken = await _gateStorage.getAccessToken();
      if (accessToken == null) {
        log('🔍 No access token found - user should be on login screen');
        return true;
      }

      return false;
    } catch (e) {
      log('❌ Error checking if on login screen: $e');
      return false;
    }
  }

  /// Perform JWT-based token check using dynamic analysis
  Future<void> _performJWTBasedTokenCheck(bool isContinuousSessionMode) async {
    try {
      final accessToken = await _gateStorage.getAccessToken();
      final refreshToken = await _gateStorage.getRefreshToken();

      if (accessToken == null || refreshToken == null) {
        log("⚠️ Missing tokens for JWT analysis");
        if (!isContinuousSessionMode) {
          _updateSessionState(UserSessionState.unauthenticated);
        }
        return;
      }

      // Analyze both tokens using JWT utility
      final analysis =
          JwtTokenUtility.analyzeBothTokens(accessToken, refreshToken);
      final sessionState = analysis['sessionState'] as String?;
      final recommendedAction = analysis['recommendedAction'] as String?;
      final shouldRefreshNow = analysis['shouldRefreshNow'] as bool? ?? false;

      log("🔍 JWT-based token analysis:");
      log("   • Session State: $sessionState");
      log("   • Recommended Action: $recommendedAction");
      log("   • Should Refresh Now: $shouldRefreshNow");

      // Handle based on JWT analysis
      switch (recommendedAction) {
        case 'refreshAccessToken':
          if (shouldRefreshNow) {
            log("🔄 JWT analysis recommends token refresh");
            final refreshed = await _authService.refreshToken();

            if (refreshed) {
              log("✅ JWT-based token refresh successful");
              _updateSessionState(UserSessionState.authenticated);
            } else {
              log("❌ JWT-based token refresh failed");
              await _handleRefreshFailure(isContinuousSessionMode);
            }
          } else {
            log("ℹ️ JWT analysis: Token refresh not needed yet");
            _updateSessionState(UserSessionState.authenticated);
          }
          break;
        case 'reauthenticate':
          log("⚠️ JWT analysis: Both tokens expired, reauthentication needed");
          await _handleSessionExpired(isContinuousSessionMode);
          break;
        case 'none':
          log("✅ JWT analysis: Session is active, no action needed");
          _updateSessionState(UserSessionState.authenticated);
          break;
        default:
          log("⚠️ Unknown JWT analysis recommendation: $recommendedAction");
          await _performLegacyTokenCheck(isContinuousSessionMode);
      }
    } catch (e) {
      log("❌ Error during JWT-based token check: $e");
      await _performLegacyTokenCheck(isContinuousSessionMode);
    }
  }

  /// Perform legacy token check (fallback)
  Future<void> _performLegacyTokenCheck(bool isContinuousSessionMode) async {
    try {
      final isExpired = await _gateStorage.isTokenExpired();

      if (isExpired) {
        log("🔄 Legacy check: Token expired, attempting refresh...");
        final refreshed = await _authService.refreshToken();

        if (refreshed) {
          log("✅ Legacy token refresh successful");
          _updateSessionState(UserSessionState.authenticated);
        } else {
          log("❌ Legacy token refresh failed");
          await _handleRefreshFailure(isContinuousSessionMode);
        }
      } else {
        log("✅ Legacy check: Token is valid");
        _updateSessionState(UserSessionState.authenticated);
      }
    } catch (e) {
      log("❌ Error during legacy token check: $e");
    }
  }

  /// Handle token refresh failure
  Future<void> _handleRefreshFailure(bool isContinuousSessionMode) async {
    if (!isContinuousSessionMode) {
      log("⏰ Continuous session mode not active - setting tokenExpired state");
      _updateSessionState(UserSessionState.tokenExpired);
    } else {
      log("🔒 Continuous session mode active - maintaining session and retrying refresh");
      _scheduleRetryRefresh();
    }
  }

  /// Handle session expired scenario
  Future<void> _handleSessionExpired(bool isContinuousSessionMode) async {
    if (!isContinuousSessionMode) {
      log("🚪 Session expired - triggering logout");
      _updateSessionState(UserSessionState.tokenExpired);
    } else {
      log("🔒 Continuous session mode active - attempting recovery");
      _scheduleRetryRefresh();
    }
  }

  /// Schedule retry refresh for continuous session mode
  void _scheduleRetryRefresh() {
    Timer(const Duration(seconds: 30), () async {
      log("🔄 Retrying token refresh in continuous session mode");
      await _checkAndRefreshToken();
    });
  }

  /// Update session state and notify listeners
  void _updateSessionState(UserSessionState newState) {
    if (_currentState != newState) {
      final previousState = _currentState;
      _currentState = newState;

      log("🔄 Session state changed: $previousState → $newState");
      _sessionStateController.add(newState);

      // Handle specific state transitions
      _handleStateTransition(previousState, newState);
    }
  }

  /// Handle state transitions
  void _handleStateTransition(UserSessionState from, UserSessionState to) {
    switch (to) {
      case UserSessionState.authenticated:
        log("✅ User session authenticated");
        break;
      case UserSessionState.unauthenticated:
        log("🚪 User session unauthenticated");
        _clearSessionData();
        break;
      case UserSessionState.tokenExpired:
        log("⏰ User session token expired");
        break;
      case UserSessionState.error:
        log("❌ User session error");
        break;
      case UserSessionState.unknown:
        log("❓ User session state unknown");
        break;
    }
  }

  /// Clear session data
  Future<void> _clearSessionData() async {
    try {
      // Clear tokens and user data
      await _authService.logout();
      log("✅ Session data cleared");
    } catch (e) {
      log("❌ Error clearing session data: $e");
    }
  }

  /// Get current user session information
  Future<Map<String, dynamic>?> getCurrentUserSession() async {
    try {
      return await _authService.getCurrentUserSession();
    } catch (e) {
      log("❌ Error getting current user session: $e");
      return null;
    }
  }

  /// Check if user has specific role
  Future<bool> hasRole(String role) async {
    try {
      final roles = await _gateStorage.getUserRoles();
      return roles.contains(role);
    } catch (e) {
      log("❌ Error checking user role: $e");
      return false;
    }
  }

  /// Check if user has any of the specified roles
  Future<bool> hasAnyRole(List<String> roles) async {
    try {
      final userRoles = await _gateStorage.getUserRoles();
      return roles.any((role) => userRoles.contains(role));
    } catch (e) {
      log("❌ Error checking user roles: $e");
      return false;
    }
  }

  /// Get user permissions based on roles
  Future<Set<String>> getUserPermissions() async {
    try {
      final roles = await _gateStorage.getUserRoles();
      final permissions = <String>{};

      // Map roles to permissions
      for (final role in roles) {
        permissions.addAll(_getPermissionsForRole(role));
      }

      return permissions;
    } catch (e) {
      log("❌ Error getting user permissions: $e");
      return {};
    }
  }

  /// Get permissions for a specific role
  Set<String> _getPermissionsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'super_admin':
        return {
          'manage_users',
          'manage_societies',
          'manage_gates',
          'view_all_visitors',
          'approve_visitors',
          'manage_settings',
        };
      case 'gatekeeper':
        return {
          'view_visitors',
          'approve_visitors',
          'create_visitor_entry',
          'update_visitor_status',
        };
      case 'security':
        return {
          'view_visitors',
          'create_visitor_entry',
          'update_visitor_status',
        };
      case 'resident':
        return {
          'view_own_visitors',
          'approve_own_visitors',
        };
      default:
        return {'view_basic'};
    }
  }

  /// Check if user has specific permission
  Future<bool> hasPermission(String permission) async {
    final permissions = await getUserPermissions();
    return permissions.contains(permission);
  }

  /// Force session refresh
  Future<void> refreshSession() async {
    log("🔄 Forcing session refresh...");
    await _checkSessionState();
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _authService.logout();
      _updateSessionState(UserSessionState.unauthenticated);
      log("✅ User logged out successfully");
    } catch (e) {
      log("❌ Error during logout: $e");
      rethrow;
    }
  }

  /// Get session duration
  Future<Duration?> getSessionDuration() async {
    try {
      final sessionTimestamp = await _gateStorage.getSessionTimestamp();
      if (sessionTimestamp != null) {
        return DateTime.now().difference(sessionTimestamp);
      }
    } catch (e) {
      log("❌ Error getting session duration: $e");
    }
    return null;
  }

  /// Dispose resources
  void dispose() {
    _sessionMonitorTimer?.cancel();
    _tokenRefreshTimer?.cancel();
    _sessionStateController.close();
    _isInitialized = false;
    log("✅ UserSessionManager disposed");
  }
}

/// User session states
enum UserSessionState {
  unknown,
  authenticated,
  unauthenticated,
  tokenExpired,
  error,
}
