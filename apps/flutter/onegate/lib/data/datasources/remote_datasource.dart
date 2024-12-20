import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

var client = Client('https://onegate.cubeone.in/')
  ..connectivityMonitor = FlutterConnectivityMonitor();

final keycloakConfig = KeycloakConfig(
  bundleIdentifier: 'com.example.keyclockflutter',
  clientId: 'onegate-sso',
  frontendUrl: 'http://stgsso.cubeone.in',
  realm: 'fstech',
  clientSecret: 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58',
);
final keycloakWrapper = KeycloakWrapper(config: keycloakConfig);

class RemoteDataSource {
  final Dio? _dio1;
  final Dio? _dio2;
  final Dio? _dio3;

  RemoteDataSource(
    this._dio1,
    this._dio2,
    this._dio3,
  );

  final gateStorage = GateStorage();

  Future<Map<String, dynamic>> loginUser() async {
    try {
      bool isLoggedIn = await keycloakWrapper.login();

      if (isLoggedIn && keycloakWrapper.accessToken != null) {
        log('Keycloak login successful. Access Token: ${keycloakWrapper.accessToken}');

        final response = await _dio2?.post(
          '/api/gatelogin',
          options: Options(
            headers: {
              'Authorization': 'Bearer ${keycloakWrapper.accessToken}',
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response?.statusCode == 200) {
          var data = response?.data?['data'];
          log('Login response: $data');
          return data;
        } else {
          throw Exception('Failed to log in: ${response?.statusCode}');
        }
      } else {
        throw Exception('Keycloak login failed.');
      }
    } catch (e) {
      log('Error during login: $e');
      return {};
    }
  }

  Future<List<dynamic>> fetchGates(int societyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      log("here i am2 ${gateStorage.getSocietyId()}");
      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }

      final queryParams = {
        'company_id': await gateStorage.getSocietyId(),
      };

      final response = await Dio().get(
        'https://gateapi.cubeone.in/api/admin/gates',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to load gates: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching gates: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchSocieties(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }
      print(
        'https://gateapi.cubeone.in/api/admin/companies/$userId',
      );
      final response = await Dio().get(
        'https://gateapi.cubeone.in/api/admin/companies/$userId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        log('Societies fetched: ${response.data?['data']}');

        return response.data?['data'];
      } else {
        throw Exception(
            'Failed to load societies fetchSocieties: ${response.statusCode}');
      }
    } catch (e) {
      log('Error in fetchSocieties: $e');
      rethrow;
    }
  }

  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
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
      print("createVisitor remote_datasrc ::: $result");

      if (result != null && result.id != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('visitorId', result.id!.toString());
        print("Visitor ID stored in SharedPreferences: ${result.id}");
      }

      return result;
    } catch (e) {
      print("Error creating visitor: ${e.toString()}");
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
    print("Attempting check-in...");
    try {
      print("VisitorLog Data: ${visitorLog.toJson()}");

      final result = await client.visitorLog.createVisitorLog(visitorLog);
      print("VisitorLog created: ${result.toJson()}");
      if (visitorLog.visitor_building_assignment != null) {
        print("Building Assignment found");
        for (BuildingAssignment buildingAssignment
            in visitorLog.visitor_building_assignment!) {
          buildingAssignment.visitor_log_id = result.id;

          print("Creating BuildingAssignment: ${buildingAssignment.toJson()}");
          await createBuildingAssignment(buildingAssignment);
        }
      } else {
        print("No building assignment found");
      }
      GlobalStorage.visitorLogId = result.id.toString();

      print("Check-in successful: ${result.toString()}");
      return result;
    } on ServerpodClientException catch (e) {
      print("Failed call: ${e.message}");
      print("Call log ID: ${e.message}");
      print("Status Code: ${e.statusCode}");
    } catch (e) {
      print("Unexpected error during check-in: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getBuilding(int companyId) async {
    try {
      final userId = gateStorage.getSocietyId();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final response = await _dio2?.get(
        'http://societybackend.cubeone.in/api/admin/building/list',
        queryParameters: {'company_id': userId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      return List<Map<String, dynamic>>.from(response?.data['data']);
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMemberUnit(int? companyId, int? buildingId) async {
    try {
      final companyDetails = await gateStorage.getSocietyDetails();
      final companyId = companyDetails['company_id'];

      if (companyId == null) {
        throw Exception(
            "Company ID is null. Please ensure the society is selected.");
      }

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }
      final response = await _dio2?.get(
        'http://societybackend.cubeone.in/api/admin/units/list',
        queryParameters: {
          'company_id': companyId,
          'building_id': buildingId,
          'per_page': 1000
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      return response?.data?['data'];
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMember(
    int companyId,
  ) async {
    try {
      final userId = gateStorage.getSocietyId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }
      final response = await _dio2?.get(
        'http://societybackend.cubeone.in/api/admin/member/list',
        queryParameters: {
          'company_id': userId,
          // 'unit_id': unitId,
          'current_tab': 'approved'
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      return response?.data?['data'];
    } catch (e) {
      print('Error fetching members: $e');
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchAllLogs(int companyId, String dateTime) async {
    try {
      final visitorLog = await client.visitorLog.fetchAllLogs(dateTime);
      return visitorLog.reversed.toList();
    } catch (e) {
      if (kDebugMode) {
        print('client.visitorLog.fetchAllLogs $e');
      }
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchCheckInLogs(
      int companyId, String dateTime) async {
    try {
      final visitorLog = await client.visitorLog.fetchCheckInLogs(dateTime);
      return visitorLog.reversed.toList();
    } catch (e) {
      print('visitorLog.fetchCheckInLogs $e');
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchCheckOutLogs(
      int companyId, String dateTime) async {
    try {
      final visitorLog = await client.visitorLog.fetchCheckOutLogs(dateTime);
      return visitorLog.reversed.toList();
    } catch (e) {
      print('Eclient.visitorLog.fetchCheckOutLogs $e');
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

  Future<String?> uploadFile(
      File file, String userMobile, int companyId) async {
    try {
      log('File path: ${file.path}');

      var data = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: '$userMobile.jpg',
        ),
        'company_id': '$companyId',
        'uuid': userMobile,
        'path': file.path,
      });

      var dio = Dio();
      var response = await dio.post(
        'http://35.154.173.226:8005/api/visitor/uploadFile',
        data: data,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 200) {
        log('Successfully uploaded: ${json.encode(response.data)}');

        var filePath = response.data['data']?['file_path'];
        if (filePath != null && filePath is String) {
          return filePath;
        } else {
          log('Unexpected response format: ${response.data}');
          return '';
        }
      } else {
        log('Upload failed: ${response.statusMessage}');
        return '';
      }
    } catch (e) {
      log('Error uploading image: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getUnitsList(int companyId) async {
    try {
      final userId = gateStorage.getSocietyId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final response =
          await _dio2?.get('/api/admin/units/list', queryParameters: {
        'company_id': userId,
      });
      print("Units List: ${response?.data?['data']}");
      return response?.data?['data'] ?? [];
    } catch (e) {
      print('Error fetching units list: $e');
      rethrow;
    }
  }

  Future<void> exportLogs(List<Map<String, dynamic>> visitorData) async {
    try {
      final companyId = await gateStorage.getSocietyId();

      final payload = {
        "company_id": companyId,
        "to_mail": visitorData[0]["to_mail"],
        "to_name": visitorData[0]["name"],
        "from_date": visitorData[0]["from_date"],
        "to_date": visitorData[0]["to_date"],
        "visitor_logs": visitorData,
      };

      print("Payload: ${payload.toString()}");

      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/visitor/sendLogs',
        data: payload,
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      // Handle the response
      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Visitor logs sent successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        print("Response Error: ${response.data}");
        // Fluttertoast.showToast(
        //   msg: "Failed to send logs: ${response.statusMessage}",
        //   backgroundColor: Colors.red,
        //   textColor: Colors.white,
        // );
      }
    } catch (e) {
      // Handle DioError and other exceptions
      if (e is DioError) {
        print("DioError: ${e.response?.data ?? e.message}");
      } else {
        print("Unexpected Error: $e");
      }

      // Fluttertoast.showToast(
      //   msg: "Error occurred: ${e.toString()}",
      //   backgroundColor: Colors.orange,
      //   textColor: Colors.white,
      // );
    }
  }

  Future<void> visitorLogDetails(
      List<Map<String, dynamic>>? visitorData) async {
    try {
      final companyDetails = await gateStorage.getSocietyDetails();
      final socId = await gateStorage.getSocietyId();
      final companyName = companyDetails["societyName"];
      if (socId == null) {
        throw Exception(
            "Company ID is null. Please ensure the society is selected.");
      }

      final List<String> memberDetails = [];
      final List<int> unitIds = [];
      final List<int> memberIds = [];
      final List<String> buildingUnits = [];

      for (var entry in visitorData!) {
        if (entry.containsKey('member_details')) {
          memberDetails
              .addAll(List<String>.from(entry['member_details'] ?? []));
        }
        if (entry.containsKey('unit_ids')) {
          unitIds.addAll(List<int>.from(entry['unit_ids'] ?? []));
        }
        if (entry.containsKey('member_ids')) {
          memberIds.addAll(List<int>.from(entry['member_ids'] ?? []));
        }
        if (entry.containsKey('building_unit')) {
          buildingUnits.addAll(List<String>.from(entry['building_unit'] ?? []));
        }
      }

      print(
          "Member Details: $memberDetails, Unit IDs: $unitIds, Member IDs: $memberIds, Building Units: $buildingUnits");

      if (memberDetails.isEmpty || unitIds.isEmpty || memberIds.isEmpty) {
        Fluttertoast.showToast(
          msg: "Error: Member details, unit IDs, or member IDs are missing!",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      log("this is${GlobalStorage.visitorLogId}");
      final payload = {
        "visitor_log_id": GlobalStorage.visitorLogId,
        "company_name": companyName,
        "member_id": memberIds[0],
        "member_name": memberDetails[0],
        "unit_id": unitIds[0],
        "unit_name": buildingUnits.isNotEmpty ? buildingUnits[0] : "N/A",
      };

      print("Payload: $payload");

      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/visitor/logDetails',
        data: payload,
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      // Handle the response
      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Visitor logs sent successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        print("Response: ${response.data}");
      } else {
        print("Response Error: ${response.data}");
        Fluttertoast.showToast(
          msg: "Failed to send logs: ${response.statusMessage}",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      // Handle DioError and other exceptions
      if (e is DioError) {
        print("DioError: ${e.response?.data ?? e.message}");
      } else {
        print("Unexpected Error: $e");
      }

      Fluttertoast.showToast(
        msg: "Error occurred: ${e.toString()}",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  Future<List<dynamic>> getBuildingsList(int companyId) async {
    try {
      final userId = gateStorage.getSocietyId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }
      final response = await _dio2?.get(
        '/api/admin/building/list',
        queryParameters: {
          'company_id': userId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      print("Buildings List: ${response?.data?['data']}");
      return response?.data?['data'] ?? [];
    } catch (e) {
      print('Error fetching buildings list: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMembersList(int companyId) async {
    try {
      final socId = gateStorage.getSocietyId();
      if (socId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }
      final response = await _dio2?.get(
        '/api/admin/member/list',
        queryParameters: {
          'company_id': socId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      print("Members List: ${response?.data?['data']}");
      return response?.data?['data'] ?? [];
    } catch (e) {
      print('Error fetching members list: $e');
      rethrow;
    }
  }

  Future<String?> sendOTP(String mobileNumber) async {
    try {
      final response = await _dio1?.get('/sms/verification-code',
          queryParameters: {'phoneNumber': '91$mobileNumber'});
      print(response?.data?['data'].toString());
      if (response?.statusCode == 200) {
        return response?.data?['data']['expires_in'];
      }
    } catch (e) {
      return e.toString();
    }
    return null;
  }

  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    try {
      final response = await _dio1?.post('/sms/verify',
          data: {'phoneNumber': '91$mobileNumber', "otp": otp});
      if (kDebugMode) {
        print(response?.data?['data'].toString());
      }
      if (response?.statusCode == 200) {
        return response?.data?['message'];
      }
    } catch (e) {
      return e.toString();
    }
    return null;
  }
}

class GlobalStorage {
  static String?
      visitorLogId; // Nullable to handle cases where it might not be set
}
