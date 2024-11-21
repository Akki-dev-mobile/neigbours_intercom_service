import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

var client = Client('https://onegate.cubeone.in/')
  ..connectivityMonitor = FlutterConnectivityMonitor();

final keycloakConfig = KeycloakConfig(
  bundleIdentifier: 'com.example.keyclockflutter',
  clientId: 'onegate-sso',
  frontendUrl: 'https://stgsso.cubeone.in',
  realm: 'fstech',
  clientSecret: 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58',
);
final keycloakWrapper = KeycloakWrapper(config: keycloakConfig);

class RemoteDataSource {
  final Dio _dio1;
  final Dio _dio2;
  final Dio _dio3;
  RemoteDataSource(
    this._dio1,
    this._dio2,
    this._dio3,
  );

  Future<Map<String, dynamic>> loginUser() async {
    try {
      // Step 1: Login using Keycloak Wrapper
      bool isLoggedIn = await keycloakWrapper.login();

      // Step 2: Check if login was successful and access token is available
      if (isLoggedIn && keycloakWrapper.accessToken != null) {
        log('Keycloak login successful. Access Token: ${keycloakWrapper.accessToken}');

        // Step 3: Use Keycloak access token to call your backend API
        final response = await _dio2.post(
          '/api/gatelogin',
          options: Options(
            headers: {
              'Authorization': 'Bearer ${keycloakWrapper.accessToken}',
              'Content-Type': 'application/json',
            },
          ),
        );

        // Step 4: Handle the response
        if (response.statusCode == 200) {
          var data = response.data['data'];
          log('Login response: $data');
          return data;
        } else {
          throw Exception('Failed to log in: ${response.statusCode}');
        }
      } else {
        throw Exception('Keycloak login failed.');
      }
    } catch (e) {
      log('Error during login: $e');
      return {};
    }
  }

  Future<List<dynamic>> fetchGates(int companyId) async {
    try {
      final queryParams = {'company_id': companyId};
      final response = await _dio2.get(
        'http://192.168.1.34:8000/api/admin/companies/list/$companyId',
      );
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

  //   try {
  //     final response = await _dio2.get('/api/admin/building/list',
  //         queryParameters: {'company_id': companyId});
  //
  //     // Check if response data is null
  //     if (response.data != null) {
  //       return response.data['data'];
  //     } else {
  //       print('Response data is null');
  //       return [];
  //     }
  //   } catch (e) {
  //     print('Error fetching buildings: $e');
  //     rethrow;
  //   }
  // }

  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      // final result = await client.visitor.fetchVisitor(mobileNumber);
      // print("searchVisitor: ${result.toString()}");
      // return result!;

      final result = await client.visitor.fetchVisitor(mobileNumber);
      if (result != null) {
        print("searchVisitor: ${result.toString()}");
        return result;
      } else {
        print("No visitor found for mobile number: $mobileNumber");
        return null;
      }
    } catch (e) {
      print('Error fetching visitor: $e');
    }
    return null;
  }

  Future<List<PurposeCategory>?> fetchPurpose() async {
    try {
      final result = await client.purposeCategory.fetchPurposeCategory();
      print("fetchPurpose: ${result.toString()}");
      return result.reversed.toList();
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<Visitor?> createVisitor(Visitor visitor) async {
    try {
      final result = await client.visitor.createVisitor(visitor);
      print("createVisitor: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<BuildingAssignment?> createBuildingAssignment(
      BuildingAssignment buildingAssignment) async {
    try {
      final result =
          await client.visitorLog.createBuildingAssignment(buildingAssignment);
      print("createBuildingAssignment: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<VisitorLog?> checkIn(VisitorLog visitorLog) async {
    try {
      final result = await client.visitorLog.createVisitorLog(visitorLog);
      for (BuildingAssignment buildingAssignment
          in visitorLog.visitor_building_assignment!) {
        buildingAssignment.visitor_log_id = result.id;
        await createBuildingAssignment(buildingAssignment);
      }
      print("checkIn: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getBuilding(int companyId) async {
    try {
      final response = await _dio2.get(
          'https://societybackend.cubeone.in/api/admin/building/list',
          queryParameters: {'company_id': companyId});
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMemberUnit(int? companyId, int? buildingId) async {
    try {
      final response = await _dio2.get(
          'https://societybackend.cubeone.in/api/admin/units/list',
          queryParameters: {
            'company_id': companyId,
            'building_id': buildingId,
            'per_page': 1000
          });
      return response.data['data'];
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMember(int companyId, int unitId) async {
    try {
      final response = await _dio2.get(
          'https://societybackend.cubeone.in/api/admin/member/list',
          queryParameters: {
            'company_id': companyId,
            'unit_id': unitId,
            'current_tab': 'approved'
          });
      return response.data['data'];
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchAllLogs(int companyId, String dateTime) async {
    try {
      final visitor_log = await client.visitorLog.fetchAllLogs(dateTime);
      return visitor_log.reversed.toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching buildings: $e');
      }
      rethrow;
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchCheckInLogs(
      int companyId, String dateTime) async {
    try {
      final visitor_log = await client.visitorLog.fetchCheckInLogs(dateTime);
      return visitor_log.reversed.toList();
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchCheckOutLogs(
      int companyId, String dateTime) async {
    try {
      final visitor_log = await client.visitorLog.fetchCheckOutLogs(dateTime);
      return visitor_log.reversed.toList();
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<bool> checkOut(VisitorLog visitorLog) async {
    try {
      final result = await client.visitorLog.checkOut(visitorLog);
      print("checkOut: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return false;
  }

  Future<bool> updateVisitor(Visitor visitor) async {
    try {
      final result = await client.visitor.updateVisitor(visitor);
      print("visitor update: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return false;
  }

  Future<String> uploadFile(File file, String userMobile, int companyId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/$userMobile.jpg');
      await file.copy(localFile.path);
      print('Image saved locally at: ${localFile.path}');
      return localFile.path;
    } catch (e) {
      print('Failed to save image locally: $e');
      return '';
    }

    // try {
    //   print('File path: ${file.path}');
    //
    //   var data = FormData.fromMap({
    //     'file': await MultipartFile.fromFile(file.path,
    //         filename: '$userMobile.jpg'),
    //     'service_id': '5',
    //     'company_id': '412',
    //     'uuid': userMobile,
    //     'path': 'test/onegate/image'
    //   });
    //
    //   Options options = Options(
    //     contentType: 'multipart/form-data',
    //   );
    //
    //   var dio = Dio();
    //   var response = await dio.request(
    //     'http://192.168.1.135:8088/api/file-upload',
    //     options: Options(
    //       method: 'POST',
    //       contentType: 'multipart/form-data',
    //       headers: {'Content-Type': 'multipart/form-data'},
    //     ),
    //     data: data,
    //   );
    //
    //   if (response.statusCode == 200) {
    //     print(json.encode(response.data));
    //     return response.data['data'];
    //   } else {
    //     print(response.statusMessage);
    //     return '';
    //   }
    // } catch (e) {
    //   print('Error uploading image: $e');
    //   rethrow;
    // }
  }

  Future<List<dynamic>> getUnitsList(int companyId) async {
    try {
      final response =
          await _dio2.get('/api/admin/units/list', queryParameters: {
        'company_id': companyId,
      });
      print("Units List: ${response.data['data']}");
      return response.data['data'] ?? [];
    } catch (e) {
      print('Error fetching units list: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getBuildingsList(int companyId) async {
    try {
      final response =
          await _dio2.get('/api/admin/building/list', queryParameters: {
        'company_id': companyId,
      });
      print("Buildings List: ${response.data['data']}");
      return response.data['data'] ?? [];
    } catch (e) {
      print('Error fetching buildings list: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMembersList(int companyId) async {
    try {
      final response =
          await _dio2.get('/api/admin/member/list', queryParameters: {
        'company_id': companyId,
      });
      print("Members List: ${response.data['data']}");
      return response.data['data'] ?? [];
    } catch (e) {
      print('Error fetching members list: $e');
      rethrow;
    }
  }

  Future<String?> sendOTP(String mobileNumber) async {
    try {
      final response = await _dio1.get('/sms/verification-code',
          queryParameters: {'phoneNumber': '91$mobileNumber'});
      print(response.data['data'].toString());
      if (response.statusCode == 200) {
        return response.data['data']['expires_in'];
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    try {
      final response = await _dio1.post('/sms/verify',
          data: {'phoneNumber': '91$mobileNumber', "otp": otp});
      if (kDebugMode) {
        print(response.data['data'].toString());
      }
      if (response.statusCode == 200) {
        return response.data['message'];
      }
    } catch (e) {
      return e.toString();
    }
  }
}
