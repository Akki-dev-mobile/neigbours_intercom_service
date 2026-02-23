import 'dart:developer';

import 'package:dio/dio.dart';

import '../services/auth_token_manager.dart';

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
    log('⬅️ [${clientTag}] ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('❌ [${clientTag}] ${err.message} ${err.requestOptions.uri}');
    handler.next(err);
  }
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final headers = await AuthTokenManager.getAuthHeaders();
    options.headers.addAll(headers);
    handler.next(options);
  }
}
