import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../services/auth_token_manager.dart';
import '../services/keycloak_service.dart';
import '../../src/config/intercom_module_config.dart';

class NetworkLoggingInterceptor extends Interceptor {
  final String clientTag;

  NetworkLoggingInterceptor({required this.clientTag});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('➡️ [${clientTag}] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log(
      '⬅️ [${clientTag}] ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('❌ [${clientTag}] ${err.message} ${err.requestOptions.uri}');
    handler.next(err);
  }
}

class AuthInterceptor extends Interceptor {
  static const String _retryKey = 'auth_retry';
  final Dio _dio;

  AuthInterceptor({required Dio dio}) : _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Do not refresh during request preparation.
    // 401 reactive path owns refresh+retry.
    final headers = await AuthTokenManager.getAuthHeadersNoRefresh();
    options.headers.addAll(headers);
    handler.next(options);
  }

  bool _isReplaySafe(RequestOptions options) {
    final data = options.data;
    if (data == null) return true;

    // We avoid automatic replay for potentially one-shot request bodies.
    // Non-replayable requests (for example upload streams/FormData) should
    // be retried by explicit caller logic.
    if (data is FormData) return false;
    if (data is Stream) return false;
    return true;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final alreadyRetried = err.requestOptions.extra[_retryKey] == true;
    if (alreadyRetried) {
      handler.next(err);
      return;
    }

    final requestOptions = err.requestOptions;
    final replaySafe = _isReplaySafe(requestOptions);

    try {
      final refreshed = await KeycloakService.refreshTokenIfNeeded();
      if (!refreshed) {
        final refreshValidity = await KeycloakService.getRefreshTokenValidity();
        if (refreshValidity == RefreshTokenValidity.expiredOrMissing &&
            IntercomModule.isConfigured) {
          await IntercomModule.config.authPort.onSessionExpired(
            reason: 'refresh_token_missing',
          );
          return;
        }
        handler.next(err);
        return;
      }

      if (!replaySafe) {
        log(
          '401 retry skipped: non-replayable request '
          '${requestOptions.method} ${requestOptions.uri}',
        );
        handler.next(err);
        return;
      }

      final headers = await AuthTokenManager.getAuthHeadersNoRefresh();
      final retryOptions = requestOptions.copyWith(
        headers: <String, dynamic>{...requestOptions.headers, ...headers},
        extra: <String, dynamic>{...requestOptions.extra, _retryKey: true},
      );

      // 401 retry owner: this interceptor is the single place that performs
      // refresh+retry. Other layers should not also replay failed requests.
      final response = await _dio.fetch(retryOptions);
      handler.resolve(response);
    } catch (e) {
      log('AuthInterceptor 401 retry failed: $e');
      try {
        final refreshValidity = await KeycloakService.getRefreshTokenValidity();
        if (refreshValidity == RefreshTokenValidity.expiredOrMissing &&
            IntercomModule.isConfigured) {
          await IntercomModule.config.authPort.onSessionExpired(
            reason: 'refresh_token_missing',
          );
          return;
        }
      } catch (_) {
        // If validity determination fails, treat as non-terminal here.
      }
      handler.next(err);
    }
  }
}
