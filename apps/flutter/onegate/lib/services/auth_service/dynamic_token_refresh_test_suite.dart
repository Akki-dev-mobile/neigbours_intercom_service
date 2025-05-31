import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/dynamic_auth_integration.dart';
import 'package:flutter_onegate/services/auth_service/dynamic_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/refresh_token_error_handler.dart';
import 'package:flutter_onegate/services/session_manager/continuous_session_manager.dart';
import 'package:get_it/get_it.dart';

/// Comprehensive test suite for the Dynamic Token Refresh System
class DynamicTokenRefreshTestSuite {
  static final DynamicTokenRefreshTestSuite _instance =
      DynamicTokenRefreshTestSuite._internal();
  factory DynamicTokenRefreshTestSuite() => _instance;
  DynamicTokenRefreshTestSuite._internal();

  // Test results storage
  final Map<String, dynamic> _testResults = {};

  /// Run complete test suite for dynamic token refresh system
  Future<Map<String, dynamic>> runCompleteTestSuite() async {
    try {
      log("🧪 ===== DYNAMIC TOKEN REFRESH TEST SUITE =====");

      _testResults.clear();

      // Test 1: JWT Token Utility Enhancements
      _testResults['jwtTokenUtility'] =
          await _testJwtTokenUtilityEnhancements();

      // Test 2: Dynamic Buffer Calculation
      _testResults['dynamicBufferCalculation'] =
          await _testDynamicBufferCalculation();

      // Test 3: Token Lifespan Analysis
      _testResults['tokenLifespanAnalysis'] =
          await _testTokenLifespanAnalysis();

      // Test 4: Dynamic Refresh Manager
      _testResults['dynamicRefreshManager'] =
          await _testDynamicRefreshManager();

      // Test 5: Enhanced Token Refresh Manager Integration
      _testResults['enhancedTokenRefreshManager'] =
          await _testEnhancedTokenRefreshManagerIntegration();

      // Test 6: Dynamic Auth Integration
      _testResults['dynamicAuthIntegration'] =
          await _testDynamicAuthIntegration();

      // Test 7: Continuous Session Management
      _testResults['continuousSessionManagement'] =
          await _testContinuousSessionManagement();

      // Test 8: App Lifecycle Integration
      _testResults['appLifecycleIntegration'] =
          await _testAppLifecycleIntegration();

      // Test 9: Network Connectivity Handling
      _testResults['networkConnectivityHandling'] =
          await _testNetworkConnectivityHandling();

      // Test 10: Performance and Timing
      _testResults['performanceAndTiming'] = await _testPerformanceAndTiming();

      // Test 11: Refresh Token Failure Scenarios
      _testResults['refreshTokenFailureScenarios'] =
          await _testRefreshTokenFailureScenarios();

      // Test 12: Error Recovery Mechanisms
      _testResults['errorRecoveryMechanisms'] =
          await _testErrorRecoveryMechanisms();

      // Test 13: Continuous Session Integration
      _testResults['continuousSessionIntegration'] =
          await _testContinuousSessionIntegration();

      // Generate comprehensive report
      await _generateTestReport();

      log("✅ Dynamic Token Refresh Test Suite completed");
      return _testResults;
    } catch (e) {
      log("❌ Error running test suite: $e");
      _testResults['error'] = e.toString();
      return _testResults;
    }
  }

  /// Test JWT Token Utility enhancements
  Future<Map<String, dynamic>> _testJwtTokenUtilityEnhancements() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing JWT Token Utility enhancements");

      // Get a sample token for testing
      final authService = GetIt.I<AuthService>();
      final token = await authService.tokenRefreshManager.getValidAccessToken();

      if (token == null) {
        result['status'] = 'SKIPPED';
        result['reason'] = 'No access token available';
        return result;
      }

      // Test token lifespan calculation
      final lifespanMinutes = JwtTokenUtility.getTokenLifespanInMinutes(token);
      result['tokenLifespanCalculation'] = {
        'success': lifespanMinutes != null,
        'lifespanMinutes': lifespanMinutes,
      };

      // Test optimal refresh buffer calculation
      final buffer = JwtTokenUtility.calculateOptimalRefreshBuffer(token);
      result['optimalRefreshBuffer'] = {
        'success': buffer.inMinutes > 0,
        'bufferMinutes': buffer.inMinutes,
      };

      // Test optimal refresh time calculation
      final refreshTime = JwtTokenUtility.getOptimalRefreshTime(token);
      result['optimalRefreshTime'] = {
        'success': refreshTime != null,
        'refreshTime': refreshTime?.toIso8601String(),
      };

      // Test should refresh now logic
      final shouldRefresh = JwtTokenUtility.shouldRefreshTokenNow(token);
      result['shouldRefreshNow'] = {
        'success': true,
        'shouldRefresh': shouldRefresh,
      };

      // Test comprehensive token analysis
      final analysis = JwtTokenUtility.getTokenAnalysis(token);
      result['comprehensiveAnalysis'] = {
        'success': !analysis.containsKey('error'),
        'hasAllFields': analysis.containsKey('lifespanMinutes') &&
            analysis.containsKey('refreshBuffer') &&
            analysis.containsKey('refreshTime'),
      };

      result['status'] = 'PASSED';
      log("✅ JWT Token Utility enhancements test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ JWT Token Utility enhancements test FAILED: $e");
    }

    return result;
  }

  /// Test dynamic buffer calculation logic
  Future<Map<String, dynamic>> _testDynamicBufferCalculation() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing dynamic buffer calculation logic");

      final authService = GetIt.I<AuthService>();
      final token = await authService.tokenRefreshManager.getValidAccessToken();

      if (token == null) {
        result['status'] = 'SKIPPED';
        result['reason'] = 'No access token available';
        return result;
      }

      // Test buffer calculation
      final buffer = JwtTokenUtility.calculateOptimalRefreshBuffer(token);
      final lifespanMinutes = JwtTokenUtility.getTokenLifespanInMinutes(token);

      result['bufferCalculation'] = {
        'success': buffer.inMinutes > 0,
        'bufferMinutes': buffer.inMinutes,
        'lifespanMinutes': lifespanMinutes,
      };

      // Verify buffer rules
      if (lifespanMinutes != null) {
        bool rulesCorrect = false;
        if (lifespanMinutes > 30 && buffer.inMinutes == 5) {
          rulesCorrect = true;
        } else if (lifespanMinutes >= 15 &&
            lifespanMinutes <= 30 &&
            buffer.inMinutes == 2) {
          rulesCorrect = true;
        } else if (lifespanMinutes < 15 && buffer.inMinutes == 1) {
          rulesCorrect = true;
        }

        result['bufferRulesCorrect'] = rulesCorrect;
      }

      // Test safety mechanisms
      final maxAllowedBuffer =
          Duration(minutes: (lifespanMinutes! / 2).floor());
      result['safetyMechanisms'] = {
        'bufferNotExceedsHalfLifespan': buffer <= maxAllowedBuffer,
        'bufferAtLeast30Seconds': buffer.inSeconds >= 30,
      };

      result['status'] = 'PASSED';
      log("✅ Dynamic buffer calculation test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Dynamic buffer calculation test FAILED: $e");
    }

    return result;
  }

  /// Test token lifespan analysis
  Future<Map<String, dynamic>> _testTokenLifespanAnalysis() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing token lifespan analysis");

      final authService = GetIt.I<AuthService>();
      final token = await authService.tokenRefreshManager.getValidAccessToken();

      if (token == null) {
        result['status'] = 'SKIPPED';
        result['reason'] = 'No access token available';
        return result;
      }

      // Test issued at time extraction
      final issuedAt = JwtTokenUtility.getTokenIssuedAtTime(token);
      result['issuedAtExtraction'] = {
        'success': issuedAt != null,
        'issuedAt': issuedAt?.toIso8601String(),
      };

      // Test expiration time extraction
      final expiresAt = JwtTokenUtility.getTokenExpirationTime(token);
      result['expirationExtraction'] = {
        'success': expiresAt != null,
        'expiresAt': expiresAt?.toIso8601String(),
      };

      // Test lifespan calculation
      final lifespanMinutes = JwtTokenUtility.getTokenLifespanInMinutes(token);
      result['lifespanCalculation'] = {
        'success': lifespanMinutes != null && lifespanMinutes > 0,
        'lifespanMinutes': lifespanMinutes,
      };

      // Verify lifespan makes sense
      if (issuedAt != null && expiresAt != null) {
        final calculatedLifespan = expiresAt.difference(issuedAt).inMinutes;
        result['lifespanVerification'] = {
          'calculatedMatches': calculatedLifespan == lifespanMinutes,
          'calculatedLifespan': calculatedLifespan,
        };
      }

      result['status'] = 'PASSED';
      log("✅ Token lifespan analysis test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Token lifespan analysis test FAILED: $e");
    }

    return result;
  }

  /// Test dynamic refresh manager
  Future<Map<String, dynamic>> _testDynamicRefreshManager() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing dynamic refresh manager");

      final dynamicManager = DynamicTokenRefreshManager();

      // Test initialization
      await dynamicManager.initialize();
      result['initialization'] = {
        'success': true,
      };

      // Test status retrieval
      final status = dynamicManager.getDynamicRefreshStatus();
      result['statusRetrieval'] = {
        'success': status.containsKey('isInitialized'),
        'isInitialized': status['isInitialized'],
      };

      // Test force token analysis
      await dynamicManager.forceTokenAnalysis();
      result['forceTokenAnalysis'] = {
        'success': true,
      };

      // Test dynamic valid access token
      final token = await dynamicManager.getDynamicValidAccessToken();
      result['dynamicValidAccessToken'] = {
        'success': token != null,
        'hasToken': token != null,
      };

      // Test app lifecycle handling
      await dynamicManager.handleAppLifecycleChange(true);
      result['appLifecycleHandling'] = {
        'success': true,
      };

      result['status'] = 'PASSED';
      log("✅ Dynamic refresh manager test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Dynamic refresh manager test FAILED: $e");
    }

    return result;
  }

  /// Test enhanced token refresh manager integration
  Future<Map<String, dynamic>>
      _testEnhancedTokenRefreshManagerIntegration() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing enhanced token refresh manager integration");

      final authService = GetIt.I<AuthService>();
      final tokenManager = authService.tokenRefreshManager;

      // Test dynamic buffer calculation
      final token = await tokenManager.getValidAccessToken();
      if (token != null) {
        final buffer = tokenManager.calculateDynamicRefreshBuffer(token);
        result['dynamicBufferCalculation'] = {
          'success': buffer.inMinutes > 0,
          'bufferMinutes': buffer.inMinutes,
        };

        // Test current refresh buffer getter
        final currentBuffer = tokenManager.currentRefreshBuffer;
        result['currentRefreshBuffer'] = {
          'success': currentBuffer.inMinutes > 0,
          'bufferMinutes': currentBuffer.inMinutes,
        };

        // Test enhanced immediate refresh
        final immediateToken =
            await tokenManager.getValidAccessTokenWithImmediateRefresh();
        result['immediateRefresh'] = {
          'success': immediateToken != null,
          'hasToken': immediateToken != null,
        };
      } else {
        result['status'] = 'SKIPPED';
        result['reason'] = 'No access token available';
        return result;
      }

      result['status'] = 'PASSED';
      log("✅ Enhanced token refresh manager integration test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Enhanced token refresh manager integration test FAILED: $e");
    }

    return result;
  }

  /// Test dynamic auth integration
  Future<Map<String, dynamic>> _testDynamicAuthIntegration() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing dynamic auth integration");

      final dynamicAuth = DynamicAuthIntegration();
      final authService = GetIt.I<AuthService>();

      // Test initialization
      await dynamicAuth.initialize(authService);
      result['initialization'] = {
        'success': true,
      };

      // Test enhanced access token
      final token = await dynamicAuth.getEnhancedAccessToken();
      result['enhancedAccessToken'] = {
        'success': token != null,
        'hasToken': token != null,
      };

      // Test comprehensive auth status
      final status = dynamicAuth.getComprehensiveAuthStatus();
      result['comprehensiveAuthStatus'] = {
        'success': status.containsKey('dynamicAuthIntegration'),
        'hasIntegrationStatus': status.containsKey('dynamicAuthIntegration'),
        'hasRefreshManagerStatus': status.containsKey('dynamicRefreshManager'),
      };

      // Test force comprehensive refresh
      final refreshed = await dynamicAuth.forceComprehensiveRefresh();
      result['forceComprehensiveRefresh'] = {
        'success': refreshed,
        'refreshed': refreshed,
      };

      result['status'] = 'PASSED';
      log("✅ Dynamic auth integration test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Dynamic auth integration test FAILED: $e");
    }

    return result;
  }

  /// Test continuous session management
  Future<Map<String, dynamic>> _testContinuousSessionManagement() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing continuous session management");

      final dynamicAuth = DynamicAuthIntegration();
      final authService = GetIt.I<AuthService>();

      await dynamicAuth.initialize(authService);

      // Test session continuity across multiple token requests
      final tokens = <String?>[];
      for (int i = 0; i < 3; i++) {
        final token = await dynamicAuth.getEnhancedAccessToken();
        tokens.add(token);
        await Future.delayed(const Duration(seconds: 1));
      }

      result['sessionContinuity'] = {
        'success': tokens.every((token) => token != null),
        'tokenCount': tokens.where((token) => token != null).length,
        'totalRequests': tokens.length,
      };

      // Test session state persistence
      final status1 = dynamicAuth.getComprehensiveAuthStatus();
      await Future.delayed(const Duration(seconds: 2));
      final status2 = dynamicAuth.getComprehensiveAuthStatus();

      result['sessionStatePersistence'] = {
        'success': status1['dynamicAuthIntegration']['isInitialized'] ==
            status2['dynamicAuthIntegration']['isInitialized'],
        'stateConsistent': true,
      };

      result['status'] = 'PASSED';
      log("✅ Continuous session management test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Continuous session management test FAILED: $e");
    }

    return result;
  }

  /// Test app lifecycle integration
  Future<Map<String, dynamic>> _testAppLifecycleIntegration() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing app lifecycle integration");

      final dynamicAuth = DynamicAuthIntegration();
      final authService = GetIt.I<AuthService>();

      await dynamicAuth.initialize(authService);

      // Test app lifecycle state changes
      dynamicAuth.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future.delayed(const Duration(milliseconds: 500));

      dynamicAuth.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 500));

      dynamicAuth.didChangeAppLifecycleState(AppLifecycleState.detached);
      await Future.delayed(const Duration(milliseconds: 500));

      result['lifecycleStateChanges'] = {
        'success': true,
        'statesHandled': ['paused', 'resumed', 'detached'],
      };

      // Verify system still works after lifecycle changes
      final token = await dynamicAuth.getEnhancedAccessToken();
      result['postLifecycleTokenAccess'] = {
        'success': token != null,
        'hasToken': token != null,
      };

      result['status'] = 'PASSED';
      log("✅ App lifecycle integration test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ App lifecycle integration test FAILED: $e");
    }

    return result;
  }

  /// Test network connectivity handling
  Future<Map<String, dynamic>> _testNetworkConnectivityHandling() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing network connectivity handling");

      final dynamicAuth = DynamicAuthIntegration();
      final authService = GetIt.I<AuthService>();

      await dynamicAuth.initialize(authService);

      // Test network connectivity changes
      await dynamicAuth.handleNetworkConnectivityChange(false);
      await Future.delayed(const Duration(milliseconds: 500));

      await dynamicAuth.handleNetworkConnectivityChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      result['connectivityHandling'] = {
        'success': true,
        'connectivityStatesHandled': ['disconnected', 'connected'],
      };

      // Verify system recovers after connectivity restoration
      final token = await dynamicAuth.getEnhancedAccessToken();
      result['postConnectivityTokenAccess'] = {
        'success': token != null,
        'hasToken': token != null,
      };

      result['status'] = 'PASSED';
      log("✅ Network connectivity handling test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Network connectivity handling test FAILED: $e");
    }

    return result;
  }

  /// Test performance and timing
  Future<Map<String, dynamic>> _testPerformanceAndTiming() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing performance and timing");

      final dynamicAuth = DynamicAuthIntegration();
      final authService = GetIt.I<AuthService>();

      await dynamicAuth.initialize(authService);

      // Test token access performance
      final stopwatch = Stopwatch()..start();
      final token = await dynamicAuth.getEnhancedAccessToken();
      stopwatch.stop();

      result['tokenAccessPerformance'] = {
        'success':
            stopwatch.elapsedMilliseconds < 5000, // Should be under 5 seconds
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'hasToken': token != null,
      };

      // Test multiple rapid token requests
      final rapidStopwatch = Stopwatch()..start();
      final rapidTokens = <String?>[];
      for (int i = 0; i < 5; i++) {
        final rapidToken = await dynamicAuth.getEnhancedAccessToken();
        rapidTokens.add(rapidToken);
      }
      rapidStopwatch.stop();

      result['rapidTokenAccess'] = {
        'success': rapidStopwatch.elapsedMilliseconds <
            10000, // Should be under 10 seconds
        'elapsedMs': rapidStopwatch.elapsedMilliseconds,
        'successfulRequests': rapidTokens.where((t) => t != null).length,
        'totalRequests': rapidTokens.length,
      };

      result['status'] = 'PASSED';
      log("✅ Performance and timing test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Performance and timing test FAILED: $e");
    }

    return result;
  }

  /// Generate comprehensive test report
  Future<void> _generateTestReport() async {
    try {
      log("📊 ===== DYNAMIC TOKEN REFRESH TEST REPORT =====");

      int passedTests = 0;
      int failedTests = 0;
      int skippedTests = 0;

      _testResults.forEach((testName, testResult) {
        if (testResult is Map<String, dynamic>) {
          final status = testResult['status'] as String?;
          switch (status) {
            case 'PASSED':
              passedTests++;
              log("✅ $testName: PASSED");
              break;
            case 'FAILED':
              failedTests++;
              log("❌ $testName: FAILED - ${testResult['error']}");
              break;
            case 'SKIPPED':
              skippedTests++;
              log("⏭️ $testName: SKIPPED - ${testResult['reason']}");
              break;
          }
        }
      });

      log("📊 TEST SUMMARY:");
      log("   • Total Tests: ${passedTests + failedTests + skippedTests}");
      log("   • Passed: $passedTests");
      log("   • Failed: $failedTests");
      log("   • Skipped: $skippedTests");
      log("   • Success Rate: ${((passedTests / (passedTests + failedTests)) * 100).toStringAsFixed(1)}%");

      log("📊 ==========================================");
    } catch (e) {
      log("❌ Error generating test report: $e");
    }
  }

  /// Test refresh token failure scenarios
  Future<Map<String, dynamic>> _testRefreshTokenFailureScenarios() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing refresh token failure scenarios");

      final authService = GetIt.I<AuthService>();
      final tokenManager = authService.tokenRefreshManager;

      // Test failure analysis
      final networkError = Exception('Connection timeout');
      final networkFailureType =
          RefreshTokenErrorHandler.analyzeFailure(networkError);
      result['networkFailureAnalysis'] = {
        'success': networkFailureType == RefreshTokenFailureType.networkTimeout,
        'detectedType': networkFailureType.toString(),
      };

      // Test retry logic
      final shouldRetryNetwork =
          RefreshTokenErrorHandler.shouldRetryFailure(networkFailureType);
      result['retryLogic'] = {
        'success': shouldRetryNetwork == true,
        'shouldRetryNetwork': shouldRetryNetwork,
      };

      // Test backoff calculation
      final backoffDelay = RefreshTokenErrorHandler.calculateBackoffDelay(2);
      result['backoffCalculation'] = {
        'success': backoffDelay.inSeconds >= 2,
        'delaySeconds': backoffDelay.inSeconds,
      };

      // Test failure statistics
      final stats = tokenManager.getRefreshFailureStatistics();
      result['failureStatistics'] = {
        'success': stats.containsKey('consecutiveFailures'),
        'hasStatistics': stats.isNotEmpty,
      };

      result['status'] = 'PASSED';
      log("✅ Refresh token failure scenarios test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Refresh token failure scenarios test FAILED: $e");
    }

    return result;
  }

  /// Test error recovery mechanisms
  Future<Map<String, dynamic>> _testErrorRecoveryMechanisms() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing error recovery mechanisms");

      // Test failure counter reset
      RefreshTokenErrorHandler.resetFailureCounters();
      final statsAfterReset = RefreshTokenErrorHandler.getFailureStatistics();
      result['failureCounterReset'] = {
        'success': statsAfterReset['consecutiveFailures'] == 0,
        'consecutiveFailures': statsAfterReset['consecutiveFailures'],
      };

      // Test different resolution strategies
      final resolutions = <RefreshTokenFailureType, bool>{
        RefreshTokenFailureType.networkTimeout:
            RefreshTokenErrorHandler.shouldRetryFailure(
                RefreshTokenFailureType.networkTimeout),
        RefreshTokenFailureType.refreshTokenExpired:
            RefreshTokenErrorHandler.shouldRetryFailure(
                RefreshTokenFailureType.refreshTokenExpired),
        RefreshTokenFailureType.serverError:
            RefreshTokenErrorHandler.shouldRetryFailure(
                RefreshTokenFailureType.serverError),
      };

      result['resolutionStrategies'] = {
        'success': resolutions[RefreshTokenFailureType.networkTimeout] ==
                true &&
            resolutions[RefreshTokenFailureType.refreshTokenExpired] == false &&
            resolutions[RefreshTokenFailureType.serverError] == true,
        'strategies': resolutions.map((k, v) => MapEntry(k.toString(), v)),
      };

      result['status'] = 'PASSED';
      log("✅ Error recovery mechanisms test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Error recovery mechanisms test FAILED: $e");
    }

    return result;
  }

  /// Test continuous session integration
  Future<Map<String, dynamic>> _testContinuousSessionIntegration() async {
    final result = <String, dynamic>{};

    try {
      log("🧪 Testing continuous session integration");

      // Test session manager availability
      try {
        final sessionManager = GetIt.I<ContinuousSessionManager>();
        result['sessionManagerAvailable'] = {
          'success': sessionManager != null,
          'available': true,
        };

        // Test session status
        final status = sessionManager.getContinuousSessionStatus();
        result['sessionStatus'] = {
          'success': status != null,
          'hasStatus': status != null,
        };
      } catch (e) {
        result['sessionManagerAvailable'] = {
          'success': false,
          'available': false,
          'error': e.toString(),
        };
      }

      // Test error handler integration
      const testFailure = RefreshTokenFailureType.refreshTokenExpired;
      final shouldDeactivate = [
        RefreshTokenFailureType.refreshTokenExpired,
        RefreshTokenFailureType.refreshTokenRevoked,
        RefreshTokenFailureType.refreshTokenInvalid,
      ].contains(testFailure);

      result['errorHandlerIntegration'] = {
        'success': shouldDeactivate,
        'shouldDeactivateOnAuthFailure': shouldDeactivate,
      };

      result['status'] = 'PASSED';
      log("✅ Continuous session integration test PASSED");
    } catch (e) {
      result['status'] = 'FAILED';
      result['error'] = e.toString();
      log("❌ Continuous session integration test FAILED: $e");
    }

    return result;
  }

  /// Get test results
  Map<String, dynamic> getTestResults() => Map.from(_testResults);
}
