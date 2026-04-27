import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/calls/callkit_service.dart';
import 'package:flutter_onegate/services/calls/call_callback_ux_service.dart';
import 'package:flutter_onegate/services/calls/pending_call_callback_store.dart';
import 'package:flutter_onegate/services/calls/pending_call_terminal_event_store.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/notifications/incoming_call_push_service.dart';
import 'package:flutter_onegate/services/notifications/push_notification_service.dart';
import 'package:flutter_onegate/services/intercom/onegate_intercom_bootstrap.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';
import 'package:intercom_module/core/services/call_websocket_service.dart';
import 'package:intercom_module/core/services/outgoing_call_acceptance_store.dart';
import 'package:intercom_module/core/services/call_coordinator.dart';
import 'package:intercom_module/core/services/keycloak_service.dart';
import 'package:intercom_module/modules/household/intercom/services/call_manager.dart';
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
  StreamSubscription<Map<String, dynamic>>? _callWsSubscription;

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
        _connectCallWebSocket();
        unawaited(
          CallKitService.instance.replayPendingAcceptIfAny(
            source: 'session_authenticated',
          ),
        );
        unawaited(_replayPendingTerminalEvent(source: 'session_authenticated'));
        unawaited(IncomingCallPushService.syncCurrentTokenWithBackend());
        break;
      case UserSessionState.unauthenticated:
        log("🚪 User session unauthenticated");
        _disconnectCallWebSocket();
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

  Future<void> _connectCallWebSocket() async {
    try {
      await OneGateIntercomBootstrap.ensureConfigured();
      final token =
          await _authService.tokenRefreshManager.getValidAccessToken() ??
              await _gateStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        log('⚠️ [UserSessionManager] Missing token; skipping call WS connect');
        return;
      }
      await CallWebSocketService.instance.connect(accessToken: token);
      _callWsSubscription?.cancel();
      _callWsSubscription =
          CallWebSocketService.instance.events.listen(_handleCallWsEvent);
    } catch (e) {
      log('⚠️ [UserSessionManager] Call WS connect failed: $e');
    }
  }

  /// Disconnects and reconnects the meet call WebSocket when the user is
  /// authenticated (e.g. after app resume) so subscriptions use a fresh token.
  Future<void> refreshCallWebSocketIfAuthenticated() async {
    if (_currentState != UserSessionState.authenticated) return;
    try {
      log('📞 [UserSessionManager] Refreshing call WebSocket');
      await CallWebSocketService.instance.disconnect();
      await _connectCallWebSocket();
    } catch (e) {
      log('⚠️ [UserSessionManager] refreshCallWebSocketIfAuthenticated: $e');
    }
  }

  void _disconnectCallWebSocket() {
    _callWsSubscription?.cancel();
    _callWsSubscription = null;
    CallWebSocketService.instance.disconnect();
  }

  Future<void> _handleCallWsEvent(Map<String, dynamic> payload) async {
    final action = _normalizeEventAction(payload);
    if (action == null || action.isEmpty) return;

    final callId = _resolveCallId(payload);
    const incomingLike = <String>{
      'incoming_call',
      'call_initiated',
      'call_created',
      'call_ringing',
      'ringing',
      'incoming',
      'call_ring',
    };
    if (incomingLike.contains(action)) {
      await IncomingCallPushService.handleIncomingCallData(
        payload,
        source: 'call_websocket',
        fromBackground: false,
      );
      return;
    }

    if (action == 'call_accepted' || action == 'call_answered') {
      if (callId != null && callId.isNotEmpty) {
        await OutgoingCallAcceptanceStore.saveForCallId(callId, payload);
      } else {
        await OutgoingCallAcceptanceStore.save(payload);
      }
      await CallCoordinator.instance.handleOutgoingCallAcceptedData(payload);

      // Join Jitsi when receiver has accepted (caller flow)
      final displayName = await _resolveDisplayNameForCall();
      final result = await CallManager.instance.joinOutgoingCallWhenAccepted(
        payload,
        displayName: displayName,
      );
      if (!result.success) {
        log('⚠️ [UserSessionManager] Failed to join Jitsi: ${result.message}');
        // Critical recovery: if join fails, release stale "connecting" state
        // so users can start a new call instead of seeing false "in progress".
        await CallCoordinator.instance.markEnded(
          reason: 'outgoing_accept_join_failed',
        );
        if (callId != null && callId.isNotEmpty) {
          await OutgoingCallAcceptanceStore.clearForCallId(callId);
        } else {
          await OutgoingCallAcceptanceStore.clear();
        }
      } else {
        await CallCoordinator.instance.markConnected(callId: callId);
      }
      return;
    }

    if (action == 'call_callback') {
      await PendingCallCallbackStore.save(payload);
      await CallCallbackUxService.instance.replayPendingIfAny(
        source: 'call_websocket',
      );
      return;
    }

    const terminalLike = <String>{
      'call_declined',
      'call_rejected',
      'call_ended',
      'ended',
      'call_terminated',
      'terminated',
      'remote_ended',
      'ended_by_caller',
      'ended_by_receiver',
      'declined',
      'rejected',
      'missed',
      'timeout',
      'caller_cancel',
      'call_cancelled',
      'call_canceled',
      'cancelled',
      'canceled',
    };
    if (terminalLike.contains(action)) {
      log(
        '📥 [CallWebSocketService] CALL_ENDED received call_id=${callId ?? "-"} '
        'active=${CallCoordinator.instance.activeCallId ?? "-"} action=$action',
      );
      await OutgoingCallAcceptanceStore.saveCallEnded(payload);
      await PushNotificationService.handleTerminalCallEvent(
        payload,
        source: 'call_websocket',
        fromBackground: false,
        normalizedAction: action,
      );
    }
  }

  Future<void> _replayPendingTerminalEvent({required String source}) async {
    final activeCallId = CallCoordinator.instance.activeCallId;
    final pending = (activeCallId != null && activeCallId.trim().isNotEmpty)
        ? await PendingCallTerminalEventStore.consumePendingCallEndedForCallId(
            activeCallId,
          )
        : await PendingCallTerminalEventStore.consumePendingCallEnded();
    if (pending == null || pending.isEmpty) return;
    final callId = _resolveCallId(pending) ?? '-';
    log('🔁 [CallCoordinator] Replaying pending terminal call_id=$callId source=$source');
    await CallCoordinator.instance
        .handleCallEndedData(pending, fromBackground: true);
    await CallKitService.instance
        .dismissIncomingUi(callId == '-' ? null : callId);
    await CallManager.instance.endFromRemote(reason: _terminalReason(pending));
  }

  String? _normalizeEventAction(Map<String, dynamic> payload) {
    final raw = (payload['action'] ??
            payload['event'] ??
            payload['type'] ??
            payload['status'] ??
            payload['reason'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    final snake = raw
        .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m.group(1)}_${m.group(2)}')
        .replaceAll('-', '_')
        .toLowerCase();
    switch (snake) {
      case 'call_ended':
      case 'ended':
      case 'hangup':
      case 'ended_by_caller':
      case 'ended_by_receiver':
      case 'remote_ended':
      case 'terminated':
      case 'call_terminated':
        return 'call_ended';
      case 'declined':
      case 'call_declined':
      case 'receiver_declined':
        return 'call_declined';
      case 'rejected':
      case 'call_rejected':
        return 'call_rejected';
      case 'caller_cancel':
      case 'call_cancelled':
      case 'call_canceled':
      case 'cancelled':
      case 'canceled':
        return 'call_ended';
      case 'missed':
        return 'missed';
      case 'timeout':
        return 'timeout';
      default:
        return snake;
    }
  }

  String? _resolveCallId(Map<String, dynamic> payload) {
    final id = payload['call_id'] ??
        payload['callId'] ??
        payload['id'] ??
        payload['uuid'];
    final text = id?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _terminalReason(Map<String, dynamic> payload) {
    final reason = payload['reason']?.toString().trim();
    if (reason != null && reason.isNotEmpty) return reason;
    final action = _normalizeEventAction(payload) ?? 'remote_ended';
    switch (action) {
      case 'declined':
      case 'call_declined':
        return 'declined';
      case 'rejected':
      case 'call_rejected':
        return 'rejected';
      case 'missed':
        return 'missed';
      case 'timeout':
        return 'timeout';
      default:
        return 'remote_ended';
    }
  }

  Future<String> _resolveDisplayNameForCall() async {
    try {
      final userData = await KeycloakService.getUserData();
      final name = userData?['name'] ?? userData?['preferred_username'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString().trim();
      }
    } catch (e) {
      log('⚠️ [UserSessionManager] Error resolving display name: $e');
    }
    return 'User';
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
