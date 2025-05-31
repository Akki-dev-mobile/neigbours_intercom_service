import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_auth_interceptor.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:get_it/get_it.dart';

/// Enhanced API client with automatic token management and authentication
class AuthenticatedApiClient {
  static final AuthenticatedApiClient _instance =
      AuthenticatedApiClient._internal();

  factory AuthenticatedApiClient() {
    return _instance;
  }

  AuthenticatedApiClient._internal();

  late final Dio _dio;
  late final AuthService _authService;

  bool _isInitialized = false;

  /// Initialize the API client
  Future<void> initialize() async {
    if (_isInitialized) return;

    _dio = Dio();
    _authService = GetIt.I<AuthService>();

    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // Add interceptors
    _dio.interceptors.add(_createEnhancedAuthInterceptor());
    _dio.interceptors.add(_createLoggingInterceptor());
    _dio.interceptors.add(_createErrorInterceptor());

    _isInitialized = true;
    log("✅ AuthenticatedApiClient initialized");
  }

  /// Create enhanced authentication interceptor
  Interceptor _createEnhancedAuthInterceptor() {
    return EnhancedAuthInterceptorFactory.createWithDefaultHandler(
      tokenManager: _authService.tokenRefreshManager,
      customHandler: () {
        log("🚪 Authentication failed in API client, user needs to re-authenticate");
        // Here you could emit an event, navigate to login, or show a dialog
        // This will be implemented based on your app's navigation structure
      },
    );
  }

  /// Create logging interceptor
  Interceptor _createLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        log("🌐 API REQUEST: ${options.method} ${options.path}");
        log("📋 Headers: ${options.headers}");
        if (options.data != null) {
          log("📦 Body: ${options.data}");
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        log("✅ API RESPONSE: ${response.statusCode} ${response.requestOptions.path}");
        handler.next(response);
      },
      onError: (error, handler) {
        log("❌ API ERROR: ${error.response?.statusCode} ${error.requestOptions.path}");
        log("❌ Error: ${error.message}");
        handler.next(error);
      },
    );
  }

  /// Create error handling interceptor
  Interceptor _createErrorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        // Handle different types of errors
        if (error.type == DioExceptionType.connectionTimeout) {
          log("⏰ Connection timeout for ${error.requestOptions.path}");
        } else if (error.type == DioExceptionType.receiveTimeout) {
          log("⏰ Receive timeout for ${error.requestOptions.path}");
        } else if (error.type == DioExceptionType.connectionError) {
          log("🌐 Connection error for ${error.requestOptions.path}");
        }

        handler.next(error);
      },
    );
  }

  /// Make authenticated GET request with pre-validation (401 error fix)
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    await _ensureInitialized();

    // Pre-request token validation to prevent 401 errors
    await _validateTokenBeforeRequest(path);

    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make authenticated POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    await _ensureInitialized();

    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make authenticated PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    await _ensureInitialized();

    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make authenticated DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    await _ensureInitialized();

    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Ensure client is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Pre-request token validation to prevent 401 errors
  Future<void> _validateTokenBeforeRequest(String path) async {
    try {
      log("🔍 Pre-validating token for request: $path");

      // Get token with immediate refresh if needed
      final validToken = await _authService.tokenRefreshManager
          .getValidAccessTokenWithImmediateRefresh();

      if (validToken == null) {
        log("❌ No valid token available for request: $path");
        throw Exception("No valid authentication token available");
      }

      // Log token status for debugging
      final timeUntilExpiry =
          JwtTokenUtility.getTimeUntilExpiration(validToken);
      log("✅ Token pre-validation successful for: $path (expires in ${timeUntilExpiry?.inMinutes ?? 'unknown'} minutes)");
    } catch (e) {
      log("❌ Token pre-validation failed for $path: $e");
      rethrow;
    }
  }

  /// Get the underlying Dio instance (for advanced usage)
  Dio get dio => _dio;
}
