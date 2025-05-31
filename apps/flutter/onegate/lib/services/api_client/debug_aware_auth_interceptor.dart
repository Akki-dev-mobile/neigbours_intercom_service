import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/auth_service/auth_token_debug_manager.dart';
import 'package:get_it/get_it.dart';

/// Enhanced authentication interceptor with comprehensive debugging capabilities
class DebugAwareAuthInterceptor extends Interceptor {
  final AuthService _authService;
  final EnhancedTokenRefreshManager _tokenManager;
  final AuthTokenDebugManager _debugManager;
  
  // Request tracking for debugging
  final Map<String, RequestDebugInfo> _activeRequests = {};
  
  DebugAwareAuthInterceptor()
      : _authService = GetIt.I<AuthService>(),
        _tokenManager = GetIt.I<AuthService>().tokenRefreshManager,
        _debugManager = AuthTokenDebugManager();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final requestId = _generateRequestId();
      final debugInfo = RequestDebugInfo(
        requestId: requestId,
        method: options.method,
        path: options.path,
        startTime: DateTime.now(),
      );
      
      _activeRequests[requestId] = debugInfo;
      options.extra['request_id'] = requestId;
      options.extra['debug_start_time'] = debugInfo.startTime;

      log("🌐 [${debugInfo.requestId}] Starting ${options.method} ${options.path}");

      // Skip authentication for public endpoints
      if (_shouldSkipAuth(options.path)) {
        log("🔓 [${debugInfo.requestId}] Skipping auth for public endpoint");
        handler.next(options);
        return;
      }

      // Get and validate access token
      await _addAuthenticationToRequest(options, debugInfo);
      
      handler.next(options);
    } catch (e) {
      log("❌ Error in request interceptor: $e");
      handler.next(options);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final requestId = response.requestOptions.extra['request_id'] as String?;
      final debugInfo = requestId != null ? _activeRequests[requestId] : null;
      
      if (debugInfo != null) {
        debugInfo.endTime = DateTime.now();
        debugInfo.statusCode = response.statusCode;
        debugInfo.success = true;
        
        final duration = debugInfo.duration;
        log("✅ [${debugInfo.requestId}] ${response.requestOptions.method} ${response.requestOptions.path} "
            "→ ${response.statusCode} (${duration?.inMilliseconds}ms)");
        
        _activeRequests.remove(requestId);
      }
      
      handler.next(response);
    } catch (e) {
      log("❌ Error in response interceptor: $e");
      handler.next(response);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final requestId = err.requestOptions.extra['request_id'] as String?;
      final debugInfo = requestId != null ? _activeRequests[requestId] : null;
      
      if (debugInfo != null) {
        debugInfo.endTime = DateTime.now();
        debugInfo.statusCode = err.response?.statusCode;
        debugInfo.success = false;
        debugInfo.error = err.message;
      }

      log("❌ [${debugInfo?.requestId ?? 'unknown'}] ${err.requestOptions.method} ${err.requestOptions.path} "
          "→ ${err.response?.statusCode ?? 'no response'} - ${err.message}");

      // Handle authentication errors with retry
      if (err.response?.statusCode == 401) {
        final retryResponse = await _handleAuthenticationError(err, debugInfo);
        if (retryResponse != null) {
          log("✅ [${debugInfo?.requestId ?? 'unknown'}] Authentication retry successful");
          handler.resolve(retryResponse);
          return;
        }
      }

      if (requestId != null) {
        _activeRequests.remove(requestId);
      }
      
      handler.next(err);
    } catch (e) {
      log("❌ Error in error interceptor: $e");
      handler.next(err);
    }
  }

  /// Add authentication to request with comprehensive debugging
  Future<void> _addAuthenticationToRequest(RequestOptions options, RequestDebugInfo debugInfo) async {
    try {
      log("🔑 [${debugInfo.requestId}] Adding authentication to request");

      // Get valid access token with immediate refresh if needed
      final accessToken = await _tokenManager.getValidAccessTokenWithImmediateRefresh();
      
      if (accessToken != null) {
        // Validate token before use
        final isValid = JwtTokenUtility.isValidJwtToken(accessToken);
        final timeUntilExpiry = JwtTokenUtility.getTimeUntilExpiration(accessToken);
        
        debugInfo.tokenUsed = accessToken.substring(0, 20) + '...'; // First 20 chars for debugging
        debugInfo.tokenValid = isValid;
        debugInfo.tokenExpiryMinutes = timeUntilExpiry?.inMinutes;
        
        if (isValid) {
          options.headers['Authorization'] = 'Bearer $accessToken';
          log("✅ [${debugInfo.requestId}] Bearer token added (expires in ${timeUntilExpiry?.inMinutes ?? 'unknown'} minutes)");
          
          // Log token details in debug mode
          if (options.extra['debug_token'] == true) {
            _logTokenDetails(accessToken, debugInfo.requestId);
          }
        } else {
          log("⚠️ [${debugInfo.requestId}] Token is invalid, proceeding without authentication");
          debugInfo.authSkipped = true;
          debugInfo.authSkipReason = 'Invalid token';
        }
      } else {
        log("⚠️ [${debugInfo.requestId}] No valid access token available");
        debugInfo.authSkipped = true;
        debugInfo.authSkipReason = 'No token available';
      }
    } catch (e) {
      log("❌ [${debugInfo.requestId}] Error adding authentication: $e");
      debugInfo.authSkipped = true;
      debugInfo.authSkipReason = 'Error: $e';
    }
  }

  /// Handle 401 authentication errors with retry logic
  Future<Response?> _handleAuthenticationError(DioException error, RequestDebugInfo? debugInfo) async {
    try {
      log("🔄 [${debugInfo?.requestId ?? 'unknown'}] Handling 401 authentication error");
      
      // Attempt token refresh
      final refreshed = await _tokenManager.refreshTokenIfNeeded();
      
      if (refreshed) {
        log("✅ [${debugInfo?.requestId ?? 'unknown'}] Token refresh successful, retrying request");
        
        // Get the new token
        final newToken = await _tokenManager.getValidAccessToken();
        
        if (newToken != null) {
          // Retry the original request with new token
          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';
          
          // Update debug info
          if (debugInfo != null) {
            debugInfo.retryAttempted = true;
            debugInfo.retryTokenUsed = newToken.substring(0, 20) + '...';
          }
          
          // Create new Dio instance to avoid interceptor loops
          final dio = Dio();
          return await dio.fetch(retryOptions);
        }
      }
      
      log("❌ [${debugInfo?.requestId ?? 'unknown'}] Token refresh failed or no new token available");
      
      if (debugInfo != null) {
        debugInfo.retryAttempted = true;
        debugInfo.retryFailed = true;
      }
      
      return null;
    } catch (e) {
      log("❌ [${debugInfo?.requestId ?? 'unknown'}] Error handling authentication error: $e");
      return null;
    }
  }

  /// Check if authentication should be skipped for this path
  bool _shouldSkipAuth(String path) {
    final publicPaths = [
      '/health',
      '/status',
      '/public',
      '/auth/login',
      '/auth/register',
    ];
    
    return publicPaths.any((publicPath) => path.contains(publicPath));
  }

  /// Log detailed token information for debugging
  void _logTokenDetails(String token, String requestId) {
    try {
      final analysis = JwtTokenUtility.getTokenAnalysis(token);
      log("🔍 [${requestId}] Token Analysis:");
      log("  - Valid: ${analysis['isValid']}");
      log("  - Expires: ${analysis['expiresAt']}");
      log("  - Time until expiry: ${analysis['timeUntilExpiryMinutes']} minutes");
      log("  - Should refresh: ${analysis['shouldRefreshNow']}");
      log("  - Lifespan: ${analysis['lifespanMinutes']} minutes");
    } catch (e) {
      log("❌ [${requestId}] Error logging token details: $e");
    }
  }

  /// Generate unique request ID for debugging
  String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  }

  /// Get current active requests for debugging
  Map<String, RequestDebugInfo> get activeRequests => Map.from(_activeRequests);

  /// Get request statistics
  Map<String, dynamic> getRequestStatistics() {
    return {
      'activeRequests': _activeRequests.length,
      'totalRequests': _activeRequests.length, // This would be cumulative in a real implementation
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Debug information for individual requests
class RequestDebugInfo {
  final String requestId;
  final String method;
  final String path;
  final DateTime startTime;
  
  DateTime? endTime;
  int? statusCode;
  bool success = false;
  String? error;
  
  // Authentication debug info
  String? tokenUsed;
  bool? tokenValid;
  int? tokenExpiryMinutes;
  bool authSkipped = false;
  String? authSkipReason;
  
  // Retry debug info
  bool retryAttempted = false;
  bool retryFailed = false;
  String? retryTokenUsed;

  RequestDebugInfo({
    required this.requestId,
    required this.method,
    required this.path,
    required this.startTime,
  });

  /// Get request duration
  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  /// Get debug summary
  Map<String, dynamic> toDebugMap() {
    return {
      'requestId': requestId,
      'method': method,
      'path': path,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'statusCode': statusCode,
      'success': success,
      'error': error,
      'tokenUsed': tokenUsed,
      'tokenValid': tokenValid,
      'tokenExpiryMinutes': tokenExpiryMinutes,
      'authSkipped': authSkipped,
      'authSkipReason': authSkipReason,
      'retryAttempted': retryAttempted,
      'retryFailed': retryFailed,
      'retryTokenUsed': retryTokenUsed,
    };
  }
}
