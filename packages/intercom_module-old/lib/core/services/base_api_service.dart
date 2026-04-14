import 'package:dio/dio.dart';

import '../models/api_response.dart';
import '../network/network_interceptors.dart';

abstract class BaseApiService {
  late final Dio _dio;
  final String baseUrl;
  final String serviceName;

  BaseApiService({
    required this.baseUrl,
    required this.serviceName,
    Map<String, dynamic>? defaultHeaders,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout ?? const Duration(seconds: 30),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?defaultHeaders,
        },
      ),
    );

    _dio.interceptors.add(NetworkLoggingInterceptor(clientTag: serviceName));
    // Single 401 retry owner is AuthInterceptor.
    // BaseApiService must not duplicate replay behavior.
    _dio.interceptors.add(AuthInterceptor(dio: _dio));
  }

  Future<Map<String, String>> getAuthHeaders() async {
    // Kept for backward compatibility with subclasses/legacy call-sites.
    // AuthInterceptor injects headers during requests.
    return <String, String>{};
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Map<String, String>? headers,
    Options? options,
  }) async {
    return _handleRequest<T>(
      () => _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: options ?? Options(headers: headers),
      ),
      fromJson,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Map<String, String>? headers,
    Options? options,
  }) async {
    final mergedOptions = (options ?? Options()).copyWith(
      headers: {...?options?.headers, ...?headers},
    );
    return _handleRequest<T>(
      () => _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: mergedOptions,
      ),
      fromJson,
    );
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Map<String, String>? headers,
    Options? options,
  }) async {
    final mergedOptions = (options ?? Options()).copyWith(
      headers: {...?options?.headers, ...?headers},
    );
    return _handleRequest<T>(
      () => _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: mergedOptions,
      ),
      fromJson,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Map<String, String>? headers,
    Options? options,
  }) async {
    final mergedOptions = (options ?? Options()).copyWith(
      headers: {...?options?.headers, ...?headers},
    );
    return _handleRequest<T>(
      () => _dio.delete(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: mergedOptions,
      ),
      fromJson,
    );
  }

  Future<ApiResponse<T>> _handleRequest<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic)? fromJson,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse.fromJson(data, fromJson);
      }
      return ApiResponse.success(
        fromJson != null ? fromJson(data) : data as T?,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}
