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
  int? user_Id;

  RemoteDataSource(this._dio1, this._dio2, this._dio3);

  /// Utility method for error handling
  void _logError(String message, Object error) {
    log('$message: $error');
    if (kDebugMode) {
      print('$message: $error');
    }
  }

  /// Login user using Keycloak
  Future<Map<String, dynamic>?> loginUser() async {
    try {
      await keycloakWrapper.initialize();
      final isLoggedIn = await keycloakWrapper.login();

      if (isLoggedIn && keycloakWrapper.accessToken != null) {
        log('Login successful. Access Token: ${keycloakWrapper.accessToken}');
        final userInfo = await keycloakWrapper.getUserInfo();
        log('User Info: $userInfo');
        user_Id =
            int.tryParse(userInfo?['old_sso_user_id']?.toString() ?? '0') ?? 0;
        return userInfo;
      } else {
        throw Exception('Login failed. Access token is null.');
      }
    } catch (e) {
      _logError('Error during login', e);
      rethrow;
    }
  }

  /// Fetch list of gates
  Future<List<dynamic>> fetchGates(int userId) async {
    try {
      final response = await _dio2.get(
        'http://192.168.1.34:8000/api/admin/companies/list/$user_Id',
      );
      if (response.statusCode == 200) {
        return response.data['data'] ?? [];
      } else {
        throw Exception('Failed to fetch gates.');
      }
    } catch (e) {
      _logError('Error fetching gates', e);
      rethrow;
    }
  }

  /// Fetch visitor by mobile number
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final result = await client.visitor.fetchVisitor(mobileNumber);
      log("Visitor fetched: $result");
      return result;
    } catch (e) {
      _logError('Error fetching visitor', e);
      return null;
    }
  }

  /// Fetch purpose categories
  Future<List<PurposeCategory>?> fetchPurpose() async {
    try {
      final result = await client.purposeCategory.fetchPurposeCategory();
      return result?.reversed.toList();
    } catch (e) {
      _logError('Error fetching purposes', e);
      return null;
    }
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

  Future<List<VisitorLog>> fetchCheckInLogs(
      int companyId, String dateTime) async {
    try {
      final visitorLog = await client.visitorLog.fetchCheckInLogs(dateTime);
      return visitorLog.reversed.toList();
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
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
      final visitorLog = await client.visitorLog.fetchAllLogs(dateTime);
      return visitorLog.reversed.toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching buildings: $e');
      }
      rethrow;
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

  Future<List<VisitorLog>> fetchCheckOutLogs(
      int companyId, String dateTime) async {
    try {
      final visitorLog = await client.visitorLog.fetchCheckOutLogs(dateTime);
      return visitorLog.reversed.toList();
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

  /// Upload file
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
  }

  /// Generic method to fetch data
  Future<List<dynamic>> fetchData(String endpoint,
      {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio2.get(endpoint, queryParameters: queryParams);
      return response.data['data'] ?? [];
    } catch (e) {
      _logError('Error fetching data from $endpoint', e);
      rethrow;
    }
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

  /// Fetch buildings for a company
  Future<List<dynamic>> getBuildingsList(int companyId) async {
    return await fetchData('/api/admin/building/list', queryParams: {
      'company_id': companyId,
    });
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

  /// Send OTP
  Future<String?> sendOTP(String mobileNumber) async {
    try {
      final response = await _dio1.get('/sms/verification-code',
          queryParameters: {'phoneNumber': '91$mobileNumber'});
      if (response.statusCode == 200) {
        return response.data['data']['expires_in'];
      } else {
        throw Exception('Failed to send OTP.');
      }
    } catch (e) {
      _logError('Error sending OTP', e);
      return null;
    }
  }

  /// Verify OTP
  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    try {
      final response = await _dio1.post('/sms/verify', data: {
        'phoneNumber': '91$mobileNumber',
        'otp': otp,
      });
      if (response.statusCode == 200) {
        return response.data['message'];
      } else {
        throw Exception('Failed to verify OTP.');
      }
    } catch (e) {
      _logError('Error verifying OTP', e);
      return null;
    }
  }
}
