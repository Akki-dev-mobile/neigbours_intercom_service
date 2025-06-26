import 'dart:developer';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/services/api_service/onegate_api_service.dart';
import 'package:get_it/get_it.dart';

/// Debug helper to troubleshoot visitor display issues
class DebugVisitorIssue {
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  late final OneGateApiService _apiService;

  DebugVisitorIssue() {
    _apiService = GetIt.I<OneGateApiService>();
  }

  /// Complete debugging checklist for missing visitors
  Future<void> debugMissingVisitor() async {
    log('🔍 DEBUGGING: Why visitor is not displaying...');
    log('===============================================');

    await _step1_checkTodaysCounts();
    await _step2_checkRawAPIResponse();
    await _step3_checkGateConfiguration();
    await _step4_checkDateFilter();
    await _step5_checkVisitorLogs();

    log('===============================================');
    log('🔍 DEBUGGING COMPLETE');
  }

  /// Step 1: Check basic counts
  Future<void> _step1_checkTodaysCounts() async {
    try {
      log('🟡 STEP 1: Checking today\'s visitor counts...');

      final counts = await _apiService.getVisitorCounts(
        fromDate: DateTime.now(),
        toDate: DateTime.now(),
      );

      log('📊 Today\'s Counts:');
      log('   📈 Total: ${counts['total']}');
      log('   📥 Visitor-In: ${counts['visitor_in']}');
      log('   📤 Visitor-Out: ${counts['visitor_out']}');

      if (counts['total'] == 0) {
        log('❌ ISSUE FOUND: No visitors recorded for today');
        log('💡 Possible causes:');
        log('   - Visitor not created yet');
        log('   - Date mismatch');
        log('   - Wrong gate/company filter');
      } else {
        log('✅ Visitors found in counts - checking logs...');
      }
    } catch (e) {
      log('❌ ERROR in Step 1: $e');
    }
  }

  /// Step 2: Check raw API response
  Future<void> _step2_checkRawAPIResponse() async {
    try {
      log('🟡 STEP 2: Checking raw V2 API response...');

      final result = await _apiService.getVisitorLogsV2(
        currentPage: 1,
        perPage: 50, // Get more records to see if visitor exists
        fromDate: DateTime.now(),
        toDate: DateTime.now(),
      );

      log('📋 Raw API Response:');
      log('   📊 Total: ${result['total']}');
      log('   📥 Checked In: ${result['checked_in_count']}');
      log('   📤 Checked Out: ${result['checked_out_count']}');
      log('   📄 Current Page: ${result['current_page']}');
      log('   📄 Per Page: ${result['per_page']}');
      log('   📄 Data Length: ${(result['data'] as List).length}');

      final data = result['data'] as List;
      if (data.isEmpty) {
        log('❌ ISSUE FOUND: No data returned from API');
        log('💡 This means either:');
        log('   - No visitors for today');
        log('   - Wrong date filter');
        log('   - API parameters mismatch');
      } else {
        log('✅ Data found! Showing first few records:');
        for (int i = 0; i < data.length && i < 3; i++) {
          final item = data[i];
          log('   📝 Record ${i + 1}:');
          log('      - Visitor ID: ${item['visitor_id']}');
          log('      - Name: ${item['name']}');
          log('      - Mobile: ${item['mobile']}');
          log('      - Check-in: ${item['visitor_check_in']}');
          log('      - Check-out: ${item['visitor_check_out']}');
          log('      - In Gate: ${item['in_gate']}');
        }
      }
    } catch (e) {
      log('❌ ERROR in Step 2: $e');
    }
  }

  /// Step 3: Check gate configuration
  Future<void> _step3_checkGateConfiguration() async {
    try {
      log('🟡 STEP 3: Checking gate configuration...');

      // This would require access to gate storage to check current gate
      log('🔧 Gate Configuration Check:');
      log('💡 Manual Check Required:');
      log('   1. Verify selected gate name matches API gate name');
      log('   2. Check if company_id is correct');
      log('   3. Ensure visitor was created for the same gate');
    } catch (e) {
      log('❌ ERROR in Step 3: $e');
    }
  }

  /// Step 4: Check date filter issues
  Future<void> _step4_checkDateFilter() async {
    try {
      log('🟡 STEP 4: Checking date filter issues...');

      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      log('📅 Date Check:');
      log('   🗓️ Today\'s date: $today');
      log('   🕐 Current time: ${now.toString()}');

      // Check with broader date range
      log('🔍 Trying broader date range...');
      final yesterdayResult = await _apiService.getVisitorLogsV2(
        currentPage: 1,
        perPage: 10,
        fromDate: DateTime.now().subtract(const Duration(days: 1)),
        toDate: DateTime.now().add(const Duration(days: 1)),
      );

      log('📊 Broader Range Results:');
      log('   📈 Total: ${yesterdayResult['total']}');
      log('   📋 Data Count: ${(yesterdayResult['data'] as List).length}');

      if (yesterdayResult['total'] > 0) {
        log('✅ Visitors found in broader range!');
        log('💡 This suggests a date filtering issue');

        final data = yesterdayResult['data'] as List;
        for (int i = 0; i < data.length && i < 2; i++) {
          final item = data[i];
          log('   📝 Found visitor: ${item['name']} - Check-in: ${item['visitor_check_in']}');
        }
      }
    } catch (e) {
      log('❌ ERROR in Step 4: $e');
    }
  }

  /// Step 5: Check visitor logs with different filters
  Future<void> _step5_checkVisitorLogs() async {
    try {
      log('🟡 STEP 5: Checking with different parameters...');

      // Try without date filters
      log('🔍 Trying without strict date filters...');
      final noDateResult = await _apiService.getVisitorLogsV2(
        currentPage: 1,
        perPage: 20,
      );

      log('📊 No Date Filter Results:');
      log('   📈 Total: ${noDateResult['total']}');
      log('   📋 Data Count: ${(noDateResult['data'] as List).length}');

      if (noDateResult['total'] > 0) {
        log('✅ Visitors found without date filter!');
        log('💡 This confirms date filtering is the issue');

        final data = noDateResult['data'] as List;
        log('📝 Recent visitors:');
        for (int i = 0; i < data.length && i < 5; i++) {
          final item = data[i];
          log('   ${i + 1}. ${item['name']} (${item['mobile']}) - ${item['visitor_check_in']}');
        }
      } else {
        log('❌ No visitors found even without date filter');
        log('💡 This suggests:');
        log('   - Visitor creation failed');
        log('   - Wrong company/gate parameters');
        log('   - Database issue');
      }
    } catch (e) {
      log('❌ ERROR in Step 5: $e');
    }
  }

  /// Quick check - just get all recent visitors
  Future<void> quickCheck() async {
    try {
      log('🚀 QUICK CHECK: Getting all recent visitors...');

      final result = await _apiService.getVisitorLogsV2(
        currentPage: 1,
        perPage: 50,
      );

      final count = result['total'];
      final data = result['data'] as List;

      log('📊 Quick Results: $count total visitors, ${data.length} in current page');

      if (data.isNotEmpty) {
        log('📝 Latest visitors:');
        for (int i = 0; i < data.length && i < 10; i++) {
          final item = data[i];
          final checkIn = item['visitor_check_in'];
          final name = item['name'];
          final mobile = item['mobile'];
          log('   ${i + 1}. $name ($mobile) - $checkIn');
        }
      } else {
        log('❌ No visitors found at all');
      }
    } catch (e) {
      log('❌ Quick check failed: $e');
    }
  }

  /// Check specific visitor by mobile number
  Future<void> checkVisitorByMobile(String mobileNumber) async {
    try {
      log('🔍 CHECKING SPECIFIC VISITOR: $mobileNumber');

      // Try to search for visitor
      final visitor = await _remoteDataSource.searchVisitor(mobileNumber);

      if (visitor != null) {
        log('✅ Visitor found in database:');
        log('   📝 ID: ${visitor.id}');
        log('   📝 Name: ${visitor.name}');
        log('   📝 Mobile: ${visitor.mobile}');
        log('   📝 Image: ${visitor.visitor_image}');
      } else {
        log('❌ Visitor not found in database for mobile: $mobileNumber');
      }
    } catch (e) {
      log('❌ Error checking visitor by mobile: $e');
    }
  }
}

/// Usage examples:
///
/// 1. **Complete debugging:**
///    ```dart
///    final debug = DebugVisitorIssue();
///    await debug.debugMissingVisitor();
///    ```
///
/// 2. **Quick check:**
///    ```dart
///    await debug.quickCheck();
///    ```
///
/// 3. **Check specific visitor:**
///    ```dart
///    await debug.checkVisitorByMobile('9876543210');
///    ```
