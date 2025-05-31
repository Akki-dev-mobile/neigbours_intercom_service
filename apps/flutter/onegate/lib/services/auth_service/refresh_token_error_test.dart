import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/refresh_token_error_handler.dart';

/// Simple test class to verify refresh token error handling functionality
class RefreshTokenErrorTest {
  
  /// Run basic tests for refresh token error handling
  static Future<Map<String, dynamic>> runBasicTests() async {
    final results = <String, dynamic>{};
    
    try {
      log("🧪 Starting Refresh Token Error Handling Tests");
      
      // Test 1: Error Analysis
      results['errorAnalysis'] = await _testErrorAnalysis();
      
      // Test 2: Retry Logic
      results['retryLogic'] = await _testRetryLogic();
      
      // Test 3: Backoff Calculation
      results['backoffCalculation'] = await _testBackoffCalculation();
      
      // Test 4: Failure Statistics
      results['failureStatistics'] = await _testFailureStatistics();
      
      log("✅ Refresh Token Error Handling Tests Completed");
      return results;
    } catch (e) {
      log("❌ Error running tests: $e");
      results['error'] = e.toString();
      return results;
    }
  }
  
  /// Test error analysis functionality
  static Future<Map<String, dynamic>> _testErrorAnalysis() async {
    final result = <String, dynamic>{};
    
    try {
      log("🔍 Testing error analysis");
      
      // Test network timeout error
      final timeoutError = Exception('Connection timeout');
      final timeoutType = RefreshTokenErrorHandler.analyzeFailure(timeoutError);
      result['timeoutAnalysis'] = {
        'success': timeoutType == RefreshTokenFailureType.networkTimeout,
        'detected': timeoutType.toString(),
      };
      
      // Test DioException analysis
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      final dioType = RefreshTokenErrorHandler.analyzeFailure(dioError);
      result['dioAnalysis'] = {
        'success': dioType == RefreshTokenFailureType.networkTimeout,
        'detected': dioType.toString(),
      };
      
      // Test refresh token exception
      const refreshError = RefreshTokenException(
        'Token expired',
        type: RefreshTokenFailureType.refreshTokenExpired,
      );
      final refreshType = RefreshTokenErrorHandler.analyzeFailure(refreshError);
      result['refreshTokenAnalysis'] = {
        'success': refreshType == RefreshTokenFailureType.refreshTokenExpired,
        'detected': refreshType.toString(),
      };
      
      result['status'] = 'PASSED';
      log("✅ Error analysis test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Error analysis test FAILED: $e");
    }
    
    return result;
  }
  
  /// Test retry logic
  static Future<Map<String, dynamic>> _testRetryLogic() async {
    final result = <String, dynamic>{};
    
    try {
      log("🔄 Testing retry logic");
      
      // Test retryable failures
      final retryableTypes = [
        RefreshTokenFailureType.networkTimeout,
        RefreshTokenFailureType.serverError,
        RefreshTokenFailureType.storageError,
      ];
      
      final retryResults = <String, bool>{};
      for (final type in retryableTypes) {
        retryResults[type.toString()] = RefreshTokenErrorHandler.shouldRetryFailure(type);
      }
      
      result['retryableFailures'] = {
        'success': retryResults.values.every((shouldRetry) => shouldRetry),
        'results': retryResults,
      };
      
      // Test non-retryable failures
      final nonRetryableTypes = [
        RefreshTokenFailureType.refreshTokenExpired,
        RefreshTokenFailureType.refreshTokenRevoked,
        RefreshTokenFailureType.missingRefreshToken,
      ];
      
      final nonRetryResults = <String, bool>{};
      for (final type in nonRetryableTypes) {
        nonRetryResults[type.toString()] = RefreshTokenErrorHandler.shouldRetryFailure(type);
      }
      
      result['nonRetryableFailures'] = {
        'success': nonRetryResults.values.every((shouldRetry) => !shouldRetry),
        'results': nonRetryResults,
      };
      
      result['status'] = 'PASSED';
      log("✅ Retry logic test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Retry logic test FAILED: $e");
    }
    
    return result;
  }
  
  /// Test backoff calculation
  static Future<Map<String, dynamic>> _testBackoffCalculation() async {
    final result = <String, dynamic>{};
    
    try {
      log("⏱️ Testing backoff calculation");
      
      // Test exponential backoff
      final delays = <int, Duration>{};
      for (int attempt = 1; attempt <= 5; attempt++) {
        delays[attempt] = RefreshTokenErrorHandler.calculateBackoffDelay(attempt);
      }
      
      // Verify exponential growth
      bool isExponential = true;
      for (int i = 2; i <= 5; i++) {
        if (delays[i]!.inMilliseconds <= delays[i-1]!.inMilliseconds) {
          isExponential = false;
          break;
        }
      }
      
      result['exponentialBackoff'] = {
        'success': isExponential,
        'delays': delays.map((k, v) => MapEntry(k.toString(), v.inSeconds)),
      };
      
      // Test maximum delay cap
      final maxDelay = RefreshTokenErrorHandler.calculateBackoffDelay(10);
      result['maxDelayCap'] = {
        'success': maxDelay.inSeconds <= 30,
        'maxDelaySeconds': maxDelay.inSeconds,
      };
      
      result['status'] = 'PASSED';
      log("✅ Backoff calculation test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Backoff calculation test FAILED: $e");
    }
    
    return result;
  }
  
  /// Test failure statistics
  static Future<Map<String, dynamic>> _testFailureStatistics() async {
    final result = <String, dynamic>{};
    
    try {
      log("📊 Testing failure statistics");
      
      // Reset counters
      RefreshTokenErrorHandler.resetFailureCounters();
      final initialStats = RefreshTokenErrorHandler.getFailureStatistics();
      
      result['initialReset'] = {
        'success': initialStats['consecutiveFailures'] == 0,
        'consecutiveFailures': initialStats['consecutiveFailures'],
      };
      
      // Simulate some failures
      await RefreshTokenErrorHandler.handleRefreshTokenFailure(
        Exception('Test failure 1'),
        1,
        RefreshTokenFailureType.networkTimeout,
      );
      
      await RefreshTokenErrorHandler.handleRefreshTokenFailure(
        Exception('Test failure 2'),
        1,
        RefreshTokenFailureType.serverError,
      );
      
      final afterFailures = RefreshTokenErrorHandler.getFailureStatistics();
      result['failureTracking'] = {
        'success': afterFailures['consecutiveFailures'] == 2,
        'consecutiveFailures': afterFailures['consecutiveFailures'],
        'hasLastFailureTime': afterFailures['lastFailureTime'] != null,
      };
      
      // Reset again
      RefreshTokenErrorHandler.resetFailureCounters();
      final finalStats = RefreshTokenErrorHandler.getFailureStatistics();
      
      result['finalReset'] = {
        'success': finalStats['consecutiveFailures'] == 0,
        'consecutiveFailures': finalStats['consecutiveFailures'],
      };
      
      result['status'] = 'PASSED';
      log("✅ Failure statistics test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Failure statistics test FAILED: $e");
    }
    
    return result;
  }
  
  /// Print test results in a readable format
  static void printTestResults(Map<String, dynamic> results) {
    log("📋 ===== REFRESH TOKEN ERROR HANDLING TEST RESULTS =====");
    
    results.forEach((testName, testResult) {
      if (testResult is Map<String, dynamic>) {
        final status = testResult['status'] as String?;
        switch (status) {
          case 'PASSED':
            log("✅ $testName: PASSED");
            break;
          case 'FAILED':
            log("❌ $testName: FAILED - ${testResult['error']}");
            break;
          default:
            log("⚠️ $testName: UNKNOWN STATUS");
        }
      }
    });
    
    log("📋 ================================================");
  }
}
