import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/common/environment.dart';

import 'package:http/http.dart' as http;

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

  Future<List<dynamic>> fetchGates() async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    try {
      String apiUrl = ApiUrls.gates;

      final Map<String, String> queryParams = {
        "company_id": companyId.toString(),
      };

      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);
      final headers = await Environment.getHeaders();
      // Make the POST request
      final response = await http.get(
        uri,
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch gates: ${response.statusCode} - ${response.body}');
      }

      // Decode the JSON response
      final responseData = jsonDecode(response.body);

      if (responseData == null) {
        throw Exception('Response data is null');
      }

      if (responseData is Map && responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is List) {
          return data;
        } else {
          throw Exception('Unexpected data format in "data" key');
        }
      } else {
        throw Exception('Unexpected response structure');
      }
    } catch (e, stackTrace) {
      log('Error fetching gates: $e');
      log('Stack trace: $stackTrace');
      throw Exception('Failed to fetch gates: $e');
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
    print("Attempting check-in...");

    try {
      final Dio dio = Dio();
      String apiUrl = ApiUrls.visitorLog;

      // Prepare the payload
      final Map<String, dynamic> data = visitorLog.toJson();

      data['visitor_check_in'] =
          _formatDateTime(visitorLog.visitor_check_in ?? DateTime.now());
      if (visitorLog.visitor_check_out != null) {
        data['visitor_check_out'] =
            _formatDateTime(visitorLog.visitor_check_out!);
      }
      final prefs = await SharedPreferences.getInstance();

      final selectedGateName = prefs.getString('selected_gate');

      final String? memberDetailsJson = prefs.getString('member_details');
      List<Map<String, dynamic>> memberDetails = [];
      if (memberDetailsJson != null) {
        try {
          final List<dynamic> decoded = json.decode(memberDetailsJson);
          memberDetails = List<Map<String, dynamic>>.from(decoded);
        } catch (e) {
          print('Error retrieving member details: $e');
        }
      }

      final companyDetails = await gateStorage.getSocietyDetails();
      final companyName = companyDetails['societyName'];

      data.addAll({
        'in_gate': selectedGateName.toString(),
        'company_name': companyName,
        'visitor_purpose_sub_category_id': 1,
        'visitor_card_id': 1,
        'id': 1,
        'member_details': memberDetails
      });

      print("Final Payload: $data");

      // Make the POST request
      final Response response = await dio.post(
        apiUrl,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'insomnia/10.3.0',
          },
        ),
      );

      print("VisitorLog Response: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          final item = responseData['data'];

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

          log("succes - $resultLog");
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
      const String apiUrl = 'https://gateapi.cubeone.in/api/visitor/getLog';

      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? "Default Gate";
      final companyDetails = await gateStorage.getSocietyId();
      final resolvedCompanyId = companyDetails;

      final Map<String, String> queryParams = {
        "company_id": resolvedCompanyId.toString(),
        "in_gate": selectedGateName,
      };

      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
      );

      print("Response: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];
        log("data--$data");
        return data.map((item) {
          try {
            final visitor = Visitor(
              id: item['visitor_id'] as int?,
              name: item['name'] as String? ?? "",
              mobile: item['mobile'] as String? ?? "",
              visitor_image: item['visitor_image'] as String? ?? "",
            );

            // Map `unit_details` to `BuildingAssignment`
            final List<BuildingAssignment>? buildingAssignments =
                (item['unit_details'] as List<dynamic>?)
                    ?.map((unit) => BuildingAssignment(
                          id: null, // Optional
                          visitor_id: item['visitor_id'] as int?,
                          visitor_log_id: item['visitor_log_id'] as int?,
                          company_id: item['company_id'] as int? ?? 0,
                          building_id: 0,
                          unit_id: [unit['building_unit'] as String? ?? ""],
                        ))
                    .toList();

            return VisitorLog(
              id: item['visitor_log_id'] as int?,
              visitor_id: item['visitor_id'] as int? ?? 0,
              visitor: visitor,
              visitor_purpose_category_id:
                  item['visitor_purpose_category_id'] as int? ?? 0,
              visitor_purpose_sub_category_id: null,
              visitor_building_assignment: buildingAssignments,
              visitor_count: item['visitor_count'] as int? ?? 0,
              visitor_check_in: item['visitor_check_in'] != null
                  ? DateTime.parse(item['visitor_check_in'] as String)
                  : null,
              visitor_check_out: item['visitor_check_out'] != null
                  ? DateTime.parse(item['visitor_check_out'] as String)
                  : null,
              visitor_card_number: item['visitor_card_number'] as String?,
              visitor_coming_from: item['visitor_coming_from'] as String?,
              visitor_card_id: null,
              company_id: item['company_id'] as int? ?? 0,
              is_checked_out: item['is_checked_out'] as bool? ?? false,
            );
          } catch (mappingError) {
            throw Exception("Failed to map visitor log: $mappingError");
          }
        }).toList();
      } else {
        throw Exception(
            'Failed to fetch visitor logs: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
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
  Future<List<VisitorLog>> fetchCheckInLogs(
      int companyId, String dateTime) async {
    try {
      // Define the API endpoint
      String apiUrl = ApiUrls.visitorGetLog;

      bool isCheckedOut = false;

      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? "Default Gate";
      final companyDetails = await gateStorage.getSocietyId();
      final resolvedCompanyId = companyDetails;
      // Prepare the request payload
      final Map<String, dynamic> requestBody = {
        "company_id": resolvedCompanyId,
        "in_gate": selectedGateName,
        "only_checkout": isCheckedOut,
      };

      // Make the POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        // Parse the visitor logs from the response
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];

        return data.map((item) {
          try {
            final visitor = Visitor(
              id: null,
              name: item['name'] as String? ?? "",
              mobile: item['mobile'] as String? ?? "",
              visitor_image: item['visitor_image'] as String? ?? "",
            );
            final List<BuildingAssignment>? buildingAssignments =
                (item['unit_details'] as List<dynamic>?)
                    ?.map((unit) => BuildingAssignment(
                          id: null,
                          visitor_id: item['visitor_id'] as int?,
                          visitor_log_id: item['visitor_log_id'] as int?,
                          company_id: item['company_id'] as int? ?? 0,
                          building_id: 0,
                          unit_id: [unit['building_unit'] as String? ?? ""],
                        ))
                    .toList();
            final visitorLog = VisitorLog(
              id: item['visitor_log_id']
                  as int?, // Map `visitor_log_id` to `id`
              visitor_id:
                  0, // Set to 0 since `visitor_id` isn't in the shared structure
              visitor: visitor, // Use the constructed `Visitor` object
              visitor_purpose_category_id:
                  0, // Default value, not in shared structure
              visitor_purpose_sub_category_id: null, // Nullable
              visitor_building_assignment: buildingAssignments,
              visitor_count: item['visitor_count'] as int? ?? 0, // Default to 0
              visitor_check_in: item['visitor_check_in'] != null
                  ? DateTime.parse(item['visitor_check_in'] as String)
                  : null,
              visitor_check_out: item['visitor_check_out'] != null
                  ? DateTime.parse(item['visitor_check_out'] as String)
                  : null,
              visitor_card_number: item['visitor_card_number'] as String?,
              visitor_coming_from: item['visitor_coming_from'] as String?,
              visitor_card_id: null, // No `visitor_card_id` in shared structure
              company_id: item['company_id'] as int? ?? 0,
              is_checked_out: item['is_checked_out'] as bool? ?? false,
            );

            // print("Mapped VisitorLog: ${visitorLog.toJson()}");
            return visitorLog;
          } catch (mappingError) {
            // print("Error mapping VisitorLog: $mappingError");
            throw Exception("Failed to map visitor log");
          }
        }).toList();
      } else {
        throw Exception(
            'Failed to fetch visitor logs: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      // Handle errors and log them
      // print('Error in fetchCheckInLogs: $e');
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

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
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
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? "Default Gate";

      // Prepare the request payload
      final data = {
        'visitor_log_id': visitorLog.id.toString(),
        'out_gate': selectedGateName,
      };

      log("Check-Out Payload: $data");

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
  Future<List<VisitorLog>> fetchCheckOutLogs(
      int companyId, String dateTime) async {
    try {
      // Define the API endpoint
      const String apiUrl = 'https://gateapi.cubeone.in/api/visitor/getLog';

      // Boolean for filtering checked-out logs
      bool isCheckedOut = true;

      // Get the gate and company details from preferences and storage
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? "Default Gate";
      final companyDetails = await gateStorage.getSocietyId();
      final resolvedCompanyId = companyDetails;
      // Prepare the request payload
      final Map<String, dynamic> requestBody = {
        "company_id": resolvedCompanyId,
        "in_gate": selectedGateName,
        "only_checkout": isCheckedOut,
      };

      // Make the POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody), // Encode the request payload
      );

      // Print the response for debugging
      // print("Response: ${response.body}");

      // Check response status
      if (response.statusCode == 200) {
        // Parse the visitor logs from the response
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];

        // Map the JSON data to `VisitorLog` objects
        return data.map((item) {
          try {
            // print("Processing Item: $item");

            // Create a `Visitor` object directly from root-level fields
            final visitor = Visitor(
              id: null, // No `id` in your shared structure
              name: item['name'] as String? ?? "",
              mobile: item['mobile'] as String? ?? "",
              visitor_image: item['visitor_image'] as String? ?? "",
            );

            final List<BuildingAssignment>? buildingAssignments =
                (item['unit_details'] as List<dynamic>?)
                    ?.map((unit) => BuildingAssignment(
                          id: null,
                          visitor_id: item['visitor_id'] as int?,
                          visitor_log_id: item['visitor_log_id'] as int?,
                          company_id: item['company_id'] as int? ?? 0,
                          building_id: 0,
                          unit_id: [unit['building_unit'] as String? ?? ""],
                        ))
                    .toList();
            // Create the `VisitorLog` object
            final visitorLog = VisitorLog(
              id: item['visitor_log_id']
                  as int?, // Map `visitor_log_id` to `id`
              visitor_id:
                  0, // Set to 0 since `visitor_id` isn't in the shared structure
              visitor: visitor, // Use the constructed `Visitor` object
              visitor_purpose_category_id:
                  0, // Default value, not in shared structure
              visitor_purpose_sub_category_id: null, // Nullable
              visitor_building_assignment: buildingAssignments,
              visitor_count: item['visitor_count'] as int? ?? 0, // Default to 0
              visitor_check_in: item['visitor_check_in'] != null
                  ? DateTime.parse(item['visitor_check_in'] as String)
                  : null,
              visitor_check_out: item['visitor_check_out'] != null
                  ? DateTime.parse(item['visitor_check_out'] as String)
                  : null,
              visitor_card_number: item['visitor_card_number'] as String?,
              visitor_coming_from: item['visitor_coming_from'] as String?,
              visitor_card_id: null, // No `visitor_card_id` in shared structure
              company_id: item['company_id'] as int? ?? 0,
              is_checked_out: item['is_checked_out'] as bool? ?? false,
            );

            // print("Mapped VisitorLog: ${visitorLog.toJson()}");
            return visitorLog;
          } catch (mappingError) {
            // print("Error mapping VisitorLog: $mappingError");
            throw Exception("Failed to map visitor log");
          }
        }).toList();
      } else {
        throw Exception(
            'Failed to fetch checkout logs: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      // Handle errors and log them
      // print('Error in fetchCheckOutLogs: $e');
      rethrow;
    }
  }

  /// Fetch approvals
  Future<List<dynamic>> fetchApprovals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? "Default Gate";

      final companyDetails = await gateStorage.getSocietyId();
      final resolvedCompanyId = companyDetails;
      final String url =
          '${ApiUrls.visitorApprovals}/$resolvedCompanyId/$selectedGateName';

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

  Future<List<dynamic>> getMembersList() async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final headers = await Environment.getHeaders();

      final Map<String, String> queryParams = {
        "company_id": companyId,
      };
      final apiUrl = ApiUrls.memberList;
      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);
      log(uri.toString());
      final response = await http.get(
        uri,
        // headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        return responseData['data'] ?? [];
      } else {
        log('Failed to fetch member list: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch member list: ${response.statusCode}');
      }
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
        throw Exception(
            'No visitor ID found. Please search for a visitor first.');
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

// Complete implementation with **ALL METHODS** and utilities included.
