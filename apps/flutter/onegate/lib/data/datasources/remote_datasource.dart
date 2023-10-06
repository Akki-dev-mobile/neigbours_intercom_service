import 'package:dio/dio.dart';

class RemoteDataSource {
  final Dio _dio1;
  final Dio _dio2;
  final Dio _dio3;

  RemoteDataSource(this._dio1, this._dio2, this._dio3);

  Future<Map<String, dynamic>> loginUser(
      String username, String password, String method) async {
    try {
      final response = await _dio1.post('/login',
          data: {'username': "91$username", 'password': password});

      return response.data['data'];
    } catch (e) {
      print(e.toString());
    }
    return {};
  }

  Future<List<dynamic>> fetchGates(int companyId) async {
    try {
      final queryParams = {'company_id': companyId};
      final response = await _dio2.get('/api/admin/gates/list',
          queryParameters: queryParams);
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
      rethrow;
    }
  }

  Future<Map<String, dynamic>> searchVisitor(
      String mobileNumber, String accessToken, int companyId) async {
    try {
      final response = await _dio3.post('/api/v1/global/vpasses', data: {
        "access_token": accessToken,
        "unit_id": companyId,
        "mobile": "91$mobileNumber",
        "iso_code": "IN",
        "paginate": 0
      });

      return response.data['data'];
    } catch (e) {
      print(e.toString());
    }
    return {};
  }
}
