import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';

/// Centralized API URL manager
class ApiUrls {
  static const String gateBaseUrl = 'https://gateapi.cubeone.in/api';
  static const String societyBaseUrl = 'https://societybackend.cubeone.in/api';

  // Gate API Endpoints
  static String get gateLogin => '$gateBaseUrl/gatelogin';
  static String get gates => '$gateBaseUrl/admin/gates';
  static String get visitorEntry => '$gateBaseUrl/visitor/entry';
  static String get visitorLog => '$gateBaseUrl/visitor/log';
  static String get visitorCheckout => '$gateBaseUrl/visitor/checkout';
  static String get visitorSendLogs => '$gateBaseUrl/visitor/sendLogs';
  static String get visitorGetLog => '$gateBaseUrl/visitor/getLog';
  static String get visitorApprovals => '$gateBaseUrl/visitor/approvals';

  // Society API Endpoints
  static String get buildingList => '$societyBaseUrl/admin/building/list';
  static String get memberList => '$societyBaseUrl/admin/member/list';
  static String get unitList => '$societyBaseUrl/admin/units/list';
  static String get staffList => '$societyBaseUrl/admin/staffs/staffLists';
}
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


/// Remote Data Source for managing API calls
class RemoteDataSource {
  final Dio? _dio1;
  final Dio? _dio2;
  final Dio? _dio3;

  RemoteDataSource(
      this._dio1,
      this._dio2,
      this._dio3,
      );

  final GateStorage gateStorage = GateStorage();

  /// Login user via Keycloak
  Future<Map<String, dynamic>> loginUser() async {
    try {
      final keycloakWrapper = KeycloakWrapper(
        config: KeycloakConfig(
          bundleIdentifier: 'com.example.keycloakflutter',
          clientId: 'onegate-sso',
          frontendUrl: 'http://stgsso.cubeone.in',
          realm: 'fstech',
          clientSecret: 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58',
        ),
      );

      bool isLoggedIn = await keycloakWrapper.login();
      if (!isLoggedIn || keycloakWrapper.accessToken == null) {
        throw Exception('Keycloak login failed.');
      }

      log('Keycloak login successful. Access Token: ${keycloakWrapper.accessToken}');

      final response = await _dio2?.post(
        ApiUrls.gateLogin,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${keycloakWrapper.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response?.statusCode == 200) {
        log('Login response: ${response?.data}');
        return response?.data?['data'] ?? {};
      } else {
        throw Exception('Failed to log in: ${response?.statusCode}');
      }
    } catch (e) {
      log('Error during login: $e');
      return {};
    }
  }

  /// Fetch gates
  Future<List<dynamic>> fetchGates() async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final response = await _dio2?.get(
        ApiUrls.gates,
        queryParameters: {'company_id': companyId},
      );

      final responseData = response?.data?['data'];
      if (responseData is List) {
        return responseData;
      } else {
        throw Exception('Unexpected response format');
      }
    } catch (e) {
      log('Error fetching gates: $e');
      rethrow;
    }
  }

  /// Fetch societies
  Future<List<dynamic>> fetchSocieties(String userId) async {
    try {
      final response = await Dio().get(
        '${ApiUrls.gateBaseUrl}/admin/companies/$userId',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        return data is List ? data : [];
      } else {
        throw Exception('Failed to fetch societies.');
      }
    } catch (e) {
      log('Error fetching societies: $e');
      rethrow;
    }
  }

  /// Search for a visitor
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final response = await _dio2?.get(
        ApiUrls.visitorEntry,
        queryParameters: {'mobile_number': mobileNumber},
      );

      final List<dynamic> data = response?.data['data'] ?? [];
      if (data.isNotEmpty) {
        final visitorData = data.first;
        log("Visitor data fetched: $visitorData");

        final visitor = Visitor(
          id: visitorData['id'] as int?,
          name: visitorData['name'] as String? ?? "",
          mobile: visitorData['mobile'] as String? ?? "",
          visitor_image: visitorData['visitor_image'] as String? ?? "",
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('search_visitor_id', visitor.id.toString());

        return visitor;
      } else {
        log("No visitor found in the response data.");
      }
    } catch (e) {
      log("Error searching visitor: $e");
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

  /// Create a visitor
  Future<Visitor?> createVisitor(Visitor visitor) async {
    try {
      final uploadImageUrl = await GateStorage().getImage();

      final data = {
        "name": visitor.name,
        "mobile_number": visitor.mobile,
        "visitor_image": uploadImageUrl.toString(),
      };

      final response = await _dio2?.post(
        ApiUrls.visitorEntry,
        data: data,
      );

      final visitorData = response?.data['data'];
      final visitorId = visitorData['visitor_id'] as int;
      log("Visitor created: $visitorData");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('visitorId', visitorId.toString());

      return Visitor(
        id: visitorId,
        name: visitor.name,
        mobile: visitor.mobile,
        visitor_image: uploadImageUrl.toString(),
      );
    } catch (error) {
      log('Error creating visitor: $error');
      return null;
    }
  }

  /// Check-in a visitor
  Future<VisitorLog?> checkIn(VisitorLog visitorLog) async {
    try {
      final Dio dio = Dio();
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate');
      final companyDetails = await gateStorage.getSocietyDetails();
      final companyName = companyDetails['societyName'];

      final Map<String, dynamic> data = {
        ...visitorLog.toJson(),
        'in_gate': selectedGateName,
        'company_name': companyName,
      };

      final response = await dio.post(
        ApiUrls.visitorLog,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          final item = responseData['data'];

          // Create Visitor object
          final visitor = Visitor(
            id: item['visitor_id'],
            name: item['name'] ?? "",
            mobile: item['mobile'] ?? "",
            visitor_image: item['visitor_image'] ?? "",
          );

          final resultLog = VisitorLog(
            id: item['visitor_log_id'],
            visitor_id: item['visitor_id'] ?? 0,
            visitor: visitor,
            visitor_purpose_category_id:
            item['visitor_purpose_category_id'] ?? 0,
            visitor_purpose_sub_category_id:
            item['visitor_purpose_sub_category_id'],
            visitor_building_assignment: item['visitor_building_assignment'],
            visitor_count: item['visitor_count'] ?? 0,
            visitor_check_in: item['visitor_check_in'] != null
                ? DateTime.parse(item['visitor_check_in'])
                : null,
            visitor_check_out: item['visitor_check_out'] != null
                ? DateTime.parse(item['visitor_check_out'])
                : null,
            visitor_card_number: item['visitor_card_number'],
            visitor_coming_from: item['visitor_coming_from'],
            visitor_card_id: item['visitor_card_id'],
            company_id: item['company_id'] ?? 0,
            is_checked_out: item['is_checked_out'] ?? false,
          );

          // Save visitor log ID globally
          GlobalStorage.visitorLogId = item['visitor_log_id'].toString();
          print("Saved Visitor Log ID: ${GlobalStorage.visitorLogId}");

          return resultLog;
        } else {
          print("API Response Error: ${responseData['message']}");
          return null;
        }
      }
    } on DioError catch (e) {
      if (e.response != null) {
        print("Dio Error: ${e.response?.data}");
        print("Status Code: ${e.response?.statusCode}");
      } else {
        print("Dio Error: ${e.message}");
      }
    } catch (e, stackTrace) {
      print("Unexpected error during check-in: $e");
      print("Stack trace: $stackTrace");
    }

    return null;
  }

  Future<List<VisitorLog>> fetchAllLogs(int companyId, String dateTime) async {
    try {
       String apiUrl = ApiUrls.visitorGetLog;

      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate') ?? "Default Gate";

      final response = await _dio2?.get(
        apiUrl,
        queryParameters: {
          "company_id": companyId,
          "in_gate": selectedGateName,
        },
      );

      if (response?.statusCode == 200) {
        final List<dynamic> data = response?.data['data'] ?? [];
        return data.map((item) => VisitorLogMapper2.fromJson(item).toVisitorLog()).toList();
      } else {
        throw Exception(
            'Failed to fetch logs: ${response?.statusCode}, ${response?.data}');
      }
    } catch (e) {
      log('Error fetching all logs: $e');
      rethrow;
    }
  }

  /// Export visitor logs
  Future<void> exportLogs(Map<String, dynamic> visitorData) async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception("Company ID not found. Please select a company.");
      }

      // Prepare the API URL
      final String url = ApiUrls.visitorSendLogs;

      log("Export Logs Payload: ${jsonEncode(visitorData)}");

      // Send the POST request to export logs
      final response = await Dio().post(
        url,
        data: visitorData,
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      // Handle successful response
      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Visitor logs exported successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        log("Export Logs Response: ${response.data}");
      } else {
        log("Failed to export logs: ${response.statusMessage}");
        Fluttertoast.showToast(
          msg: "Failed to export logs: ${response.data}",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      // Handle errors during log export
      log("Error exporting logs: $e");
      Fluttertoast.showToast(
        msg: "Error exporting logs: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
  /// Fetch check-in logs
  Future<List<VisitorLog>> fetchCheckInLogs(int companyId, String dateTime) async {
    try {
      // Define the API endpoint
      String apiUrl = ApiUrls.visitorGetLog;

      // Retrieve selected gate and company details
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate') ?? "Default Gate";
      final companyDetails = await gateStorage.getSocietyId();
      final resolvedCompanyId = companyDetails;

      // Prepare the POST request payload
      final requestBody = {
        "company_id": resolvedCompanyId,
        "in_gate": selectedGateName,
        "only_checkout": false, // Indicating check-in logs only
        // "date_time": dateTime,  // Optional: If logs are filtered by date
      };

      log("Fetching Check-In Logs with Payload: $requestBody");

      // Send the POST request
      final response = await _dio2?.post(
        apiUrl,
        data: requestBody,
        options: Options(
          headers: {
            "Content-Type": "application/json",
          },
        ),
      );

      // Handle the response
      if (response?.statusCode == 200) {
        final List<dynamic> data = response?.data['data'] ?? [];
        return data.map((item) => VisitorLogMapper2.fromJson(item).toVisitorLog()).toList();
      } else {
        throw Exception(
            'Failed to fetch check-in logs: ${response?.statusCode}, ${response?.data}');
      }
    } catch (e) {
      log('Error fetching check-in logs: $e');
      rethrow;
    }
  }
  /// Fetch members for a company
  Future<List<dynamic>> getMember(int companyId) async {
    try {
      final String? userId = await gateStorage.getSocietyId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }

      final response = await _dio2?.get(
        ApiUrls.memberList,
        queryParameters: {
          'company_id': userId,
          'current_tab': 'approved', // Default tab for approved members
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      return response?.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching members: $e');
      rethrow;
    }
  }

  /// Fetch member units for a specific building in a company
  Future<List<dynamic>> getMemberUnit(int? companyId, int? buildingId) async {
    try {
      if (companyId == null) {
        final companyDetails = await gateStorage.getSocietyDetails();
        companyId = companyDetails['company_id'];
      }

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
        ApiUrls.unitList,
        queryParameters: {
          'company_id': companyId,
          'building_id': buildingId,
          'per_page': 1000,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      return response?.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching member units: $e');
      rethrow;
    }
  }
  /// Fetch buildings for a company
  Future<List<Map<String, dynamic>>> getBuilding(int companyId) async {
    try {
      final String? userId = await gateStorage.getSocietyId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) {
        throw Exception('Access token not found. Please log in again.');
      }

      final response = await _dio2?.get(
        ApiUrls.buildingList,
        queryParameters: {'company_id': userId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      return List<Map<String, dynamic>>.from(response?.data['data'] ?? []);
    } catch (e) {
      log('Error fetching buildings: $e');
      rethrow;
    }
  }
  /// Fetch list of buildings for a company
  Future<List<dynamic>> getBuildingsList() async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception('Company ID not found. Please select a company.');
      }

      final response = await _dio2?.get(
        ApiUrls.buildingList,
        queryParameters: {'company_id': companyId},
      );

      return response?.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching buildings list: $e');
      rethrow;
    }
  }
  /// Send OTP to a mobile number
  Future<String?> sendOTP(String mobileNumber) async {
    try {
      final response = await _dio1?.get(
        '${ApiUrls.gateBaseUrl}/sms/verification-code',
        queryParameters: {'phoneNumber': '91$mobileNumber'},
      );

      if (response?.statusCode == 200) {
        final expiresIn = response?.data?['data']['expires_in'];
        log('OTP sent successfully. Expires in: $expiresIn');
        return expiresIn;
      } else {
        log('Failed to send OTP: ${response?.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error sending OTP: $e');
      rethrow;
    }
  }
  /// Verify OTP for a mobile number
  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    try {
      final response = await _dio1?.post(
        '${ApiUrls.gateBaseUrl}/sms/verify',
        data: {'phoneNumber': '91$mobileNumber', 'otp': otp},
      );

      if (response?.statusCode == 200) {
        final message = response?.data?['message'];
        log('OTP verified successfully. Message: $message');
        return message;
      } else {
        log('Failed to verify OTP: ${response?.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error verifying OTP: $e');
      rethrow;
    }
  }
  /// Check out a visitor
  Future<bool> checkOut(VisitorLog visitorLog) async {
    try {
      // Retrieve the selected gate from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate') ?? "Default Gate";

      // Prepare the request payload
      final data = {
        'visitor_log_id': visitorLog.id.toString(),
        'out_gate': selectedGateName,
      };

      log("Check-Out Payload: $data");

      // Send the PATCH request to the check-out endpoint
      final response = await _dio2?.patch(
        ApiUrls.visitorCheckout,
        data: data,
        options: Options(
          headers: {
            "Content-Type": "application/json",
          },
        ),
      );

      // Handle response
      if (response?.statusCode == 200) {
        log("Visitor checked out successfully.");
        return true;
      } else {
        log("Failed to check out visitor: ${response?.statusCode} - ${response?.data}");
        return false;
      }
    } catch (e) {
      log("Error during visitor check-out: $e");
      return false;
    }
  }
  /// Fetch check-out logs
  Future<List<VisitorLog>> fetchCheckOutLogs(int companyId, String dateTime) async {
    try {
       String apiUrl = ApiUrls.visitorGetLog;

      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate') ?? "Default Gate";

      final response = await _dio2?.get(
        apiUrl,
        queryParameters: {
          "company_id": companyId,
          "in_gate": selectedGateName,
          "only_checkout": true,
        },
      );

      if (response?.statusCode == 200) {
        final List<dynamic> data = response?.data['data'] ?? [];
        return data.map((item) => VisitorLogMapper2.fromJson(item).toVisitorLog()).toList();
      } else {
        throw Exception(
            'Failed to fetch check-out logs: ${response?.statusCode}, ${response?.data}');
      }
    } catch (e) {
      log('Error fetching check-out logs: $e');
      rethrow;
    }
  }

  /// Fetch approvals
  Future<List<dynamic>> fetchApprovals() async {
    try {

      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate') ?? "Default Gate";

      final companyDetails = await gateStorage.getSocietyId();
      final resolvedCompanyId = companyDetails;
      final String url = '${ApiUrls.visitorApprovals}/$resolvedCompanyId/$selectedGateName';

      final response = await _dio2?.get(url);
      if (response?.statusCode == 200) {
        final List<dynamic> data = response?.data['data'] ?? [];
        return data;
      } else {
        throw Exception(
            'Failed to fetch approvals: ${response?.statusCode}, ${response?.data}');
      }
    } catch (e) {
      log('Error fetching approvals: $e');
      rethrow;
    }
  }

  /// Send visitor logs
  Future<void> sendLogs(Map<String, dynamic> visitorData) async {
    try {
      final response = await _dio2?.post(
        ApiUrls.visitorSendLogs,
        data: visitorData,
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      if (response?.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Visitor logs sent successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        log('Failed to send logs: ${response?.statusMessage}');
      }
    } catch (e) {
      log('Error sending logs: $e');
      Fluttertoast.showToast(
        msg: "Error sending logs: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  /// Upload a file
  Future<String?> uploadFile(File file, String userMobile, int companyId) async {
    try {
      log('File path: ${file.path}');

      var data = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: '$userMobile.jpg',
        ),
        'company_id': '$companyId',
        'uuid': userMobile,
      });

      var response = await _dio2?.post(
        '${ApiUrls.gateBaseUrl}/visitor/uploadFile',
        data: data,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response?.statusCode == 200) {
        log('File uploaded successfully: ${response?.data}');
        return response?.data['data']['file_path'];
      } else {
        log('File upload failed: ${response?.statusMessage}');
      }
    } catch (e) {
      log('Error uploading file: $e');
    }

    return null;
  }

  /// Fetch members for a specific company
  Future<List<dynamic>> getMembersList() async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final response = await _dio2?.get(
        ApiUrls.memberList,
        queryParameters: {'company_id': companyId},
      );

      return response?.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching member list: $e');
      rethrow;
    }
  }

  /// Fetch units for a specific building
  Future<List<dynamic>> getUnitsList(int buildingId) async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final response = await _dio2?.get(
        ApiUrls.unitList,
        queryParameters: {
          'company_id': companyId,
          'building_id': buildingId,
        },
      );

      return response?.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching unit list: $e');
      rethrow;
    }
  }

  /// Fetch staff list for a company
  Future<List<StaffModel>> fetchStaffList(String companyId) async {
    try {
      final response = await _dio2?.get(
        ApiUrls.staffList,
        queryParameters: {'company_id': companyId},
      );

      if (response?.statusCode == 200) {
        final List<dynamic> data = response?.data?['data'];
        return data.map<StaffModel>((e) => StaffModel.fromJson(e)).toList();
      } else {
        throw Exception('Failed to fetch staff list: ${response?.statusCode}');
      }
    } catch (e) {
      log('Error fetching staff list: $e');
      rethrow;
    }
  }
  /// Update visitor details
  Future<bool> updateVisitor(Visitor visitor) async {
    try {
      // Retrieve the visitor ID from SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final searchedVisitorId = prefs.getString('search_visitor_id');
      if (searchedVisitorId == null) {
        throw Exception('No visitor ID found. Please search for a visitor first.');
      }

      // Prepare the API URL
      final url = '${ApiUrls.visitorEntry}/$searchedVisitorId';

      // Prepare the request payload
      final data = {
        "name": visitor.name,
        "mobile_number": visitor.mobile,
      };

      // Send the PATCH request
      final response = await Dio().patch(
        url,
        data: data,
        options: Options(
          headers: {
            "Content-Type": "application/json",
          },
        ),
      );

      // Check for success response
      if (response.statusCode == 200) {
        log("Visitor updated successfully!");
        return true;
      } else {
        log("Failed to update visitor: ${response.statusCode} - ${response.data}");
        return false;
      }
    } catch (e) {
      log("Error updating visitor: $e");
      return false;
    }
  }
}

class GlobalStorage {
  static String? _visitorLogId; // Private field for visitorLogId
  static String? _visitorId; // Private field for visitorId

  // Getter for visitorLogId
  static String? get visitorLogId => _visitorLogId;

  // Setter for visitorLogId
  static set visitorLogId(String? value) {
    _visitorLogId = value;
    print("VisitorLogId has been set to: $value");
  }

  // Getter for visitorId
  static String? get visitorId => _visitorId;

  // Setter for visitorId
  static set visitorId(String? value) {
    _visitorId = value;
    print("VisitorId has been set to: $value");
  }
}
class VisitorLogMapper2 {
  VisitorLogMapper2({
    this.id,
    this.visitorId,
    this.visitor,
    this.visitorPurposeCategoryId,
    this.visitorPurposeSubCategoryId,
    this.visitorBuildingAssignment,
    this.visitorCount,
    this.visitorCheckIn,
    this.visitorCheckOut,
    this.visitorCardNumber,
    this.visitorComingFrom,
    this.visitorCardId,
    this.companyId,
    this.isCheckedOut,
  });

  final int? id;
  final int? visitorId;
  final VisitorMapper? visitor;
  final int? visitorPurposeCategoryId;
  final int? visitorPurposeSubCategoryId;
  final List<dynamic>? visitorBuildingAssignment;
  final int? visitorCount;
  final DateTime? visitorCheckIn;
  final DateTime? visitorCheckOut;
  final String? visitorCardNumber;
  final String? visitorComingFrom;
  final int? visitorCardId;
  final int? companyId;
  final bool? isCheckedOut;

  /// Factory method to create a `VisitorLogMapper2` instance from JSON.
  factory VisitorLogMapper2.fromJson(Map<String, dynamic> json) {
    return VisitorLogMapper2(
      id: json['id'] as int?,
      visitorId: json['visitor_id'] as int?,
      visitor: json['visitor'] != null
          ? VisitorMapper.fromJson(json['visitor'])
          : null,
      visitorPurposeCategoryId: json['visitor_purpose_category_id'] as int?,
      visitorPurposeSubCategoryId:
      json['visitor_purpose_sub_category_id'] as int?,
      visitorBuildingAssignment: json['visitor_building_assignment'] != null
          ? List<dynamic>.from(json['visitor_building_assignment'])
          : null,
      visitorCount: json['visitor_count'] as int?,
      visitorCheckIn: json['visitor_check_in'] != null
          ? DateTime.parse(json['visitor_check_in'] as String)
          : null,
      visitorCheckOut: json['visitor_check_out'] != null
          ? DateTime.parse(json['visitor_check_out'] as String)
          : null,
      visitorCardNumber: json['visitor_card_number'] as String?,
      visitorComingFrom: json['visitor_coming_from'] as String?,
      visitorCardId: json['visitor_card_id'] as int?,
      companyId: json['company_id'] as int?,
      isCheckedOut: json['is_checked_out'] as bool?,
    );
  }

  /// Converts the current `VisitorLogMapper2` instance to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitorId,
      'visitor': visitor?.toJson(),
      'visitor_purpose_category_id': visitorPurposeCategoryId,
      'visitor_purpose_sub_category_id': visitorPurposeSubCategoryId,
      'visitor_building_assignment': visitorBuildingAssignment,
      'visitor_count': visitorCount,
      'visitor_check_in': visitorCheckIn?.toIso8601String(),
      'visitor_check_out': visitorCheckOut?.toIso8601String(),
      'visitor_card_number': visitorCardNumber,
      'visitor_coming_from': visitorComingFrom,
      'visitor_card_id': visitorCardId,
      'company_id': companyId,
      'is_checked_out': isCheckedOut,
    };
  }

  /// Converts `VisitorLogMapper2` into a `VisitorLog` object.
  VisitorLog toVisitorLog() {
    return VisitorLog(
      id: id,
      visitor_id: visitorId ?? 0,
      visitor: visitor?.toVisitor(),
      visitor_purpose_category_id: visitorPurposeCategoryId ?? 0,
      visitor_purpose_sub_category_id: visitorPurposeSubCategoryId,
      visitor_count: visitorCount ?? 0,
      visitor_check_in: visitorCheckIn,
      visitor_check_out: visitorCheckOut,
      visitor_card_number: visitorCardNumber,
      visitor_coming_from: visitorComingFrom,
      visitor_card_id: visitorCardId,
      company_id: companyId ?? 0,
      is_checked_out: isCheckedOut ?? false,
    );
  }
}
// Complete implementation with **ALL METHODS** and utilities included.