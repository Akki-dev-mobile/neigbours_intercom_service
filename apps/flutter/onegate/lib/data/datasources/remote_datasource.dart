import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class RemoteDataSource {
  final Dio _dio1;
  final Dio _dio2;

  RemoteDataSource(this._dio1, this._dio2);

  Future<Map<String, dynamic>> loginUser(
      String username, String password, String method) async {
    try {
      final response = await _dio1.post('/saas/auth/sso',
          data: {'username': "91$username", 'otp': password, 'method': method});

      return response.data['data'];
    } catch (e) {
      print(e.toString());
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> fetchGates(int companyId) async {
    try {
      final queryParams = {
      'company_id': companyId.toString()
    };
      final response = await _dio2.get('/api/admin/gates/list',queryParameters: queryParams);
      print(response.data['data'].toString());
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw DioError(
            requestOptions: response.requestOptions,
            response: response,
            type: DioErrorType.response);
      }
    } catch (e) {
      print('Error fetching gates: $e');
      throw e;
    }
  }
}
