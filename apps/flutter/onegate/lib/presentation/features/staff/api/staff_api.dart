import 'dart:developer';

import 'package:dio/dio.dart';

class StaffApi {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://societybackend.cubeone.in/api/',
    connectTimeout: 5000,
    receiveTimeout: 5000,
  ));

  Future<List<dynamic>> fetchStaffList(String companyId) async {
    log('Staff list ');

    try {
      final response = await _dio.get(
        'admin/staffs/staffLists',
        queryParameters: {'company_id': companyId},
      );
      if (response.statusCode == 200) {
        log("api full body with params: https://socbackend.cubeone.in/api/admin/staffs/staffLists?company_id=$companyId");
        log('Staff list fetched successfully');
        log('Staff list: ${response.data['data']}');
        return response.data['data']; // Return list of staff
      } else {
        throw Exception('Failed to fetch staff list');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
