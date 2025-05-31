import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/persistent_authentication_manager.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:get_it/get_it.dart';

/// Enhanced API client that automatically handles persistent authentication
/// Ensures all API calls use valid tokens without user intervention
class PersistentAuthenticatedApiClient {
  static final PersistentAuthenticatedApiClient _instance = 
      PersistentAuthenticatedApiClient._internal();
  factory PersistentAuthenticatedApiClient() => _instance;
  PersistentAuthenticatedApiClient._internal();

  late final Dio _dio;
  late final AuthService _authService;
  late final PersistentAuthenticationManager _persistentAuth;
  late final EnhancedTokenRefreshManager _tokenManager;

  bool _isInitialized = false;

  /// Initialize the persistent authenticated API client
  Future<void> initialize({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) async {
    if (_isInitialized) return;

    try {
      log("🚀 Initializing Persistent Authenticated API Client");

      // Initialize dependencies
      _authService = GetIt.I<AuthService>();
      _persistentAuth = PersistentAuthenticationManager();
      _tokenManager = _authService.tokenRefreshManager;

      // Initialize persistent authentication
      await _persistentAuth.initialize();

      // Configure Dio
      _dio = Dio(BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout ?? const Duration(seconds: 30),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        sendTimeout: sendTimeout ?? const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      // Add interceptors
      _addInterceptors();

      _isInitialized = true;
      log("✅ Persistent Authenticated API Client initialized successfully");
    } catch (e) {
      log("❌ Error initializing Persistent Authenticated API Client: $e");
      rethrow;
    }
  }

  /// Add interceptors for automatic authentication and token management
  void _addInterceptors() {
    // Request interceptor - automatically add valid token to requests
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _addAuthenticationToRequest(options);
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logSuccessfulRequest(response);
        handler.next(response);
      },
      onError: (error, handler) async {
        final retryResponse = await _handleApiError(error);
        if (retryResponse != null) {
          handler.resolve(retryResponse);
        } else {
          handler.next(error);
        }
      },
    ));

    // Logging interceptor
    _dio.interceptors.add(LogInterceptor(
      requestBody: false, // Don't log request body for security
      responseBody: false, // Don't log response body for performance
      logPrint: (object) => log("🌐 API: $object"),
    ));
  }

  /// Automatically add authentication to API requests
  Future<void> _addAuthenticationToRequest(RequestOptions options) async {
    try {
      // Get valid access token (automatically refreshed if needed)
      final accessToken = await _getValidAccessToken();
      
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
        log("🔐 Added authentication to ${options.method} ${options.path}");
      } else {
        log("⚠️ No valid access token available for ${options.method} ${options.path}");
      }
    } catch (e) {
      log("❌ Error adding authentication to request: $e");
    }
  }

  /// Get valid access token with automatic refresh
  Future<String?> _getValidAccessToken() async {
    try {
      // First, try to get token from enhanced token manager
      final token = await _tokenManager.getValidAccessTokenWithImmediateRefresh();
      
      if (token != null) {
        // Validate token is not expiring soon
        if (!JwtTokenUtility.isTokenExpiredOrExpiring(token, buffer: const Duration(minutes: 2))) {
          return token;
        }
      }

      // If token is null or expiring soon, force refresh
      log("🔄 Token expiring soon or null, forcing refresh");
      final refreshed = await _tokenManager.refreshTokenIfNeeded();
      
      if (refreshed) {
        return await _tokenManager.getValidAccessToken();
      }

      log("❌ Unable to obtain valid access token");
      return null;
    } catch (e) {
      log("❌ Error getting valid access token: $e");
      return null;
    }
  }

  /// Handle API errors with automatic retry for authentication failures
  Future<Response?> _handleApiError(DioException error) async {
    try {
      // Handle 401 Unauthorized errors
      if (error.response?.statusCode == 401) {
        log("🔄 Received 401 Unauthorized, attempting token refresh and retry");
        
        // Attempt to refresh token
        final refreshed = await _tokenManager.refreshTokenIfNeeded();
        
        if (refreshed) {
          // Retry the original request with new token
          final retryOptions = error.requestOptions;
          await _addAuthenticationToRequest(retryOptions);
          
          log("🔄 Retrying request with refreshed token");
          return await _dio.fetch(retryOptions);
        } else {
          log("❌ Token refresh failed for 401 error");
        }
      }

      // Handle other authentication-related errors
      if (_isAuthenticationError(error)) {
        log("🚫 Authentication error detected: ${error.response?.statusCode}");
        // Let the persistent authentication manager handle this
      }

      return null;
    } catch (e) {
      log("❌ Error handling API error: $e");
      return null;
    }
  }

  /// Check if error is authentication-related
  bool _isAuthenticationError(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  /// Log successful API requests
  void _logSuccessfulRequest(Response response) {
    final duration = response.requestOptions.extra['request_start_time'] != null
        ? DateTime.now().difference(response.requestOptions.extra['request_start_time'])
        : null;
    
    log("✅ ${response.requestOptions.method} ${response.requestOptions.path} "
        "→ ${response.statusCode} ${duration != null ? '(${duration.inMilliseconds}ms)' : ''}");
  }

  /// Make GET request with automatic authentication
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    _ensureInitialized();
    
    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Make POST request with automatic authentication
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    _ensureInitialized();
    
    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Make PUT request with automatic authentication
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    _ensureInitialized();
    
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Make DELETE request with automatic authentication
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureInitialized();
    
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make PATCH request with automatic authentication
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    _ensureInitialized();
    
    return await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Ensure the client is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('PersistentAuthenticatedApiClient must be initialized before use');
    }
  }

  /// Get current authentication status
  Map<String, dynamic> getAuthenticationStatus() {
    return {
      'isInitialized': _isInitialized,
      'persistentAuthStatus': _persistentAuth.getPersistentAuthStatus(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    try {
      log("🗑️ Disposing Persistent Authenticated API Client");
      
      _dio.close();
      _isInitialized = false;
      
      log("✅ Persistent Authenticated API Client disposed");
    } catch (e) {
      log("❌ Error disposing Persistent Authenticated API Client: $e");
    }
  }
}
