import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/dynamic_auth_integration.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Continuous session manager that maintains user authentication indefinitely
/// during periods of inactivity without requiring re-authentication
class ContinuousSessionManager with WidgetsBindingObserver {
  static final ContinuousSessionManager _instance = ContinuousSessionManager._internal();
  factory ContinuousSessionManager() => _instance;
  ContinuousSessionManager._internal();

  // Core dependencies
  late final AuthService _authService;
  late final GateStorage _gateStorage;
  late final DynamicAuthIntegration _dynamicAuth;
  late final UserSessionManager _userSessionManager;

  // Continuous session state
  bool _isInitialized = false;
  bool _isContinuousSessionActive = false;
  bool _isObservingLifecycle = false;
  
  // Background refresh management
  Timer? _backgroundRefreshTimer;
  Timer? _sessionPersistenceTimer;
  Timer? _connectivityCheckTimer;
  
  // Session persistence
  static const String _sessionActiveKey = 'continuous_session_active';
  static const String _lastActivityKey = 'last_activity_timestamp';
  static const String _sessionStartKey = 'session_start_timestamp';
  static const String _backgroundRefreshEnabledKey = 'background_refresh_enabled';
  
  // Configuration for continuous session
  static const Duration _backgroundRefreshInterval = Duration(minutes: 2); // Frequent background refresh
  static const Duration _sessionPersistenceInterval = Duration(minutes: 5); // Save session state
  static const Duration _connectivityCheckInterval = Duration(minutes: 1); // Check connectivity
  static const Duration _maxInactivityPeriod = Duration(days: 365); // Effectively infinite
  
  // Session state streams
  final StreamController<ContinuousSessionState> _sessionStateController = 
      StreamController<ContinuousSessionState>.broadcast();
  final StreamController<Duration> _sessionDurationController = 
      StreamController<Duration>.broadcast();

  /// Stream of continuous session state changes
  Stream<ContinuousSessionState> get sessionStateStream => _sessionStateController.stream;
  
  /// Stream of session duration updates
  Stream<Duration> get sessionDurationStream => _sessionDurationController.stream;

  /// Initialize continuous session management
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Continuous Session Manager");

      // Initialize dependencies
      _authService = GetIt.I<AuthService>();
      _gateStorage = GetIt.I<GateStorage>();
      _dynamicAuth = DynamicAuthIntegration();
      _userSessionManager = UserSessionManager();

      // Initialize dynamic auth integration
      await _dynamicAuth.initialize(_authService);

      // Set up app lifecycle observation
      _setupAppLifecycleObservation();

      // Check if continuous session should be restored
      await _checkAndRestoreContinuousSession();

      // Start continuous session monitoring
      await _startContinuousSessionMonitoring();

      _isInitialized = true;
      log("✅ Continuous Session Manager initialized successfully");
    } catch (e) {
      log("❌ Error initializing Continuous Session Manager: $e");
      rethrow;
    }
  }

  /// Set up app lifecycle observation for background session management
  void _setupAppLifecycleObservation() {
    if (!_isObservingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _isObservingLifecycle = true;
      log("👁️ App lifecycle observation enabled for continuous session");
    }
  }

  /// Check and restore continuous session from previous app session
  Future<void> _checkAndRestoreContinuousSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasSessionActive = prefs.getBool(_sessionActiveKey) ?? false;
      final lastActivityTimestamp = prefs.getInt(_lastActivityKey);
      
      if (wasSessionActive && lastActivityTimestamp != null) {
        final lastActivity = DateTime.fromMillisecondsSinceEpoch(lastActivityTimestamp);
        final inactivityDuration = DateTime.now().difference(lastActivity);
        
        log("🔍 Found previous continuous session:");
        log("   • Last activity: $lastActivity");
        log("   • Inactivity duration: ${inactivityDuration.inHours} hours");
        
        // Check if user is still authenticated
        final isAuthenticated = await _authService.isLoggedIn();
        
        if (isAuthenticated && inactivityDuration < _maxInactivityPeriod) {
          log("✅ Restoring continuous session after ${inactivityDuration.inHours} hours of inactivity");
          await _activateContinuousSession(isRestore: true);
        } else {
          log("⚠️ Cannot restore session - authentication expired or max inactivity exceeded");
          await _deactivateContinuousSession();
        }
      } else {
        log("ℹ️ No previous continuous session found");
      }
    } catch (e) {
      log("❌ Error checking previous continuous session: $e");
    }
  }

  /// Start continuous session monitoring
  Future<void> _startContinuousSessionMonitoring() async {
    try {
      // Start background token refresh
      _startBackgroundTokenRefresh();
      
      // Start session persistence
      _startSessionPersistence();
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      log("🔄 Continuous session monitoring started");
    } catch (e) {
      log("❌ Error starting continuous session monitoring: $e");
    }
  }

  /// Start background token refresh to maintain authentication
  void _startBackgroundTokenRefresh() {
    _backgroundRefreshTimer?.cancel();
    
    _backgroundRefreshTimer = Timer.periodic(_backgroundRefreshInterval, (timer) async {
      if (_isContinuousSessionActive) {
        await _performBackgroundTokenRefresh();
      }
    });
    
    log("🔄 Background token refresh started (every ${_backgroundRefreshInterval.inMinutes} minutes)");
  }

  /// Perform background token refresh
  Future<void> _performBackgroundTokenRefresh() async {
    try {
      log("🔄 Performing background token refresh for continuous session");
      
      // Use dynamic auth integration for intelligent refresh
      final token = await _dynamicAuth.getEnhancedAccessToken();
      
      if (token != null) {
        log("✅ Background token refresh successful");
        await _updateLastActivity();
        _sessionStateController.add(ContinuousSessionState.activeWithRefresh);
      } else {
        log("⚠️ Background token refresh failed - checking authentication status");
        await _handleBackgroundRefreshFailure();
      }
    } catch (e) {
      log("❌ Error during background token refresh: $e");
      await _handleBackgroundRefreshFailure();
    }
  }

  /// Handle background refresh failure
  Future<void> _handleBackgroundRefreshFailure() async {
    try {
      // Check if user is still authenticated
      final isAuthenticated = await _authService.isLoggedIn();
      
      if (!isAuthenticated) {
        log("❌ User no longer authenticated - deactivating continuous session");
        await _deactivateContinuousSession();
        _sessionStateController.add(ContinuousSessionState.expired);
      } else {
        log("⚠️ Background refresh failed but user still authenticated - will retry");
        _sessionStateController.add(ContinuousSessionState.activeWithError);
      }
    } catch (e) {
      log("❌ Error handling background refresh failure: $e");
    }
  }

  /// Start session persistence to maintain state across app restarts
  void _startSessionPersistence() {
    _sessionPersistenceTimer?.cancel();
    
    _sessionPersistenceTimer = Timer.periodic(_sessionPersistenceInterval, (timer) async {
      if (_isContinuousSessionActive) {
        await _persistSessionState();
      }
    });
    
    log("💾 Session persistence started (every ${_sessionPersistenceInterval.inMinutes} minutes)");
  }

  /// Persist session state to storage
  Future<void> _persistSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_sessionActiveKey, _isContinuousSessionActive);
      await prefs.setInt(_lastActivityKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(_backgroundRefreshEnabledKey, true);
      
      // Update session duration
      final sessionStart = prefs.getInt(_sessionStartKey);
      if (sessionStart != null) {
        final duration = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(sessionStart)
        );
        _sessionDurationController.add(duration);
      }
      
      log("💾 Session state persisted successfully");
    } catch (e) {
      log("❌ Error persisting session state: $e");
    }
  }

  /// Start connectivity monitoring for network-aware session management
  void _startConnectivityMonitoring() {
    _connectivityCheckTimer?.cancel();
    
    _connectivityCheckTimer = Timer.periodic(_connectivityCheckInterval, (timer) async {
      if (_isContinuousSessionActive) {
        await _checkNetworkConnectivity();
      }
    });
    
    log("🌐 Connectivity monitoring started (every ${_connectivityCheckInterval.inMinutes} minutes)");
  }

  /// Check network connectivity and handle accordingly
  Future<void> _checkNetworkConnectivity() async {
    try {
      // Simple connectivity check by attempting to get current token
      final token = await _authService.tokenRefreshManager.getValidAccessToken();
      
      if (token != null) {
        // Network seems available, notify dynamic auth
        await _dynamicAuth.handleNetworkConnectivityChange(true);
      } else {
        // Potential network issue
        log("⚠️ Potential network connectivity issue detected");
        await _dynamicAuth.handleNetworkConnectivityChange(false);
      }
    } catch (e) {
      log("❌ Error checking network connectivity: $e");
    }
  }

  /// Activate continuous session for authenticated user
  Future<void> activateContinuousSession() async {
    try {
      log("🔐 Activating continuous session");
      
      // Verify user is authenticated
      final isAuthenticated = await _authService.isLoggedIn();
      if (!isAuthenticated) {
        throw Exception("Cannot activate continuous session - user not authenticated");
      }

      await _activateContinuousSession(isRestore: false);
    } catch (e) {
      log("❌ Error activating continuous session: $e");
      rethrow;
    }
  }

  /// Internal method to activate continuous session
  Future<void> _activateContinuousSession({required bool isRestore}) async {
    try {
      _isContinuousSessionActive = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionActiveKey, true);
      
      if (!isRestore) {
        // Set session start time for new sessions
        await prefs.setInt(_sessionStartKey, DateTime.now().millisecondsSinceEpoch);
      }
      
      await _updateLastActivity();
      
      // Disable any existing idle timeouts
      await _disableIdleTimeouts();
      
      // Start monitoring if not already started
      if (_isInitialized) {
        await _startContinuousSessionMonitoring();
      }
      
      _sessionStateController.add(ContinuousSessionState.active);
      
      log("✅ Continuous session ${isRestore ? 'restored' : 'activated'} successfully");
    } catch (e) {
      log("❌ Error in _activateContinuousSession: $e");
      rethrow;
    }
  }

  /// Deactivate continuous session
  Future<void> deactivateContinuousSession() async {
    try {
      log("🚪 Deactivating continuous session");
      await _deactivateContinuousSession();
    } catch (e) {
      log("❌ Error deactivating continuous session: $e");
      rethrow;
    }
  }

  /// Internal method to deactivate continuous session
  Future<void> _deactivateContinuousSession() async {
    try {
      _isContinuousSessionActive = false;
      
      // Stop all timers
      _backgroundRefreshTimer?.cancel();
      _sessionPersistenceTimer?.cancel();
      _connectivityCheckTimer?.cancel();
      
      // Clear session state from storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionActiveKey);
      await prefs.remove(_lastActivityKey);
      await prefs.remove(_sessionStartKey);
      await prefs.remove(_backgroundRefreshEnabledKey);
      
      _sessionStateController.add(ContinuousSessionState.inactive);
      
      log("✅ Continuous session deactivated successfully");
    } catch (e) {
      log("❌ Error in _deactivateContinuousSession: $e");
    }
  }

  /// Disable idle timeouts to prevent automatic logout
  Future<void> _disableIdleTimeouts() async {
    try {
      log("⏰ Disabling idle timeouts for continuous session");
      
      // Override any existing session timeout mechanisms
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('disable_idle_timeout', true);
      await prefs.setInt('session_timeout_override', _maxInactivityPeriod.inMilliseconds);
      
      log("✅ Idle timeouts disabled successfully");
    } catch (e) {
      log("❌ Error disabling idle timeouts: $e");
    }
  }

  /// Update last activity timestamp
  Future<void> _updateLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastActivityKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      log("❌ Error updating last activity: $e");
    }
  }

  /// Handle app lifecycle changes for background session management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
      default:
        break;
    }
  }

  /// Handle app resumed - seamless return to authenticated state
  void _handleAppResumed() async {
    try {
      log("📱 App resumed - checking continuous session status");
      
      if (_isContinuousSessionActive) {
        // Update activity and perform immediate token check
        await _updateLastActivity();
        await _performBackgroundTokenRefresh();
        
        // Notify dynamic auth of app resume
        await _dynamicAuth.handleAppLifecycleChange(true);
        
        log("✅ Seamless return to authenticated state");
        _sessionStateController.add(ContinuousSessionState.activeAfterResume);
      }
    } catch (e) {
      log("❌ Error handling app resumed: $e");
    }
  }

  /// Handle app paused - continue background session management
  void _handleAppPaused() async {
    try {
      log("📱 App paused - maintaining continuous session in background");
      
      if (_isContinuousSessionActive) {
        await _updateLastActivity();
        await _persistSessionState();
        
        // Notify dynamic auth of app pause
        await _dynamicAuth.handleAppLifecycleChange(false);
        
        log("✅ Background session management active");
      }
    } catch (e) {
      log("❌ Error handling app paused: $e");
    }
  }

  /// Handle app detached - preserve session state
  void _handleAppDetached() async {
    try {
      log("📱 App detached - preserving continuous session state");
      
      if (_isContinuousSessionActive) {
        await _persistSessionState();
        log("✅ Session state preserved for app restart");
      }
    } catch (e) {
      log("❌ Error handling app detached: $e");
    }
  }

  /// Handle app hidden - maintain background operations
  void _handleAppHidden() async {
    try {
      log("📱 App hidden - maintaining background session operations");
      
      if (_isContinuousSessionActive) {
        // Continue background refresh operations
        log("✅ Background operations maintained");
      }
    } catch (e) {
      log("❌ Error handling app hidden: $e");
    }
  }

  /// Get current continuous session status
  ContinuousSessionStatus getContinuousSessionStatus() {
    try {
      return ContinuousSessionStatus(
        isActive: _isContinuousSessionActive,
        isInitialized: _isInitialized,
        backgroundRefreshActive: _backgroundRefreshTimer?.isActive ?? false,
        sessionPersistenceActive: _sessionPersistenceTimer?.isActive ?? false,
        connectivityMonitoringActive: _connectivityCheckTimer?.isActive ?? false,
        lastActivity: DateTime.now(), // Would be loaded from storage in real implementation
      );
    } catch (e) {
      log("❌ Error getting continuous session status: $e");
      return ContinuousSessionStatus(
        isActive: false,
        isInitialized: false,
        backgroundRefreshActive: false,
        sessionPersistenceActive: false,
        connectivityMonitoringActive: false,
        lastActivity: DateTime.now(),
      );
    }
  }

  /// Force immediate session validation and refresh
  Future<bool> validateAndRefreshSession() async {
    try {
      log("🔍 Forcing immediate session validation and refresh");
      
      if (!_isContinuousSessionActive) {
        log("⚠️ Continuous session not active");
        return false;
      }

      // Perform comprehensive refresh
      final refreshed = await _dynamicAuth.forceComprehensiveRefresh();
      
      if (refreshed) {
        await _updateLastActivity();
        _sessionStateController.add(ContinuousSessionState.activeWithRefresh);
        log("✅ Session validation and refresh successful");
        return true;
      } else {
        log("❌ Session validation and refresh failed");
        await _handleBackgroundRefreshFailure();
        return false;
      }
    } catch (e) {
      log("❌ Error during session validation and refresh: $e");
      return false;
    }
  }

  /// Get session duration since activation
  Future<Duration?> getSessionDuration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStart = prefs.getInt(_sessionStartKey);
      
      if (sessionStart != null) {
        return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(sessionStart)
        );
      }
      
      return null;
    } catch (e) {
      log("❌ Error getting session duration: $e");
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      log("🗑️ Disposing Continuous Session Manager");
      
      // Stop all timers
      _backgroundRefreshTimer?.cancel();
      _sessionPersistenceTimer?.cancel();
      _connectivityCheckTimer?.cancel();
      
      // Remove lifecycle observer
      if (_isObservingLifecycle) {
        WidgetsBinding.instance.removeObserver(this);
        _isObservingLifecycle = false;
      }
      
      // Close streams
      _sessionStateController.close();
      _sessionDurationController.close();
      
      // Dispose dynamic auth
      _dynamicAuth.dispose();
      
      _isInitialized = false;
      log("✅ Continuous Session Manager disposed");
    } catch (e) {
      log("❌ Error disposing Continuous Session Manager: $e");
    }
  }
}

/// Continuous session states
enum ContinuousSessionState {
  inactive,
  active,
  activeWithRefresh,
  activeWithError,
  activeAfterResume,
  expired,
}

/// Continuous session status information
class ContinuousSessionStatus {
  final bool isActive;
  final bool isInitialized;
  final bool backgroundRefreshActive;
  final bool sessionPersistenceActive;
  final bool connectivityMonitoringActive;
  final DateTime lastActivity;

  ContinuousSessionStatus({
    required this.isActive,
    required this.isInitialized,
    required this.backgroundRefreshActive,
    required this.sessionPersistenceActive,
    required this.connectivityMonitoringActive,
    required this.lastActivity,
  });

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'isInitialized': isInitialized,
      'backgroundRefreshActive': backgroundRefreshActive,
      'sessionPersistenceActive': sessionPersistenceActive,
      'connectivityMonitoringActive': connectivityMonitoringActive,
      'lastActivity': lastActivity.toIso8601String(),
    };
  }
}
