import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_interceptor.dart';
import 'package:flutter_onegate/utils/network_log/network_log_manager.dart';

/// Factory for creating authenticated Dio instances with automatic Bearer token injection
/// This factory ensures all HTTP clients in the app have consistent authentication handling
class AuthenticatedDioFactory {
  /// Create a Dio instance with automatic authentication
  /// 
  /// Parameters:
  /// - [baseUrl]: Base URL for the API
  /// - [connectTimeout]: Connection timeout duration
  /// - [receiveTimeout]: Receive timeout duration
  /// - [sendTimeout]: Send timeout duration
  /// - [enableNetworkLogging]: Whether to enable network logging (debug mode only)
  /// - [customHeaders]: Additional headers to include in all requests
  static Dio createAuthenticatedDio({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    bool enableNetworkLogging = true,
    Map<String, String>? customHeaders,
  }) {
    // Create Dio instance with base configuration
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: connectTimeout ?? const Duration(seconds: 30),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
      sendTimeout: sendTimeout ?? const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?customHeaders,
      },
    ));

    // Add unified authentication interceptor (highest priority)
    dio.interceptors.add(UnifiedAuthInterceptor());

    // Add network logging interceptor in debug mode
    if (kDebugMode && enableNetworkLogging) {
      try {
        NetworkLogManager().addInterceptorToDio(dio);
      } catch (e) {
        // Network logging is optional, don't fail if it's not available
        if (kDebugMode) {
          print('⚠️ [AuthenticatedDioFactory] Network logging not available: $e');
        }
      }
    }

    // Add general logging interceptor in debug mode
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
        logPrint: (object) {
          if (kDebugMode) {
            print('🌐 [HTTP] $object');
          }
        },
      ));
    }

    return dio;
  }

  /// Create a Dio instance for OneGate API with predefined configuration
  static Dio createOneGateApiClient({
    required String baseUrl,
    Map<String, String>? customHeaders,
  }) {
    return createAuthenticatedDio(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      customHeaders: {
        'X-API-Source': 'OneGate-Flutter',
        'X-Client-Version': '1.0.0',
        ...?customHeaders,
      },
    );
  }

  /// Create a Dio instance for Society API with predefined configuration
  static Dio createSocietyApiClient({
    Map<String, String>? customHeaders,
  }) {
    return createAuthenticatedDio(
      baseUrl: 'https://societybackend.cubeone.in/api',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      customHeaders: {
        'X-API-Source': 'OneGate-Society',
        'X-Client-Version': '1.0.0',
        ...?customHeaders,
      },
    );
  }

  /// Create a Dio instance for file uploads with extended timeouts
  static Dio createFileUploadClient({
    String? baseUrl,
    Map<String, String>? customHeaders,
  }) {
    return createAuthenticatedDio(
      baseUrl: baseUrl,
      connectTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 5),
      customHeaders: {
        'X-API-Source': 'OneGate-FileUpload',
        ...?customHeaders,
      },
    );
  }

  /// Create a Dio instance without authentication for public endpoints
  static Dio createPublicDio({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, String>? customHeaders,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: connectTimeout ?? const Duration(seconds: 30),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
      sendTimeout: sendTimeout ?? const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?customHeaders,
      },
    ));

    // Add network logging interceptor in debug mode
    if (kDebugMode) {
      try {
        NetworkLogManager().addInterceptorToDio(dio);
      } catch (e) {
        // Network logging is optional
        if (kDebugMode) {
          print('⚠️ [AuthenticatedDioFactory] Network logging not available: $e');
        }
      }

      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
        logPrint: (object) {
          if (kDebugMode) {
            print('🌐 [HTTP-Public] $object');
          }
        },
      ));
    }

    return dio;
  }

  /// Create a Dio instance for WebSocket or real-time communication
  static Dio createRealtimeClient({
    String? baseUrl,
    Map<String, String>? customHeaders,
  }) {
    return createAuthenticatedDio(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 10),
      customHeaders: {
        'X-API-Source': 'OneGate-Realtime',
        ...?customHeaders,
      },
    );
  }
}
