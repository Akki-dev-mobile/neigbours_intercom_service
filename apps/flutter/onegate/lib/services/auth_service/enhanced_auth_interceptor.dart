import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';

/// Enhanced authentication interceptor with automatic token refresh
class EnhancedAuthInterceptor extends Interceptor {
  final EnhancedTokenRefreshManager _tokenManager;
  final Function()? onAuthenticationFailed;
  final TokenNotificationService _notificationService =
      TokenNotificationService();

  // Request retry configuration
  static const int _maxRetryAttempts = 2;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  EnhancedAuthInterceptor({
    required EnhancedTokenRefreshManager tokenManager,
    this.onAuthenticationFailed,
  }) : _tokenManager = tokenManager;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Skip auth for certain endpoints
      if (_shouldSkipAuth(options.path)) {
        handler.next(options);
        return;
      }

      // Get valid access token with immediate refresh (401 error fix)
      final accessToken =
          await _tokenManager.getValidAccessTokenWithImmediateRefresh();

      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
        log("🔑 Added Bearer token to request: ${options.path}");

        // Log token expiration info for debugging 401 errors
        final timeUntilExpiry =
            JwtTokenUtility.getTimeUntilExpiration(accessToken);
        log("⏰ Token expires in: ${timeUntilExpiry?.inMinutes ?? 'unknown'} minutes");

        // Log token details in debug mode
        if (options.extra['debug_token'] == true) {
          JwtTokenUtility.logTokenDetails("ACCESS", accessToken);
        }
      } else {
        log("⚠️ No valid access token available for request: ${options.path}");
        // Don't fail the request here, let the server respond with 401
      }

      // Add default headers
      options.headers['Content-Type'] ??= 'application/json';
      options.headers['Accept'] ??= 'application/json';
    } catch (e) {
      log("❌ Error adding auth headers: $e");
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized errors with automatic retry
    if (err.response?.statusCode == 401) {
      log("🔄 Received 401 Unauthorized for: ${err.requestOptions.path}");

      final retryResult = await _handleUnauthorizedError(err);
      if (retryResult != null) {
        handler.resolve(retryResult);
        return;
      }
    }

    // Handle other authentication-related errors
    if (_isAuthenticationError(err)) {
      log("🚫 Authentication error detected: ${err.response?.statusCode}");
      await _handleAuthenticationFailure();
    }

    handler.next(err);
  }

  /// Handle 401 Unauthorized errors with token refresh and retry
  Future<Response?> _handleUnauthorizedError(DioException error) async {
    try {
      // Check if we should retry this request
      final retryCount = error.requestOptions.extra['retry_count'] ?? 0;
      if (retryCount >= _maxRetryAttempts) {
        log("❌ Max retry attempts reached for: ${error.requestOptions.path}");
        return null;
      }

      log("🔄 Attempting token refresh for 401 error (attempt ${retryCount + 1}/$_maxRetryAttempts)");

      // Attempt to refresh the token
      final refreshed = await _tokenManager.refreshTokenIfNeeded();
      if (!refreshed) {
        log("❌ Token refresh failed for 401 error");
        await _handleAuthenticationFailure();
        return null;
      }

      // Get the new access token with immediate refresh
      final newAccessToken =
          await _tokenManager.getValidAccessTokenWithImmediateRefresh();
      if (newAccessToken == null) {
        log("❌ No valid access token after refresh");
        await _handleAuthenticationFailure();
        return null;
      }

      // Update the request with new token and retry count
      final requestOptions = error.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      requestOptions.extra['retry_count'] = retryCount + 1;

      log("🔄 Retrying request with new token: ${requestOptions.path}");

      // Add a small delay before retry
      await Future.delayed(_retryDelay);

      // Create a new Dio instance to avoid interceptor loops
      final dio = Dio();

      // Copy base options from the original request
      dio.options.baseUrl = requestOptions.baseUrl;
      dio.options.connectTimeout = requestOptions.connectTimeout;
      dio.options.receiveTimeout = requestOptions.receiveTimeout;
      dio.options.sendTimeout = requestOptions.sendTimeout;

      // Retry the request
      final response = await dio.fetch(requestOptions);
      log("✅ Request retry successful: ${requestOptions.path}");

      return response;
    } catch (e) {
      log("❌ Error handling 401 unauthorized: $e");
      return null;
    }
  }

  /// Handle authentication failure
  Future<void> _handleAuthenticationFailure() async {
    try {
      log("🚪 Authentication failed, clearing tokens and notifying app");

      // Show authentication error notification
      _notificationService.showAuthenticationError(
          errorMessage: "Session expired. Please login again.");

      // Clear all tokens
      await _tokenManager.clearTokens();

      // Notify the app about authentication failure
      if (onAuthenticationFailed != null) {
        onAuthenticationFailed!();
      }
    } catch (e) {
      log("❌ Error handling authentication failure: $e");
      _notificationService.showAuthenticationError(
          errorMessage: "Authentication error occurred");
    }
  }

  /// Check if the request path should skip authentication
  bool _shouldSkipAuth(String path) {
    final skipAuthPaths = [
      '/auth/',
      '/login',
      '/token',
      '/refresh',
      '/public/',
      '/.well-known/',
    ];

    return skipAuthPaths.any((skipPath) => path.contains(skipPath));
  }

  /// Check if the error is authentication-related
  bool _isAuthenticationError(DioException error) {
    final authErrorCodes = [401, 403];
    return authErrorCodes.contains(error.response?.statusCode);
  }
}

/// Enhanced authentication interceptor factory
class EnhancedAuthInterceptorFactory {
  static EnhancedAuthInterceptor create({
    required EnhancedTokenRefreshManager tokenManager,
    Function()? onAuthenticationFailed,
  }) {
    return EnhancedAuthInterceptor(
      tokenManager: tokenManager,
      onAuthenticationFailed: onAuthenticationFailed,
    );
  }

  /// Create interceptor with default authentication failure handler
  static EnhancedAuthInterceptor createWithDefaultHandler({
    required EnhancedTokenRefreshManager tokenManager,
    Function()? customHandler,
  }) {
    return EnhancedAuthInterceptor(
      tokenManager: tokenManager,
      onAuthenticationFailed: customHandler ?? _defaultAuthFailureHandler,
    );
  }

  /// Default authentication failure handler
  static void _defaultAuthFailureHandler() {
    log("🚪 Default auth failure handler: User needs to re-authenticate");
    // Here you could emit an event, navigate to login, or show a dialog
    // This will be implemented based on your app's navigation structure
  }
}

/// Request options extension for auth-related metadata
extension AuthRequestOptions on RequestOptions {
  /// Mark request to debug token information
  void enableTokenDebug() {
    extra['debug_token'] = true;
  }

  /// Get retry count for this request
  int get retryCount => extra['retry_count'] ?? 0;

  /// Set retry count for this request
  set retryCount(int count) => extra['retry_count'] = count;

  /// Check if this request should skip authentication
  bool get skipAuth => extra['skip_auth'] == true;

  /// Mark request to skip authentication
  void setSkipAuth() {
    extra['skip_auth'] = true;
  }
}
