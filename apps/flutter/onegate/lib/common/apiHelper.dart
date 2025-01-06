import 'package:dio/dio.dart';
import 'package:flutter_onegate/common/environment.dart';

class ApiHelper {
  final Dio dio = Dio();

  Future<Response> get(
      String url, {
        Map<String, dynamic>? queryParameters,
        Map<String, String>? headers,
      }) async {
    final combinedHeaders = headers ?? await Environment.getHeaders();
    return await dio.get(
      url,
      queryParameters: queryParameters,
      options: Options(headers: combinedHeaders),
    );
  }

  Future<Response> post(
      String url, {
        Map<String, dynamic>? data,
        Map<String, String>? headers,
      }) async {
    final combinedHeaders = headers ?? await Environment.getHeaders();
    return await dio.post(
      url,
      data: data,
      options: Options(headers: combinedHeaders),
    );
  }

  Future<Response> patch(
      String url, {
        Map<String, dynamic>? data,
        Map<String, String>? headers,
      }) async {
    final combinedHeaders = headers ?? await Environment.getHeaders();
    return await dio.patch(
      url,
      data: data,
      options: Options(headers: combinedHeaders),
    );
  }

  Future<Response> uploadFile(
      String url, {
        required FormData data,
        Map<String, String>? headers,
      }) async {
    final combinedHeaders = headers ?? await Environment.getHeaders();
    return await dio.post(
      url,
      data: data,
      options: Options(headers: combinedHeaders, contentType: 'multipart/form-data'),
    );
  }
}