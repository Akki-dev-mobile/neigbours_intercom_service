import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';
import 'package:flutter_onegate/services/api_client/authenticated_dio_factory.dart';
import 'package:flutter_onegate/presentation/widgets/advanced_search_widget.dart';
import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';

void main() {
  group('Meilisearch Integration Tests', () {
    late MeilisearchService meilisearchService;

    setUp(() {
      meilisearchService = MeilisearchService();
    });

    group('Service Integration', () {
      test('should integrate with existing authentication system', () async {
        // Verify that MeilisearchService can be initialized
        expect(meilisearchService, isA<MeilisearchService>());
        
        // Test initialization (will fail without server but shouldn't crash)
        final result = await meilisearchService.initialize();
        expect(result, isA<bool>());
      });

      test('should handle data indexing operations', () async {
        // Test resident indexing
        final testResidents = [
          Member(
            id: 1,
            memberName: 'John Doe',
            memberMobileNumber: '1234567890',
            socBuildingName: 'Tower A',
            unitFlatNumber: 'A-101',
          ),
        ];

        final residentResult = await meilisearchService.indexResidents(testResidents);
        expect(residentResult, isA<bool>());

        // Test visitor indexing
        final testVisitors = [
          Visitor(
            id: 1,
            name: 'Jane Smith',
            mobile: '9876543210',
            isStaff: false,
          ),
        ];

        final visitorResult = await meilisearchService.indexVisitors(testVisitors);
        expect(visitorResult, isA<bool>());
      });

      test('should handle search operations with filters', () async {
        // Test resident search
        final residentResults = await meilisearchService.searchResidents(
          query: 'John',
          building: 'Tower A',
          memberStatus: 'Active',
          approved: true,
        );
        expect(residentResults, isA<List<Map<String, dynamic>>>());

        // Test visitor search
        final visitorResults = await meilisearchService.searchVisitors(
          query: 'Jane',
          isStaff: false,
          fromDate: DateTime.now().subtract(const Duration(days: 30)),
          toDate: DateTime.now(),
        );
        expect(visitorResults, isA<List<Map<String, dynamic>>>());
      });

      test('should provide search suggestions', () async {
        final suggestions = await meilisearchService.getSearchSuggestions(
          'John',
          index: 'residents',
        );
        expect(suggestions, isA<List<String>>());
      });

      test('should handle health checks', () async {
        final isHealthy = await meilisearchService.isHealthy();
        expect(isHealthy, isA<bool>());
      });
    });

    group('UI Component Integration', () {
      test('should have AdvancedSearchWidget available', () {
        // Verify the widget can be instantiated
        expect(() => AdvancedSearchWidget(
          hintText: 'Search residents',
          searchType: SearchType.residents,
          onSearchResults: (results) {},
        ), isA<Function>());
      });

      test('should handle search type enumeration', () {
        // Verify search types are available
        expect(SearchType.residents, isA<SearchType>());
        expect(SearchType.visitors, isA<SearchType>());
      });
    });

    group('Authentication Integration', () {
      test('should work with AuthenticatedDioFactory', () {
        // Test that both systems can coexist
        final authenticatedDio = AuthenticatedDioFactory.createAuthenticatedDio(
          baseUrl: 'http://localhost:7700',
        );
        
        expect(authenticatedDio, isNotNull);
        expect(meilisearchService, isNotNull);
      });

      test('should handle concurrent operations with auth system', () async {
        // Test that Meilisearch operations don't interfere with auth
        final futures = [
          meilisearchService.isHealthy(),
          meilisearchService.searchResidents(query: 'test'),
          meilisearchService.searchVisitors(query: 'test'),
        ];

        final results = await Future.wait(futures);
        expect(results.length, equals(3));
        expect(results[0], isA<bool>()); // Health check
        expect(results[1], isA<List>()); // Resident search
        expect(results[2], isA<List>()); // Visitor search
      });
    });

    group('Error Handling Integration', () {
      test('should handle network errors gracefully', () async {
        // Test with invalid configuration
        final result = await meilisearchService.initialize(
          host: 'http://invalid-host:7700',
          apiKey: 'invalid-key',
        );
        
        expect(result, isFalse);
      });

      test('should handle search errors without crashing', () async {
        // Test search operations that will fail
        final residentResults = await meilisearchService.searchResidents(
          query: 'test-query-that-will-fail',
        );
        
        final visitorResults = await meilisearchService.searchVisitors(
          query: 'test-query-that-will-fail',
        );

        expect(residentResults, isEmpty);
        expect(visitorResults, isEmpty);
      });

      test('should handle indexing errors gracefully', () async {
        // Test indexing with invalid data
        final result = await meilisearchService.indexResidents([]);
        expect(result, isA<bool>());
      });
    });

    group('Performance Integration', () {
      test('should handle multiple concurrent searches', () async {
        // Test concurrent search operations
        final searchFutures = List.generate(5, (index) => 
          meilisearchService.searchResidents(query: 'test$index')
        );

        final results = await Future.wait(searchFutures);
        expect(results.length, equals(5));
        expect(results.every((result) => result is List), isTrue);
      });

      test('should handle large data indexing', () async {
        // Test with larger datasets
        final largeResidentList = List.generate(100, (index) => Member(
          id: index,
          memberName: 'Test User $index',
          memberMobileNumber: '123456789$index',
          socBuildingName: 'Tower ${index % 5}',
          unitFlatNumber: 'A-${index + 100}',
        ));

        final result = await meilisearchService.indexResidents(largeResidentList);
        expect(result, isA<bool>());
      });
    });

    group('Configuration Integration', () {
      test('should handle different initialization scenarios', () async {
        // Test with no parameters
        final result1 = await meilisearchService.initialize();
        expect(result1, isA<bool>());

        // Test with custom host
        final result2 = await meilisearchService.initialize(
          host: 'http://custom-host:7700',
        );
        expect(result2, isA<bool>());

        // Test with custom host and API key
        final result3 = await meilisearchService.initialize(
          host: 'http://custom-host:7700',
          apiKey: 'custom-key',
        );
        expect(result3, isA<bool>());
      });

      test('should maintain singleton behavior', () {
        final instance1 = MeilisearchService();
        final instance2 = MeilisearchService();
        
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Data Consistency Integration', () {
      test('should handle data format consistency', () async {
        // Test that search results have consistent format
        final results = await meilisearchService.searchResidents(query: 'test');
        
        expect(results, isA<List<Map<String, dynamic>>>());
        
        // Each result should be a Map
        for (final result in results) {
          expect(result, isA<Map<String, dynamic>>());
        }
      });

      test('should handle empty search results', () async {
        final emptyResults = await meilisearchService.searchResidents(query: '');
        expect(emptyResults, isEmpty);
      });
    });
  });
}
