import 'package:dio/dio.dart';

class DioSingleton {
  static final Dio instance1 = Dio(BaseOptions(baseUrl: 'http://13.200.100.161:8048/api'));
  // static final Dio instance2 = Dio(BaseOptions(baseUrl: 'http://13.233.71.222:8051'));
  static final Dio instance2 = Dio(BaseOptions(baseUrl: 'https://societybackend.cubeone.in'));
  static final Dio instance3 = Dio(BaseOptions(baseUrl: 'http://192.168.1.190'));
  //static final Dio instance3 = Dio(BaseOptions(baseUrl: 'http://gateapi.cubeone.biz'));
}

// Export the Dio instance
Dio get dioInstance1 => DioSingleton.instance1;
Dio get dioInstance2 => DioSingleton.instance2;
Dio get dioInstance3 => DioSingleton.instance3;
