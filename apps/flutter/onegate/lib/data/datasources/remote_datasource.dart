import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_onegate/common/apiHelper.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';
import 'package:provider/provider.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class RemoteDataSource {
  final Dio? _dio1;
  final Dio? _dio2;
  final Dio? _dio3;

  RemoteDataSource(
    this._dio1,
    this._dio2,
    this._dio3,
  );
  final ApiHelper _apiHelper = ApiHelper();

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

  Future<List<dynamic>> fetchGates() async {
    final int? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    final response = await _apiHelper.get(
      '${Environment.baseUrl}/api/admin/gates',
      queryParameters: {'company_id': companyId},
    );

    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> fetchSocieties(String userId) async {
    final response = await _apiHelper.get(
      '${Environment.baseUrl}/api/admin/companies/$userId',
    );

    return response.data['data'] ?? [];
  }

  Future<VisitorMapper?> searchVisitor(String mobileNumber) async {
    try {
      final response = await _apiHelper.get(
        '${Environment.baseUrl}/api/visitor/entry',
        queryParameters: {'mobile_number': mobileNumber},
      );

      final List<dynamic> data = response.data["data"] ?? [];
      if (data.isNotEmpty) {
        log("data--$data");

        final visitor = VisitorMapper.fromJson(data.first);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('search_visitor_id', visitor.id.toString());

        return visitor;
      }
    } catch (e) {
      log("Error searching visitor: $e");
    }

    return null;
  }

  //Pending++++++++++++++
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

  Future<VisitorMapper?> createVisitor(VisitorMapper visitor) async {
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
      final response = await _apiHelper.post(
        '${Environment.baseUrl}/api/visitor/entry',
        data: data,
      );

      // Parse the response and map it to VisitorMapper
      final visitorData = response.data['data'];
      final visitorId = visitorData['visitor_id'] as int;
      log("createvisitorresponse $response");

      GlobalStorage.visitorId = visitorId.toString();

      print("$visitorId visitorId");
      // Return the VisitorMapper instance
      log("createdVisitor:$response");
      return VisitorMapper(
        id: visitorId,
        name: visitor.name,
        mobile: visitor.mobile,
        VisitorMapperImage: uploadImageUrl.toString(),
      );
    } catch (error) {
      // Handle any errors
      log('Error creating visitor: $error');
      return null;
    }
  }

  Future<bool> updateVisitor(VisitorMapper visitor) async {

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final searchedVisitorId=  prefs.getString('search_visitor_id');    try {
      final url = 'http://gateapi.cubeone.in/api/visitor/entry/$searchedVisitorId';

      // Prepare the request payload
      final data = {
        "name": visitor.name,
        "mobile_number": visitor.mobile ?? "",
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
        print("Visitor updated successfully!");
        return true;
      } else {
        print(
            "Failed to update visitor: ${response.statusCode} - ${response.data}");
        return false;
      }
    } catch (e) {
      print("Error updating visitor: $e");
      return false;
    }
  }

  Future<dynamic> passcodeVerify(String passcode, BuildContext context) async {
    const String endpoint = 'https://gateapi.cubeone.in/api/member/verifyGuest';

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Payload
      final Map<String, dynamic> payload = {
        'passcode': passcode,
      };

      // Make API call
      final Response? response = await _dio1?.post(
        endpoint,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      // Hide loading indicator
      Navigator.pop(context);

      // Handle response
      if (response?.statusCode == 200) {
        final responseData = response?.data;
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    responseData['message'] ?? 'Verification successful!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(responseData['message'] ?? 'Verification failed.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API Error: ${response?.statusCode}')),
        );
      }
    } on DioError catch (e) {
      Navigator.pop(context);

      // Handle Dio errors
      final errorMessage = e.response?.data['message'] ?? 'An error occurred';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $errorMessage')),
      );
    } catch (e) {
      Navigator.pop(context);

      // Handle unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
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

  String formatDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(dateTime);
  }

  Future<VisitorLogMapper?> checkIn(VisitorLogMapper visitorLog) async {
    print("Attempting check-in...");

    try {
      // Instantiate Dio
      final Dio dio = Dio();

      // Define the API endpoint
      const String apiUrl = "https://gateapi.cubeone.in/api/visitor/log";

      // Prepare the payload using VisitorLogMapper's `toJson` method
      final Map<String, dynamic> data = visitorLog.toJson();

      // Format `visitor_check_in` and `visitor_check_out`
      data['visitor_check_in'] =
          formatDateTime(visitorLog.visitorCheckIn ?? DateTime.now());
      if (visitorLog.visitorCheckOut != null) {
        data['visitor_check_out'] = formatDateTime(visitorLog.visitorCheckOut!);
      }

      // Load the selected gate from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate');

      // Add additional fields dynamically
      data.addAll({
        'in_gate': selectedGateName.toString(), // Example dynamic field
        'visitor_purpose_sub_category_id': 1,
        'visitor_card_id': 1,
        'id': 1,
      });

      print("Final Payload: $data");

      // Make the POST request
      final Response response = await dio.post(
        apiUrl,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'insomnia/10.3.0', // Example header
          },
        ),
      );

      // Log the response
      print("VisitorLog Response: ${response.data}");

      // Parse the response and return the VisitorLogMapper object if successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          final VisitorLogMapper result =
              VisitorLogMapper.fromJson(responseData['data']);
          print("VisitorLog created: ${visitorLog.toJson()}");

          // Save visitor log ID globally if needed
          GlobalStorage.visitorLogId =
              responseData['data']['visitor_log_id'].toString();
          print("Saved Visitor Log ID: ${GlobalStorage.visitorLogId}");
          print("Saved Visitor Log ID: ${GlobalStorage.visitorId}");

          return result;
        } else {
          print("API Response Error: ${responseData['message']}");
        }
      } else {
        print(
            "Failed to create VisitorLog. Status Code: ${response.statusCode}, Response: ${response.data}");
      }
    } on DioError catch (e) {
      // Handle Dio-specific errors
      if (e.response != null) {
        print("Dio Error: ${e.response?.data}");
        print("Status Code: ${e.response?.statusCode}");
      } else {
        print("Dio Error: ${e.message}");
      }
    } catch (e, stackTrace) {
      // Handle unexpected errors
      print("Unexpected error during check-in: $e");
      print("Stack trace: $stackTrace");
    }

    return null; // Return null if the check-in fails
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

  //
  // Future<void> checkoutVisitor(String visitorId) async {
  //   // Load the selected gate from SharedPreferences
  //   final prefs = await SharedPreferences.getInstance();
  //   final selectedGateName = prefs.getString('selected_gate');
  //
  //   final data = {
  //
  //     'visitor_log_id': visitorId,
  //     "out_gate": selectedGateName.toString()
  //
  //
  //   };
  //
  //   await _apiHelper.patch('${Environment.baseUrl}/api/visitor/checkout', data: data);
  // }
//NOt in use
  Future<bool> checkOut(VisitorLog visitorLog) async {
    try {
      // Load the selected gate from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate');

      // Prepare the data payload
      final data = {
        'visitor_log_id': visitorLog.id.toString(),
        'out_gate': selectedGateName ?? 'Unknown Gate', // Handle null gate name
      };

      // Send the API request
      final response = await _apiHelper
          .patch('${Environment.baseUrl}/api/visitor/checkout', data: data);

      // If the response is successful, return true
      if (response.statusCode == 200) {
        return true;
      } else {
        log('Check-out failed: ${response.statusCode} - ${response.data}');
        return false;
      }
    } catch (e) {
      // Handle any errors
      log('Error during check-out: $e');
      return false;
    }
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
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate');

      final payload = {
        "company_id": companyId,
        "to_mail": visitorData[0]["to_mail"],
        "to_name": visitorData[0]["name"],
        "from_date": visitorData[0]["from_date"],
        "to_date": visitorData[0]["to_date"],
        "visitor_logs": visitorData,
        "in_gate": "A Gate"
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
          msg: "Visitor logs sent Successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        print("Response Error: ${response.data}");
        Fluttertoast.showToast(
          msg: "${response.data}",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      // Handle DioError and other exceptions
      if (e is DioError) {
        Fluttertoast.showToast(
          msg: "feature unlocking soon",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        print("DioError: ${e.response?.data ?? e.message}");
      } else {
        Fluttertoast.showToast(
          msg: "feature unlocking soon",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
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

      SharedPreferences prefs = await SharedPreferences.getInstance();
      final searchedVisitor = await prefs.getString("searched_visitor_id");

      log("this is${GlobalStorage.visitorLogId}");
      final payload = {
        "visitor_log_id": GlobalStorage.visitorLogId,
        "visitor_id": GlobalStorage.visitorId ?? searchedVisitor ,
        "company_name": companyName,
        "member_id": memberIds[0],
        "member_name": memberDetails[0],
        "unit_id": unitIds[0],
        "company_id": socId,
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
          msg: "Visitor checked-in successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        print("Response: ${response.data}");
      } else {
        print("Response Error: ${response.data}");
      }
    } catch (e) {
      if (e is DioError) {
        print("DioError: ${e.response?.data ?? e.message}");
      } else {
        print("Unexpected Error: $e");
      }
      log("Error: $e");

      // Fluttertoast.showToast(
      //   msg: "Error occurred: ${e.toString()}",
      //   backgroundColor: Colors.orange,
      //   textColor: Colors.white,
      // );
    }
  }

  Future<List<dynamic>> getBuildingsList() async {
    final int? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    final response = await _apiHelper.get(
      '${Environment.societyBackendUrl}/admin/building/list',
      queryParameters: {'company_id': companyId},
    );

    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> getMembersList() async {
    final int? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    final response = await _apiHelper.get(
      '${Environment.societyBackendUrl}/admin/member/list',
      queryParameters: {'company_id': companyId},
    );

    return response.data['data'] ?? [];
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

  Future<List<StaffModel>> fetchStaffList(String companyId) async {
    final response = await _dio1?.get('admin/staffs/staffLists',
        queryParameters: {'company_id': companyId});
    if (response?.statusCode == 200) {
      final List<dynamic> data = response?.data['data'];
      return data.map((e) => StaffModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch staff list');
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
