import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/dynamic_auth_integration.dart';
import 'package:flutter_onegate/services/session_manager/background_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/continuous_session_manager.dart';
import 'package:flutter_onegate/services/session_manager/session_timeout_override.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:get_it/get_it.dart';

/// Main integration layer for continuous session management that coordinates
/// all session management components for indefinite authentication
class ContinuousSessionIntegration with WidgetsBindingObserver {
  static final ContinuousSessionIntegration _instance =
      ContinuousSessionIntegration._internal();
  factory ContinuousSessionIntegration() => _instance;
  ContinuousSessionIntegration._internal();

  // Core session management components
  late final ContinuousSessionManager _continuousSessionManager;
  late final SessionTimeoutOverride _timeoutOverride;
  late final BackgroundSessionManager _backgroundSessionManager;
  late final DynamicAuthIntegration _dynamicAuth;
  late final UserSessionManager _userSessionManager;
  late final AuthService _authService;

  // Integration state
  bool _isInitialized = false;
  bool _isContinuousSessionActive = false;
  bool _isObservingLifecycle = false;

  // Session monitoring
  Timer? _sessionMonitorTimer;
  Timer? _healthCheckTimer;

  // Configuration
  static const Duration _sessionMonitorInterval = Duration(minutes: 1);
  static const Duration _healthCheckInterval = Duration(minutes: 5);

  // Session state streams
  final StreamController<ContinuousSessionIntegrationState> _stateController =
      StreamController<ContinuousSessionIntegrationState>.broadcast();
  final StreamController<ContinuousSessionHealth> _healthController =
      StreamController<ContinuousSessionHealth>.broadcast();

  /// Stream of integration state changes
  Stream<ContinuousSessionIntegrationState> get stateStream =>
      _stateController.stream;

  /// Stream of session health updates
  Stream<ContinuousSessionHealth> get healthStream => _healthController.stream;

  /// Initialize continuous session integration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Continuous Session Integration");

      // Initialize core dependencies
      _authService = GetIt.I<AuthService>();
      _userSessionManager = UserSessionManager();

      // Initialize session management components
      _continuousSessionManager = ContinuousSessionManager();
      _timeoutOverride = SessionTimeoutOverride();
      _backgroundSessionManager = BackgroundSessionManager();
      _dynamicAuth = DynamicAuthIntegration();

      // Initialize all components
      await _initializeComponents();

      // Set up app lifecycle observation
      _setupAppLifecycleObservation();

      // Set up session monitoring
      _startSessionMonitoring();

      // Set up health checks
      _startHealthChecks();

      _isInitialized = true;
      _stateController.add(ContinuousSessionIntegrationState.initialized);

      log("✅ Continuous Session Integration initialized successfully");
    } catch (e) {
      log("❌ Error initializing Continuous Session Integration: $e");
      _stateController.add(ContinuousSessionIntegrationState.error);
      rethrow;
    }
  }

  /// Initialize all session management components
  Future<void> _initializeComponents() async {
    try {
      log("🔧 Initializing session management components");

      // Initialize in dependency order
      await _timeoutOverride.initialize();
      await _backgroundSessionManager.initialize();
      await _continuousSessionManager.initialize();
      await _dynamicAuth.initialize(_authService);
      await _userSessionManager.initialize();

      log("✅ All session management components initialized");
    } catch (e) {
      log("❌ Error initializing components: $e");
      rethrow;
    }
  }

  /// Set up app lifecycle observation
  void _setupAppLifecycleObservation() {
    if (!_isObservingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _isObservingLifecycle = true;
      log("👁️ App lifecycle observation enabled for continuous session integration");
    }
  }

  /// Start session monitoring
  void _startSessionMonitoring() {
    _sessionMonitorTimer?.cancel();

    _sessionMonitorTimer =
        Timer.periodic(_sessionMonitorInterval, (timer) async {
      await _performSessionMonitoring();
    });

    log("📊 Session monitoring started (every ${_sessionMonitorInterval.inMinutes} minutes)");
  }

  /// Start health checks
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();

    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      await _performHealthCheck();
    });

    log("🏥 Health checks started (every ${_healthCheckInterval.inMinutes} minutes)");
  }

  /// Perform session monitoring
  Future<void> _performSessionMonitoring() async {
    try {
      if (!_isContinuousSessionActive) return;

      log("📊 Performing session monitoring");

      // Check authentication status
      final isAuthenticated = await _authService.isAuthenticated();

      if (!isAuthenticated) {
        log("❌ User no longer authenticated - deactivating continuous session");
        await deactivateContinuousSession();
        return;
      }

      // Validate session components
      await _validateSessionComponents();

      log("✅ Session monitoring completed successfully");
    } catch (e) {
      log("❌ Error during session monitoring: $e");
    }
  }

  /// Validate all session components are working correctly
  Future<void> _validateSessionComponents() async {
    try {
      // Check continuous session manager
      final continuousStatus =
          _continuousSessionManager.getContinuousSessionStatus();
      if (!continuousStatus.isActive) {
        log("⚠️ Continuous session manager not active - reactivating");
        await _continuousSessionManager.activateContinuousSession();
      }

      // Check timeout override
      if (!_timeoutOverride.isOverrideActive) {
        log("⚠️ Timeout override not active - reactivating");
        await _timeoutOverride.activateTimeoutOverride();
      }

      // Check background session manager
      final backgroundStatus =
          _backgroundSessionManager.getBackgroundTaskStatus();
      if (!backgroundStatus.isActive) {
        log("⚠️ Background session manager not active - reactivating");
        await _backgroundSessionManager.startBackgroundTask();
      }

      log("✅ All session components validated");
    } catch (e) {
      log("❌ Error validating session components: $e");
    }
  }

  /// Perform comprehensive health check
  Future<void> _performHealthCheck() async {
    try {
      log("🏥 Performing comprehensive session health check");

      final health = await _generateHealthReport();
      _healthController.add(health);

      // Take corrective action if needed
      if (health.overallHealth < 0.8) {
        log("⚠️ Session health below threshold (${(health.overallHealth * 100).toStringAsFixed(1)}%) - taking corrective action");
        await _performCorrectiveAction(health);
      }

      log("✅ Health check completed - overall health: ${(health.overallHealth * 100).toStringAsFixed(1)}%");
    } catch (e) {
      log("❌ Error during health check: $e");
    }
  }

  /// Generate comprehensive health report
  Future<ContinuousSessionHealth> _generateHealthReport() async {
    try {
      // Check authentication status
      final isAuthenticated = await _authService.isAuthenticated();

      // Check component statuses
      final continuousStatus =
          _continuousSessionManager.getContinuousSessionStatus();
      final timeoutStatus = _timeoutOverride.getOverrideStatus();
      final backgroundStatus =
          _backgroundSessionManager.getBackgroundTaskStatus();
      final backgroundStats =
          await _backgroundSessionManager.getBackgroundRefreshStats();

      // Calculate health scores
      final authHealth = isAuthenticated ? 1.0 : 0.0;
      final continuousHealth = continuousStatus.isActive ? 1.0 : 0.0;
      final timeoutHealth = timeoutStatus.isActive ? 1.0 : 0.0;
      final backgroundHealth = backgroundStatus.isActive ? 1.0 : 0.0;
      final refreshHealth = backgroundStats.successRate / 100.0;

      // Calculate overall health
      final overallHealth = (authHealth +
              continuousHealth +
              timeoutHealth +
              backgroundHealth +
              refreshHealth) /
          5.0;

      return ContinuousSessionHealth(
        isAuthenticated: isAuthenticated,
        continuousSessionActive: continuousStatus.isActive,
        timeoutOverrideActive: timeoutStatus.isActive,
        backgroundTaskActive: backgroundStatus.isActive,
        refreshSuccessRate: backgroundStats.successRate,
        overallHealth: overallHealth,
        lastHealthCheck: DateTime.now(),
      );
    } catch (e) {
      log("❌ Error generating health report: $e");
      return ContinuousSessionHealth(
        isAuthenticated: false,
        continuousSessionActive: false,
        timeoutOverrideActive: false,
        backgroundTaskActive: false,
        refreshSuccessRate: 0.0,
        overallHealth: 0.0,
        lastHealthCheck: DateTime.now(),
      );
    }
  }

  /// Perform corrective action based on health report
  Future<void> _performCorrectiveAction(ContinuousSessionHealth health) async {
    try {
      log("🔧 Performing corrective action for session health issues");

      if (!health.isAuthenticated) {
        log("❌ Authentication lost - cannot perform corrective action");
        await deactivateContinuousSession();
        return;
      }

      if (!health.continuousSessionActive) {
        log("🔄 Reactivating continuous session");
        await _continuousSessionManager.activateContinuousSession();
      }

      if (!health.timeoutOverrideActive) {
        log("🔄 Reactivating timeout override");
        await _timeoutOverride.activateTimeoutOverride();
      }

      if (!health.backgroundTaskActive) {
        log("🔄 Restarting background task");
        await _backgroundSessionManager.startBackgroundTask();
      }

      if (health.refreshSuccessRate < 50.0) {
        log("🔄 Low refresh success rate - forcing refresh");
        await _backgroundSessionManager.forceBackgroundRefresh();
      }

      log("✅ Corrective action completed");
    } catch (e) {
      log("❌ Error performing corrective action: $e");
    }
  }

  /// Activate continuous session for indefinite authentication
  Future<void> activateContinuousSession() async {
    if (_isContinuousSessionActive) {
      log("ℹ️ Continuous session already active");
      return;
    }

    try {
      log("🔐 Activating continuous session for indefinite authentication");

      // Verify user is authenticated
      final isAuthenticated = await _authService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception(
            "Cannot activate continuous session - user not authenticated");
      }

      // Activate all session management components
      await _activateAllComponents();

      _isContinuousSessionActive = true;
      _stateController.add(ContinuousSessionIntegrationState.active);

      log("✅ Continuous session activated successfully - user will remain logged in indefinitely");
    } catch (e) {
      log("❌ Error activating continuous session: $e");
      _stateController.add(ContinuousSessionIntegrationState.error);
      rethrow;
    }
  }

  /// Activate all session management components
  Future<void> _activateAllComponents() async {
    try {
      log("🔧 Activating all session management components");

      // Activate timeout override first to prevent any timeouts
      await _timeoutOverride.activateTimeoutOverride();

      // Activate continuous session manager
      await _continuousSessionManager.activateContinuousSession();

      // Start background session management
      await _backgroundSessionManager.startBackgroundTask();

      // Force immediate token refresh to ensure everything is working
      await _dynamicAuth.forceComprehensiveRefresh();

      log("✅ All session management components activated");
    } catch (e) {
      log("❌ Error activating session management components: $e");
      rethrow;
    }
  }

  /// Deactivate continuous session
  Future<void> deactivateContinuousSession() async {
    if (!_isContinuousSessionActive) {
      log("ℹ️ Continuous session not active");
      return;
    }

    try {
      log("🚪 Deactivating continuous session");

      // Deactivate all components
      await _deactivateAllComponents();

      _isContinuousSessionActive = false;
      _stateController.add(ContinuousSessionIntegrationState.inactive);

      log("✅ Continuous session deactivated successfully");
    } catch (e) {
      log("❌ Error deactivating continuous session: $e");
      _stateController.add(ContinuousSessionIntegrationState.error);
    }
  }

  /// Deactivate all session management components
  Future<void> _deactivateAllComponents() async {
    try {
      log("🔧 Deactivating all session management components");

      // Stop background session management
      await _backgroundSessionManager.stopBackgroundTask();

      // Deactivate continuous session manager
      await _continuousSessionManager.deactivateContinuousSession();

      // Deactivate timeout override
      await _timeoutOverride.deactivateTimeoutOverride();

      log("✅ All session management components deactivated");
    } catch (e) {
      log("❌ Error deactivating session management components: $e");
    }
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
      log("📱 App resumed - ensuring seamless authenticated state");

      if (_isContinuousSessionActive) {
        // Notify all components of app resume
        await _continuousSessionManager.validateAndRefreshSession();
        await _backgroundSessionManager.handleAppForeground();
        // Note: DynamicAuthIntegration handles lifecycle internally

        // Perform immediate health check
        await _performHealthCheck();

        log("✅ Seamless return to authenticated state confirmed");
        _stateController
            .add(ContinuousSessionIntegrationState.activeAfterResume);
      }
    } catch (e) {
      log("❌ Error handling app resumed: $e");
    }
  }

  /// Handle app paused - maintain background authentication
  void _handleAppPaused() async {
    try {
      log("📱 App paused - maintaining background authentication");

      if (_isContinuousSessionActive) {
        // Notify all components of app pause
        await _backgroundSessionManager.handleAppBackground();
        // Note: DynamicAuthIntegration handles lifecycle internally

        log("✅ Background authentication maintenance activated");
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
        // Ensure session state is persisted
        await _performHealthCheck();
        log("✅ Session state preserved for app restart");
      }
    } catch (e) {
      log("❌ Error handling app detached: $e");
    }
  }

  /// Handle app hidden - maintain all operations
  void _handleAppHidden() async {
    try {
      log("📱 App hidden - maintaining all session operations");

      if (_isContinuousSessionActive) {
        // Continue all background operations
        log("✅ All session operations maintained");
      }
    } catch (e) {
      log("❌ Error handling app hidden: $e");
    }
  }

  /// Get comprehensive integration status
  ContinuousSessionIntegrationStatus getIntegrationStatus() {
    try {
      final continuousStatus =
          _continuousSessionManager.getContinuousSessionStatus();
      final timeoutStatus = _timeoutOverride.getOverrideStatus();
      final backgroundStatus =
          _backgroundSessionManager.getBackgroundTaskStatus();

      return ContinuousSessionIntegrationStatus(
        isInitialized: _isInitialized,
        isActive: _isContinuousSessionActive,
        isObservingLifecycle: _isObservingLifecycle,
        continuousSessionStatus: continuousStatus,
        timeoutOverrideStatus: timeoutStatus,
        backgroundTaskStatus: backgroundStatus,
      );
    } catch (e) {
      log("❌ Error getting integration status: $e");
      return ContinuousSessionIntegrationStatus(
        isInitialized: false,
        isActive: false,
        isObservingLifecycle: false,
        continuousSessionStatus:
            _continuousSessionManager.getContinuousSessionStatus(),
        timeoutOverrideStatus: _timeoutOverride.getOverrideStatus(),
        backgroundTaskStatus:
            _backgroundSessionManager.getBackgroundTaskStatus(),
      );
    }
  }

  /// Force comprehensive session validation and refresh
  Future<bool> forceComprehensiveSessionValidation() async {
    try {
      log("🔍 Forcing comprehensive session validation");

      if (!_isContinuousSessionActive) {
        log("⚠️ Continuous session not active");
        return false;
      }

      // Validate and refresh all components
      final continuousRefresh =
          await _continuousSessionManager.validateAndRefreshSession();
      final backgroundRefresh =
          await _backgroundSessionManager.forceBackgroundRefresh();
      final dynamicRefresh = await _dynamicAuth.forceComprehensiveRefresh();

      final success = continuousRefresh && backgroundRefresh && dynamicRefresh;

      if (success) {
        log("✅ Comprehensive session validation successful");
        _stateController
            .add(ContinuousSessionIntegrationState.activeWithRefresh);
      } else {
        log("❌ Comprehensive session validation failed");
        _stateController.add(ContinuousSessionIntegrationState.error);
      }

      return success;
    } catch (e) {
      log("❌ Error during comprehensive session validation: $e");
      return false;
    }
  }

  /// Check if continuous session is active
  bool get isContinuousSessionActive => _isContinuousSessionActive;

  /// Dispose resources
  void dispose() {
    try {
      log("🗑️ Disposing Continuous Session Integration");

      // Stop monitoring
      _sessionMonitorTimer?.cancel();
      _healthCheckTimer?.cancel();

      // Remove lifecycle observer
      if (_isObservingLifecycle) {
        WidgetsBinding.instance.removeObserver(this);
        _isObservingLifecycle = false;
      }

      // Dispose all components
      _continuousSessionManager.dispose();
      _timeoutOverride.dispose();
      _backgroundSessionManager.dispose();
      _dynamicAuth.dispose();

      // Close streams
      _stateController.close();
      _healthController.close();

      _isInitialized = false;
      log("✅ Continuous Session Integration disposed");
    } catch (e) {
      log("❌ Error disposing Continuous Session Integration: $e");
    }
  }
}

/// Integration state enumeration
enum ContinuousSessionIntegrationState {
  uninitialized,
  initialized,
  active,
  activeAfterResume,
  activeWithRefresh,
  inactive,
  error,
}

/// Session health information
class ContinuousSessionHealth {
  final bool isAuthenticated;
  final bool continuousSessionActive;
  final bool timeoutOverrideActive;
  final bool backgroundTaskActive;
  final double refreshSuccessRate;
  final double overallHealth;
  final DateTime lastHealthCheck;

  ContinuousSessionHealth({
    required this.isAuthenticated,
    required this.continuousSessionActive,
    required this.timeoutOverrideActive,
    required this.backgroundTaskActive,
    required this.refreshSuccessRate,
    required this.overallHealth,
    required this.lastHealthCheck,
  });

  Map<String, dynamic> toJson() {
    return {
      'isAuthenticated': isAuthenticated,
      'continuousSessionActive': continuousSessionActive,
      'timeoutOverrideActive': timeoutOverrideActive,
      'backgroundTaskActive': backgroundTaskActive,
      'refreshSuccessRate': refreshSuccessRate,
      'overallHealth': overallHealth,
      'lastHealthCheck': lastHealthCheck.toIso8601String(),
    };
  }
}

/// Integration status information
class ContinuousSessionIntegrationStatus {
  final bool isInitialized;
  final bool isActive;
  final bool isObservingLifecycle;
  final dynamic continuousSessionStatus;
  final dynamic timeoutOverrideStatus;
  final dynamic backgroundTaskStatus;

  ContinuousSessionIntegrationStatus({
    required this.isInitialized,
    required this.isActive,
    required this.isObservingLifecycle,
    required this.continuousSessionStatus,
    required this.timeoutOverrideStatus,
    required this.backgroundTaskStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'isActive': isActive,
      'isObservingLifecycle': isObservingLifecycle,
      'continuousSessionStatus': continuousSessionStatus?.toJson(),
      'timeoutOverrideStatus': timeoutOverrideStatus?.toJson(),
      'backgroundTaskStatus': backgroundTaskStatus?.toJson(),
    };
  }
}

/// Extension for easy access to continuous session integration
extension ContinuousSessionExtension on AuthService {
  /// Get continuous session integration instance
  ContinuousSessionIntegration get continuousSession =>
      ContinuousSessionIntegration();
}
