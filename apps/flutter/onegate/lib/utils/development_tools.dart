import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Development Tools for OneGate Flutter App
/// Provides enhanced debugging and testing capabilities
class DevelopmentTools {
  static bool get isDebugMode => kDebugMode;
  static bool get isProfileMode => kProfileMode;
  static bool get isReleaseMode => kReleaseMode;

  /// Initialize development tools
  static void initialize() {
    if (isDebugMode) {
      developer.log('🛠️ Development Tools initialized');
      developer.log('📱 Running in DEBUG mode');
      _setupNetworkLogging();
    }
  }

  /// Setup network request/response logging
  static void _setupNetworkLogging() {
    developer.log('🌐 Network logging enabled');
  }

  /// Log API request details
  static void logApiRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    if (!isDebugMode) return;

    developer.log('📤 API REQUEST', name: 'NetworkLogger');
    developer.log('Method: $method', name: 'NetworkLogger');
    developer.log('URL: $url', name: 'NetworkLogger');
    
    if (headers != null) {
      developer.log('Headers: $headers', name: 'NetworkLogger');
    }
    
    if (queryParameters != null) {
      developer.log('Query Parameters: $queryParameters', name: 'NetworkLogger');
    }
    
    if (data != null) {
      developer.log('Request Data: $data', name: 'NetworkLogger');
    }
  }

  /// Log API response details
  static void logApiResponse({
    required int statusCode,
    required String url,
    Map<String, dynamic>? headers,
    dynamic data,
    Duration? responseTime,
  }) {
    if (!isDebugMode) return;

    final statusEmoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    
    developer.log('📥 API RESPONSE $statusEmoji', name: 'NetworkLogger');
    developer.log('Status: $statusCode', name: 'NetworkLogger');
    developer.log('URL: $url', name: 'NetworkLogger');
    
    if (responseTime != null) {
      developer.log('Response Time: ${responseTime.inMilliseconds}ms', name: 'NetworkLogger');
    }
    
    if (headers != null) {
      developer.log('Response Headers: $headers', name: 'NetworkLogger');
    }
    
    if (data != null) {
      developer.log('Response Data: $data', name: 'NetworkLogger');
    }
  }

  /// Log API error details
  static void logApiError({
    required String url,
    required String error,
    int? statusCode,
    dynamic response,
    StackTrace? stackTrace,
  }) {
    if (!isDebugMode) return;

    developer.log('🚨 API ERROR', name: 'NetworkLogger');
    developer.log('URL: $url', name: 'NetworkLogger');
    developer.log('Error: $error', name: 'NetworkLogger');
    
    if (statusCode != null) {
      developer.log('Status Code: $statusCode', name: 'NetworkLogger');
    }
    
    if (response != null) {
      developer.log('Error Response: $response', name: 'NetworkLogger');
    }
    
    if (stackTrace != null) {
      developer.log('Stack Trace: $stackTrace', name: 'NetworkLogger');
    }
  }

  /// Create a Dio interceptor for automatic request/response logging
  static InterceptorsWrapper createNetworkLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final stopwatch = Stopwatch()..start();
        options.extra['request_start_time'] = stopwatch;

        logApiRequest(
          method: options.method,
          url: options.uri.toString(),
          headers: options.headers,
          data: options.data,
          queryParameters: options.queryParameters,
        );

        handler.next(options);
      },
      onResponse: (response, handler) {
        final stopwatch = response.requestOptions.extra['request_start_time'] as Stopwatch?;
        stopwatch?.stop();

        logApiResponse(
          statusCode: response.statusCode ?? 0,
          url: response.requestOptions.uri.toString(),
          headers: response.headers.map,
          data: response.data,
          responseTime: stopwatch?.elapsed,
        );

        handler.next(response);
      },
      onError: (error, handler) {
        logApiError(
          url: error.requestOptions.uri.toString(),
          error: error.message ?? 'Unknown error',
          statusCode: error.response?.statusCode,
          response: error.response?.data,
          stackTrace: error.stackTrace,
        );

        handler.next(error);
      },
    );
  }

  /// Log visitor list ordering for investigation
  static void logVisitorListOrdering({
    required List<dynamic> visitors,
    required String context,
  }) {
    if (!isDebugMode) return;

    developer.log('📋 VISITOR LIST ORDERING INVESTIGATION', name: 'OrderingLogger');
    developer.log('Context: $context', name: 'OrderingLogger');
    developer.log('Total visitors: ${visitors.length}', name: 'OrderingLogger');

    if (visitors.isNotEmpty) {
      developer.log('First visitor: ${_getVisitorInfo(visitors.first)}', name: 'OrderingLogger');
      developer.log('Last visitor: ${_getVisitorInfo(visitors.last)}', name: 'OrderingLogger');

      // Log ordering pattern
      final checkInTimes = visitors
          .map((v) => v['visitor_check_in'] as String?)
          .where((time) => time != null)
          .toList();

      if (checkInTimes.length > 1) {
        final isChronological = _isChronologicalOrder(checkInTimes);
        final isReverseChronological = _isReverseChronologicalOrder(checkInTimes);

        if (isChronological) {
          developer.log('✅ Ordering: Chronological (oldest first)', name: 'OrderingLogger');
        } else if (isReverseChronological) {
          developer.log('✅ Ordering: Reverse chronological (newest first)', name: 'OrderingLogger');
        } else {
          developer.log('❌ Ordering: No clear chronological pattern', name: 'OrderingLogger');
        }
      }
    }
  }

  /// Helper method to get visitor info for logging
  static String _getVisitorInfo(dynamic visitor) {
    if (visitor is Map<String, dynamic>) {
      final visitorData = visitor['visitor'] as Map<String, dynamic>?;
      final name = visitorData?['name'] ?? 'Unknown';
      final checkIn = visitor['visitor_check_in'] ?? 'Unknown';
      return '$name (Check-in: $checkIn)';
    }
    return 'Invalid visitor data';
  }

  /// Check if times are in chronological order (oldest first)
  static bool _isChronologicalOrder(List<String?> times) {
    for (int i = 1; i < times.length; i++) {
      final prev = DateTime.tryParse(times[i - 1] ?? '');
      final curr = DateTime.tryParse(times[i] ?? '');
      if (prev != null && curr != null && prev.isAfter(curr)) {
        return false;
      }
    }
    return true;
  }

  /// Check if times are in reverse chronological order (newest first)
  static bool _isReverseChronologicalOrder(List<String?> times) {
    for (int i = 1; i < times.length; i++) {
      final prev = DateTime.tryParse(times[i - 1] ?? '');
      final curr = DateTime.tryParse(times[i] ?? '');
      if (prev != null && curr != null && prev.isBefore(curr)) {
        return false;
      }
    }
    return true;
  }

  /// Performance monitoring for API calls
  static void logPerformanceMetrics({
    required String operation,
    required Duration duration,
    Map<String, dynamic>? additionalData,
  }) {
    if (!isDebugMode) return;

    final emoji = duration.inMilliseconds < 2000 ? '⚡' : '🐌';
    
    developer.log('$emoji PERFORMANCE METRICS', name: 'PerformanceLogger');
    developer.log('Operation: $operation', name: 'PerformanceLogger');
    developer.log('Duration: ${duration.inMilliseconds}ms', name: 'PerformanceLogger');
    
    if (additionalData != null) {
      developer.log('Additional Data: $additionalData', name: 'PerformanceLogger');
    }

    // Log performance warnings
    if (duration.inMilliseconds > 5000) {
      developer.log('⚠️ SLOW OPERATION: $operation took ${duration.inMilliseconds}ms', 
          name: 'PerformanceLogger');
    }
  }

  /// Log authentication events
  static void logAuthEvent({
    required String event,
    bool success = true,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    if (!isDebugMode) return;

    final emoji = success ? '🔐' : '🚨';
    
    developer.log('$emoji AUTH EVENT', name: 'AuthLogger');
    developer.log('Event: $event', name: 'AuthLogger');
    developer.log('Success: $success', name: 'AuthLogger');
    
    if (details != null) {
      developer.log('Details: $details', name: 'AuthLogger');
    }
    
    if (metadata != null) {
      developer.log('Metadata: $metadata', name: 'AuthLogger');
    }
  }

  /// Get development tools status
  static Map<String, dynamic> getStatus() {
    return {
      'debug_mode': isDebugMode,
      'profile_mode': isProfileMode,
      'release_mode': isReleaseMode,
      'network_logging': isDebugMode,
      'performance_monitoring': isDebugMode,
      'auth_logging': isDebugMode,
    };
  }

  /// Print development tools help
  static void printHelp() {
    if (!isDebugMode) return;

    developer.log('🛠️ DEVELOPMENT TOOLS HELP', name: 'DevTools');
    developer.log('Available features:', name: 'DevTools');
    developer.log('- Network request/response logging', name: 'DevTools');
    developer.log('- Visitor list ordering investigation', name: 'DevTools');
    developer.log('- Performance monitoring', name: 'DevTools');
    developer.log('- Authentication event logging', name: 'DevTools');
    developer.log('- Flutter DevTools integration', name: 'DevTools');
    developer.log('', name: 'DevTools');
    developer.log('To access Flutter DevTools:', name: 'DevTools');
    developer.log('1. Run: flutter run', name: 'DevTools');
    developer.log('2. Press "d" in terminal to open DevTools', name: 'DevTools');
    developer.log('3. Or visit: http://localhost:9100', name: 'DevTools');
  }
}
