import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/features/missed_approval/missed_approval_screen.dart';

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
  RemoteDataSource();

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

      final response = await Dio().post(
        ApiUrls.gateLogin,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${keycloakWrapper.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        log("Bearer ${keycloakWrapper.accessToken}");
        log('Login response: ${response.data}');
        return response.data?['data'] ?? {};
      } else {
        throw Exception('Failed to log in: ${response.statusCode}');
      }
    } catch (e) {
      log('Error during login: $e');
      return {};
    }
  }

  Future<List<dynamic>> fetchGates() async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final commonHeaders = await Environment.getHeaders();
    try {
      final response = await Dio().get(
        ApiUrls.gates,
        queryParameters: {'company_id': companyId},
        options: Options(
          headers: commonHeaders,
        ),
      );
      final responseData = response.data;

      if (responseData == null) {
        throw Exception('Response data is null');
      }

      if (responseData is List) {
        return responseData;
      } else if (responseData is Map && responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is List) {
          print("gates$data");
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
        print("data--$data");

        return data is List ? data : [];
      } else {
        throw Exception('Failed to fetch societies.');
      }
    } catch (e) {
      log('Error fetching societies: $e');
      rethrow;
    }
  }

  Future<void> sendFcmNotification(Map<String, dynamic> requestData) async {
    try {
      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("✅ FCM API Response: ${response.data}");
      } else {
        log("❌ Failed to send FCM Notification. Status Code: ${response.statusCode}");
        throw Exception('Failed to send FCM Notification');
      }
    } catch (e) {
      log("❌ Error sending FCM Notification: $e");
      throw Exception('Error sending FCM Notification: $e');
    }
  }

  /// Search for a visitor
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      // API call to fetch visitor details
      final response = await Dio().get(
        ApiUrls.visitorEntry,
        queryParameters: {'mobile_number': mobileNumber},
      );

      // Extract the data from the response
      final List<dynamic> data = response.data['data'] ?? [];
      if (data.isNotEmpty) {
        final visitorData = data.first;
        log("Visitor data fetched: $visitorData");

        final prefs = await SharedPreferences.getInstance();

        // Store the `coming_from` field in SharedPreferences if available
        final comingFrom = visitorData['coming_from'] as String? ?? "";
        await prefs.setString('visitor_coming_from', comingFrom);
        log("Coming from stored: $comingFrom");

        // Store visitor ID in SharedPreferences
        final visitorId = visitorData['id']?.toString() ?? "";
        await prefs.setString('search_visitor_id', visitorId);

        // Use the factory constructor to create and return the Visitor object
        return Visitor.fromJson(visitorData);
      } else {
        log("No visitor found in the response data.");
      }
    } catch (e) {
      log("Error searching visitor: $e");
    }

    return null;
  }

  Future<List<PurposeCategory1>?> fetchPurpose() async {
    try {
      String apiUrl = "${ApiUrls.gateBaseUrl}/visitor/purposeCategory";

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final purposesList = responseData['data'] as List;
          final purposes = purposesList
              .map((json) => PurposeCategory1.fromJson(json))
              .toList();

          for (var purpose in purposes) {
            // debugPrint('Fetched Purpose: ${purpose.categoryName}');
            // debugPrint(
            //     'Subcategories count: ${purpose.subCategories?.length ?? 0}');
            if (purpose.subCategories != null) {
              for (var sub in purpose.subCategories!) {
                debugPrint('  - ${sub.subCategoryName}: ${sub.image}');
              }
            }
          }

          return purposes;
        }
      }
    } catch (e) {
      debugPrint('Error fetching purposes: $e');
    }
    return null;
  }

  /// Create a visitor
  Future<Visitor?> createVisitor(Visitor visitor) async {
    try {
      // Fetch the uploaded image URL from GateStorage
      final uploadImageUrl = await GateStorage().getImage();

      // Prepare the data payload
      final data = {
        "name": visitor.name,
        "mobile_number": visitor.mobile,
        "visitor_image": uploadImageUrl.toString(),
      };

      // Make the POST request to the API
      final response = await Dio().post(
        ApiUrls.visitorEntry,
        data: data,
      );

      final visitorData = response.data['data'];
      print(visitorData);
      final visitorId = visitorData['visitor_id'] as int;
      log("createvisitorresponse $response");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('visitorId', visitorId.toString());
      GlobalStorage.visitorId = visitorId.toString();

      print("$visitorId visitorId");
      log("createdVisitor:$response");
      return Visitor(
        id: visitorId,
        name: visitor.name,
        mobile: visitor.mobile,
        visitor_image: uploadImageUrl.toString(),
      );
    } catch (error) {
      // Handle any errors
      log('Error creating visitor: $error');
      return null;
    }
  }

  Future<List<VisitorLog>?> fetchCardNumbers() async {
    try {
      final response = await fetchCheckInLogs();

      final filteredLogs =
          response.where((log) => log.visitor_card_number != null).toList();

      return filteredLogs;
    } catch (error) {
      log("Error fetching card numbers: $error");
      return null;
    }
  }

  Future<List<String>> _getMobileNumbersFromMemberDetails(
      int visitorLogId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? memberDetailsJson = prefs.getString('member_details');

    if (memberDetailsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(memberDetailsJson);
        final mobileNumbers = decoded
            .map((member) => member['mobile_number'].toString())
            .where((mobile) => mobile.isNotEmpty)
            .toSet()
            .toList();

        if (mobileNumbers.isNotEmpty) {
          return mobileNumbers;
        }
      } catch (e) {
        log('❌ Error parsing member_details: $e');
      }
    }

    // Fallback: Empty List
    return [];
  }

  /// Check-in a visitor
  Future<VisitorLog?> checkIn(VisitorLog visitorLog,
      [bool? statusallowed]) async {
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
      final selectedGateName = prefs.getString('selected_gate') ?? "";
      final memberDetailsJson = prefs.getString('member_details');
      List<dynamic> memberDetails = memberDetailsJson != null
          ? json.decode(memberDetailsJson) as List<dynamic>
          : [];
      final companyDetails = await gateStorage.getSocietyDetails();
      final companyName = companyDetails['societyName'] ?? "";

      data.addAll({
        'in_gate': selectedGateName,
        'company_name': companyName,
        'member_details': memberDetails,
        "is_always_allowed": statusallowed
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
          final visitorLogResult = VisitorLog.fromJson(responseData['data']);
          log("Success - $visitorLogResult");
          final prefs = await SharedPreferences.getInstance();

          prefs.setString("visitor_log",
              response.data["data"]["visitor_log_id"].toString());

          return visitorLogResult;
        } else {
          print("API Response Error: ${responseData['message']}");
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

  DateTime? tryParseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;

    final List<DateFormat> formats = [
      DateFormat('yyyy-MM-ddTHH:mm:ss'), // ISO 8601 (default from APIs)
      DateFormat('yyyy-MM-dd HH:mm:ss'), // Common format with spaces
      DateFormat('dd-MM-yyyy'), // Custom format
      DateFormat('dd-MM-yyyy HH:mm:ss'), // Custom format with time
    ];

    for (var format in formats) {
      try {
        return format.parse(dateString, true);
      } catch (_) {
        // Continue to the next format
      }
    }

    log('Date format not supported: $dateString');
    return null;
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
        myFluttertoast(
          msg: "Visitor logs exported successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        log("Export Logs Response: ${response.data}");
      } else {
        log("Failed to export logs: ${response.statusMessage}");
        myFluttertoast(
          msg: "Failed to export logs: ${response.data}",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      // Handle errors during log export
      log("Error exporting logs: $e");
      myFluttertoast(
        msg: "Error exporting logs: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<List<VisitorLog>> fetchCheckInLogs() async {
    return _fetchVisitorLogs(onlyCheckout: false);
  }

  Future<List<VisitorLog>> fetchAllLogs() async {
    return _fetchVisitorLogs();
  }

  Future<List<VisitorLog>> fetchCheckOutLogs() async {
    return _fetchVisitorLogs(onlyCheckout: true);
  }

  Future<List<VisitorLog>> _fetchVisitorLogs({bool? onlyCheckout}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? 'Default Gate';
      final resolvedCompanyId = await gateStorage.getSocietyId();

      final String formattedDate =
          DateFormat('yyyy-MM-dd').format(DateTime.now());

      final requestBody = <String, dynamic>{
        'from_date': formattedDate,
        'to_date': formattedDate,
        'company_id': int.parse(resolvedCompanyId.toString()),
        'in_gate': selectedGateName,
      };

      if (onlyCheckout != null) {
        requestBody['only_checkout'] = onlyCheckout;
      }

      final response = await http.post(
        Uri.parse(ApiUrls.visitorGetLog),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];
        log("data--$data");
        return data.map((item) => _mapToVisitorLog(item)).toList();
      } else {
        throw Exception(
            'Failed to fetch visitor logs: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  VisitorLog _mapToVisitorLog(Map<String, dynamic> item) {
    final visitor = Visitor(
      id: item['visitor_id'] as int?,
      name: item['name'] as String? ?? '',
      mobile: item['mobile'] as String? ?? '',
      visitor_image: item['visitor_image'] as String? ?? '',
    );

    final List<BuildingAssignment>? buildingAssignments =
        (item['unit_details'] as List<dynamic>?)?.map((unit) {
      return BuildingAssignment(
        id: null,
        visitor_id: item['visitor_id'] as int?,
        visitor_log_id: item['visitor_log_id'] as int?,
        company_id: item['company_id'] as int? ?? 0,
        building_id: 0,
        unit_id: [unit['building_unit'] as String? ?? ''],
      );
    }).toList();

    // Handling additional_details safely
    String? initiatedFrom;
    final additionalDetails = item['additional_details'];

    if (additionalDetails is Map<String, dynamic>) {
      initiatedFrom = additionalDetails['initiated_from'] as String?;
    }

    return VisitorLog(
      id: item['visitor_log_id'] as int?,
      visitor_id: item['visitor_id'] as int? ?? 0,
      visitor: visitor,
      visitor_purpose_category_id:
          item['visitor_purpose_category_id'] as int? ?? 0,
      visitor_purpose_sub_category_id:
          item['visitor_purpose_sub_category_id'] as int?,
      visitor_building_assignment: buildingAssignments,
      visitor_count: item['visitor_count'] as int? ?? 0,
      visitor_check_in: item['visitor_check_in'] != null
          ? tryParseDate(item['visitor_check_in'] as String)
          : null,
      visitor_check_out: item['visitor_check_out'] != null
          ? tryParseDate(item['visitor_check_out'] as String)
          : null,
      visitor_card_number: item['visitor_card_number'] as String?,
      visitor_coming_from: item['visitor_coming_from'] as String?,
      visitor_card_id: null,
      company_id: item['company_id'] as int? ?? 0,
      is_checked_out: item['is_checked_out'] as bool? ?? false,
      purpose_sub_category_name: item['purpose_sub_category_name'] as String?,
      visitor_purpose_Category_name: item['purpose_category_name'] as String,
      carNumber: item['vehicle_number'] as String?,
      initiated_from: initiatedFrom,
      approved_by: additionalDetails is Map<String, dynamic>
          ? additionalDetails['approved_by'] as String?
          : null,
    );
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

      final response = await Dio().get(
        ApiUrls.memberList,
        queryParameters: {
          'company_id': userId,
          'current_tab': 'approved',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      log("memberlist${response.data?['data']}");
      return response.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching members: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getSubCategoryId(int companyId) async {
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

      final response = await Dio().get(
        ApiUrls.visitorGetLog,
        queryParameters: {
          'company_id': userId,
          'current_tab': 'approved',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      return response.data?['data'] ?? [];
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

      final response = await Dio().get(
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

      return response.data?['data'] ?? [];
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

      final response = await Dio().get(
        ApiUrls.buildingList,
        queryParameters: {'company_id': userId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
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

      final response = await Dio().get(
        ApiUrls.buildingList,
        queryParameters: {'company_id': companyId},
      );

      return response.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching buildings list: $e');
      rethrow;
    }
  }

  //Otp verifiction for self checkin
  Future<void> sendOtpForSelfCheckIn(String mobileNumber) async {
    try {
      final response = await Dio().post(
        'https://stggateapi.cubeone.in/api/visitor/selfCheckin',
        data: {'mobile': mobileNumber}, // Send only the 10-digit mobile number
      );

      if (response.statusCode == 200) {
        log('OTP sent successfully. Response: ${response.data}');
        // You can perform additional processing here if needed.
      } else {
        log('Failed to send OTP: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      if (e is DioError) {
        log('Error sending OTP: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        log('Error sending OTP: $e');
      }
      rethrow;
    }
  }

  //Verify otp for self checkin

  Future<Map<String, dynamic>> verifySelfCheckin({
    required String mobileNumber,
    required String otp,
  }) async {
    try {
      final response = await Dio().post(
        'https://stggateapi.cubeone.in/api/visitor/selfCheckin/verify',
        data: {
          'mobile': mobileNumber,
          'otp': otp,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
            'Failed to verify self-checkin: ${response.statusCode}');
      }
    } catch (e) {
      log('Error during self-checkin verification: $e');
      throw Exception('Error during self-checkin verification: $e');
    }
  }

  /// Send OTP to a mobile number
  Future<String?> sendOTP(String mobileNumber) async {
    try {
      final response = await Dio().get(
        '${ApiUrls.gateBaseUrl}/sms/verification-code',
        queryParameters: {'phoneNumber': '91$mobileNumber'},
      );

      if (response.statusCode == 200) {
        final expiresIn = response.data?['data']['expires_in'];
        log('OTP sent successfully. Expires in: $expiresIn');
        return expiresIn;
      } else {
        log('Failed to send OTP: ${response.statusCode}');
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
      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/sms/verify',
        data: {'phoneNumber': '91$mobileNumber', 'otp': otp},
      );

      if (response.statusCode == 200) {
        final message = response.data?['message'];
        log('OTP verified successfully. Message: $message');
        return message;
      } else {
        log('Failed to verify OTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error verifying OTP: $e');
      rethrow;
    }
  }

  Future<bool> checkOut(VisitorLog visitorLog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate');

      final data = {
        'visitor_log_id': visitorLog.id.toString(),
        'out_gate': selectedGateName ?? 'Unknown Gate',
      };

      final response = await Dio().patch(ApiUrls.visitorCheckout, data: data);

      if (response.statusCode == 200) {
        return true;
      } else {
        log('Check-out failed: ${response.statusCode} - ${response.data}');
        return false;
      }
    } catch (e) {
      log('Error during check-out: $e');
      return false;
    }
  }

  /// Fetch check-out logs

  Future<bool> uploadParcelImage({
    required int visitorLogId,
    required String imageUrl,
  }) async {
    try {
      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/parcelData/',
        data: {
          'visitor_log_id': visitorLogId,
          'parcel_image': imageUrl,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      log('Error uploading parcel image: $e');
      return false;
    }
  }

  Future<List<VisitorInfo>> fetchApprovals([String? logID]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? "Default Gate";
      final resolvedCompanyId = await gateStorage.getSocietyId();

      final String baseUrl = '${ApiUrls.gateBaseUrl}/visitor/approvals/';

      final DateTime now = DateTime.now();
      final String formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Construct Request Body
      final Map<String, dynamic> requestBody = {
        "company_id": resolvedCompanyId,
        "in_gate": selectedGateName,
        "from_date": formattedDate,
        "to_date": formattedDate
      };

      final uri = Uri.parse(baseUrl);

      log("🔍 Sending request to: $baseUrl");
      log("📦 Request Body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        // log("📡 Full API Response: ${jsonEncode(responseData)}");

        if (!responseData.containsKey('data')) {
          log("🚨 API Response does not contain 'data' key.");
          return [];
        }

        final List<dynamic> data = responseData['data'];
        if (data.isEmpty) {
          log("🚫 No approvals found in response.");
          return [];
        }

        // ✅ Parse the API Response to a List of VisitorInfo Objects
        final List<VisitorInfo> visitorList = data.map((json) {
          List<UnitDetails> parsedUnitDetails = [];

          try {
            // 🔍 Log the raw `unit_details` value before decoding
            // log("🔍 Raw unit_details: ${json['unit_details']}");

            final dynamic unitDetailsValue = json['unit_details'];

            if (unitDetailsValue is String) {
              final String cleanedJsonString = unitDetailsValue
                  .replaceAll(r'\"', '"')
                  .replaceAll('"[', '[')
                  .replaceAll(']"', ']');

              // ✅ Step 2: Decode the cleaned JSON string
              final List<dynamic> decodedUnitDetails =
                  jsonDecode(cleanedJsonString);

              parsedUnitDetails =
                  decodedUnitDetails.map<UnitDetails>((unitJson) {
                return UnitDetails(
                  unitId: _parseToInt(unitJson['unit_id']),
                  building_unit: unitJson["building_unit"]?.toString() ?? '',
                );
              }).toList();
            }
          } catch (e) {
            log("❌ Error decoding unit details: $e");
          }

          // 🔍 Log parsed `unitDetails`
          // log("✅ Parsed unitDetails: ${parsedUnitDetails.map((u) => u.building_unit).toList()}");

          return VisitorInfo(
            visitorId: _parseToInt(json['visitor_id']),
            visitorName: json['visitor_name']?.toString() ?? '',
            visitorMobile: json['visitor_mobile']?.toString() ?? '',
            visitorImage: json['visitor_image']?.toString() ?? '',
            allowStatus: json['allow_status']?.toString() ?? '',
            visitorLogId: _parseToInt(json['visitor_log_id']),
            companyId: _parseToInt(json['company_id']),
            inGate: json['in_gate']?.toString() ?? '',
            logCreatedAt: json['log_created_at']?.toString() ?? '',
            unitDetails: parsedUnitDetails.isNotEmpty
                ? parsedUnitDetails.first
                : UnitDetails(unitId: 0, building_unit: ''),
            // Assign default
            memberInfo: MemberInfo(
              name: json['member_name']?.toString() ?? '',
              mobileNumber: json['memb_mobile_number']?.toString(),
              email: json['memb_email']?.toString(),
              memberId: _parseToInt(json['member_id']),
              unitId: _parseToInt(json['unit_id']),
              building_unit: json["building_unit"]?.toString(),
            ),
            visitorComingFrom: json['visitor_coming_from']?.toString(),
            visitorPurposeCategoryId:
                _parseToInt(json['visitor_purpose_category_id']),
            purposeCategoryName: json['purpose_category_name']?.toString(),
            purposeSubCategoryName:
                json['purpose_sub_category_name']?.toString(),
          );
        }).toList();

        // log("✅ Formatted Visitor List: ${jsonEncode(visitorList.map((e) => e.toString()).toList())}");
        return visitorList;
      } else {
        throw Exception(
            '❌ Failed to fetch approvals: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      log('❌ Error fetching approvals: $e');
      rethrow;
    }
  }

  // Helper method to safely parse integers
  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  /// Send visitor logs
  Future<void> sendLogs(Map<String, dynamic> visitorData) async {
    try {
      final response = await Dio().post(
        ApiUrls.visitorSendLogs,
        data: visitorData,
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      if (response.statusCode == 200) {
        myFluttertoast(
          msg: "Visitor logs sent successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        log('Failed to send logs: ${response.statusMessage}');
      }
    } catch (e) {
      log('Error sending logs: $e');
      myFluttertoast(
        msg: "Error sending logs: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  /// read status
  Future<Response?> readStatus(String memberID, String visitorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? visitorId1 = prefs.getString('visitorId');

      final response = await Dio().post(
        ApiUrls.readStatus,
        data: {
          "member_id": memberID,
          "visitor_id": visitorId1,
        },
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      if (response.statusCode == 200) {
        log("Success: ${response.data}");
        return response;
      } else {
        log('Failed to readStatus: ${response.statusMessage}');
        return null;
      }
    } catch (e) {
      log('Error readStatus: $e');
      return null;
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

  //
  // Future<List<dynamic>> getMembersList() async {
  //   final String? companyId = await gateStorage.getSocietyId();
  //   if (companyId == null) throw Exception('Company ID not found.');
  //
  //   final response = await Dio().get(
  //     '${ApiUrls.memberList}',
  //     queryParameters: {'company_id': companyId},
  //   );
  //
  //   return response.data['data'] ?? [];
  // }

  final String cacheKey = 'members_list_cache';
  final String cacheTimestampKey = 'members_list_cache_timestamp';
  final Duration cacheDuration = Duration(minutes: 30); // Cache expiry time

  Future<List<dynamic>> getMembersList() async {
    try {
      // Check if cached data is still valid
      final cachedData = await _getCachedData();
      if (cachedData != null) {
        log('Using cached data.');
        return cachedData;
      }

      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final Map<String, String> queryParams = {
        "company_id": companyId,
      };
      final apiUrl = ApiUrls.memberList;
      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);
      log('API URL: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final membersList = responseData['data'] ?? [];
        log('Fetched members list: $membersList');

        // Cache the new data
        await _cacheData(membersList);

        return membersList;
      } else {
        log('Failed to fetch member list: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch member list: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching member list: $e');
      rethrow;
    }
  }

  // Get cached data if it's still valid
  Future<List<dynamic>?> _getCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if cached data exists
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson == null) return null;

    // Check if the cache is still valid
    final cachedTimestamp = prefs.getInt(cacheTimestampKey);
    if (cachedTimestamp == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheAge = Duration(milliseconds: now - cachedTimestamp);

    if (cacheAge <= cacheDuration) {
      // Cache is still valid
      return jsonDecode(cachedJson) as List<dynamic>;
    } else {
      // Cache is expired
      return null;
    }
  }

  // Cache the data with a timestamp
  Future<void> _cacheData(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(data);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString(cacheKey, jsonData);
    await prefs.setInt(cacheTimestampKey, timestamp);
  }

  /// Fetch units for a specific building
  Future<List<dynamic>> getUnitsList(int buildingId) async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final response = await Dio().get(
        ApiUrls.unitList,
        queryParameters: {
          'company_id': companyId,
          'building_id': buildingId,
        },
      );

      return response.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching unit list: $e');
      rethrow;
    }
  }

  /// Fetch staff list for a company
  Future<List<StaffModel>> fetchStaffList(String companyId) async {
    try {
      final response = await Dio().get(
        ApiUrls.staffList,
        queryParameters: {'company_id': companyId},
      );

      log("response--$response");
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data?['data'];
        return data.map<StaffModel>((e) => StaffModel.fromJson(e)).toList();
      } else {
        throw Exception('Failed to fetch staff list: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching staff list: $e');
      rethrow;
    }
  }

  Future<void> makeExotelCall({
    required String memberMobileNumber,
    required int visitorId,
    required int memberId,
    required int visitorLogId,
    required String purposeCategory,
  }) async {
    try {
      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/exotel/call',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: {
          'member_mobile_number': memberMobileNumber,
          'visitor_id': visitorId,
          'member_id': memberId,
          'visitor_log_id': visitorLogId,
          'purpose_category': purposeCategory,
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to make Exotel call. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error making Exotel call: $e');
    }
  }

  Future<List<dynamic>> fetchParcels() async {
    final prefs = await SharedPreferences.getInstance();

    final String? companyId = await gateStorage.getSocietyId();

    String url = '${ApiUrls.gateBaseUrl}/visitor/parcelData/$companyId';

    try {
      final response = await Dio().get(url);
      if (response.statusCode == 200) {
        log('Parcels fetched successfully: ${response.data}');
        if (response.data is Map<String, dynamic>) {
          final data = response.data['data'];
          if (data is List<dynamic>) {
            return data;
          }
        }
        return [];
      } else {
        log('Failed to fetch parcels: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      log('Error fetching parcels: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> verifyParcelOtp(
      String parcelId, String otp) async {
    try {
      log("Starting verifyParcelOtp API call...");
      log("Request Data -> parcel_id: $parcelId, otp: $otp");

      final response = await http.post(
        Uri.parse("https://stggateapi.cubeone.in/api/visitor/parcelOtpVerify"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'parcel_id': int.parse(parcelId), // Convert parcel_id to int
          'otp': int.parse(otp), // Convert otp to int
        }),
      );

      log("Response Status Code -> ${response.statusCode}");
      log("Response Body -> ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        log("Parcel OTP verified successfully: $responseData");
        return responseData;
      } else {
        log("Failed to verify parcel OTP. Status Code: ${response.statusCode}, Response Body: ${response.body}");
        throw Exception('Failed to verify parcel OTP');
      }
    } catch (e, stackTrace) {
      log("Error in verifyParcelOtp: $e");
      log("StackTrace: $stackTrace");
      throw Exception('Failed to verify parcel OTP');
    }
  }

  Future<Map<String, dynamic>> getParcelOtp(
      String parcelId, String mobileNumber) async {
    try {
      String formattedMobileNumber =
          mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (formattedMobileNumber.length == 12 &&
          formattedMobileNumber.startsWith('91')) {
        formattedMobileNumber = formattedMobileNumber.substring(2);
      }
      final response = await http.post(
        Uri.parse("https://stggateapi.cubeone.in/api/visitor/parcelOtp"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'parcel_id': parcelId,
          'mobile_number': formattedMobileNumber,
        }),
      );

      if (response.statusCode == 200) {
        log("Parcel OTP fetched successfully: ${response.body}");
        return jsonDecode(response.body);
      } else {
        log("Failed to load parcel OTP: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to load parcel OTP');
      }
    } catch (e) {
      log("Error in getParcelOtp: $e");
      throw Exception('Failed to load parcel OTP');
    }
  }

  Future<dynamic> fetchStaffCategory() async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    final String url =
        'https://societybackend.cubeone.in/api/admin/staffs/settings?company_id=$companyId&per_page=100';

    try {
      final response = await Dio().get(url);

      if (response.statusCode == 200) {
        log("Categories${response.data.toString()}");
        return response.data;
      } else {
        throw Exception(
            'Failed to fetch staff category: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching staff category: $e');
      throw Exception('Failed to fetch staff category: $e');
    }
  }

  Future<dynamic> addStaff(Map<String, dynamic> staffData) async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null || companyId.isEmpty) {
      throw Exception("Company ID is missing. Cannot add staff.");
    }

    final String addStaffUrl =
        'https://societybackend.cubeone.in/api/admin/staffs/addStaff?company_id=$companyId';

    try {
      log('Incoming staffData: $staffData');

      final Map<String, dynamic> formMap = {
        'staff_type_id': staffData['category'],
        'staff_gender': staffData['gender'],
        'staff_first_name': staffData['name'],
        'staff_badge_number': staffData['idProofNumber'],
        'staff_contact_number': staffData['phone'],
        'staff_email_id': staffData['email'],
        'staff_address_1': staffData['address'] ?? '',
        'staff_dob': staffData['dateOfBirth'] != null
            ? DateTime.parse(staffData['dateOfBirth'])
                .toIso8601String()
                .split('T')[0]
            : '',
        'staff_qualification': staffData['qualification'],
        'staff_skill': staffData['categoryValue'] ?? '',
        'staff_lang_iso_639_3': 'eng',
        'staff_rfid': staffData['idProofNumber'] ?? '',
        'staff_note': '',
        'staff_proof': staffData['idProofImageUrl'],
        'staff_image': staffData['profileImageUrl'],
      };

      final formData = FormData.fromMap(formMap);

      log('Request URL: $addStaffUrl');
      log('FormData fields: ${formData.fields}');
      log('FormData files: ${formData.files.length} files');

      final response = await Dio().post(
        addStaffUrl,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      log('Response status: ${response.statusCode}');
      log('Response data: ${response.data}');

      if (response.statusCode == 200) {
        log("Staff added successfully: ${response.data}");
        return response.data;
      } else {
        log('Error response: ${response.data}');
        throw Exception(
            'Server returned ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      log('Error adding staff: $e');
      rethrow;
    }
  }

  Future<dynamic> editStaff(int staffId, Map<String, dynamic> staffData) async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null || companyId.isEmpty) {
      throw Exception("Company ID is missing. Cannot edit staff.");
    }

    final String editStaffUrl =
        'https://societybackend.cubeone.in/api/admin/staffs/editStaff/$staffId?company_id=$companyId';

    try {
      log('Editing staff with ID: $staffId');
      log('Incoming staffData: $staffData');

      // Build a JSON body matching your server's expected fields
      final Map<String, dynamic> requestBody = {
        'staff_type_id': staffData['category'],
        'staff_gender': staffData['gender'],
        'staff_first_name': staffData['name'],
        'staff_badge_number': staffData['idProofNumber'],
        'staff_contact_number': staffData['phone'],
        'staff_email_id': staffData['email'],
        'staff_address_1': staffData['address'] ?? '',
        'staff_dob': staffData['dateOfBirth'] != null
            ? DateTime.parse(staffData['dateOfBirth'])
                .toIso8601String()
                .split('T')[0]
            : '',
        'staff_qualification': staffData['qualification'],
        'staff_skill': staffData['categoryValue'] ?? '',
        'staff_lang_iso_639_3': 'eng',
        'staff_rfid': staffData['idProofNumber'] ?? '',
        'staff_note': '',
        'staff_proof':
            "https://storage-as-service.s3.amazonaws.com/1//1737540834_scaled_aa85f48c-f79e-4e65-8334-a4c168dd67867233042262877539451.jpg"
        // 'staff_proof': staffData['idProofImageUrl'] ?? '',
      };

      log('Request URL: $editStaffUrl');
      log('Request Body: $requestBody');

      final response = await Dio().put(
        editStaffUrl,
        data: requestBody,
        options: Options(
          contentType: 'application/json',
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      log('Response status: ${response.statusCode}');
      log('Response data: ${response.data}');

      if (response.statusCode == 200) {
        log("Staff edited successfully: ${response.data}");
        myFluttertoast(
            backgroundColor: Colors.green,
            msg: "Staff edited successfully",
            toastLength: Toast.LENGTH_SHORT);

        return response.data;
      } else {
        log('Error response: ${response.data}');
        throw Exception(
            'Server returned ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      log('Error editing staff: $e');

      if (e is DioError && e.response?.statusCode == 400) {
        final responseData = e.response?.data.toString().toLowerCase();
        if (responseData != null &&
            responseData.contains('mobile number already exist')) {
          myFluttertoast(
              backgroundColor: Colors.red,
              msg: "User already exists",
              toastLength: Toast.LENGTH_SHORT);
        } else {
          myFluttertoast(
              msg: "Please check all required fields and try again.",
              toastLength: Toast.LENGTH_SHORT);
        }
      } else {
        log('Error editing staff: $e');
        // myFluttertoast(
        //     msg: "Error editing staff: $e", toastLength: Toast.LENGTH_SHORT);
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>?> uploadStaffImages(
      File file, int companyId) async {
    final String uploadUrl =
        'https://societybackend.cubeone.in/api/admin/file-upload?company_id=$companyId';

    try {
      FormData formData = FormData.fromMap({
        'files[]': await MultipartFile.fromFile(file.path,
            filename: file.path.split('/').last),
      });

      Dio dio = Dio();

      Response response = await dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        print("images${response.data}");
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
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
  static String? _visitorLogId;
  static String? _visitorId;

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
