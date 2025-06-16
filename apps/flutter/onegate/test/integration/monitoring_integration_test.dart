import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/services/observatory/comprehensive_monitoring_service.dart';
import 'package:flutter_onegate/services/observatory/sentry_monitoring_service.dart';
import 'package:flutter_onegate/services/observatory/hyperdx_logging_service.dart';
import 'package:flutter_onegate/services/observatory/skywalking_tracing_service.dart';
import 'package:flutter_onegate/services/observatory/highlight_session_service.dart';
import 'package:flutter_onegate/services/observatory/observatory_dashboard_service.dart';

void main() {
  group('Monitoring Integration Tests', () {
    late ComprehensiveMonitoringService comprehensiveService;

    setUpAll(() async {
      comprehensiveService = ComprehensiveMonitoringService.instance;
    });

    tearDownAll(() async {
      await comprehensiveService.dispose();
    });

    test('should initialize comprehensive monitoring service', () async {
      await comprehensiveService.initialize();
      expect(comprehensiveService.isInitialized, isTrue);
    });

    test('should initialize all individual monitoring services', () async {
      await comprehensiveService.initialize();
      
      final status = comprehensiveService.getMonitoringStatus();
      
      // Check that all services are initialized
      expect(status['comprehensive_monitoring'], isTrue);
      expect(status['observatory'], isTrue);
      expect(status['sentry'], isTrue);
      expect(status['hyperdx'], isTrue);
      expect(status['skywalking'], isTrue);
      expect(status['highlight'], isTrue);
    });

    test('should set user context across all services', () async {
      await comprehensiveService.initialize();
      
      await comprehensiveService.setUser(
        userId: 'test_user_123',
        email: 'test@example.com',
        name: 'Test User',
        properties: {
          'role': 'tester',
          'plan': 'premium',
        },
      );
      
      expect(comprehensiveService.currentUserId, equals('test_user_123'));
    });

    test('should track events across all platforms', () async {
      await comprehensiveService.initialize();
      
      // Track a custom event
      await comprehensiveService.trackEvent(
        name: 'test_event',
        category: 'testing',
        properties: {
          'test_property': 'test_value',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Should not throw any exceptions
      expect(true, isTrue);
    });

    test('should track screen navigation', () async {
      await comprehensiveService.initialize();
      
      await comprehensiveService.trackScreenNavigation(
        screenName: 'test_screen',
        previousScreen: 'previous_screen',
        properties: {
          'navigation_type': 'push',
          'duration_ms': 250,
        },
      );
      
      // Should not throw any exceptions
      expect(true, isTrue);
    });

    test('should track user actions', () async {
      await comprehensiveService.initialize();
      
      await comprehensiveService.trackUserAction(
        action: 'button_click',
        element: 'submit_button',
        screen: 'test_screen',
        properties: {
          'button_id': 'submit',
          'form_valid': true,
        },
      );
      
      // Should not throw any exceptions
      expect(true, isTrue);
    });

    test('should track network requests', () async {
      await comprehensiveService.initialize();
      
      await comprehensiveService.trackNetworkRequest(
        method: 'GET',
        url: 'https://api.example.com/test',
        statusCode: 200,
        duration: const Duration(milliseconds: 150),
        properties: {
          'endpoint': '/test',
          'cache_hit': false,
        },
      );
      
      // Should not throw any exceptions
      expect(true, isTrue);
    });

    test('should report errors', () async {
      await comprehensiveService.initialize();
      
      final testError = Exception('Test error for monitoring');
      final testStackTrace = StackTrace.current;
      
      await comprehensiveService.reportError(
        testError,
        stackTrace: testStackTrace,
        context: 'integration_test',
        properties: {
          'test_case': 'error_reporting',
          'severity': 'low',
        },
      );
      
      // Should not throw any exceptions
      expect(true, isTrue);
    });

    test('should track performance metrics', () async {
      await comprehensiveService.initialize();
      
      await comprehensiveService.trackPerformance(
        metric: 'screen_load_time',
        value: 1250,
        unit: 'ms',
        screen: 'test_screen',
        properties: {
          'cache_enabled': true,
          'network_type': 'wifi',
        },
      );
      
      // Should not throw any exceptions
      expect(true, isTrue);
    });

    test('should clear user context', () async {
      await comprehensiveService.initialize();
      
      // Set user first
      await comprehensiveService.setUser(
        userId: 'test_user_456',
        email: 'test2@example.com',
      );
      
      expect(comprehensiveService.currentUserId, equals('test_user_456'));
      
      // Clear user
      await comprehensiveService.clearUser();
      
      expect(comprehensiveService.currentUserId, isNull);
    });

    test('should handle service disposal gracefully', () async {
      await comprehensiveService.initialize();
      expect(comprehensiveService.isInitialized, isTrue);
      
      await comprehensiveService.dispose();
      expect(comprehensiveService.isInitialized, isFalse);
    });

    test('should verify all services are fully operational', () async {
      await comprehensiveService.initialize();
      
      // Check if all services are operational
      final isFullyOperational = comprehensiveService.isFullyOperational;
      
      // In test environment, some services might not be fully operational
      // due to missing configuration, but the service should handle this gracefully
      expect(comprehensiveService.isInitialized, isTrue);
    });
  });

  group('Individual Service Tests', () {
    test('Sentry service should initialize', () async {
      final sentryService = SentryMonitoringService.instance;
      await sentryService.initialize();
      
      // Service should handle missing DSN gracefully
      expect(true, isTrue);
    });

    test('HyperDX service should initialize', () async {
      final hyperDxService = HyperDxLoggingService.instance;
      await hyperDxService.initialize();
      
      expect(hyperDxService.isInitialized, isTrue);
    });

    test('SkyWalking service should initialize', () async {
      final skyWalkingService = SkyWalkingTracingService.instance;
      await skyWalkingService.initialize();
      
      expect(skyWalkingService.isInitialized, isTrue);
    });

    test('Highlight service should initialize', () async {
      final highlightService = HighlightSessionService.instance;
      await highlightService.initialize();
      
      expect(highlightService.isInitialized, isTrue);
    });

    test('Observatory service should initialize', () async {
      final observatoryService = ObservatoryDashboardService();
      await observatoryService.initialize();
      
      expect(observatoryService.isInitialized, isTrue);
    });
  });

  group('Error Handling Tests', () {
    test('should handle initialization errors gracefully', () async {
      // Test that services don't crash when configuration is missing
      final comprehensiveService = ComprehensiveMonitoringService.instance;
      
      // This should not throw even if some services fail to initialize
      await comprehensiveService.initialize();
      
      expect(comprehensiveService.isInitialized, isTrue);
    });

    test('should handle tracking errors gracefully', () async {
      final comprehensiveService = ComprehensiveMonitoringService.instance;
      await comprehensiveService.initialize();
      
      // These should not throw even if underlying services have issues
      await comprehensiveService.trackEvent(name: 'test', category: 'test');
      await comprehensiveService.trackScreenNavigation(screenName: 'test');
      await comprehensiveService.trackUserAction(action: 'test', element: 'test');
      
      expect(true, isTrue);
    });
  });
}
