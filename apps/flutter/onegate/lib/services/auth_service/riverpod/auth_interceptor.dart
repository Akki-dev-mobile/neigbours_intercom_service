import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';

/// Dio interceptor that automatically handles authentication
class AuthInterceptor extends Interceptor {
  final Ref ref;
  final Duration _retryDelay = const Duration(milliseconds: 500);
  final int _maxRetries = 2;

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Skip auth for certain endpoints
      if (_shouldSkipAuth(options.path)) {
        handler.next(options);
        return;
      }

      // Get current access token
      final authController = ref.read(authControllerProvider.notifier);
      final accessToken = authController.accessToken;

      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
        log('🔑 Added Bearer token to request: ${options.path}');
      } else {
        log('⚠️ No access token available for request: ${options.path}');
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

    // Check if we've already retried this request
    final retryCount = err.requestOptions.extra['retry_count'] ?? 0;
    if (retryCount >= _maxRetries) {
      log('❌ Max retries reached for request: ${err.requestOptions.path}');
      handler.next(err);
      return;
    }

    // Skip auth for certain endpoints
    if (_shouldSkipAuth(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    try {
      log('🔄 401 error detected, attempting token refresh...');
      
      // Attempt to refresh token
      final authController = ref.read(authControllerProvider.notifier);
      final refreshSuccess = await authController.refreshToken();

      if (!refreshSuccess) {
        log('❌ Token refresh failed, user needs to re-authenticate');
        // Token refresh failed, user needs to login again
        await authController.logout();
        handler.next(err);
        return;
      }

      // Get new access token
      final newAccessToken = authController.accessToken;
      if (newAccessToken == null) {
        log('❌ No access token after refresh');
        handler.next(err);
        return;
      }

      // Update request with new token and retry
      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      requestOptions.extra['retry_count'] = retryCount + 1;

      log('🔄 Retrying request with new token: ${requestOptions.path}');

      // Add delay before retry
      await Future.delayed(_retryDelay);

      // Create new Dio instance to avoid interceptor loops
      final dio = Dio();
      dio.options.baseUrl = requestOptions.baseUrl;
      dio.options.connectTimeout = requestOptions.connectTimeout;
      dio.options.receiveTimeout = requestOptions.receiveTimeout;
      dio.options.sendTimeout = requestOptions.sendTimeout;

      try {
        final response = await dio.request(
          requestOptions.path,
          data: requestOptions.data,
          queryParameters: requestOptions.queryParameters,
          options: Options(
            method: requestOptions.method,
            headers: requestOptions.headers,
            contentType: requestOptions.contentType,
            responseType: requestOptions.responseType,
            followRedirects: requestOptions.followRedirects,
            maxRedirects: requestOptions.maxRedirects,
            receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
            extra: requestOptions.extra,
          ),
        );

        log('✅ Request retry successful: ${requestOptions.path}');
        handler.resolve(response);
      } catch (retryError) {
        log('❌ Request retry failed: ${requestOptions.path}');
        if (retryError is DioException) {
          handler.next(retryError);
        } else {
          handler.next(DioException(
            requestOptions: requestOptions,
            error: retryError,
            message: 'Retry failed: $retryError',
          ));
        }
      }
    } catch (e) {
      log('❌ Error handling 401 response: $e');
      handler.next(err);
    }
  }

  /// Check if authentication should be skipped for this path
  bool _shouldSkipAuth(String path) {
    final skipPaths = [
      '/auth/',
      '/login',
      '/logout',
      '/token',
      '/health',
      '/public/',
    ];

    return skipPaths.any((skipPath) => path.contains(skipPath));
  }
}

/// Factory for creating AuthInterceptor with proper Riverpod integration
class AuthInterceptorFactory {
  /// Create an AuthInterceptor with the given Ref
  static AuthInterceptor create(Ref ref) {
    return AuthInterceptor(ref);
  }

  /// Create an AuthInterceptor with a custom error handler
  static AuthInterceptor createWithErrorHandler(
    Ref ref, {
    void Function()? onAuthenticationFailed,
  }) {
    final interceptor = AuthInterceptor(ref);
    
    // If a custom error handler is provided, we could extend the interceptor
    // For now, we'll return the basic interceptor
    return interceptor;
  }
}

/// Extension for RequestOptions to handle retry metadata
extension AuthRequestOptions on RequestOptions {
  /// Get retry count for this request
  int get retryCount => extra['retry_count'] ?? 0;

  /// Set retry count for this request
  set retryCount(int count) => extra['retry_count'] = count;

  /// Check if this request should skip authentication
  bool get skipAuth => extra['skip_auth'] == true;

  /// Mark request to skip authentication
  void setSkipAuth() => extra['skip_auth'] = true;
}
