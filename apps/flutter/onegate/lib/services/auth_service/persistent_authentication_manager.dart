import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/dynamic_auth_integration.dart';
import 'package:flutter_onegate/services/session_manager/continuous_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/session_timeout_override.dart';
import 'package:flutter_onegate/services/session_manager/background_session_manager.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';

/// Comprehensive persistent authentication manager that provides "login once, stay logged in" experience
/// Handles automatic token refresh, session persistence, and background authentication management
class PersistentAuthenticationManager with WidgetsBindingObserver {
  static final PersistentAuthenticationManager _instance =
      PersistentAuthenticationManager._internal();
  factory PersistentAuthenticationManager() => _instance;
  PersistentAuthenticationManager._internal();

  // Core components
  late final AuthService _authService;
  late final EnhancedTokenRefreshManager _tokenManager;
  late final DynamicAuthIntegration _dynamicAuth;
  late final ContinuousSessionManager _continuousSession;
  late final SessionTimeoutOverride _timeoutOverride;
  late final BackgroundSessionManager _backgroundSession;
  late final GateStorage _gateStorage;

  // Secure storage for persistent authentication state
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Persistence keys
  static const String _persistentAuthEnabledKey = 'persistent_auth_enabled';
  static const String _lastSuccessfulAuthKey = 'last_successful_auth';
  static const String _authPersistenceVersionKey = 'auth_persistence_version';
  static const String _backgroundRefreshEnabledKey =
      'background_refresh_enabled';
  static const String _sessionPersistenceDataKey = 'session_persistence_data';

  // State management
  bool _isInitialized = false;
  bool _isPersistentAuthEnabled = false;
  bool _isBackgroundRefreshActive = false;
  Timer? _persistenceHealthCheckTimer;
  Timer? _backgroundTokenRefreshTimer;
  StreamSubscription<bool>? _authStateSubscription;

  // Configuration
  static const Duration _backgroundRefreshInterval = Duration(minutes: 2);
  static const Duration _persistenceHealthCheckInterval = Duration(minutes: 5);
  static const Duration _tokenValidityBuffer = Duration(minutes: 5);
  static const int _currentPersistenceVersion = 1;

  /// Initialize persistent authentication system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Persistent Authentication Manager");

      // Initialize dependencies
      await _initializeDependencies();

      // Check for existing persistent authentication
      await _checkExistingPersistentAuth();

      // Set up app lifecycle observation
      _setupAppLifecycleObservation();

      // Set up authentication state monitoring
      await _setupAuthStateMonitoring();

      // Start persistence health monitoring
      _startPersistenceHealthCheck();

      _isInitialized = true;
      log("✅ Persistent Authentication Manager initialized successfully");
    } catch (e) {
      log("❌ Error initializing Persistent Authentication Manager: $e");
      rethrow;
    }
  }

  /// Initialize all required dependencies
  Future<void> _initializeDependencies() async {
    try {
      _authService = GetIt.I<AuthService>();
      _tokenManager = _authService.tokenRefreshManager;
      _dynamicAuth = DynamicAuthIntegration();
      _continuousSession = ContinuousSessionManager();
      _timeoutOverride = SessionTimeoutOverride();
      _backgroundSession = BackgroundSessionManager();
      _gateStorage = GetIt.I<GateStorage>();

      // Initialize all components
      await _dynamicAuth.initialize(_authService);
      await _continuousSession.initialize();
      await _timeoutOverride.initialize();
      await _backgroundSession.initialize();

      log("✅ All dependencies initialized for persistent authentication");
    } catch (e) {
      log("❌ Error initializing dependencies: $e");
      rethrow;
    }
  }

  /// Check for existing persistent authentication and restore if valid
  Future<void> _checkExistingPersistentAuth() async {
    try {
      log("🔍 Checking for existing persistent authentication");

      final prefs = await SharedPreferences.getInstance();
      final isPersistentEnabled =
          prefs.getBool(_persistentAuthEnabledKey) ?? false;

      if (!isPersistentEnabled) {
        log("ℹ️ Persistent authentication not previously enabled");
        return;
      }

      // Check if user is still authenticated
      final isAuthenticated = await _authService.isAuthenticated();
      if (isAuthenticated) {
        log("✅ Existing authentication found - enabling persistent authentication");
        await _enablePersistentAuthentication();
      } else {
        log("⚠️ Previous authentication expired - clearing persistent state");
        await _clearPersistentAuthState();
      }
    } catch (e) {
      log("❌ Error checking existing persistent authentication: $e");
    }
  }

  /// Enable persistent authentication after successful login
  Future<void> enablePersistentAuthentication() async {
    try {
      log("🔐 Enabling persistent authentication");

      if (!await _authService.isAuthenticated()) {
        throw Exception(
            'Cannot enable persistent authentication - user not authenticated');
      }

      await _enablePersistentAuthentication();
      log("✅ Persistent authentication enabled successfully");
    } catch (e) {
      log("❌ Error enabling persistent authentication: $e");
      rethrow;
    }
  }

  /// Internal method to enable persistent authentication
  Future<void> _enablePersistentAuthentication() async {
    try {
      // Mark persistent authentication as enabled
      _isPersistentAuthEnabled = true;
      await _savePersistentAuthState();

      // Activate continuous session management
      await _continuousSession.activateContinuousSession();

      // Override session timeouts
      await _timeoutOverride.activateTimeoutOverride();

      // Start background session management
      await _backgroundSession.startBackgroundTask();

      // Start background token refresh
      _startBackgroundTokenRefresh();

      // Save authentication timestamp
      await _saveLastSuccessfulAuth();

      log("🔐 Persistent authentication fully activated");
    } catch (e) {
      log("❌ Error in _enablePersistentAuthentication: $e");
      rethrow;
    }
  }

  /// Start background token refresh for persistent authentication
  void _startBackgroundTokenRefresh() {
    _backgroundTokenRefreshTimer?.cancel();

    _backgroundTokenRefreshTimer =
        Timer.periodic(_backgroundRefreshInterval, (timer) async {
      if (_isPersistentAuthEnabled) {
        await _performBackgroundTokenRefresh();
      }
    });

    _isBackgroundRefreshActive = true;
    log("🔄 Background token refresh started for persistent authentication");
  }

  /// Perform background token refresh
  Future<void> _performBackgroundTokenRefresh() async {
    try {
      log("🔄 Performing background token refresh for persistent authentication");

      // Use dynamic auth integration for intelligent refresh
      final token = await _dynamicAuth.getEnhancedAccessToken();

      if (token != null) {
        log("✅ Background token refresh successful");
        await _saveLastSuccessfulAuth();
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
      final isAuthenticated = await _authService.isAuthenticated();

      if (!isAuthenticated) {
        log("❌ Authentication lost - disabling persistent authentication");
        await disablePersistentAuthentication();
      } else {
        log("⚠️ Background refresh failed but user still authenticated - continuing");
      }
    } catch (e) {
      log("❌ Error handling background refresh failure: $e");
    }
  }

  /// Set up app lifecycle observation
  void _setupAppLifecycleObservation() {
    WidgetsBinding.instance.addObserver(this);
    log("👁️ App lifecycle observation enabled for persistent authentication");
  }

  /// Set up authentication state monitoring
  Future<void> _setupAuthStateMonitoring() async {
    try {
      _authStateSubscription =
          _authService.isLoggedInStream.listen((isLoggedIn) async {
        if (isLoggedIn && !_isPersistentAuthEnabled) {
          log("🔐 User logged in - checking if persistent auth should be enabled");
          // Auto-enable persistent authentication on login
          await enablePersistentAuthentication();
        } else if (!isLoggedIn && _isPersistentAuthEnabled) {
          log("🚪 User logged out - disabling persistent authentication");
          await disablePersistentAuthentication();
        }
      });

      log("📡 Authentication state monitoring enabled for persistent authentication");
    } catch (e) {
      log("❌ Error setting up auth state monitoring: $e");
    }
  }

  /// Start persistence health check
  void _startPersistenceHealthCheck() {
    _persistenceHealthCheckTimer?.cancel();

    _persistenceHealthCheckTimer =
        Timer.periodic(_persistenceHealthCheckInterval, (timer) async {
      if (_isPersistentAuthEnabled) {
        await _performPersistenceHealthCheck();
      }
    });

    log("🏥 Persistence health check started");
  }

  /// Perform persistence health check
  Future<void> _performPersistenceHealthCheck() async {
    try {
      log("🏥 Performing persistence health check");

      // Check if all components are still active by attempting to reactivate them
      // This ensures they are properly configured for persistent authentication
      await _reactivatePersistenceComponents();

      // Validate token health
      final isAuthenticated = await _authService.isAuthenticated();
      if (!isAuthenticated) {
        log("❌ Authentication lost during health check");
        await disablePersistentAuthentication();
      } else {
        log("✅ Persistence health check passed");
      }
    } catch (e) {
      log("❌ Error during persistence health check: $e");
    }
  }

  /// Reactivate persistence components if needed
  Future<void> _reactivatePersistenceComponents() async {
    try {
      // Always reactivate components to ensure they are properly configured
      await _continuousSession.activateContinuousSession();
      await _timeoutOverride.activateTimeoutOverride();
      await _backgroundSession.startBackgroundTask();

      log("✅ Persistence components reactivated");
    } catch (e) {
      log("❌ Error reactivating persistence components: $e");
    }
  }

  /// Disable persistent authentication
  Future<void> disablePersistentAuthentication() async {
    try {
      log("🔒 Disabling persistent authentication");

      _isPersistentAuthEnabled = false;

      // Stop background token refresh
      _stopBackgroundTokenRefresh();

      // Deactivate continuous session
      await _continuousSession.deactivateContinuousSession();

      // Restore original timeouts
      await _timeoutOverride.deactivateTimeoutOverride();

      // Stop background session management
      await _backgroundSession.stopBackgroundTask();

      // Clear persistent authentication state
      await _clearPersistentAuthState();

      log("✅ Persistent authentication disabled successfully");
    } catch (e) {
      log("❌ Error disabling persistent authentication: $e");
    }
  }

  /// Stop background token refresh
  void _stopBackgroundTokenRefresh() {
    _backgroundTokenRefreshTimer?.cancel();
    _backgroundTokenRefreshTimer = null;
    _isBackgroundRefreshActive = false;
    log("🛑 Background token refresh stopped");
  }

  /// Save persistent authentication state
  Future<void> _savePersistentAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_persistentAuthEnabledKey, _isPersistentAuthEnabled);
      await prefs.setBool(
          _backgroundRefreshEnabledKey, _isBackgroundRefreshActive);
      await prefs.setInt(
          _authPersistenceVersionKey, _currentPersistenceVersion);

      // Save session persistence data
      final sessionData = {
        'enabled_timestamp': DateTime.now().toIso8601String(),
        'version': _currentPersistenceVersion,
        'components': {
          'continuous_session': true, // Will be checked during health check
          'timeout_override': true, // Will be checked during health check
          'background_session': true, // Will be checked during health check
        },
      };

      await _secureStorage.write(
        key: _sessionPersistenceDataKey,
        value: sessionData.toString(),
      );

      log("💾 Persistent authentication state saved");
    } catch (e) {
      log("❌ Error saving persistent authentication state: $e");
    }
  }

  /// Clear persistent authentication state
  Future<void> _clearPersistentAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_persistentAuthEnabledKey);
      await prefs.remove(_backgroundRefreshEnabledKey);
      await prefs.remove(_lastSuccessfulAuthKey);
      await _secureStorage.delete(key: _sessionPersistenceDataKey);

      log("🧹 Persistent authentication state cleared");
    } catch (e) {
      log("❌ Error clearing persistent authentication state: $e");
    }
  }

  /// Save timestamp of last successful authentication
  Future<void> _saveLastSuccessfulAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastSuccessfulAuthKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      log("❌ Error saving last successful auth timestamp: $e");
    }
  }

  /// Get time since last successful authentication
  Future<Duration?> getTimeSinceLastAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAuthTimestamp = prefs.getInt(_lastSuccessfulAuthKey);

      if (lastAuthTimestamp != null) {
        final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTimestamp);
        return DateTime.now().difference(lastAuth);
      }
    } catch (e) {
      log("❌ Error getting time since last auth: $e");
    }
    return null;
  }

  /// Handle app lifecycle changes
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
      default:
        break;
    }
  }

  /// Handle app resumed
  void _handleAppResumed() async {
    try {
      log("📱 App resumed - checking persistent authentication");

      if (_isPersistentAuthEnabled) {
        // Perform immediate token refresh on app resume
        await _performBackgroundTokenRefresh();

        // Notify all components of app resume
        await _dynamicAuth.handleAppLifecycleChange(true);

        log("✅ Persistent authentication maintained on app resume");
      }
    } catch (e) {
      log("❌ Error handling app resumed: $e");
    }
  }

  /// Handle app paused
  void _handleAppPaused() async {
    try {
      log("📱 App paused - maintaining persistent authentication");

      if (_isPersistentAuthEnabled) {
        // Save current state
        await _savePersistentAuthState();

        // Notify components of app pause
        await _dynamicAuth.handleAppLifecycleChange(false);

        log("✅ Persistent authentication state preserved");
      }
    } catch (e) {
      log("❌ Error handling app paused: $e");
    }
  }

  /// Handle app detached
  void _handleAppDetached() async {
    try {
      log("📱 App detached - preserving persistent authentication");

      if (_isPersistentAuthEnabled) {
        await _savePersistentAuthState();
        log("✅ Persistent authentication state preserved for app restart");
      }
    } catch (e) {
      log("❌ Error handling app detached: $e");
    }
  }

  /// Get comprehensive persistent authentication status
  Map<String, dynamic> getPersistentAuthStatus() {
    return {
      'isInitialized': _isInitialized,
      'isPersistentAuthEnabled': _isPersistentAuthEnabled,
      'isBackgroundRefreshActive': _isBackgroundRefreshActive,
      'backgroundRefreshInterval': _backgroundRefreshInterval.inMinutes,
      'persistenceHealthCheckInterval':
          _persistenceHealthCheckInterval.inMinutes,
      'tokenValidityBuffer': _tokenValidityBuffer.inMinutes,
      'currentPersistenceVersion': _currentPersistenceVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if persistent authentication is enabled
  bool get isPersistentAuthEnabled => _isPersistentAuthEnabled;

  /// Check if background refresh is active
  bool get isBackgroundRefreshActive => _isBackgroundRefreshActive;

  /// Dispose resources
  void dispose() {
    try {
      log("🗑️ Disposing Persistent Authentication Manager");

      // Stop all timers
      _persistenceHealthCheckTimer?.cancel();
      _backgroundTokenRefreshTimer?.cancel();

      // Cancel subscriptions
      _authStateSubscription?.cancel();

      // Remove lifecycle observer
      WidgetsBinding.instance.removeObserver(this);

      // Reset state
      _isInitialized = false;
      _isPersistentAuthEnabled = false;
      _isBackgroundRefreshActive = false;

      log("✅ Persistent Authentication Manager disposed");
    } catch (e) {
      log("❌ Error disposing Persistent Authentication Manager: $e");
    }
  }
}
