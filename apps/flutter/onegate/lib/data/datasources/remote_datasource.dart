import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_onegate/common/apiHelper.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:intl/intl.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLogMapper.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:provider/provider.dart';
import 'package:serverpod_client/serverpod_client.dart' as _i1;
// import 'protocol.dart' as _i2;

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
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    try {
      // Make the API call
      final response = await _apiHelper.get(
        '${Environment.baseUrl}/api/admin/gates',
        queryParameters: {'company_id': companyId},
      );

      // Check and adapt to response structure
      final responseData = response.data;

      if (responseData == null) {
        throw Exception('Response data is null');
      }

      if (responseData is List) {
        // If the response is a list directly
        return responseData;
      } else if (responseData is Map && responseData.containsKey('data')) {
        // If the response is a map containing 'data'
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

  // Future<Map<String, dynamic>> fetchUserRoles(String userId, int societyId) async {
  //   try {
  //     final response = await _dio1?.get(
  //       '/api/users/$userId/societies/$societyId/roles',  // Adjust endpoint as per your API
  //       options: Options(
  //         // headers: await _getHeaders(),
  //       ),
  //     );
  //
  //     if (response?.statusCode == 200) {
  //       return response?.data;
  //     } else {
  //       throw Exception('Failed to fetch user roles: ${response?.statusCode}');
  //     }
  //   } catch (e) {
  //     log('Error fetching user roles: $e');
  //     throw Exception('Failed to fetch user roles: $e');
  //   }
  // }

  Future<List<dynamic>> fetchSocieties(String userId) async {
    try {
      final response = await Dio().get(
        'https://gateapi.cubeone.in/api/admin/companies/$userId', // Correct the URL
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer YOUR_ACCESS_TOKEN', // Add authorization if required
          },
        ),
      );

      print("API Response: ${response.data}");

      // Safely handle the response
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is List) {
          return data; // Return the list of societies
        } else {
          throw Exception('Unexpected data format: ${response.data}');
        }
      } else {
        throw Exception(
            'Failed to fetch societies. Status code: ${response.statusCode}');
      }
    } on DioError catch (e) {
      print("DioError: ${e.response?.data ?? e.message}");
      throw Exception('Failed to fetch societies: ${e.message}');
    } catch (e) {
      print("Unexpected error: $e");
      throw Exception('Unexpected error occurred');
    }
  }

  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final response = await _apiHelper.get(
        '${Environment.baseUrl}/api/visitor/entry',
        queryParameters: {'mobile_number': mobileNumber},
      );

      // Extract the data array from the response
      final List<dynamic> data = response.data["data"] ?? [];
      if (data.isNotEmpty) {
        final visitorData = data.first; // Get the first visitor in the list
        log("Visitor data fetched: $visitorData");

        // Map the visitorData to a Visitor object
        final visitor = Visitor(
          id: visitorData['id'] as int?,
          name: visitorData['name'] as String? ?? "",
          mobile: visitorData['mobile'] as String? ?? "",
          visitor_image: visitorData['visitor_image'] as String? ?? "",
        );

        // Store the visitor's ID in SharedPreferences
        final SharedPreferences prefs = await SharedPreferences.getInstance();
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
      final response = await _apiHelper.post(
        '${Environment.baseUrl}/api/visitor/entry',
        data: data,
      );

      // Parse the response and map it to VisitorMapper
      final visitorData = response.data['data'];
      final visitorId = visitorData['visitor_id'] as int;
      log("createvisitorresponse $response");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('visitorId', visitorId.toString());
      GlobalStorage.visitorId = visitorId.toString();

      print("$visitorId visitorId");
      // Return the VisitorMapper instance
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

  Future<bool> updateVisitor(Visitor visitor) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final searchedVisitorId = prefs.getString('search_visitor_id');
    try {
      final url =
          'https://gateapi.cubeone.in/api/visitor/entry/$searchedVisitorId';

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

  Future<VisitorLog?> checkIn(VisitorLog visitorLog) async {
    print("Attempting check-in...");

    try {
      final Dio dio = Dio();
      const String apiUrl = "https://gateapi.cubeone.in/api/visitor/log";

      // Prepare the payload
      final Map<String, dynamic> data = visitorLog.toJson();

      // Format datetime fields
      data['visitor_check_in'] =
          formatDateTime(visitorLog.visitor_check_in ?? DateTime.now());
      if (visitorLog.visitor_check_out != null) {
        data['visitor_check_out'] =
            formatDateTime(visitorLog.visitor_check_out!);
      }

      // Load selected gate and member details
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate');

      // Get member details from SharedPreferences
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

      // Get company details
      final companyDetails = await gateStorage.getSocietyDetails();
      final companyName = companyDetails['societyName'];

      // Add additional fields
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

  Future<void> _fetchVisitorLogs() async {
    try {
      final response = await Dio().get(
        'https://gateapi.cubeone.in/api/visitor/log',
        queryParameters: {
          // 'company_id': companyId,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Handle the response data
        print("Visitor Logs: ${response.data}");
      } else {
        print("Response Error: ${response.statusMessage}");
      }
    } catch (e) {
      if (e is DioError) {
        print("DioError: ${e.response?.data ?? e.message}");
      } else {
        print("Unexpected Error: $e");
      }
    }
  }

  // Future<List<VisitorLog>> fetchAllLogs(int companyId, String dateTime) async {
  //   try {
  //     final response = await Dio().get(
  //       'https://gateapi.cubeone.in/api/visitor/log',
  //       queryParameters: {
  //         // 'company_id': companyId,
  //       },
  //       options: Options(
  //         headers: {
  //           'Content-Type': 'application/json',
  //         },
  //       ),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       // Handle the response data
  //       print("Visitor Logs: ${response.data}");
  //     } else {
  //       print("Response Error: ${response.statusMessage}");
  //     }
  //   } catch (e) {
  //     if (e is DioError) {
  //       print("DioError: ${e.response?.data ?? e.message}");
  //     } else {
  //       print("Unexpected Error: $e");
  //     }
  //   }
  // }

  Future<List<VisitorLog>> fetchAllLogs(int companyId, String dateTime) async {
    try {
      const String apiUrl = 'https://gateapi.cubeone.in/api/visitor/getLog';

      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate') ?? "Default Gate";
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
              visitor_purpose_category_id: item['visitor_purpose_category_id'] as int? ?? 0,
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

  Future<List<VisitorLog>> fetchCheckInLogs(
      int companyId, String dateTime) async {
    try {
      // Define the API endpoint
      const String apiUrl = 'https://gateapi.cubeone.in/api/visitor/getLog';

      // Boolean for filtering checked-in logs
      bool isCheckedOut = false;

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


      if (response.statusCode == 200) {
        // Parse the visitor logs from the response
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];

        return data.map((item) {
          try {



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

  Future<void> exportLogs(Map<String, dynamic> visitorData) async {
    try {
      final companyId = await gateStorage.getSocietyId();
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate');

      print("Payload: ${visitorData.toString()}");

      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/visitor/sendLogs',
        data: visitorData,
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
          msg: "No data found for this gate",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        print("DioError: ${e.response?.data ?? e.message}");
      } else {
        Fluttertoast.showToast(
          msg: "No data found for this gate",
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

  // Future<void> visitorLogDetails(
  //     List<Map<String, dynamic>>? visitorData,
  //     void Function(bool) setLoading, // Callback to manage loading state
  //     ) async {
  //   try {
  //     setLoading(true); // Start loading
  //
  //     final companyDetails = await gateStorage.getSocietyDetails();
  //     final socId = await gateStorage.getSocietyId();
  //     final companyName = companyDetails["societyName"];
  //
  //     if (socId == null) {
  //       throw Exception(
  //           "Company ID is null. Please ensure the society is selected.");
  //     }
  //
  //     if (visitorData == null || visitorData.isEmpty) {
  //       throw Exception("Visitor data is null or empty");
  //     }
  //
  //     // Extract member details from the new format
  //     List<Map<String, dynamic>> memberDetails = [];
  //     if (visitorData.first.containsKey('member_details')) {
  //       memberDetails = List<Map<String, dynamic>>.from(
  //           visitorData.first['member_details'] ?? []);
  //     }
  //
  //     if (memberDetails.isEmpty) {
  //       Fluttertoast.showToast(
  //         msg: "Error: Member details are missing!",
  //         backgroundColor: Colors.red,
  //         textColor: Colors.white,
  //       );
  //       return;
  //     }
  //
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     final searchedVisitor = await prefs.getString("search_visitor_id");
  //     final selectedGateName = prefs.getString('selected_gate');
  //
  //     log("Visitor Log ID: ${GlobalStorage.visitorLogId}");
  //     log("Searched Visitor: $searchedVisitor");
  //
  //     // Iterate through all members to create the payloads
  //     List<Map<String, dynamic>> payloads = memberDetails.map((member) {
  //       final memberId = int.tryParse(member['member_ids'].toString()) ?? 0;
  //       if (memberId == 0) {
  //         log("Invalid member_id detected for member: ${member['name']}");
  //       }
  //
  //       return {
  //         "visitor_log_id": GlobalStorage.visitorLogId,
  //         "visitor_id": (GlobalStorage.visitorId == null ||
  //             GlobalStorage.visitorId!.isEmpty)
  //             ? searchedVisitor
  //             : GlobalStorage.visitorId,
  //         "company_name": companyName,
  //         "member_id": memberId,
  //         "member_name": member['name'],
  //         "unit_id": member['unit_id'],
  //         "company_id": socId,
  //         "unit_name": member['building_unit'],
  //         "in_gate": selectedGateName.toString()
  //       };
  //     }).toList();
  //
  //     log("Sending payloads: ${jsonEncode(payloads)}");
  //
  //     // Send each payload
  //     for (final payload in payloads) {
  //       if (payload['member_id'] == 0) {
  //         continue; // Skip invalid member
  //       }
  //
  //       final response = await Dio().post(
  //         'https://gateapi.cubeone.in/api/visitor/logDetails',
  //         data: payload,
  //         options: Options(
  //           headers: {"Content-Type": "application/json"},
  //         ),
  //       );
  //
  //       if (response.statusCode == 200) {
  //         log("API Response for member ${payload['member_name']}: ${response.data}");
  //       } else {
  //         log("API Error Response for member ${payload['member_name']}: ${response.data}");
  //         throw Exception("API returned status code ${response.statusCode}");
  //       }
  //     }
  //
  //     Fluttertoast.showToast(
  //       msg: "Visitor checked-in successfully for all members!",
  //       backgroundColor: Colors.green,
  //       textColor: Colors.white,
  //     );
  //   } catch (e) {
  //     if (e is DioError) {
  //       log("DioError: ${e.response?.data ?? e.message}");
  //     } else {
  //       log("Error in visitorLogDetails: $e");
  //     }
  //   } finally {
  //     setLoading(false); // Stop loading
  //   }
  // }
  Future<List<dynamic>> getBuildingsList() async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    final response = await _apiHelper.get(
      '${Environment.societyBackendUrl}/admin/building/list',
      queryParameters: {'company_id': companyId},
    );

    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> getMembersList() async {
    final String? companyId = await gateStorage.getSocietyId();
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

  /// From JSON
  factory VisitorLogMapper2.fromJson(Map<String, dynamic> json) {
    return VisitorLogMapper2(
      id: json['id'] as int?,
      visitorId: json['visitor_id'] as int?,
      visitor: json['visitor'] != null
          ? VisitorMapper.fromJson(json['visitor'])
          : null, // Handle null visitor
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

  /// To JSON
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
