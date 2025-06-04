import 'dart:developer';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';

/// Utility class for sorting visitor logs to address API ordering issues
/// 
/// This class provides client-side fallback sorting functionality to ensure
/// visitor logs are displayed in the correct chronological order (newest first)
/// with secondary alphabetical sorting when check-in times are identical.
/// 
/// **Background**: The API endpoint testing revealed that the backend does not
/// return visitors in proper chronological order, causing UX issues where
/// visitors appear in incorrect time sequence.
/// 
/// **Solution**: This utility implements client-side sorting as a fallback
/// until the backend API can be fixed to include proper ORDER BY clauses.
class VisitorSortingUtility {
  
  /// Sorts visitor logs with primary chronological ordering (newest first)
  /// and secondary alphabetical ordering by visitor name.
  /// 
  /// **Sorting Logic**:
  /// 1. Primary sort: Check-in time (newest first) - DESC order
  /// 2. Secondary sort: Visitor name (alphabetical) - ASC order
  /// 3. Null safety: Handles null check-in times and visitor names gracefully
  /// 
  /// **Parameters**:
  /// - [logs]: List of VisitorLog objects to be sorted
  /// 
  /// **Returns**: 
  /// - Sorted list of VisitorLog objects (modifies original list in-place)
  /// 
  /// **Example**:
  /// ```dart
  /// final logs = await remoteDataSource.fetchAllLogs();
  /// final sortedLogs = VisitorSortingUtility.sortVisitorLogs(logs);
  /// ```
  static List<VisitorLog> sortVisitorLogs(List<VisitorLog> logs) {
    log('🔄 Applying client-side visitor log sorting for ${logs.length} logs');
    
    try {
      logs.sort((a, b) {
        // Handle null check-in times - put null times at the end
        if (a.visitor_check_in == null && b.visitor_check_in == null) {
          // Both null, sort by name
          return _compareVisitorNames(a, b);
        }
        if (a.visitor_check_in == null) return 1; // a goes after b
        if (b.visitor_check_in == null) return -1; // a goes before b
        
        // Primary sort: Check-in time (newest first)
        final timeComparison = b.visitor_check_in!.compareTo(a.visitor_check_in!);
        if (timeComparison != 0) {
          return timeComparison;
        }
        
        // Secondary sort: Visitor name (alphabetical)
        return _compareVisitorNames(a, b);
      });
      
      log('✅ Visitor logs sorted successfully - newest first with alphabetical fallback');
      return logs;
    } catch (e) {
      log('❌ Error sorting visitor logs: $e');
      // Return original list if sorting fails
      return logs;
    }
  }
  
  /// Compares visitor names for alphabetical sorting with null safety
  /// 
  /// **Parameters**:
  /// - [a]: First VisitorLog to compare
  /// - [b]: Second VisitorLog to compare
  /// 
  /// **Returns**: 
  /// - Negative if a < b, positive if a > b, zero if equal
  /// 
  /// **Null Handling**:
  /// - Null names are treated as empty strings
  /// - Case-insensitive comparison for better UX
  static int _compareVisitorNames(VisitorLog a, VisitorLog b) {
    final nameA = a.visitor?.name?.toLowerCase() ?? '';
    final nameB = b.visitor?.name?.toLowerCase() ?? '';
    return nameA.compareTo(nameB);
  }
  
  /// Validates that visitor logs are properly sorted (for testing purposes)
  /// 
  /// **Parameters**:
  /// - [logs]: List of VisitorLog objects to validate
  /// 
  /// **Returns**: 
  /// - true if logs are properly sorted, false otherwise
  /// 
  /// **Validation Rules**:
  /// 1. Check-in times should be in descending order (newest first)
  /// 2. When check-in times are identical, names should be alphabetical
  /// 3. Null check-in times should appear at the end
  static bool validateSorting(List<VisitorLog> logs) {
    if (logs.length <= 1) return true;
    
    for (int i = 0; i < logs.length - 1; i++) {
      final current = logs[i];
      final next = logs[i + 1];
      
      // Check chronological ordering
      if (current.visitor_check_in != null && next.visitor_check_in != null) {
        if (current.visitor_check_in!.isBefore(next.visitor_check_in!)) {
          log('❌ Sorting validation failed: chronological order incorrect at index $i');
          return false;
        }
        
        // Check alphabetical ordering for same times
        if (current.visitor_check_in!.isAtSameMomentAs(next.visitor_check_in!)) {
          final nameComparison = _compareVisitorNames(current, next);
          if (nameComparison > 0) {
            log('❌ Sorting validation failed: alphabetical order incorrect at index $i');
            return false;
          }
        }
      }
      
      // Check null handling
      if (current.visitor_check_in == null && next.visitor_check_in != null) {
        log('❌ Sorting validation failed: null check-in time not at end at index $i');
        return false;
      }
    }
    
    log('✅ Visitor log sorting validation passed');
    return true;
  }
  
  /// Gets sorting statistics for debugging and monitoring purposes
  /// 
  /// **Parameters**:
  /// - [logs]: List of VisitorLog objects to analyze
  /// 
  /// **Returns**: 
  /// - Map containing sorting statistics
  static Map<String, dynamic> getSortingStatistics(List<VisitorLog> logs) {
    final stats = <String, dynamic>{
      'total_logs': logs.length,
      'logs_with_check_in': 0,
      'logs_without_check_in': 0,
      'logs_with_names': 0,
      'logs_without_names': 0,
      'date_range': null,
    };
    
    DateTime? earliest;
    DateTime? latest;
    
    for (final log in logs) {
      // Count check-in times
      if (log.visitor_check_in != null) {
        stats['logs_with_check_in']++;
        
        // Track date range
        if (earliest == null || log.visitor_check_in!.isBefore(earliest)) {
          earliest = log.visitor_check_in;
        }
        if (latest == null || log.visitor_check_in!.isAfter(latest)) {
          latest = log.visitor_check_in;
        }
      } else {
        stats['logs_without_check_in']++;
      }
      
      // Count names
      if (log.visitor?.name?.isNotEmpty == true) {
        stats['logs_with_names']++;
      } else {
        stats['logs_without_names']++;
      }
    }
    
    if (earliest != null && latest != null) {
      stats['date_range'] = {
        'earliest': earliest.toIso8601String(),
        'latest': latest.toIso8601String(),
        'span_hours': latest.difference(earliest).inHours,
      };
    }
    
    return stats;
  }
}
