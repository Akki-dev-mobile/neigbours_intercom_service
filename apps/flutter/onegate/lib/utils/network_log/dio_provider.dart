import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'network_log_manager.dart';

/// A provider for Dio instances with network logging capabilities
class DioProvider {
  static final DioProvider _instance = DioProvider._internal();

  factory DioProvider() {
    return _instance;
  }

  DioProvider._internal();

  /// Get a Dio instance with network logging interceptor
  Dio getDio() {
    // Try to get the Dio instance from GetIt
    Dio dio;
    try {
      dio = GetIt.I<Dio>();
    } catch (e) {
      // If not registered, create a new one
      dio = Dio();

      // Add default configurations if needed
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);
    }

    // Add the network logger interceptor if in debug mode
    if (kDebugMode) {
      // Check if the interceptor is already added
      final hasInterceptor = dio.interceptors.any(
          (i) => i.runtimeType.toString().contains('NetworkLoggerInterceptor'));
      if (!hasInterceptor) {
        NetworkLogManager().addInterceptorToDio(dio);
      }
    }

    return dio;
  }
}
