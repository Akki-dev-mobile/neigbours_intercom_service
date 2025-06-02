import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

/// Unified authentication interceptor for automatic Bearer token injection
/// This interceptor handles:
/// 1. Automatic Bearer token injection for all API requests
/// 2. Token refresh when tokens are expired or about to expire
/// 3. 401 error handling with automatic retry
/// 4. Public endpoint detection and auth skipping
/// 5. Integration with existing Keycloak authentication system
class UnifiedAuthInterceptor extends Interceptor {
  final SecureTokenManager _tokenManager = SecureTokenManager();
  
  // Configuration
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  
  // Endpoints that should skip authentication
  static const List<String> _skipAuthEndpoints = [
    '/auth/',
    '/login',
    '/logout',
    '/token',
    '/health',
    '/public/',
    '/gatelogin',
    '/sms/verification-code',
    '/visitor/selfCheckin',
    '/realms/',  // Keycloak endpoints
  ];

  // Track retry attempts to prevent infinite loops
  static const String _retryCountKey = 'unified_auth_retry_count';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Skip authentication for certain endpoints
      if (_shouldSkipAuth(options.path)) {
        log('🔓 [UnifiedAuth] Skipping auth for endpoint: ${options.path}');
        handler.next(options);
        return;
      }

      // Check if this is a retry request
      final retryCount = options.extra[_retryCountKey] as int? ?? 0;
      
      // Get valid access token (will refresh if needed)
      final accessToken = await _tokenManager.getValidAccessToken();
      
      if (accessToken != null && accessToken.isNotEmpty) {
        // Validate token before use
        final isValid = JwtTokenUtility.isValidJwtToken(accessToken);
        
        if (isValid) {
          options.headers['Authorization'] = 'Bearer $accessToken';
          
          if (kDebugMode) {
            final timeUntilExpiry = JwtTokenUtility.getTimeUntilExpiration(accessToken);
            log('🔑 [UnifiedAuth] Added Bearer token to ${options.method} ${options.path}');
            log('⏰ [UnifiedAuth] Token expires in: ${timeUntilExpiry?.inMinutes ?? 'unknown'} minutes');
          }
        } else {
          log('⚠️ [UnifiedAuth] Token is invalid, proceeding without auth for: ${options.path}');
        }
      } else {
        log('⚠️ [UnifiedAuth] No valid access token available for: ${options.method} ${options.path}');
      }

      handler.next(options);
    } catch (e) {
      log('❌ [UnifiedAuth] Error in onRequest: $e');
      // Continue with request even if auth fails
      handler.next(options);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized errors with automatic retry
    if (err.response?.statusCode == 401) {
      log('🔄 [UnifiedAuth] Received 401 Unauthorized for: ${err.requestOptions.path}');

      final retryResult = await _handleUnauthorizedError(err);
      if (retryResult != null) {
        log('✅ [UnifiedAuth] Request retry successful: ${err.requestOptions.path}');
        handler.resolve(retryResult);
        return;
      }
    }

    // Handle other authentication-related errors
    if (_isAuthenticationError(err)) {
      log('🚫 [UnifiedAuth] Authentication error detected: ${err.response?.statusCode}');
      await _handleAuthenticationFailure();
    }

    handler.next(err);
  }

  /// Handle 401 unauthorized errors with token refresh and retry
  Future<Response?> _handleUnauthorizedError(DioException error) async {
    try {
      final requestOptions = error.requestOptions;
      final retryCount = requestOptions.extra[_retryCountKey] as int? ?? 0;

      // Check retry limit
      if (retryCount >= _maxRetries) {
        log('❌ [UnifiedAuth] Max retry attempts reached for: ${requestOptions.path}');
        return null;
      }

      // Skip retry for auth endpoints to prevent infinite loops
      if (_shouldSkipAuth(requestOptions.path)) {
        log('🔓 [UnifiedAuth] Skipping retry for auth endpoint: ${requestOptions.path}');
        return null;
      }

      log('🔄 [UnifiedAuth] Attempting token refresh for retry ${retryCount + 1}/${_maxRetries}');

      // Attempt to refresh tokens
      final refreshSuccess = await _tokenManager.refreshTokens();
      if (!refreshSuccess) {
        log('❌ [UnifiedAuth] Token refresh failed, cannot retry request');
        await _handleAuthenticationFailure();
        return null;
      }

      // Get the new access token
      final newAccessToken = await _tokenManager.getAccessToken();
      if (newAccessToken == null || newAccessToken.isEmpty) {
        log('❌ [UnifiedAuth] No new access token available after refresh');
        return null;
      }

      // Update the request with new token and retry count
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      requestOptions.extra[_retryCountKey] = retryCount + 1;

      log('🔄 [UnifiedAuth] Retrying request with new token: ${requestOptions.path}');

      // Add a small delay before retry
      await Future.delayed(_retryDelay);

      // Create a new Dio instance to avoid interceptor loops
      final dio = Dio();
      
      // Copy base options from the original request
      dio.options.baseUrl = requestOptions.baseUrl;
      dio.options.connectTimeout = requestOptions.connectTimeout;
      dio.options.receiveTimeout = requestOptions.receiveTimeout;
      dio.options.sendTimeout = requestOptions.sendTimeout;

      // Make the retry request
      return await dio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
          contentType: requestOptions.contentType,
          responseType: requestOptions.responseType,
          extra: requestOptions.extra,
        ),
      );
    } catch (e) {
      log('❌ [UnifiedAuth] Error during retry: $e');
      return null;
    }
  }

  /// Check if authentication should be skipped for this path
  bool _shouldSkipAuth(String path) {
    return _skipAuthEndpoints.any((skipPath) => path.contains(skipPath));
  }

  /// Check if the error is authentication-related
  bool _isAuthenticationError(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  /// Handle authentication failure
  Future<void> _handleAuthenticationFailure() async {
    try {
      log('🚪 [UnifiedAuth] Handling authentication failure');
      
      // Clear invalid tokens
      await _tokenManager.clearTokens();
      
      // Note: Navigation to login screen should be handled by the app's navigation logic
      // This interceptor should not directly handle navigation
      
    } catch (e) {
      log('❌ [UnifiedAuth] Error handling authentication failure: $e');
    }
  }
}
