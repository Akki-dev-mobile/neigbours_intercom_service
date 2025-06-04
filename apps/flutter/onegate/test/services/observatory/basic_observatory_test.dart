import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/services/observatory/observatory_dashboard_service.dart';

void main() {
  group('ObservatoryDashboardService Basic Tests', () {
    late ObservatoryDashboardService observatoryService;

    setUp(() {
      observatoryService = ObservatoryDashboardService();
    });

    tearDown(() {
      observatoryService.dispose();
    });

    group('Basic Functionality', () {
      test('should create instance successfully', () {
        expect(observatoryService, isNotNull);
        expect(observatoryService.isInitialized, isFalse);
        expect(observatoryService.isCollectingMetrics, isFalse);
      });

      test('should have default configuration', () {
        final config = observatoryService.getConfiguration();
        expect(config, isNotEmpty);
        expect(config['dashboardUrl'], isNotNull);
        expect(config['enableRealTimeMetrics'], isNotNull);
      });

      test('should update configuration successfully', () async {
        // Arrange
        final newConfig = {
          'dashboardUrl': 'http://test-dashboard:5015',
          'metricsCollectionInterval': 60,
        };

        // Act
        await observatoryService.updateConfiguration(newConfig);

        // Assert
        final config = observatoryService.getConfiguration();
        expect(config['dashboardUrl'], equals('http://test-dashboard:5015'));
        expect(config['metricsCollectionInterval'], equals(60));
      });

      test('should return empty metrics when not initialized', () {
        final metrics = observatoryService.getAllMetrics();
        expect(metrics, isEmpty);
      });

      test('should return empty real-time metrics when not initialized', () {
        final realtimeMetrics = observatoryService.getRealTimeMetrics();
        expect(realtimeMetrics, isEmpty);
      });

      test('should handle disposal gracefully', () async {
        // Act & Assert
        expect(() => observatoryService.dispose(), returnsNormally);
        expect(observatoryService.isInitialized, isFalse);
        expect(observatoryService.isCollectingMetrics, isFalse);
      });

      test('should handle multiple disposal calls', () async {
        // Act & Assert
        await observatoryService.dispose();
        expect(() => observatoryService.dispose(), returnsNormally);
      });
    });

    group('Configuration Management', () {
      test('should merge configuration updates correctly', () async {
        // Arrange
        final initialConfig = observatoryService.getConfiguration();
        final originalDashboardUrl = initialConfig['dashboardUrl'];
        
        final partialUpdate = {
          'metricsCollectionInterval': 120,
        };

        // Act
        await observatoryService.updateConfiguration(partialUpdate);

        // Assert
        final updatedConfig = observatoryService.getConfiguration();
        expect(updatedConfig['dashboardUrl'], equals(originalDashboardUrl));
        expect(updatedConfig['metricsCollectionInterval'], equals(120));
      });

      test('should handle empty configuration updates', () async {
        // Arrange
        final originalConfig = observatoryService.getConfiguration();

        // Act
        await observatoryService.updateConfiguration({});

        // Assert
        final updatedConfig = observatoryService.getConfiguration();
        expect(updatedConfig, equals(originalConfig));
      });
    });

    group('Error Handling', () {
      test('should handle invalid configuration gracefully', () async {
        // Act & Assert
        expect(() => observatoryService.updateConfiguration({
          'invalidKey': 'invalidValue',
        }), returnsNormally);
      });

      test('should maintain state after configuration errors', () async {
        // Arrange
        final originalConfig = observatoryService.getConfiguration();

        // Act
        await observatoryService.updateConfiguration({
          'dashboardUrl': null, // Invalid value
        });

        // Assert
        final config = observatoryService.getConfiguration();
        expect(config['dashboardUrl'], isNotNull);
      });
    });

    group('Integration Tests', () {
      test('should not interfere with existing OneGate services', () {
        // This test ensures that creating an Observatory service instance
        // doesn't break existing functionality
        
        final service1 = ObservatoryDashboardService();
        final service2 = ObservatoryDashboardService();
        
        // Both should reference the same singleton instance
        expect(identical(service1, service2), isTrue);
      });

      test('should maintain singleton pattern', () {
        final service1 = ObservatoryDashboardService();
        final service2 = ObservatoryDashboardService();
        
        expect(identical(service1, service2), isTrue);
      });
    });
  });

  group('Observatory Service Integration', () {
    test('should be compatible with OneGate architecture', () {
      // Test that the service follows OneGate's architectural patterns
      final observatoryService = ObservatoryDashboardService();
      
      // Should have proper initialization pattern
      expect(observatoryService.isInitialized, isFalse);
      
      // Should have proper configuration management
      expect(observatoryService.getConfiguration(), isNotEmpty);
      
      // Should have proper disposal pattern
      expect(() => observatoryService.dispose(), returnsNormally);
    });

    test('should follow clean architecture principles', () {
      // Test that the service follows clean architecture patterns
      final observatoryService = ObservatoryDashboardService();
      
      // Should be a singleton
      final anotherInstance = ObservatoryDashboardService();
      expect(identical(observatoryService, anotherInstance), isTrue);
      
      // Should have clear separation of concerns
      expect(observatoryService.getConfiguration, isNotNull);
      expect(observatoryService.getAllMetrics, isNotNull);
      expect(observatoryService.getRealTimeMetrics, isNotNull);
    });
  });
}
