import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';

/// Dio interceptor that automatically handles authentication with secure token management
/// This interceptor:
/// 1. Automatically adds Bearer tokens to all requests
/// 2. Handles 401 responses by refreshing tokens and retrying requests
/// 3. Prevents multiple concurrent refresh attempts
class SecureAuthInterceptor extends Interceptor {
  final SecureTokenManager _tokenManager = SecureTokenManager();
  
  // Configuration
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  
  // Endpoints that should skip authentication
  static const List<String> _skipAuthEndpoints = [
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/health',
    '/public',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Skip authentication for certain endpoints
      if (_shouldSkipAuth(options.path)) {
        log('🔓 Skipping auth for endpoint: ${options.path}');
        handler.next(options);
        return;
      }

      // Get valid access token (will refresh if needed)
      final accessToken = await _tokenManager.getValidAccessToken();
      
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
        log('🔑 Added Bearer token to request: ${options.method} ${options.path}');
      } else {
        log('⚠️ No valid access token available for request: ${options.method} ${options.path}');
      }

      handler.next(options);
    } catch (e) {
      log('❌ Error in auth interceptor onRequest: $e');
      handler.next(options);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401 Unauthorized errors
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Skip retry for auth endpoints to prevent infinite loops
    if (_shouldSkipAuth(err.requestOptions.path)) {
      log('🔓 Skipping 401 retry for auth endpoint: ${err.requestOptions.path}');
      handler.next(err);
      return;
    }

    // Check if we've already retried this request
    final retryCount = err.requestOptions.extra['retry_count'] as int? ?? 0;
    if (retryCount >= _maxRetries) {
      log('❌ Max retries reached for request: ${err.requestOptions.path}');
      handler.next(err);
      return;
    }

    try {
      log('🔄 401 error detected, attempting token refresh and retry...');
      
      // Attempt to refresh tokens
      final refreshSuccess = await _tokenManager.refreshTokens();
      
      if (!refreshSuccess) {
        log('❌ Token refresh failed, cannot retry request');
        handler.next(err);
        return;
      }

      // Get the new access token
      final newAccessToken = await _tokenManager.getAccessToken();
      if (newAccessToken == null) {
        log('❌ No access token after refresh');
        handler.next(err);
        return;
      }

      // Wait a bit before retrying
      await Future.delayed(_retryDelay);

      // Create a new request with the updated token
      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      requestOptions.extra['retry_count'] = retryCount + 1;

      log('🔄 Retrying request with new token: ${requestOptions.method} ${requestOptions.path} (attempt ${retryCount + 1})');

      // Retry the request
      final dio = Dio();
      final response = await dio.fetch(requestOptions);
      
      log('✅ Request retry successful: ${requestOptions.path}');
      handler.resolve(response);
    } catch (e) {
      log('❌ Error during 401 retry: $e');
      handler.next(err);
    }
  }

  /// Check if authentication should be skipped for this endpoint
  bool _shouldSkipAuth(String path) {
    return _skipAuthEndpoints.any((endpoint) => path.contains(endpoint));
  }
}

/// Factory class to create a configured Dio instance with secure authentication
class SecureDioFactory {
  static Dio createAuthenticatedDio({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    final dio = Dio();
    
    // Configure base options
    dio.options = BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: connectTimeout ?? const Duration(seconds: 30),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
      sendTimeout: sendTimeout ?? const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Add the secure auth interceptor
    dio.interceptors.add(SecureAuthInterceptor());

    // Add logging interceptor in debug mode
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: false,
      error: true,
      logPrint: (obj) => log(obj.toString()),
    ));

    return dio;
  }
}
