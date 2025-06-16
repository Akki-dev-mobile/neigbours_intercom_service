import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/services/observatory/observatory_dashboard_service.dart';
import 'package:flutter_onegate/services/observatory/sentry_monitoring_service.dart';
import 'package:flutter_onegate/services/observatory/hyperdx_logging_service.dart';
import 'package:flutter_onegate/services/observatory/skywalking_tracing_service.dart';
import 'package:flutter_onegate/services/observatory/highlight_session_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Comprehensive monitoring service that coordinates all monitoring platforms
class ComprehensiveMonitoringService {
  static ComprehensiveMonitoringService? _instance;
  static ComprehensiveMonitoringService get instance =>
      _instance ??= ComprehensiveMonitoringService._();

  ComprehensiveMonitoringService._();

  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentSessionId;
  Map<String, dynamic> _userContext = {};

  /// Initialize all monitoring services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      dev.log('Initializing comprehensive monitoring service...');

      // Initialize all monitoring services in parallel for better performance
      await Future.wait([
        ObservatoryDashboardService().initialize(),
        SentryMonitoringService.instance.initialize(),
        HyperDxLoggingService.instance.initialize(),
        SkyWalkingTracingService.instance.initialize(),
        HighlightSessionService.instance.initialize(),
      ]);

      _isInitialized = true;
      dev.log('Comprehensive monitoring service initialized successfully');

      // Track initialization across all platforms
      await _trackEvent(
        type: 'system',
        name: 'monitoring_initialized',
        properties: {
          'services': [
            'observatory',
            'sentry',
            'hyperdx',
            'skywalking',
            'highlight',
            'posthog',
          ],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Send a test error to verify PostHog error tracking is working
      if (kDebugMode) {
        dev.log('🧪 Sending test error to verify PostHog error tracking...');
        await Future.delayed(const Duration(seconds: 2));
        await testErrorTracking();
      }
    } catch (e, stackTrace) {
      dev.log('Error initializing comprehensive monitoring service: $e');
      dev.log('Stack trace: $stackTrace');

      // Report initialization error to available services
      await _reportError('monitoring_initialization_failed', e, stackTrace);
    }
  }

  /// Set user context across all monitoring platforms
  Future<void> setUser({
    required String userId,
    String? email,
    String? name,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) return;

    _currentUserId = userId;
    _userContext = {
      'user_id': userId,
      'email': email,
      'name': name,
      ...?properties,
    };

    try {
      // Set user context in all services
      await Future.wait([
        SentryMonitoringService.instance.setUser(
          userId: userId,
          email: email,
          username: name,
          extras: properties,
        ),
        HyperDxLoggingService.instance.logEvent(
          level: 'info',
          message: 'User identified',
          category: 'user',
          metadata: _userContext,
          userId: userId,
        ),
        HighlightSessionService.instance.setUser(
          userId: userId,
          email: email,
          name: name,
          properties: properties,
        ),
      ]);

      dev.log('User context set across all monitoring platforms: $userId');
    } catch (e) {
      dev.log('Error setting user context: $e');
    }
  }

  /// Clear user context from all platforms
  Future<void> clearUser() async {
    if (!_isInitialized) return;

    try {
      _currentUserId = null;
      _userContext.clear();

      await Future.wait([
        SentryMonitoringService.instance.clearUser(),
        HyperDxLoggingService.instance.logEvent(
          level: 'info',
          message: 'User logged out',
          category: 'user',
        ),
      ]);

      dev.log('User context cleared from all monitoring platforms');
    } catch (e) {
      dev.log('Error clearing user context: $e');
    }
  }

  /// Track an event across all relevant platforms
  Future<void> trackEvent({
    required String name,
    String? category,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) return;

    await _trackEvent(
      type: category ?? 'custom',
      name: name,
      properties: properties,
    );
  }

  /// Track screen navigation across all platforms
  Future<void> trackScreenNavigation({
    required String screenName,
    String? previousScreen,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) return;

    try {
      // Track screen view across platforms (handle void returns)
      SentryMonitoringService.instance.trackScreenView(
        screenName,
        extras: {
          'previous_screen': previousScreen,
          ...?properties,
        },
      );

      await HyperDxLoggingService.instance.logEvent(
        level: 'info',
        message: 'Screen navigation: $screenName',
        category: 'navigation',
        metadata: {
          'screen_name': screenName,
          'previous_screen': previousScreen,
          ...?properties,
        },
        userId: _currentUserId,
      );

      HighlightSessionService.instance.trackScreenView(
        screenName: screenName,
        previousScreen: previousScreen,
        properties: properties,
        userId: _currentUserId,
      );

      dev.log('Screen navigation tracked: $screenName');
    } catch (e) {
      dev.log('Error tracking screen navigation: $e');
    }
  }

  /// Track user action across all platforms
  Future<void> trackUserAction({
    required String action,
    String? element,
    String? screen,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) return;

    try {
      // Track user action across platforms (handle void returns)
      SentryMonitoringService.instance.trackUserAction(
        action,
        extras: {
          'element': element,
          'screen': screen,
          ...?properties,
        },
      );

      await HyperDxLoggingService.instance.logUserAction(
        action: action,
        screen: screen,
        metadata: {
          'element': element,
          ...?properties,
        },
        userId: _currentUserId,
      );

      HighlightSessionService.instance.trackUserInteraction(
        action: action,
        element: element ?? 'unknown',
        screen: screen,
        properties: properties,
        userId: _currentUserId,
      );

      dev.log('User action tracked: $action');
    } catch (e) {
      dev.log('Error tracking user action: $e');
    }
  }

  /// Track network request across all platforms
  Future<void> trackNetworkRequest({
    required String method,
    required String url,
    int? statusCode,
    Duration? duration,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) return;

    try {
      // Track network request across platforms (handle void returns)
      SentryMonitoringService.instance.trackNetworkRequest(
        url: url,
        method: method,
        statusCode: statusCode,
        duration: duration,
        extras: properties,
      );

      await HyperDxLoggingService.instance.logNetworkRequest(
        method: method,
        url: url,
        statusCode: statusCode,
        duration: duration,
        requestData: properties,
        userId: _currentUserId,
      );

      HighlightSessionService.instance.trackNetworkRequest(
        method: method,
        url: url,
        statusCode: statusCode,
        duration: duration,
        properties: properties,
        userId: _currentUserId,
      );

      dev.log('Network request tracked: $method $url');
    } catch (e) {
      dev.log('Error tracking network request: $e');
    }
  }

  /// Report error across all platforms
  Future<void> reportError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) return;

    await _reportError(
        context ?? 'application_error', error, stackTrace, properties);
  }

  /// Track performance metric across all platforms
  Future<void> trackPerformance({
    required String metric,
    required num value,
    String? unit,
    String? screen,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) return;

    try {
      await Future.wait([
        HyperDxLoggingService.instance.logEvent(
          level: 'info',
          message: 'Performance metric: $metric',
          category: 'performance',
          metadata: {
            'metric': metric,
            'value': value,
            'unit': unit ?? 'ms',
            'screen': screen,
            ...?properties,
          },
          userId: _currentUserId,
        ),
        HighlightSessionService.instance.trackPerformance(
          metric: metric,
          value: value,
          unit: unit,
          screen: screen,
          properties: properties,
          userId: _currentUserId,
        ),
      ]);

      dev.log('Performance metric tracked: $metric = $value');
    } catch (e) {
      dev.log('Error tracking performance metric: $e');
    }
  }

  /// Internal method to track events across platforms
  Future<void> _trackEvent({
    required String type,
    required String name,
    Map<String, dynamic>? properties,
  }) async {
    try {
      await Future.wait([
        HyperDxLoggingService.instance.logEvent(
          level: 'info',
          message: 'Event: $name',
          category: type,
          metadata: properties,
          userId: _currentUserId,
        ),
        HighlightSessionService.instance.trackEvent(
          type: type,
          name: name,
          properties: properties,
          userId: _currentUserId,
        ),
      ]);
    } catch (e) {
      dev.log('Error tracking event: $e');
    }
  }

  /// Internal method to report errors across platforms
  Future<void> _reportError(
    String context,
    dynamic error,
    StackTrace? stackTrace, [
    Map<String, dynamic>? properties,
  ]) async {
    try {
      await Future.wait([
        SentryMonitoringService.instance.captureException(
          error,
          stackTrace: stackTrace,
          extra: {
            'context': context,
            ...?properties,
          },
        ),
        HyperDxLoggingService.instance.logError(
          message: 'Error in $context',
          error: error,
          stackTrace: stackTrace,
          metadata: properties,
          userId: _currentUserId,
        ),
        HighlightSessionService.instance.trackError(
          error: error.toString(),
          stackTrace: stackTrace?.toString(),
          properties: {
            'context': context,
            ...?properties,
          },
          userId: _currentUserId,
        ),
        _sendErrorToPostHog(context, error, stackTrace, properties),
      ]);
    } catch (e) {
      dev.log('Error reporting error: $e');
    }
  }

  /// Send error to PostHog
  Future<void> _sendErrorToPostHog(
    String context,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? properties,
  ) async {
    try {
      // Convert properties to Object for PostHog compatibility
      final Map<String, Object> postHogProperties = {};

      // Add standard properties
      postHogProperties['error_type'] = error.runtimeType.toString();
      postHogProperties['error_message'] = error.toString();
      postHogProperties['error_context'] = context;
      postHogProperties['is_fatal'] = false;
      postHogProperties['timestamp'] = DateTime.now().toIso8601String();

      // Add optional properties if not null
      if (stackTrace != null) {
        postHogProperties['stack_trace'] = stackTrace.toString();
      }
      if (_currentUserId != null) {
        postHogProperties['user_id'] = _currentUserId!;
      }

      // Add additional properties if provided
      properties?.forEach((key, value) {
        if (value != null) {
          postHogProperties[key] = value;
        }
      });

      await Posthog().capture(
        eventName: 'error_occurred',
        properties: postHogProperties,
      );
    } catch (e) {
      dev.log('Error sending error to PostHog: $e');
    }
  }

  /// Get monitoring status
  Map<String, bool> getMonitoringStatus() {
    return {
      'comprehensive_monitoring': _isInitialized,
      'observatory': ObservatoryDashboardService().isInitialized,
      'sentry': SentryMonitoringService.instance.isInitialized,
      'hyperdx': HyperDxLoggingService.instance.isInitialized,
      'skywalking': SkyWalkingTracingService.instance.isInitialized,
      'highlight': HighlightSessionService.instance.isInitialized,
    };
  }

  /// Check if monitoring is fully operational
  bool get isFullyOperational {
    final status = getMonitoringStatus();
    return status.values.every((isInitialized) => isInitialized);
  }

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Test error tracking - sends a test error to all platforms including PostHog
  Future<void> testErrorTracking() async {
    if (!_isInitialized) return;

    try {
      await reportError(
        Exception('Test error for monitoring verification'),
        stackTrace: StackTrace.current,
        context: 'test_error_tracking',
        properties: {
          'test_type': 'error_tracking_verification',
          'platform': 'flutter',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      dev.log('Test error sent to all monitoring platforms including PostHog');
    } catch (e) {
      dev.log('Error during test error tracking: $e');
    }
  }

  /// Dispose all monitoring services
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await Future.wait([
        ObservatoryDashboardService().dispose(),
        SentryMonitoringService.instance.dispose(),
        HyperDxLoggingService.instance.dispose(),
        SkyWalkingTracingService.instance.dispose(),
        HighlightSessionService.instance.dispose(),
      ]);

      _isInitialized = false;
      _currentUserId = null;
      _userContext.clear();

      dev.log('Comprehensive monitoring service disposed');
    } catch (e) {
      dev.log('Error disposing comprehensive monitoring service: $e');
    }
  }
}
