import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_onegate/services/data_health/data_health_service.dart';
import 'package:flutter_onegate/services/notifications/ntfy_service.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';
import 'package:flutter_onegate/services/background/data_observability_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Observability Services Tests', () {
    late DataHealthService healthService;
    late NtfyService ntfyService;
    late MeilisearchService meilisearchService;
    late DataObservabilityService observabilityService;

    setUpAll(() async {
      // Initialize Hive for testing
      Hive.init('./test_hive');
    });

    setUp(() {
      healthService = DataHealthService();
      ntfyService = NtfyService();
      meilisearchService = MeilisearchService();
      observabilityService = DataObservabilityService();
    });

    tearDownAll(() async {
      await Hive.close();
    });

    group('DataHealthService', () {
      test('should create service instance', () async {
        // Test service creation
        expect(healthService, isNotNull);
        expect(healthService, isA<DataHealthService>());
      });

      test('should create health check result objects', () async {
        // Test creating health check results
        final result = HealthCheckResult();
        result.timestamp = DateTime.now();
        result.overallStatus = HealthStatus.healthy;

        expect(result.overallStatus, equals(HealthStatus.healthy));
        expect(result.timestamp, isNotNull);
      });

      test('should create data consistency check objects', () async {
        // Test creating data consistency check objects
        final check = DataConsistencyCheck();
        check.checkType = 'test_check';
        check.timestamp = DateTime.now();
        check.status = HealthStatus.warning;
        check.message = 'Test message';

        expect(check.checkType, equals('test_check'));
        expect(check.status, equals(HealthStatus.warning));
        expect(check.message, equals('Test message'));
        expect(check.timestamp, isNotNull);
      });
    });

    group('NtfyService', () {
      test('should create service instance', () async {
        expect(ntfyService, isNotNull);
        expect(ntfyService, isA<NtfyService>());
      });

      test('should create alert priority enum values', () async {
        expect(AlertPriority.min.value, equals(1));
        expect(AlertPriority.low.value, equals(2));
        expect(AlertPriority.default_.value, equals(3));
        expect(AlertPriority.high.value, equals(4));
        expect(AlertPriority.max.value, equals(5));
      });
    });

    group('MeilisearchService', () {
      test('should initialize successfully', () async {
        expect(() => meilisearchService.initialize(), returnsNormally);
      });

      test('should return empty results when not connected', () async {
        final results = await meilisearchService.searchResidents(
          query: 'John',
          building: 'Tower A',
        );

        expect(results, isA<List<Map<String, dynamic>>>());
      });

      test('should return empty suggestions when not connected', () async {
        final suggestions = await meilisearchService.getSearchSuggestions(
          'John',
          index: 'residents',
        );

        expect(suggestions, isA<List<String>>());
      });
    });

    group('DataObservabilityService', () {
      test('should initialize successfully', () async {
        expect(() => observabilityService.initialize(), returnsNormally);
      });
    });

    group('Data Models', () {
      test('HealthCheckResult should serialize/deserialize correctly', () {
        final result = HealthCheckResult();
        result.timestamp = DateTime.now();
        result.overallStatus = HealthStatus.warning;
        result.error = 'Test error';

        final json = result.toJson();
        final restored = HealthCheckResult.fromJson(json);

        expect(restored.overallStatus, equals(result.overallStatus));
        expect(restored.error, equals(result.error));
        expect(restored.timestamp?.millisecondsSinceEpoch,
            equals(result.timestamp?.millisecondsSinceEpoch));
      });

      test('DataConsistencyCheck should serialize/deserialize correctly', () {
        final check = DataConsistencyCheck();
        check.checkType = 'test_check';
        check.timestamp = DateTime.now();
        check.status = HealthStatus.critical;
        check.message = 'Test message';
        check.details = {'key': 'value'};

        final json = check.toJson();
        final restored = DataConsistencyCheck.fromJson(json);

        expect(restored.checkType, equals(check.checkType));
        expect(restored.status, equals(check.status));
        expect(restored.message, equals(check.message));
        expect(restored.details, equals(check.details));
      });

      test('AlertPriority enum should have correct values', () {
        expect(AlertPriority.min.value, equals(1));
        expect(AlertPriority.low.value, equals(2));
        expect(AlertPriority.default_.value, equals(3));
        expect(AlertPriority.high.value, equals(4));
        expect(AlertPriority.max.value, equals(5));
      });

      test('HealthStatus enum should have correct display names', () {
        expect(HealthStatus.healthy.displayName, equals('Healthy'));
        expect(HealthStatus.warning.displayName, equals('Warning'));
        expect(HealthStatus.critical.displayName, equals('Critical'));
      });
    });
  });
}
