import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/dynamic_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';

/// Integration layer for dynamic token refresh system with OneGate authentication
class DynamicAuthIntegration with WidgetsBindingObserver {
  static final DynamicAuthIntegration _instance = DynamicAuthIntegration._internal();
  factory DynamicAuthIntegration() => _instance;
  DynamicAuthIntegration._internal();

  // Core components
  final DynamicTokenRefreshManager _dynamicManager = DynamicTokenRefreshManager();
  final TokenNotificationService _notificationService = TokenNotificationService();
  
  // Integration state
  bool _isInitialized = false;
  bool _isObservingLifecycle = false;
  StreamSubscription<bool>? _authStateSubscription;

  /// Initialize dynamic authentication integration
  Future<void> initialize(AuthService authService) async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Dynamic Authentication Integration");

      // Initialize dynamic token refresh manager
      await _dynamicManager.initialize();

      // Set up app lifecycle observation
      _setupAppLifecycleObservation();

      // Set up authentication state monitoring
      await _setupAuthStateMonitoring(authService);

      // Perform initial token analysis if user is logged in
      await _performInitialTokenAnalysis(authService);

      _isInitialized = true;
      log("✅ Dynamic Authentication Integration initialized successfully");
    } catch (e) {
      log("❌ Error initializing Dynamic Authentication Integration: $e");
      rethrow;
    }
  }

  /// Set up app lifecycle observation for continuous session management
  void _setupAppLifecycleObservation() {
    if (!_isObservingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _isObservingLifecycle = true;
      log("👁️ App lifecycle observation enabled for dynamic auth");
    }
  }

  /// Set up authentication state monitoring
  Future<void> _setupAuthStateMonitoring(AuthService authService) async {
    try {
      // Monitor authentication state changes
      _authStateSubscription = authService.isLoggedInStream.listen((isLoggedIn) async {
        if (isLoggedIn) {
          log("🔐 User logged in - starting dynamic token management");
          await _handleUserLogin(authService);
        } else {
          log("🚪 User logged out - stopping dynamic token management");
          await _handleUserLogout();
        }
      });

      log("📡 Authentication state monitoring enabled");
    } catch (e) {
      log("❌ Error setting up auth state monitoring: $e");
    }
  }

  /// Handle user login event
  Future<void> _handleUserLogin(AuthService authService) async {
    try {
      // Perform immediate token analysis
      await _performInitialTokenAnalysis(authService);

      // Show login success notification with token info
      final status = _dynamicManager.getDynamicRefreshStatus();
      if (status['nextScheduledRefresh'] != null) {
        _notificationService.showDynamicRefreshScheduled(
          DateTime.parse(status['nextScheduledRefresh']),
          Duration(minutes: status['currentRefreshBuffer'] ?? 1),
        );
      }
    } catch (e) {
      log("❌ Error handling user login: $e");
    }
  }

  /// Handle user logout event
  Future<void> _handleUserLogout() async {
    try {
      // Stop dynamic refresh monitoring
      _dynamicManager.stopDynamicRefreshMonitoring();

      // Clear notifications
      _notificationService.clearNotifications();

      log("✅ Dynamic auth cleaned up for logout");
    } catch (e) {
      log("❌ Error handling user logout: $e");
    }
  }

  /// Perform initial token analysis after login
  Future<void> _performInitialTokenAnalysis(AuthService authService) async {
    try {
      log("🔍 Performing initial token analysis");

      final accessToken = await authService.tokenRefreshManager.getValidAccessToken();
      if (accessToken == null) {
        log("⚠️ No access token available for initial analysis");
        return;
      }

      // Get comprehensive token analysis
      final analysis = JwtTokenUtility.getTokenAnalysis(accessToken);
      
      log("📊 Initial Token Analysis Results:");
      log("   • Token lifespan: ${analysis['lifespanMinutes']} minutes");
      log("   • Refresh buffer: ${analysis['refreshBuffer']} minutes");
      log("   • Next refresh: ${analysis['refreshTime']}");
      log("   • Time until expiry: ${analysis['timeUntilExpiryMinutes']} minutes");

      // Force immediate analysis in dynamic manager
      await _dynamicManager.forceTokenAnalysis();

      // Show token lifespan notification for very short tokens
      final lifespanMinutes = analysis['lifespanMinutes'] as int?;
      if (lifespanMinutes != null && lifespanMinutes < 10) {
        _notificationService.showShortTokenLifespanWarning(
          Duration(minutes: lifespanMinutes)
        );
      }
    } catch (e) {
      log("❌ Error during initial token analysis: $e");
    }
  }

  /// Handle app lifecycle changes for continuous session management
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

  /// Handle app resumed for session continuity
  void _handleAppResumed() async {
    try {
      log("📱 App resumed - checking dynamic auth status");
      
      if (_isInitialized) {
        await _dynamicManager.handleAppLifecycleChange(true);
        
        // Show session continuity notification
        final status = _dynamicManager.getDynamicRefreshStatus();
        if (status['hasScheduledRefresh'] == true) {
          _notificationService.showSessionContinuityConfirmed();
        }
      }
    } catch (e) {
      log("❌ Error handling app resumed: $e");
    }
  }

  /// Handle app paused
  void _handleAppPaused() async {
    try {
      log("📱 App paused - maintaining dynamic auth in background");
      
      if (_isInitialized) {
        await _dynamicManager.handleAppLifecycleChange(false);
      }
    } catch (e) {
      log("❌ Error handling app paused: $e");
    }
  }

  /// Handle app detached
  void _handleAppDetached() {
    log("📱 App detached - preserving dynamic auth state");
    // Keep dynamic refresh running for seamless return
  }

  /// Get enhanced access token with dynamic refresh
  Future<String?> getEnhancedAccessToken() async {
    try {
      if (!_isInitialized) {
        log("⚠️ Dynamic auth integration not initialized");
        return null;
      }

      return await _dynamicManager.getDynamicValidAccessToken();
    } catch (e) {
      log("❌ Error getting enhanced access token: $e");
      return null;
    }
  }

  /// Get comprehensive authentication status
  Map<String, dynamic> getComprehensiveAuthStatus() {
    try {
      final dynamicStatus = _dynamicManager.getDynamicRefreshStatus();
      
      return {
        'dynamicAuthIntegration': {
          'isInitialized': _isInitialized,
          'isObservingLifecycle': _isObservingLifecycle,
          'hasAuthStateSubscription': _authStateSubscription != null,
        },
        'dynamicRefreshManager': dynamicStatus,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Force comprehensive token refresh and analysis
  Future<bool> forceComprehensiveRefresh() async {
    try {
      log("🔄 Forcing comprehensive token refresh and analysis");

      // Force token analysis
      await _dynamicManager.forceTokenAnalysis();

      // Get fresh token
      final token = await _dynamicManager.getDynamicValidAccessToken();
      
      if (token != null) {
        log("✅ Comprehensive refresh successful");
        
        // Show success notification
        _notificationService.showComprehensiveRefreshSuccess();
        return true;
      } else {
        log("❌ Comprehensive refresh failed");
        return false;
      }
    } catch (e) {
      log("❌ Error during comprehensive refresh: $e");
      return false;
    }
  }

  /// Handle network connectivity changes
  Future<void> handleNetworkConnectivityChange(bool isConnected) async {
    try {
      if (isConnected) {
        log("🌐 Network connectivity restored - resuming dynamic auth");
        
        if (_isInitialized) {
          // Force immediate token check when connectivity returns
          await _dynamicManager.forceTokenAnalysis();
        }
      } else {
        log("🌐 Network connectivity lost - dynamic auth will retry when restored");
        
        // Show connectivity warning
        _notificationService.showNetworkConnectivityWarning();
      }
    } catch (e) {
      log("❌ Error handling network connectivity change: $e");
    }
  }

  /// Dispose resources and cleanup
  void dispose() {
    try {
      log("🗑️ Disposing Dynamic Authentication Integration");

      // Stop dynamic manager
      _dynamicManager.dispose();

      // Remove lifecycle observer
      if (_isObservingLifecycle) {
        WidgetsBinding.instance.removeObserver(this);
        _isObservingLifecycle = false;
      }

      // Cancel auth state subscription
      _authStateSubscription?.cancel();
      _authStateSubscription = null;

      // Clear notifications
      _notificationService.clearNotifications();

      _isInitialized = false;
      log("✅ Dynamic Authentication Integration disposed");
    } catch (e) {
      log("❌ Error disposing Dynamic Authentication Integration: $e");
    }
  }
}

/// Extension for TokenNotificationService to support dynamic refresh notifications
extension DynamicRefreshNotifications on TokenNotificationService {
  /// Show dynamic refresh scheduled notification
  void showDynamicRefreshScheduled(DateTime refreshTime, Duration buffer) {
    // Implementation would show notification about scheduled refresh
    log("📅 Dynamic refresh scheduled for $refreshTime (buffer: ${buffer.inMinutes} min)");
  }

  /// Show short token lifespan warning
  void showShortTokenLifespanWarning(Duration lifespan) {
    // Implementation would warn about very short token lifespan
    log("⚠️ Short token lifespan detected: ${lifespan.inMinutes} minutes");
  }

  /// Show session continuity confirmed
  void showSessionContinuityConfirmed() {
    // Implementation would confirm session is maintained
    log("✅ Session continuity confirmed");
  }

  /// Show comprehensive refresh success
  void showComprehensiveRefreshSuccess() {
    // Implementation would show successful comprehensive refresh
    log("🎉 Comprehensive token refresh successful");
  }
}
