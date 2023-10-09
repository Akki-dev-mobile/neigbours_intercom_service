import 'package:dio/dio.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

var client = Client('http://localhost:8080/')
  ..connectivityMonitor = FlutterConnectivityMonitor();
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

  Future<Visitor?> searchVisitor(
      String mobileNumber) async {
    try {
      final result = await client.visitor.fetchVisitor(mobileNumber);
      return result!;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<List<PurposeCategory>?> fetchPurpose() async {
    try {
      final result = await client.purposeCategory.fetchPurposeCategory();
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }
}
