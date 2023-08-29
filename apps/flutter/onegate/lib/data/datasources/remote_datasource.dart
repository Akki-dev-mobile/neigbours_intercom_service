import 'package:dio/dio.dart';

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
}
