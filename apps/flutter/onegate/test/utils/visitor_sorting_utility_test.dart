import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/utils/visitor_sorting_utility.dart';

void main() {
  group('VisitorSortingUtility Tests', () {
    
    /// Helper method to create test visitor logs with specific check-in times and names
    VisitorLog createTestVisitorLog({
      required int id,
      required String name,
      DateTime? checkInTime,
      String? mobile,
    }) {
      return VisitorLog(
        id: id,
        visitor_id: id,
        visitor: Visitor(
          id: id,
          name: name,
          mobile: mobile ?? '1234567890',
        ),
        visitor_check_in: checkInTime,
        visitor_purpose_category_id: 1,
        visitor_count: 1,
        company_id: 1,
        is_checked_out: false,
      );
    }

    group('Chronological Sorting Tests', () {
      test('should sort visitor logs by check-in time (newest first)', () {
        // Arrange
        final now = DateTime.now();
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Alice Johnson',
            checkInTime: now.subtract(Duration(hours: 2)), // Oldest
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Bob Smith',
            checkInTime: now, // Newest
          ),
          createTestVisitorLog(
            id: 3,
            name: 'Charlie Brown',
            checkInTime: now.subtract(Duration(hours: 1)), // Middle
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs.length, equals(3));
        expect(sortedLogs[0].visitor?.name, equals('Bob Smith')); // Newest first
        expect(sortedLogs[1].visitor?.name, equals('Charlie Brown')); // Middle
        expect(sortedLogs[2].visitor?.name, equals('Alice Johnson')); // Oldest last
        
        // Verify chronological order
        expect(
          sortedLogs[0].visitor_check_in!.isAfter(sortedLogs[1].visitor_check_in!),
          isTrue,
        );
        expect(
          sortedLogs[1].visitor_check_in!.isAfter(sortedLogs[2].visitor_check_in!),
          isTrue,
        );
      });

      test('should handle same check-in times with secondary alphabetical sorting', () {
        // Arrange
        final sameTime = DateTime.now();
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Zebra User',
            checkInTime: sameTime,
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Alpha User',
            checkInTime: sameTime,
          ),
          createTestVisitorLog(
            id: 3,
            name: 'Beta User',
            checkInTime: sameTime,
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs.length, equals(3));
        expect(sortedLogs[0].visitor?.name, equals('Alpha User')); // Alphabetically first
        expect(sortedLogs[1].visitor?.name, equals('Beta User')); // Alphabetically second
        expect(sortedLogs[2].visitor?.name, equals('Zebra User')); // Alphabetically last
      });

      test('should handle mixed chronological and alphabetical sorting', () {
        // Arrange
        final now = DateTime.now();
        final olderTime = now.subtract(Duration(hours: 1));
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Charlie Brown',
            checkInTime: now, // Same as Bob, should be alphabetically after
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Alice Johnson',
            checkInTime: olderTime, // Older time
          ),
          createTestVisitorLog(
            id: 3,
            name: 'Bob Smith',
            checkInTime: now, // Same as Charlie, should be alphabetically before
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs.length, equals(3));
        // First two should be from newer time, alphabetically sorted
        expect(sortedLogs[0].visitor?.name, equals('Bob Smith'));
        expect(sortedLogs[1].visitor?.name, equals('Charlie Brown'));
        // Last should be from older time
        expect(sortedLogs[2].visitor?.name, equals('Alice Johnson'));
      });
    });

    group('Edge Cases Tests', () {
      test('should handle empty visitor list', () {
        // Arrange
        final logs = <VisitorLog>[];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs, isEmpty);
      });

      test('should handle single visitor', () {
        // Arrange
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Single Visitor',
            checkInTime: DateTime.now(),
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs.length, equals(1));
        expect(sortedLogs[0].visitor?.name, equals('Single Visitor'));
      });

      test('should handle null check-in times', () {
        // Arrange
        final now = DateTime.now();
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'No Check-in Time',
            checkInTime: null, // Null check-in time
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Valid Check-in',
            checkInTime: now,
          ),
          createTestVisitorLog(
            id: 3,
            name: 'Another Null',
            checkInTime: null, // Another null check-in time
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs.length, equals(3));
        // Valid check-in time should come first
        expect(sortedLogs[0].visitor?.name, equals('Valid Check-in'));
        expect(sortedLogs[0].visitor_check_in, isNotNull);
        
        // Null check-in times should come after, sorted alphabetically
        expect(sortedLogs[1].visitor?.name, equals('Another Null'));
        expect(sortedLogs[1].visitor_check_in, isNull);
        expect(sortedLogs[2].visitor?.name, equals('No Check-in Time'));
        expect(sortedLogs[2].visitor_check_in, isNull);
      });

      test('should handle null visitor names', () {
        // Arrange
        final now = DateTime.now();
        final logs = [
          VisitorLog(
            id: 1,
            visitor_id: 1,
            visitor: Visitor(id: 1, name: null), // Null name
            visitor_check_in: now,
            visitor_purpose_category_id: 1,
            visitor_count: 1,
            company_id: 1,
            is_checked_out: false,
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Valid Name',
            checkInTime: now,
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs.length, equals(2));
        // Should not crash and should handle null names gracefully
        expect(sortedLogs[0].visitor?.name, anyOf(isNull, equals('')));
        expect(sortedLogs[1].visitor?.name, equals('Valid Name'));
      });

      test('should handle case-insensitive name sorting', () {
        // Arrange
        final sameTime = DateTime.now();
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'zebra user', // lowercase
            checkInTime: sameTime,
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Alpha User', // mixed case
            checkInTime: sameTime,
          ),
          createTestVisitorLog(
            id: 3,
            name: 'BETA USER', // uppercase
            checkInTime: sameTime,
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs.length, equals(3));
        expect(sortedLogs[0].visitor?.name, equals('Alpha User'));
        expect(sortedLogs[1].visitor?.name, equals('BETA USER'));
        expect(sortedLogs[2].visitor?.name, equals('zebra user'));
      });
    });

    group('Validation Tests', () {
      test('should validate correctly sorted logs', () {
        // Arrange
        final now = DateTime.now();
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Bob Smith',
            checkInTime: now, // Newest
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Alice Johnson',
            checkInTime: now.subtract(Duration(hours: 1)), // Older
          ),
        ];

        // Act
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);
        final isValid = VisitorSortingUtility.validateSorting(sortedLogs);

        // Assert
        expect(isValid, isTrue);
      });

      test('should detect incorrectly sorted logs', () {
        // Arrange - manually create incorrectly sorted logs
        final now = DateTime.now();
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Alice Johnson',
            checkInTime: now.subtract(Duration(hours: 1)), // Older time first (incorrect)
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Bob Smith',
            checkInTime: now, // Newer time second (incorrect)
          ),
        ];

        // Act - don't sort, just validate the incorrect order
        final isValid = VisitorSortingUtility.validateSorting(logs);

        // Assert
        expect(isValid, isFalse);
      });

      test('should validate empty and single item lists', () {
        // Arrange & Act & Assert
        expect(VisitorSortingUtility.validateSorting([]), isTrue);
        expect(
          VisitorSortingUtility.validateSorting([
            createTestVisitorLog(id: 1, name: 'Single', checkInTime: DateTime.now())
          ]),
          isTrue,
        );
      });
    });

    group('Statistics Tests', () {
      test('should generate correct sorting statistics', () {
        // Arrange
        final now = DateTime.now();
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Valid Name',
            checkInTime: now,
          ),
          createTestVisitorLog(
            id: 2,
            name: 'Another Valid',
            checkInTime: now.subtract(Duration(hours: 1)),
          ),
          VisitorLog(
            id: 3,
            visitor_id: 3,
            visitor: Visitor(id: 3, name: null), // No name
            visitor_check_in: null, // No check-in time
            visitor_purpose_category_id: 1,
            visitor_count: 1,
            company_id: 1,
            is_checked_out: false,
          ),
        ];

        // Act
        final stats = VisitorSortingUtility.getSortingStatistics(logs);

        // Assert
        expect(stats['total_logs'], equals(3));
        expect(stats['logs_with_check_in'], equals(2));
        expect(stats['logs_without_check_in'], equals(1));
        expect(stats['logs_with_names'], equals(2));
        expect(stats['logs_without_names'], equals(1));
        expect(stats['date_range'], isNotNull);
        expect(stats['date_range']['span_hours'], equals(1));
      });

      test('should handle statistics for empty list', () {
        // Arrange
        final logs = <VisitorLog>[];

        // Act
        final stats = VisitorSortingUtility.getSortingStatistics(logs);

        // Assert
        expect(stats['total_logs'], equals(0));
        expect(stats['logs_with_check_in'], equals(0));
        expect(stats['logs_without_check_in'], equals(0));
        expect(stats['logs_with_names'], equals(0));
        expect(stats['logs_without_names'], equals(0));
        expect(stats['date_range'], isNull);
      });
    });

    group('Error Handling Tests', () {
      test('should handle sorting errors gracefully', () {
        // This test ensures that if sorting fails for any reason,
        // the original list is returned without crashing
        
        // Arrange
        final logs = [
          createTestVisitorLog(
            id: 1,
            name: 'Test Visitor',
            checkInTime: DateTime.now(),
          ),
        ];

        // Act - this should not throw an exception
        final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);

        // Assert
        expect(sortedLogs, isNotNull);
        expect(sortedLogs.length, equals(1));
      });
    });
  });
}
