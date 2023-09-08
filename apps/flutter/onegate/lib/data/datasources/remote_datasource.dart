import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class RemoteDataSource {
  final Dio _dio;

  RemoteDataSource(this._dio);

  Future<Map<String, dynamic>> loginUser(String username, String password, String method) async {
  try{
     final response = await _dio.post('/saas/auth/sso', data: {
      'username': "91$username",
      'otp': password,
      'method': method
    });

    return response.data['data'];
  }catch(e){
    print(e.toString());
  }
  return {};
  }

  Future<Map<String, dynamic>> fetchGatesData(int companyId, int userId) async {
  final String jsonText = await rootBundle.loadString('assets/gates_data.json');
  final Map<String,dynamic>jsonData = json.decode(jsonText);
  return jsonData;
}
}
