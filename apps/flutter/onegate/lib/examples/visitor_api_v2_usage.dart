import 'dart:developer';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/services/api_service/onegate_api_service.dart';
import 'package:get_it/get_it.dart';

/// Example usage of the new V2 Visitor Log API
/// This demonstrates how to fetch visitor logs with counts and pagination
class VisitorApiV2Usage {
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  late final OneGateApiService _apiService;

  VisitorApiV2Usage() {
    _apiService = GetIt.I<OneGateApiService>();
  }

  /// Example 1: Get visitor counts for today
  Future<void> getTodayVisitorCounts() async {
    try {
      log('📊 Fetching today\'s visitor counts...');

      // Using RemoteDataSource
      final counts = await _remoteDataSource.fetchVisitorCounts();

      log('✅ Visitor Counts (RemoteDataSource):');
      log('📈 Total (In-Out): ${counts['total']}');
      log('📥 Visitor-In: ${counts['visitor_in']}');
      log('📤 Visitor-Out: ${counts['visitor_out']}');
    } catch (e) {
      log('❌ Error fetching visitor counts: $e');
    }
  }

  /// Example 2: Get visitor counts using API Service
  Future<void> getVisitorCountsViaApiService() async {
    try {
      log('📊 Fetching visitor counts via API Service...');

      final counts = await _apiService.getVisitorCounts();

      log('✅ Visitor Counts (OneGateApiService):');
      log('📈 Total (In-Out): ${counts['total']}');
      log('📥 Visitor-In: ${counts['visitor_in']}');
      log('📤 Visitor-Out: ${counts['visitor_out']}');
    } catch (e) {
      log('❌ Error fetching visitor counts: $e');
    }
  }

  /// Example 3: Get visitor logs with pagination and counts
  Future<void> getVisitorLogsWithPagination() async {
    try {
      log('📋 Fetching visitor logs with pagination...');

      final result = await _apiService.getVisitorLogsV2(
        currentPage: 1,
        perPage: 20,
        fromDate: DateTime.now(), // Today only (same as before)
        toDate: DateTime.now(), // Today only (same as before)
      );

      log('✅ Visitor Logs V2 Response (Today Only):');
      log('📊 Total Records: ${result['total']}');
      log('📥 Checked In: ${result['checked_in_count']}');
      log('📤 Checked Out: ${result['checked_out_count']}');
      log('📄 Current Page: ${result['current_page']}');
      log('📄 Per Page: ${result['per_page']}');
      log('📄 Last Page: ${result['last_page']}');
      log('📋 Data Count: ${(result['data'] as List).length}');
    } catch (e) {
      log('❌ Error fetching visitor logs: $e');
    }
  }

  /// Example 4: Get visitor counts for today only (same as before)
  Future<void> getVisitorCountsForToday() async {
    try {
      log('📊 Fetching visitor counts for today...');

      final counts = await _apiService.getVisitorCounts(
        fromDate: DateTime.now(), // Today only
        toDate: DateTime.now(), // Today only
      );

      log('✅ Visitor Counts (Today Only):');
      log('📈 Total (In-Out): ${counts['total']}');
      log('📥 Visitor-In: ${counts['visitor_in']}');
      log('📤 Visitor-Out: ${counts['visitor_out']}');
    } catch (e) {
      log('❌ Error fetching visitor counts for today: $e');
    }
  }

  /// Example 5: Get visitor logs with specific gate filter
  Future<void> getVisitorLogsForSpecificGate() async {
    try {
      log('📋 Fetching visitor logs for specific gate...');

      final result = await _apiService.getVisitorLogsV2(
        currentPage: 1,
        perPage: 10,
        fromDate: DateTime.now(), // Today only
        toDate: DateTime.now(), // Today only
        inGate: 'cyberone lobby', // Specific gate name
      );

      log('✅ Visitor Logs for Gate "cyberone lobby":');
      log('📊 Total Records: ${result['total']}');
      log('📥 Checked In: ${result['checked_in_count']}');
      log('📤 Checked Out: ${result['checked_out_count']}');
    } catch (e) {
      log('❌ Error fetching visitor logs for specific gate: $e');
    }
  }

  /// Example 6: Comprehensive dashboard data fetch (today only - same as before)
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      log('📊 Fetching comprehensive dashboard data...');

      // Get today's counts only
      final todayCounts = await _apiService.getVisitorCounts(
        fromDate: DateTime.now(), // Today only
        toDate: DateTime.now(), // Today only
      );

      // Get today's visitor logs (first page)
      final todayLogs = await _apiService.getVisitorLogsV2(
        currentPage: 1,
        perPage: 10,
        fromDate: DateTime.now(), // Today only
        toDate: DateTime.now(), // Today only
      );

      final dashboardData = {
        'today_counts': todayCounts,
        'today_logs': todayLogs,
        'last_updated': DateTime.now().toIso8601String(),
      };

      log('✅ Dashboard Data Compiled (Today Only):');
      log('📊 Today - Total: ${todayCounts['total']}, In: ${todayCounts['visitor_in']}, Out: ${todayCounts['visitor_out']}');
      log('📋 Today Logs: ${(todayLogs['data'] as List).length} entries');

      return dashboardData;
    } catch (e) {
      log('❌ Error fetching dashboard data: $e');
      rethrow;
    }
  }

  /// Example 7: Paginated visitor logs loading (today only - same as before)
  Future<List<dynamic>> loadAllVisitorLogs({
    DateTime? fromDate,
    DateTime? toDate,
    int maxPages = 10,
  }) async {
    final allLogs = <dynamic>[];
    int currentPage = 1;

    // Default to today only (same as before)
    final today = DateTime.now();
    final actualFromDate = fromDate ?? today;
    final actualToDate = toDate ?? today;

    try {
      while (currentPage <= maxPages) {
        log('📄 Loading page $currentPage...');

        final result = await _apiService.getVisitorLogsV2(
          currentPage: currentPage,
          perPage: 50,
          fromDate: actualFromDate, // Today by default
          toDate: actualToDate, // Today by default
        );

        final pageData = result['data'] as List;
        allLogs.addAll(pageData);

        final lastPage = result['last_page'] as int;

        log('📋 Page $currentPage loaded: ${pageData.length} records');

        if (currentPage >= lastPage) {
          log('✅ All pages loaded. Total records: ${allLogs.length}');
          break;
        }

        currentPage++;
      }

      return allLogs;
    } catch (e) {
      log('❌ Error loading paginated visitor logs: $e');
      rethrow;
    }
  }
}

/// Usage instructions and examples
/// 
/// 1. **Get Today's Visitor Counts:**
///    ```dart
///    final usage = VisitorApiV2Usage();
///    await usage.getTodayVisitorCounts();
///    ```
///
/// 2. **Get Visitor Logs with Pagination (Today Only):**
///    ```dart
///    await usage.getVisitorLogsWithPagination();
///    ```
///
/// 3. **Get Dashboard Data (Today Only):**
///    ```dart
///    final dashboardData = await usage.getDashboardData();
///    ```
///
/// 4. **Load All Visitor Logs (Today Only by default):**
///    ```dart
///    final allLogs = await usage.loadAllVisitorLogs();
///    // Or for custom date range:
///    final customLogs = await usage.loadAllVisitorLogs(
///      fromDate: DateTime.now(),
///      toDate: DateTime.now(),
///    );
///    ```
///
/// ## API Response Structure
/// 
/// The V2 API returns the following structure:
/// ```json
/// {
///   "data": [...], // Array of visitor log objects
///   "total": 52, // Total count (In-Out count)
///   "checked_in_count": 9, // Visitor-In count
///   "checked_out_count": 43, // Visitor-Out count
///   "current_page": 1,
///   "per_page": 20,
///   "last_page": 3,
///   "next_page_url": "...",
///   "prev_page_url": null
/// }
/// ```
///
/// ## Count Mapping
/// - **In-Out Count**: `total` field
/// - **Visitor-In Count**: `checked_in_count` field  
/// - **Visitor-Out Count**: `checked_out_count` field 