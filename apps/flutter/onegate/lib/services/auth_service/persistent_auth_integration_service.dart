import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/persistent_authentication_manager.dart';
import 'package:flutter_onegate/services/api_client/persistent_authenticated_api_client.dart';
import 'package:flutter_onegate/services/session_manager/continuous_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/session_timeout_override.dart';
import 'package:flutter_onegate/services/session_manager/background_session_manager.dart';
import 'package:get_it/get_it.dart';

/// Main integration service for persistent authentication
/// Provides a single entry point for "login once, stay logged in" functionality
class PersistentAuthIntegrationService {
  static final PersistentAuthIntegrationService _instance = 
      PersistentAuthIntegrationService._internal();
  factory PersistentAuthIntegrationService() => _instance;
  PersistentAuthIntegrationService._internal();

  // Core components
  late final AuthService _authService;
  late final PersistentAuthenticationManager _persistentAuth;
  late final PersistentAuthenticatedApiClient _apiClient;
  late final ContinuousSessionManager _continuousSession;
  late final SessionTimeoutOverride _timeoutOverride;
  late final BackgroundSessionManager _backgroundSession;

  // State management
  bool _isInitialized = false;
  bool _isPersistentAuthActive = false;
  StreamSubscription<bool>? _authStateSubscription;

  // Stream controllers for status updates
  final StreamController<PersistentAuthStatus> _statusController = 
      StreamController<PersistentAuthStatus>.broadcast();

  /// Initialize the persistent authentication integration
  Future<void> initialize({
    String? apiBaseUrl,
    bool autoEnableOnLogin = true,
  }) async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Persistent Authentication Integration Service");

      // Initialize core components
      await _initializeComponents(apiBaseUrl);

      // Set up authentication monitoring
      if (autoEnableOnLogin) {
        await _setupAutoEnableOnLogin();
      }

      // Check for existing persistent authentication
      await _checkAndRestoreExistingAuth();

      _isInitialized = true;
      _notifyStatusChange(PersistentAuthStatus.initialized);

      log("✅ Persistent Authentication Integration Service initialized successfully");
    } catch (e) {
      log("❌ Error initializing Persistent Authentication Integration Service: $e");
      _notifyStatusChange(PersistentAuthStatus.error);
      rethrow;
    }
  }

  /// Initialize all core components
  Future<void> _initializeComponents(String? apiBaseUrl) async {
    try {
      // Get dependencies
      _authService = GetIt.I<AuthService>();
      _persistentAuth = PersistentAuthenticationManager();
      _apiClient = PersistentAuthenticatedApiClient();
      _continuousSession = ContinuousSessionManager();
      _timeoutOverride = SessionTimeoutOverride();
      _backgroundSession = BackgroundSessionManager();

      // Initialize components
      await _persistentAuth.initialize();
      await _apiClient.initialize(baseUrl: apiBaseUrl);

      log("✅ All persistent authentication components initialized");
    } catch (e) {
      log("❌ Error initializing components: $e");
      rethrow;
    }
  }

  /// Set up automatic enabling of persistent auth on login
  Future<void> _setupAutoEnableOnLogin() async {
    try {
      _authStateSubscription = _authService.isLoggedInStream.listen((isLoggedIn) async {
        if (isLoggedIn && !_isPersistentAuthActive) {
          log("🔐 User logged in - auto-enabling persistent authentication");
          await enablePersistentAuthentication();
        } else if (!isLoggedIn && _isPersistentAuthActive) {
          log("🚪 User logged out - disabling persistent authentication");
          await disablePersistentAuthentication();
        }
      });

      log("📡 Auto-enable on login configured");
    } catch (e) {
      log("❌ Error setting up auto-enable on login: $e");
    }
  }

  /// Check and restore existing persistent authentication
  Future<void> _checkAndRestoreExistingAuth() async {
    try {
      if (_persistentAuth.isPersistentAuthEnabled) {
        log("🔍 Found existing persistent authentication - restoring");
        _isPersistentAuthActive = true;
        _notifyStatusChange(PersistentAuthStatus.active);
      } else {
        log("ℹ️ No existing persistent authentication found");
        _notifyStatusChange(PersistentAuthStatus.inactive);
      }
    } catch (e) {
      log("❌ Error checking existing persistent authentication: $e");
    }
  }

  /// Enable persistent authentication
  Future<void> enablePersistentAuthentication() async {
    try {
      log("🔐 Enabling persistent authentication");

      if (!await _authService.isAuthenticated()) {
        throw Exception('Cannot enable persistent authentication - user not authenticated');
      }

      await _persistentAuth.enablePersistentAuthentication();
      _isPersistentAuthActive = true;
      _notifyStatusChange(PersistentAuthStatus.active);

      log("✅ Persistent authentication enabled successfully");
    } catch (e) {
      log("❌ Error enabling persistent authentication: $e");
      _notifyStatusChange(PersistentAuthStatus.error);
      rethrow;
    }
  }

  /// Disable persistent authentication
  Future<void> disablePersistentAuthentication() async {
    try {
      log("🔒 Disabling persistent authentication");

      await _persistentAuth.disablePersistentAuthentication();
      _isPersistentAuthActive = false;
      _notifyStatusChange(PersistentAuthStatus.inactive);

      log("✅ Persistent authentication disabled successfully");
    } catch (e) {
      log("❌ Error disabling persistent authentication: $e");
      _notifyStatusChange(PersistentAuthStatus.error);
    }
  }

  /// Get the persistent authenticated API client
  PersistentAuthenticatedApiClient get apiClient {
    if (!_isInitialized) {
      throw StateError('PersistentAuthIntegrationService must be initialized before accessing apiClient');
    }
    return _apiClient;
  }

  /// Check if persistent authentication is active
  bool get isPersistentAuthActive => _isPersistentAuthActive;

  /// Get stream of persistent authentication status changes
  Stream<PersistentAuthStatus> get statusStream => _statusController.stream;

  /// Get current persistent authentication status
  PersistentAuthStatus get currentStatus {
    if (!_isInitialized) return PersistentAuthStatus.uninitialized;
    if (_isPersistentAuthActive) return PersistentAuthStatus.active;
    return PersistentAuthStatus.inactive;
  }

  /// Get comprehensive status information
  Map<String, dynamic> getComprehensiveStatus() {
    return {
      'integrationService': {
        'isInitialized': _isInitialized,
        'isPersistentAuthActive': _isPersistentAuthActive,
        'currentStatus': currentStatus.toString(),
      },
      'persistentAuthManager': _persistentAuth.getPersistentAuthStatus(),
      'apiClient': _apiClient.getAuthenticationStatus(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get time since last successful authentication
  Future<Duration?> getTimeSinceLastAuth() async {
    return await _persistentAuth.getTimeSinceLastAuth();
  }

  /// Force immediate token refresh
  Future<bool> forceTokenRefresh() async {
    try {
      log("🔄 Forcing immediate token refresh");
      
      final refreshed = await _authService.tokenRefreshManager.refreshTokenIfNeeded();
      
      if (refreshed) {
        log("✅ Token refresh successful");
        return true;
      } else {
        log("❌ Token refresh failed");
        return false;
      }
    } catch (e) {
      log("❌ Error during forced token refresh: $e");
      return false;
    }
  }

  /// Validate current authentication state
  Future<bool> validateAuthenticationState() async {
    try {
      log("🔍 Validating authentication state");
      
      final isAuthenticated = await _authService.isAuthenticated();
      
      if (isAuthenticated && _isPersistentAuthActive) {
        log("✅ Authentication state valid");
        return true;
      } else if (!isAuthenticated && _isPersistentAuthActive) {
        log("⚠️ Authentication lost - disabling persistent authentication");
        await disablePersistentAuthentication();
        return false;
      }
      
      return isAuthenticated;
    } catch (e) {
      log("❌ Error validating authentication state: $e");
      return false;
    }
  }

  /// Perform health check on all persistent authentication components
  Future<Map<String, bool>> performHealthCheck() async {
    try {
      log("🏥 Performing persistent authentication health check");
      
      final results = <String, bool>{};
      
      // Check authentication service
      results['authService'] = await _authService.isAuthenticated();
      
      // Check persistent authentication manager
      results['persistentAuthManager'] = _persistentAuth.isPersistentAuthEnabled;
      
      // Check API client
      results['apiClient'] = _apiClient.getAuthenticationStatus()['isInitialized'] ?? false;
      
      // Check if all components are healthy
      final allHealthy = results.values.every((healthy) => healthy);
      results['overall'] = allHealthy;
      
      log("🏥 Health check completed - Overall: ${allHealthy ? 'HEALTHY' : 'UNHEALTHY'}");
      
      return results;
    } catch (e) {
      log("❌ Error during health check: $e");
      return {'overall': false, 'error': true};
    }
  }

  /// Notify status change
  void _notifyStatusChange(PersistentAuthStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      log("🗑️ Disposing Persistent Authentication Integration Service");

      // Cancel subscriptions
      _authStateSubscription?.cancel();

      // Close stream controllers
      _statusController.close();

      // Dispose components
      _persistentAuth.dispose();
      _apiClient.dispose();

      // Reset state
      _isInitialized = false;
      _isPersistentAuthActive = false;

      log("✅ Persistent Authentication Integration Service disposed");
    } catch (e) {
      log("❌ Error disposing Persistent Authentication Integration Service: $e");
    }
  }
}

/// Status of persistent authentication
enum PersistentAuthStatus {
  uninitialized,
  initialized,
  active,
  inactive,
  error,
}

/// Extension for user-friendly status descriptions
extension PersistentAuthStatusExtension on PersistentAuthStatus {
  String get description {
    switch (this) {
      case PersistentAuthStatus.uninitialized:
        return 'Persistent authentication not initialized';
      case PersistentAuthStatus.initialized:
        return 'Persistent authentication initialized but not active';
      case PersistentAuthStatus.active:
        return 'Persistent authentication active - user will stay logged in';
      case PersistentAuthStatus.inactive:
        return 'Persistent authentication inactive - normal session behavior';
      case PersistentAuthStatus.error:
        return 'Persistent authentication error - check logs for details';
    }
  }

  bool get isActive => this == PersistentAuthStatus.active;
  bool get isError => this == PersistentAuthStatus.error;
}
