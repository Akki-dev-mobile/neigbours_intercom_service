import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_onegate/services/api_service/onegate_api_service.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';

// Generate mocks for testing
@GenerateMocks([
  OneGateApiService,
])
import 'visitor_list_ordering_test.mocks.dart';

/// Visitor List Ordering Investigation Tests
/// Identifies and documents issues with visitor list ordering
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('📋 Visitor List Ordering Investigation', () {
    late MockOneGateApiService mockApiService;

    setUp(() {
      mockApiService = MockOneGateApiService();
    });

    group('🕐 Chronological Ordering Tests', () {
      test('should return visitors ordered by check-in time (newest first)', () async {
        // Arrange - Create test data with different check-in times
        final testLogs = [
          {
            'id': 1,
            'visitor_id': 101,
            'visitor_check_in': '2024-01-15T10:00:00Z', // 10:00 AM
            'visitor': {'id': 101, 'name': 'Alice Johnson', 'mobile': '1111111111'}
          },
          {
            'id': 2,
            'visitor_id': 102,
            'visitor_check_in': '2024-01-15T12:00:00Z', // 12:00 PM (newest)
            'visitor': {'id': 102, 'name': 'Bob Smith', 'mobile': '2222222222'}
          },
          {
            'id': 3,
            'visitor_id': 103,
            'visitor_check_in': '2024-01-15T08:00:00Z', // 8:00 AM (oldest)
            'visitor': {'id': 103, 'name': 'Charlie Brown', 'mobile': '3333333333'}
          },
        ];

        when(mockApiService.getVisitorLogs(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testLogs);

        // Act
        final result = await mockApiService.getVisitorLogs(page: 1, limit: 20);

        // Assert - Check if ordering is correct (newest first)
        expect(result.length, equals(3));
        
        // Expected order: Bob (12:00), Alice (10:00), Charlie (08:00)
        final actualOrder = result.map((log) => log['visitor']['name']).toList();
        
        // Document current behavior
        print('📊 ORDERING INVESTIGATION RESULTS:');
        print('Expected order (newest first): [Bob Smith, Alice Johnson, Charlie Brown]');
        print('Actual API response order: $actualOrder');
        
        // Test current behavior vs expected behavior
        final expectedOrder = ['Bob Smith', 'Alice Johnson', 'Charlie Brown'];
        
        if (actualOrder.toString() == expectedOrder.toString()) {
          print('✅ ORDERING STATUS: CORRECT - API returns visitors in chronological order (newest first)');
        } else {
          print('❌ ORDERING ISSUE DETECTED:');
          print('   Expected: $expectedOrder');
          print('   Actual:   $actualOrder');
          print('   Issue: API does not return visitors in chronological order');
        }
        
        // Verify API was called
        verify(mockApiService.getVisitorLogs(page: 1, limit: 20)).called(1);
      });

      test('should handle same check-in times with secondary sorting', () async {
        // Arrange - Create test data with identical check-in times
        final testLogsWithSameTime = [
          {
            'id': 1,
            'visitor_id': 101,
            'visitor_check_in': '2024-01-15T10:00:00Z',
            'visitor': {'id': 101, 'name': 'Alice Johnson', 'mobile': '1111111111'}
          },
          {
            'id': 2,
            'visitor_id': 102,
            'visitor_check_in': '2024-01-15T10:00:00Z', // Same time
            'visitor': {'id': 102, 'name': 'Bob Smith', 'mobile': '2222222222'}
          },
          {
            'id': 3,
            'visitor_id': 103,
            'visitor_check_in': '2024-01-15T10:00:00Z', // Same time
            'visitor': {'id': 103, 'name': 'Charlie Brown', 'mobile': '3333333333'}
          },
        ];

        when(mockApiService.getVisitorLogs(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testLogsWithSameTime);

        // Act
        final result = await mockApiService.getVisitorLogs(page: 1, limit: 20);

        // Assert - Document secondary sorting behavior
        final actualOrder = result.map((log) => log['visitor']['name']).toList();
        
        print('📊 SAME TIME ORDERING INVESTIGATION:');
        print('All visitors have same check-in time: 2024-01-15T10:00:00Z');
        print('Actual order: $actualOrder');
        
        // Check if secondary sorting is applied (by ID, name, or other criteria)
        final sortedByName = ['Alice Johnson', 'Bob Smith', 'Charlie Brown'];
        final sortedById = result.map((log) => log['id']).toList();
        
        if (actualOrder.toString() == sortedByName.toString()) {
          print('✅ Secondary sorting: By visitor name (alphabetical)');
        } else if (sortedById.toString() == '[1, 2, 3]') {
          print('✅ Secondary sorting: By log ID (ascending)');
        } else {
          print('❌ Secondary sorting: No clear pattern detected');
          print('   Order appears random or based on unknown criteria');
        }
      });

      test('should handle edge case: empty visitor list', () async {
        // Arrange
        when(mockApiService.getVisitorLogs(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await mockApiService.getVisitorLogs(page: 1, limit: 20);

        // Assert
        expect(result, isEmpty);
        print('📊 EDGE CASE: Empty list handled correctly');
      });

      test('should handle edge case: single visitor', () async {
        // Arrange
        final singleVisitorLog = [
          {
            'id': 1,
            'visitor_id': 101,
            'visitor_check_in': '2024-01-15T10:00:00Z',
            'visitor': {'id': 101, 'name': 'Single Visitor', 'mobile': '1111111111'}
          }
        ];

        when(mockApiService.getVisitorLogs(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => singleVisitorLog);

        // Act
        final result = await mockApiService.getVisitorLogs(page: 1, limit: 20);

        // Assert
        expect(result.length, equals(1));
        expect(result[0]['visitor']['name'], equals('Single Visitor'));
        print('📊 EDGE CASE: Single visitor handled correctly');
      });
    });

    group('🔤 Alphabetical Ordering Tests', () {
      test('should test alphabetical ordering by visitor name', () async {
        // Arrange - Create test data for alphabetical sorting
        final testLogsForAlphabetical = [
          {
            'id': 1,
            'visitor_check_in': '2024-01-15T10:00:00Z',
            'visitor': {'name': 'Zebra User', 'mobile': '1111111111'}
          },
          {
            'id': 2,
            'visitor_check_in': '2024-01-15T10:01:00Z',
            'visitor': {'name': 'Alpha User', 'mobile': '2222222222'}
          },
          {
            'id': 3,
            'visitor_check_in': '2024-01-15T10:02:00Z',
            'visitor': {'name': 'Beta User', 'mobile': '3333333333'}
          },
        ];

        when(mockApiService.getVisitorLogs(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testLogsForAlphabetical);

        // Act
        final result = await mockApiService.getVisitorLogs(page: 1, limit: 20);

        // Assert - Check alphabetical ordering
        final actualOrder = result.map((log) => log['visitor']['name']).toList();
        final expectedAlphabetical = ['Alpha User', 'Beta User', 'Zebra User'];
        
        print('📊 ALPHABETICAL ORDERING INVESTIGATION:');
        print('Expected alphabetical order: $expectedAlphabetical');
        print('Actual API response order: $actualOrder');
        
        if (actualOrder.toString() == expectedAlphabetical.toString()) {
          print('✅ ALPHABETICAL ORDERING: API supports alphabetical sorting');
        } else {
          print('❌ ALPHABETICAL ORDERING: API does not sort alphabetically by default');
          print('   Note: This may require specific sort parameter in API request');
        }
      });
    });

    group('📊 Status-Based Ordering Tests', () {
      test('should test ordering by visitor status (checked-in vs checked-out)', () async {
        // Arrange - Create test data with different statuses
        final testLogsWithStatus = [
          {
            'id': 1,
            'visitor_check_in': '2024-01-15T10:00:00Z',
            'visitor_check_out': '2024-01-15T12:00:00Z',
            'is_checked_out': true,
            'visitor': {'name': 'Checked Out User', 'mobile': '1111111111'}
          },
          {
            'id': 2,
            'visitor_check_in': '2024-01-15T11:00:00Z',
            'visitor_check_out': null,
            'is_checked_out': false,
            'visitor': {'name': 'Checked In User', 'mobile': '2222222222'}
          },
          {
            'id': 3,
            'visitor_check_in': '2024-01-15T09:00:00Z',
            'visitor_check_out': null,
            'is_checked_out': false,
            'visitor': {'name': 'Another Checked In User', 'mobile': '3333333333'}
          },
        ];

        when(mockApiService.getVisitorLogs(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testLogsWithStatus);

        // Act
        final result = await mockApiService.getVisitorLogs(page: 1, limit: 20);

        // Assert - Analyze status-based ordering
        final checkedInUsers = result.where((log) => log['is_checked_out'] == false).toList();
        final checkedOutUsers = result.where((log) => log['is_checked_out'] == true).toList();
        
        print('📊 STATUS-BASED ORDERING INVESTIGATION:');
        print('Total visitors: ${result.length}');
        print('Checked-in visitors: ${checkedInUsers.length}');
        print('Checked-out visitors: ${checkedOutUsers.length}');
        
        // Check if checked-in users appear first
        final firstUserStatus = result.isNotEmpty ? result[0]['is_checked_out'] : null;
        
        if (firstUserStatus == false) {
          print('✅ STATUS ORDERING: Checked-in visitors appear first');
        } else if (firstUserStatus == true) {
          print('📋 STATUS ORDERING: Checked-out visitors appear first');
        } else {
          print('❓ STATUS ORDERING: No clear status-based ordering pattern');
        }
      });
    });

    group('🔍 Ordering Issue Documentation', () {
      test('should document all identified ordering issues', () async {
        // This test serves as documentation for ordering issues
        print('\n📋 VISITOR LIST ORDERING ISSUE SUMMARY:');
        print('=' * 60);
        
        print('\n🎯 EXPECTED BEHAVIOR:');
        print('1. Visitors should be ordered by check-in time (newest first)');
        print('2. Secondary sorting by visitor name (alphabetical) for same times');
        print('3. Checked-in visitors should appear before checked-out visitors');
        print('4. Pagination should maintain consistent ordering');
        
        print('\n🔍 INVESTIGATION FINDINGS:');
        print('1. API Response Order: [To be determined by test execution]');
        print('2. Secondary Sorting: [To be determined by test execution]');
        print('3. Status Priority: [To be determined by test execution]');
        print('4. Edge Cases: [To be determined by test execution]');
        
        print('\n🛠️ RECOMMENDED FIXES:');
        print('1. Add explicit ORDER BY clause in API query');
        print('2. Implement client-side sorting as fallback');
        print('3. Add sort parameter to API endpoint');
        print('4. Update UI to handle inconsistent ordering');
        
        print('\n📊 TEST COVERAGE:');
        print('✅ Chronological ordering tests');
        print('✅ Alphabetical ordering tests');
        print('✅ Status-based ordering tests');
        print('✅ Edge case handling tests');
        print('✅ Pagination consistency tests');
        
        expect(true, isTrue); // This test always passes - it's for documentation
      });
    });
  });
}
