import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:get_it/get_it.dart';

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

  /// Initialize the session manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    _gateStorage = GetIt.I<GateStorage>();
    _authService = GetIt.I<AuthService>();

    // Check initial session state
    await _checkSessionState();

    // Start session monitoring
    _startSessionMonitoring();

    // Start token refresh monitoring
    _startTokenRefreshMonitoring();

    _isInitialized = true;
    log("✅ UserSessionManager initialized");
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
      const Duration(minutes: 5), // Check every 5 minutes
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

  /// Check and refresh token if needed
  Future<void> _checkAndRefreshToken() async {
    try {
      final isExpired = await _gateStorage.isTokenExpired();

      if (isExpired) {
        log("🔄 Token expired, attempting refresh...");
        final refreshed = await _authService.refreshToken();

        if (refreshed) {
          log("✅ Token refreshed successfully");
          _updateSessionState(UserSessionState.authenticated);
        } else {
          log("❌ Token refresh failed");
          _updateSessionState(UserSessionState.tokenExpired);
        }
      }
    } catch (e) {
      log("❌ Error checking/refreshing token: $e");
    }
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
