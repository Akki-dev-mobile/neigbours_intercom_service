import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/utils/token_refresh_util.dart';
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
  late final GateStorage _gateStorage;
  late final AuthService _authService;

  bool _isInitialized = false;

  /// Initialize the API client
  Future<void> initialize() async {
    if (_isInitialized) return;

    _dio = Dio();
    _gateStorage = GetIt.I<GateStorage>();
    _authService = GetIt.I<AuthService>();

    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // Add interceptors
    _dio.interceptors.add(_createAuthInterceptor());
    _dio.interceptors.add(_createLoggingInterceptor());
    _dio.interceptors.add(_createErrorInterceptor());

    _isInitialized = true;
    log("✅ AuthenticatedApiClient initialized");
  }

  /// Create authentication interceptor
  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          // Get valid access token (automatically refreshes if needed)
          final accessToken = await _authService.getValidAccessToken();

          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
            log("🔑 Added Bearer token to request: ${options.path}");
          } else {
            log("⚠️ No valid access token available for request: ${options.path}");
          }

          // Add default headers
          options.headers['Content-Type'] = 'application/json';
          options.headers['Accept'] = 'application/json';
        } catch (e) {
          log("❌ Error adding auth headers: $e");
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized errors
        if (error.response?.statusCode == 401) {
          log("🔄 Received 401, attempting token refresh...");

          try {
            final refreshed = await _authService.refreshToken();
            if (refreshed) {
              // Retry the original request with new token
              final newToken = await _authService.getValidAccessToken();
              if (newToken != null) {
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newToken';

                // Retry the request
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              }
            }
          } catch (e) {
            log("❌ Token refresh failed: $e");
          }

          // If refresh failed, redirect to login
          log("🚪 Token refresh failed, user needs to re-authenticate");
          // You can emit an event here to redirect to login screen
        }

        handler.next(error);
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

  /// Make authenticated GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    await _ensureInitialized();

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

  /// Get the underlying Dio instance (for advanced usage)
  Dio get dio => _dio;
}
