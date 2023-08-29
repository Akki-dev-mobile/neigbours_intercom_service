import 'package:dio/dio.dart';

class DioSingleton {
  static final Dio instance = Dio(BaseOptions(baseUrl: 'https://api.cubeonebiz.com'));
}

// Export the Dio instance
Dio get dioInstance => DioSingleton.instance;