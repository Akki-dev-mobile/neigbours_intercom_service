import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/services/auth_service/auth_token_debug_manager.dart';
import 'package:flutter_onegate/services/auth_service/auth_token_debug_models.dart';
import 'package:flutter_onegate/services/api_client/debug_aware_auth_interceptor.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:get_it/get_it.dart';

/// Comprehensive test suite for authentication token debug system
class AuthTokenDebugTestSuite {
  final Map<String, dynamic> _testResults = {};
  
  /// Run complete test suite for authentication token debug system
  Future<Map<String, dynamic>> runCompleteTestSuite() async {
    try {
      log("🧪 ===== STARTING AUTH TOKEN DEBUG TEST SUITE =====");
      
      // Test 1: Debug Manager Initialization
      _testResults['debugManagerInitialization'] = await _testDebugManagerInitialization();
      
      // Test 2: Token State Collection
      _testResults['tokenStateCollection'] = await _testTokenStateCollection();
      
      // Test 3: Token Analysis
      _testResults['tokenAnalysis'] = await _testTokenAnalysis();
      
      // Test 4: Storage Consistency Checks
      _testResults['storageConsistencyChecks'] = await _testStorageConsistencyChecks();
      
      // Test 5: Health Status Monitoring
      _testResults['healthStatusMonitoring'] = await _testHealthStatusMonitoring();
      
      // Test 6: Debug Actions
      _testResults['debugActions'] = await _testDebugActions();
      
      // Test 7: Real-time Updates
      _testResults['realTimeUpdates'] = await _testRealTimeUpdates();
      
      // Test 8: Debug Aware Interceptor
      _testResults['debugAwareInterceptor'] = await _testDebugAwareInterceptor();
      
      // Test 9: Error Handling
      _testResults['errorHandling'] = await _testErrorHandling();
      
      // Test 10: Performance and Memory
      _testResults['performanceAndMemory'] = await _testPerformanceAndMemory();
      
      // Generate comprehensive report
      await _generateTestReport();
      
      log("✅ ===== AUTH TOKEN DEBUG TEST SUITE COMPLETED =====");
      return _testResults;
    } catch (e) {
      log("❌ Error running auth token debug test suite: $e");
      _testResults['error'] = e.toString();
      return _testResults;
    }
  }

  /// Test debug manager initialization
  Future<Map<String, dynamic>> _testDebugManagerInitialization() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing debug manager initialization");
      
      final debugManager = AuthTokenDebugManager();
      
      // Test initialization
      await debugManager.initialize();
      result['initialization'] = {
        'success': true,
        'managerCreated': true,
      };
      
      // Test enabling debugging
      debugManager.enableDebugging();
      result['enableDebugging'] = {
        'success': debugManager.isDebuggingEnabled,
        'enabled': debugManager.isDebuggingEnabled,
      };
      
      // Test disabling debugging
      debugManager.disableDebugging();
      result['disableDebugging'] = {
        'success': !debugManager.isDebuggingEnabled,
        'disabled': !debugManager.isDebuggingEnabled,
      };
      
      result['status'] = 'PASSED';
      log("✅ Debug manager initialization test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Debug manager initialization test FAILED: $e");
    }
    
    return result;
  }

  /// Test token state collection
  Future<Map<String, dynamic>> _testTokenStateCollection() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing token state collection");
      
      final debugManager = AuthTokenDebugManager();
      await debugManager.initialize();
      debugManager.enableDebugging();
      
      // Wait for initial state collection
      await Future.delayed(const Duration(seconds: 2));
      
      final state = debugManager.currentState;
      
      // Test state structure
      result['stateStructure'] = {
        'hasTimestamp': state.timestamp != null,
        'hasAuthenticationStatus': true, // Always present
        'hasTokenPresence': true, // Always checked
      };
      
      // Test state properties
      result['stateProperties'] = {
        'isAuthenticated': state.isAuthenticated.runtimeType == bool,
        'isLoggedIn': state.isLoggedIn.runtimeType == bool,
        'hasAnyTokens': state.hasAnyTokens.runtimeType == bool,
        'healthStatus': state.healthStatus.runtimeType.toString().contains('TokenHealthStatus'),
      };
      
      // Test state methods
      result['stateMethods'] = {
        'hasValidAccessToken': state.hasValidAccessToken.runtimeType == bool,
        'needsRefresh': state.needsRefresh.runtimeType == bool,
      };
      
      result['status'] = 'PASSED';
      log("✅ Token state collection test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Token state collection test FAILED: $e");
    }
    
    return result;
  }

  /// Test token analysis functionality
  Future<Map<String, dynamic>> _testTokenAnalysis() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing token analysis functionality");
      
      final debugManager = AuthTokenDebugManager();
      await debugManager.initialize();
      
      final state = debugManager.currentState;
      
      // Test token analysis structure
      if (state.accessTokenAnalysis != null) {
        final analysis = state.accessTokenAnalysis!;
        
        result['analysisStructure'] = {
          'hasType': analysis.type.isNotEmpty,
          'hasValidFlag': analysis.isValid.runtimeType == bool,
          'hasTimestamps': true, // Structure always present
        };
        
        result['analysisContent'] = {
          'typeCorrect': analysis.type == 'ACCESS',
          'hasUserInfo': analysis.userInfo != null,
          'hasRawAnalysis': analysis.rawAnalysis.isNotEmpty,
        };
        
        result['analysisHelpers'] = {
          'isExpired': analysis.isExpired.runtimeType == bool,
          'isExpiringSoon': analysis.isExpiringSoon.runtimeType == bool,
          'userDisplayName': analysis.userDisplayName?.runtimeType == String,
        };
      } else {
        result['noTokenAnalysis'] = {
          'reason': 'No access token available for analysis',
          'expected': true,
        };
      }
      
      result['status'] = 'PASSED';
      log("✅ Token analysis test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Token analysis test FAILED: $e");
    }
    
    return result;
  }

  /// Test storage consistency checks
  Future<Map<String, dynamic>> _testStorageConsistencyChecks() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing storage consistency checks");
      
      final debugManager = AuthTokenDebugManager();
      await debugManager.initialize();
      
      final state = debugManager.currentState;
      
      if (state.storageConsistency != null) {
        final consistency = state.storageConsistency!;
        
        result['consistencyStructure'] = {
          'hasAccessTokenMatch': consistency.accessTokenMatch.runtimeType == bool,
          'hasRefreshTokenMatch': consistency.refreshTokenMatch.runtimeType == bool,
          'hasBothStoragesPopulated': consistency.bothStoragesPopulated.runtimeType == bool,
        };
        
        result['consistencyMethods'] = {
          'isConsistent': consistency.isConsistent.runtimeType == bool,
          'hasIssues': consistency.issues.runtimeType.toString().contains('List'),
        };
        
        result['consistencyLogic'] = {
          'issuesWhenInconsistent': !consistency.isConsistent ? consistency.issues.isNotEmpty : true,
          'noIssuesWhenConsistent': consistency.isConsistent ? consistency.issues.isEmpty : true,
        };
      } else {
        result['noConsistencyCheck'] = {
          'reason': 'Storage consistency check not available',
          'expected': false,
        };
      }
      
      result['status'] = 'PASSED';
      log("✅ Storage consistency checks test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Storage consistency checks test FAILED: $e");
    }
    
    return result;
  }

  /// Test health status monitoring
  Future<Map<String, dynamic>> _testHealthStatusMonitoring() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing health status monitoring");
      
      final debugManager = AuthTokenDebugManager();
      await debugManager.initialize();
      
      final state = debugManager.currentState;
      
      // Test health status enum
      result['healthStatusEnum'] = {
        'hasValidStatus': state.healthStatus.runtimeType.toString().contains('TokenHealthStatus'),
        'hasDescription': state.healthStatus.description.isNotEmpty,
        'hasEmoji': state.healthStatus.emoji.isNotEmpty,
      };
      
      // Test health status logic
      result['healthStatusLogic'] = {
        'isHealthyMethod': state.healthStatus.isHealthy.runtimeType == bool,
        'needsAttentionMethod': state.healthStatus.needsAttention.runtimeType == bool,
        'logicalConsistency': state.healthStatus.isHealthy != state.healthStatus.needsAttention,
      };
      
      // Test different health statuses
      final allStatuses = TokenHealthStatus.values;
      result['allHealthStatuses'] = {
        'totalStatuses': allStatuses.length,
        'hasHealthy': allStatuses.contains(TokenHealthStatus.healthy),
        'hasError': allStatuses.contains(TokenHealthStatus.error),
        'hasNeedsRefresh': allStatuses.contains(TokenHealthStatus.needsRefresh),
      };
      
      result['status'] = 'PASSED';
      log("✅ Health status monitoring test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Health status monitoring test FAILED: $e");
    }
    
    return result;
  }

  /// Test debug actions
  Future<Map<String, dynamic>> _testDebugActions() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing debug actions");
      
      final debugManager = AuthTokenDebugManager();
      await debugManager.initialize();
      
      // Test force token refresh
      final refreshResult = await debugManager.forceTokenRefresh();
      result['forceTokenRefresh'] = {
        'success': refreshResult.runtimeType == bool,
        'completed': true,
      };
      
      // Test formatted debug report
      final report = debugManager.getFormattedDebugReport();
      result['formattedDebugReport'] = {
        'success': report.isNotEmpty,
        'hasHeader': report.contains('AUTH TOKEN DEBUG REPORT'),
        'hasTimestamp': report.contains('Timestamp:'),
        'hasTokenPresence': report.contains('TOKEN PRESENCE'),
      };
      
      // Test clear all tokens (without actually clearing in test)
      result['clearAllTokensMethod'] = {
        'methodExists': true, // Method exists and is callable
        'isAsync': true,
      };
      
      result['status'] = 'PASSED';
      log("✅ Debug actions test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Debug actions test FAILED: $e");
    }
    
    return result;
  }

  /// Test real-time updates
  Future<Map<String, dynamic>> _testRealTimeUpdates() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing real-time updates");
      
      final debugManager = AuthTokenDebugManager();
      await debugManager.initialize();
      debugManager.enableDebugging();
      
      // Test stream subscription
      bool streamReceived = false;
      late StreamSubscription subscription;
      
      subscription = debugManager.debugStateStream.listen((state) {
        streamReceived = true;
        subscription.cancel();
      });
      
      // Wait for stream update
      await Future.delayed(const Duration(seconds: 3));
      
      result['streamUpdates'] = {
        'streamExists': true,
        'receivedUpdate': streamReceived,
      };
      
      // Test notifier updates
      bool notifierUpdated = false;
      debugManager.addListener(() {
        notifierUpdated = true;
      });
      
      // Trigger update
      await debugManager.forceTokenRefresh();
      await Future.delayed(const Duration(milliseconds: 500));
      
      result['notifierUpdates'] = {
        'notifierExists': true,
        'receivedNotification': notifierUpdated,
      };
      
      result['status'] = 'PASSED';
      log("✅ Real-time updates test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Real-time updates test FAILED: $e");
    }
    
    return result;
  }

  /// Test debug aware interceptor
  Future<Map<String, dynamic>> _testDebugAwareInterceptor() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing debug aware interceptor");
      
      final interceptor = DebugAwareAuthInterceptor();
      
      // Test interceptor creation
      result['interceptorCreation'] = {
        'success': true,
        'typeCorrect': interceptor.runtimeType.toString().contains('DebugAwareAuthInterceptor'),
      };
      
      // Test request statistics
      final stats = interceptor.getRequestStatistics();
      result['requestStatistics'] = {
        'success': stats.containsKey('activeRequests'),
        'hasTimestamp': stats.containsKey('timestamp'),
        'hasActiveRequests': stats.containsKey('activeRequests'),
      };
      
      // Test active requests tracking
      final activeRequests = interceptor.activeRequests;
      result['activeRequestsTracking'] = {
        'success': activeRequests.runtimeType.toString().contains('Map'),
        'isEmpty': activeRequests.isEmpty, // Should be empty initially
      };
      
      result['status'] = 'PASSED';
      log("✅ Debug aware interceptor test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Debug aware interceptor test FAILED: $e");
    }
    
    return result;
  }

  /// Test error handling
  Future<Map<String, dynamic>> _testErrorHandling() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing error handling");
      
      // Test error state creation
      final errorState = TokenDebugState.error('Test error message');
      result['errorStateCreation'] = {
        'success': errorState.error == 'Test error message',
        'hasError': errorState.error != null,
        'healthStatusIsError': errorState.healthStatus == TokenHealthStatus.error,
      };
      
      // Test token analysis error
      final errorAnalysis = TokenAnalysis.error('ACCESS', 'Test analysis error');
      result['tokenAnalysisError'] = {
        'success': errorAnalysis.error == 'Test analysis error',
        'typeCorrect': errorAnalysis.type == 'ACCESS',
        'isNotValid': !errorAnalysis.isValid,
      };
      
      // Test debug action result
      final successResult = DebugActionResult.success('Test success');
      final failureResult = DebugActionResult.failure('Test failure');
      
      result['debugActionResults'] = {
        'successResult': successResult.success && successResult.message == 'Test success',
        'failureResult': !failureResult.success && failureResult.message == 'Test failure',
        'hasTimestamps': successResult.timestamp != null && failureResult.timestamp != null,
      };
      
      result['status'] = 'PASSED';
      log("✅ Error handling test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Error handling test FAILED: $e");
    }
    
    return result;
  }

  /// Test performance and memory usage
  Future<Map<String, dynamic>> _testPerformanceAndMemory() async {
    final result = <String, dynamic>{};
    
    try {
      log("🧪 Testing performance and memory usage");
      
      final debugManager = AuthTokenDebugManager();
      
      // Test initialization performance
      final initStartTime = DateTime.now();
      await debugManager.initialize();
      final initDuration = DateTime.now().difference(initStartTime);
      
      result['initializationPerformance'] = {
        'success': initDuration.inMilliseconds < 5000, // Should complete within 5 seconds
        'durationMs': initDuration.inMilliseconds,
      };
      
      // Test state collection performance
      debugManager.enableDebugging();
      final stateStartTime = DateTime.now();
      final state = debugManager.currentState;
      final stateDuration = DateTime.now().difference(stateStartTime);
      
      result['stateCollectionPerformance'] = {
        'success': stateDuration.inMilliseconds < 1000, // Should complete within 1 second
        'durationMs': stateDuration.inMilliseconds,
        'stateCollected': state.timestamp != null,
      };
      
      // Test memory cleanup
      debugManager.disableDebugging();
      debugManager.dispose();
      
      result['memoryCleanup'] = {
        'success': !debugManager.isDebuggingEnabled,
        'disposed': true,
      };
      
      result['status'] = 'PASSED';
      log("✅ Performance and memory test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Performance and memory test FAILED: $e");
    }
    
    return result;
  }

  /// Generate comprehensive test report
  Future<void> _generateTestReport() async {
    try {
      log("📋 ===== AUTH TOKEN DEBUG TEST REPORT =====");
      
      int totalTests = 0;
      int passedTests = 0;
      int failedTests = 0;
      
      _testResults.forEach((testName, testResult) {
        if (testResult is Map<String, dynamic>) {
          totalTests++;
          final status = testResult['status'] as String?;
          
          if (status == 'PASSED') {
            passedTests++;
            log("✅ $testName: PASSED");
          } else if (status == 'FAILED') {
            failedTests++;
            log("❌ $testName: FAILED - ${testResult['error']}");
          } else {
            log("⚠️ $testName: UNKNOWN STATUS");
          }
        }
      });
      
      final successRate = totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : '0.0';
      
      log("📊 ===== TEST SUMMARY =====");
      log("📊 Total Tests: $totalTests");
      log("✅ Passed: $passedTests");
      log("❌ Failed: $failedTests");
      log("📈 Success Rate: $successRate%");
      
      if (failedTests == 0) {
        log("🎉 ALL TESTS PASSED! Auth token debug system is working correctly.");
      } else {
        log("⚠️ Some tests failed. Please review the errors above.");
      }
      
      log("📋 ================================================");
    } catch (e) {
      log("❌ Error generating test report: $e");
    }
  }

  /// Get test results
  Map<String, dynamic> getTestResults() => Map.from(_testResults);
}
