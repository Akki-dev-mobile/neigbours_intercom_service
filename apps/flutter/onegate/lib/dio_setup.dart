import 'package:dio/dio.dart';

class DioSingleton {
  static final Dio instance1 = Dio(BaseOptions(baseUrl: 'https://api.cubeonebiz.com'));
  static final Dio instance2 = Dio(BaseOptions(baseUrl: 'http://35.154.204.205:8051'));

}

// Export the Dio instance
Dio get dioInstance1 => DioSingleton.instance1;
Dio get dioInstance2 => DioSingleton.instance2;