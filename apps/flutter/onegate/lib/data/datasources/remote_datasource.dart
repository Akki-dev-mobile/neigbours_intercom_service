import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/config/gate_config.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/exceptions/visitor_exceptions.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/data/visitor_info.dart';
import 'package:flutter_onegate/utils/app_urls.dart';

import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/utils/network_log/dio_provider.dart';
import 'package:flutter_onegate/utils/token_refresh_util.dart';
import 'package:flutter_onegate/services/api_client/authenticated_api_client.dart';
import 'package:flutter_onegate/services/api_client/authenticated_dio_factory.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Legacy comment - KeycloakWrapper removed in favor of AppAuth

/// Remote Data Source for managing API calls
class RemoteDataSource {
  final GateStorage _gateStorage = GateStorage();

  RemoteDataSource();

  /// Get valid access token for API calls using enhanced token manager
  Future<String?> _getAccessToken() async {
    try {
      // Use EnhancedTokenRefreshManager for consistent token management
      final enhancedTokenManager = EnhancedTokenRefreshManager();
      final token = await enhancedTokenManager.getValidAccessToken();

      if (token == null) {
        log('❌ No valid access token available from enhanced manager');

        // Fallback to legacy method for backward compatibility
        log('🔄 Falling back to legacy token retrieval...');
        final legacyToken = await _gateStorage.getAccessToken();
        if (legacyToken == null) {
          log('❌ No access token available in legacy storage');
          return null;
        }

        // Check if legacy token is expired and refresh if needed
        final isExpired = await _gateStorage.isTokenExpired();
        if (isExpired) {
          log('🔄 Legacy token expired, attempting refresh...');
          final refreshed = await enhancedTokenManager.refreshTokenIfNeeded();
          if (refreshed) {
            return await enhancedTokenManager.getValidAccessToken();
          } else {
            log('❌ Enhanced token refresh failed');
            return null;
          }
        }

        return legacyToken;
      }

      log('✅ Valid access token obtained from enhanced manager');
      return token;
    } catch (e) {
      log('❌ Error getting access token: $e');
      return null;
    }
  }

  /// Handle error responses consistently
  void _handleErrorResponse() {
    // This method can be used for consistent error handling
    // Currently just a placeholder for backward compatibility
    log('⚠️ Error response handled');
  }

  final GateStorage gateStorage = GateStorage();

  // Get a Dio instance with network logging
  Dio _getDio() {
    return DioProvider().getDio();
  }

  /// Get AuthenticatedApiClient for enhanced authentication
  /// This ensures consistent token management and automatic refresh
  AuthenticatedApiClient _getAuthenticatedApiClient() {
    try {
      final apiClient = GetIt.I<AuthenticatedApiClient>();
      log("🔑 Using AuthenticatedApiClient for enhanced auth");
      return apiClient;
    } catch (e) {
      log("❌ Error getting AuthenticatedApiClient: $e");
      throw Exception(
          "AuthenticatedApiClient not available. Please ensure proper initialization.");
    }
  }

  /// Get authenticated Dio client for Gate API
  Dio _getAuthenticatedGateDio() {
    return AuthenticatedDioFactory.createOneGateApiClient(
      baseUrl: ApiUrls.gateBaseUrl,
      customHeaders: {
        'X-Service': 'RemoteDataSource-Gate',
      },
    );
  }

  /// Get authenticated Dio client for Society API
  Dio _getAuthenticatedSocietyDio() {
    return AuthenticatedDioFactory.createSocietyApiClient(
      customHeaders: {
        'X-Service': 'RemoteDataSource-Society',
      },
    );
  }

  /// Get public Dio client (no authentication)
  Dio _getPublicDio() {
    return AuthenticatedDioFactory.createPublicDio(
      baseUrl: ApiUrls.gateBaseUrl,
      customHeaders: {
        'X-Service': 'RemoteDataSource-Public',
      },
    );
  }

  /// Handle authentication errors and token refresh
  Future<bool> _handleAuthError(dynamic error) async {
    // Check if the error is related to an expired token
    bool isAuthError = false;

    if (error is DioException) {
      isAuthError = error.response?.statusCode == 401;
    } else if (error is String && error.contains("Expired refresh token")) {
      isAuthError = true;
    }

    if (isAuthError) {
      log("Authentication error detected: $error");

      // Try to refresh the token using enhanced token manager
      final enhancedTokenManager = EnhancedTokenRefreshManager();
      final refreshed = await enhancedTokenManager.refreshTokenIfNeeded();

      if (refreshed) {
        log("Token refreshed successfully using enhanced manager");
        return true; // Retry the request
      } else {
        log("Enhanced token refresh failed, redirecting to login");

        // Clear tokens and redirect to login
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');

        // Navigate to login screen
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (route) => false);

        // Show toast message
        myFluttertoast(
          msg: "Session expired. Please log in again.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );

        return false; // Don't retry the request
      }
    }

    return false; // Not an auth error, don't retry
  }

  /// Login user via AppAuth (deprecated - use AuthService instead)
  @deprecated
  Future<Map<String, dynamic>> loginUser() async {
    throw Exception(
        'Login method deprecated. Use AuthService.login() instead.');
  }

  Future<void> callMember(String mobile, BuildContext context,
      {String? name}) async {
    final url = Uri.parse("${ApiUrls.gateBaseUrl}/visitor/exotel/initiatecall");
    final body = jsonEncode({
      "from_number": "918452060059",
      "member_name": name ?? "",
      "to_number": mobile,
    });
    try {
      final accessToken = await _getAccessToken();
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          'Authorization': accessToken != null ? 'Bearer $accessToken' : '',
        },
        body: body,
      );
      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Will get a call soon",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Call failed: ${response.statusCode} ${response.reasonPhrase}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error initiating call: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
    }
  }

  Future<List<dynamic>> getCallHistory(String fromNumber) async {
    final url = Uri.parse(
        "${ApiUrls.gateBaseUrl}/visitor/exotel/callLogs?from_number=$fromNumber");
    try {
      final response = await http.get(url, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${await _getAccessToken() ?? ''}",
      });
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          return decoded['data'] as List<dynamic>;
        } else {
          throw Exception("Unexpected JSON format");
        }
      } else {
        throw Exception(
            "Error: ${response.statusCode} ${response.reasonPhrase}");
      }
    } catch (e) {
      throw Exception("Error fetching call logs: $e");
    }
  }

  Future<List<dynamic>> fetchGates() async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    try {
      // Use AuthenticatedApiClient for consistent token management
      final apiClient = _getAuthenticatedApiClient();
      final response = await apiClient.get(
        ApiUrls.gates,
        queryParameters: {'company_id': int.parse(companyId.toString())},
      );

      final responseData = response.data;

      if (responseData == null) {
        throw Exception('Response data is null');
      }

      if (responseData is List) {
        log("✅ Gates fetched successfully using enhanced auth");
        return responseData;
      } else if (responseData is Map && responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is List) {
          log("✅ Gates fetched successfully: ${data.length} gates");
          return data;
        } else {
          throw Exception('Unexpected data format in "data" key');
        }
      } else {
        throw Exception('Unexpected response structure');
      }
    } catch (e, stackTrace) {
      log('❌ Error fetching gates with enhanced auth: $e');
      log('Stack trace: $stackTrace');

      // Fallback to old method for backward compatibility
      try {
        log('🔄 Falling back to legacy method');
        final commonHeaders = await Environment.getHeaders();
        final response = await _getDio().get(
          ApiUrls.gates,
          queryParameters: {'company_id': int.parse(companyId.toString())},
          options: Options(headers: commonHeaders),
        );

        final responseData = response.data;
        if (responseData is Map && responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            log("✅ Gates fetched successfully using fallback method");
            return data;
          }
        }
        throw Exception('Fallback method also failed');
      } catch (fallbackError) {
        log('❌ Fallback method also failed: $fallbackError');
        throw Exception('Failed to fetch gates: $e');
      }
    }
  }

  /// Fetch societies
  Future<List<dynamic>> fetchSocieties(String userId) async {
    try {
      // Use AuthenticatedApiClient for consistent token management
      final apiClient = _getAuthenticatedApiClient();
      final response = await apiClient.get(
        '${ApiUrls.gateBaseUrl}/admin/companies/$userId',
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        log("✅ Societies fetched successfully using enhanced auth: $data");
        return data is List ? data : [];
      } else {
        _handleErrorResponse();
        return [];
      }
    } catch (e) {
      log('❌ Error fetching societies with enhanced auth: $e');

      // Fallback to old method for backward compatibility
      try {
        log('🔄 Falling back to legacy method for societies');
        final response = await _getDio().get(
          '${ApiUrls.gateBaseUrl}/admin/companies/$userId',
          options: Options(
            headers: {
              'Authorization': 'Bearer ${await _getAccessToken() ?? ''}',
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data['data'];
          log("✅ Societies fetched successfully using fallback method");
          return data is List ? data : [];
        } else {
          _handleErrorResponse();
          return [];
        }
      } catch (fallbackError) {
        _handleErrorResponse();
        log('❌ Fallback method also failed for societies: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> sendFcmNotification(Map<String, dynamic> requestData) async {
    try {
      final response = await _getDio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
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

  Future<GateConfig> fetchGateBaseDomain() async {
    final url = Uri.parse(
        'https://fstech-cms-db.s3.ap-south-1.amazonaws.com/gate_base_domain_f30d9e1d99.json');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print(json);
        return GateConfig.fromJson(json);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  /// Search for a visitor
  // Future<Visitor?> searchVisitor(String mobileNumber) async {
  //   try {
  //     final String? companyId = await gateStorage.getSocietyId();
  //     if (companyId == null) {
  //       throw Exception("Company ID not found. Please select a company.");
  //     }

  //     final apiUrl =
  //         '${ApiUrls.visitorEntry}?mobile_number=$mobileNumber&company_id=$companyId';

  //     log("API Request: $apiUrl");
  //     log("Bearer ${keycloakWrapper.accessToken}");

  //     final response = await _getDio().get(
  //       apiUrl,
  //       options: Options(
  //         headers: {
  //           'Content-Type': 'application/json',
  //           'Authorization': keycloakWrapper.accessToken != null
  //               ? 'Bearer ${keycloakWrapper.accessToken}'
  //               : 'sdad',
  //         },
  //       ),
  //     );
  //     final List<dynamic> data = response.data['data'] ?? [];

  //     if (data.isNotEmpty) {
  //       log("$data");

  //       final prefs = await SharedPreferences.getInstance();

  //       // Separate visitor and staff entries
  //       Map<String, dynamic>? visitorData;
  //       Map<String, dynamic>? staffData;

  //       for (var item in data) {
  //         if (item == null) continue; // ✅ Skip nulls

  //         final Map<String, dynamic> map = Map<String, dynamic>.from(item);

  //         if (map.containsKey('category') &&
  //             (map['category']?.toString().toUpperCase() == 'SECURITY' ||
  //                 map['category']?.toString().toUpperCase() == 'STAFF')) {
  //           staffData = map;
  //         } else {
  //           visitorData = map;
  //         }
  //       }

  //       // Store visitor info if found
  //       if (visitorData != null) {
  //         log("Visitor data fetched: $visitorData");

  //         final comingFrom = visitorData['coming_from'] as String;
  //         log("comingFrom $comingFrom");
  //         await gateStorage.setComingFrom(
  //           comingFrom,
  //         );
  //         final myComingFrom = await gateStorage.getComingFrom();

  //         log("comingFrom pref $myComingFrom");
  //         // Store the coming_from value in SharedPreferences
  //         // final prefs = await SharedPreferences.getInstance();
  //         // await prefs.setString('visitor_coming_from', comingFrom);

  //         GateStorage().saveImage(
  //           visitorData['visitor_image'] as String? ?? "",
  //         );
  //         log("vis data stored in shared pref coming_from $comingFrom, image ${visitorData['visitor_image']}");

  //         final visitorId = visitorData['id']?.toString() ?? "";
  //         await prefs.setString('search_visitor_id', visitorId);
  //       }

  //       // Store staff info if found
  //       // if (staffData != null) {
  //       //   final staffJson = jsonEncode(staffData);
  //       //   await prefs.setString('search_staff_info', staffJson);
  //       //   log("Staff info stored in SharedPreferences.");
  //       // }

  //       if (visitorData != null) {
  //         // Create visitor from JSON and set isStaff property
  //         Visitor visitor = Visitor.fromJson(visitorData);

  //         // Set isStaff based on whether a staff entry was found
  //         visitor.isStaff = visitor.isStaff;

  //         return visitor;
  //       } else {
  //         log("No visitor found in the response data.");
  //       }
  //     }
  //   } catch (e) {
  //     log("Error searching visitor: $e");
  //   }

  //   return null;
  // }
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception("Company ID not found. Please select a company.");
      }

      final apiUrl =
          '${ApiUrls.visitorEntry}?mobile_number=$mobileNumber&company_id=$companyId';

      log("API Request: $apiUrl");
      final accessToken = await _getAccessToken();
      log("Bearer $accessToken");

      final response = await _getDio().get(
        apiUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': accessToken != null
                ? 'Bearer $accessToken'
                : 'Bearer fallback_token',
          },
        ),
      );

      // Debug: Print complete API response
      log("🔍 API Response Status: ${response.statusCode}");
      log("🔍 API Response Headers: ${response.headers}");
      log("🔍 API Response Data: ${response.data}");
      log("🔍 API Response Data Type: ${response.data.runtimeType}");

      // Check if response contains status_code field and it's not 200
      if (response.data is Map<String, dynamic>) {
        final responseMap = response.data as Map<String, dynamic>;
        final statusCode = responseMap['status_code'] as int?;
        final message = responseMap['message'] as String?;
        final success = responseMap['success'] as bool?;

        log("🔍 Extracted status_code: $statusCode");
        log("🔍 Extracted message: $message");
        log("🔍 Extracted success: $success");

        if (statusCode != null && statusCode != 200) {
          log("🚨 Non-200 status code detected: $statusCode - Throwing VisitorApiException");
          throw VisitorApiException(message ?? 'API Error', statusCode);
        } else if (statusCode == null) {
          log("⚠️ No status_code field found in response");
        } else {
          log("✅ Status code is 200, continuing normal flow");
        }
      } else {
        log("⚠️ Response data is not a Map<String, dynamic>, type: ${response.data.runtimeType}");
      }

      final List<dynamic> data = response.data['data'] ?? [];

      if (data.isNotEmpty) {
        log("$data");

        final prefs = await SharedPreferences.getInstance();

        Map<String, dynamic>? visitorData;
        Map<String, dynamic>? staffData;

        for (var item in data) {
          if (item == null) continue;

          final Map<String, dynamic> map = Map<String, dynamic>.from(item);

          if (map.containsKey('category') &&
              (map['category']?.toString().toUpperCase() == 'SECURITY' ||
                  map['category']?.toString().toUpperCase() == 'STAFF')) {
            staffData = map;
          } else {
            visitorData = map;
          }
        }

        if (visitorData != null) {
          log("Visitor data fetched: $visitorData");

          final comingFromRaw = visitorData['coming_from'];
          final comingFrom = comingFromRaw is String ? comingFromRaw : '';

          log("comingFrom $comingFrom");

          await gateStorage.setComingFrom(comingFrom);
          final myComingFrom = await gateStorage.getComingFrom();
          log("comingFrom pref $myComingFrom");

          GateStorage().saveImage(
            visitorData['visitor_image'] as String? ?? "",
          );

          final visitorId = visitorData['id']?.toString() ?? "";
          await prefs.setString('search_visitor_id', visitorId);
        }

        if (visitorData != null) {
          Visitor visitor = Visitor.fromJson(visitorData);
          visitor.isStaff = visitor.isStaff;
          return visitor;
        } else {
          log("No visitor found in the response data.");
        }
      }
    } on DioException catch (e) {
      log("🚨 DioException searching visitor: ${e.response?.statusCode}");
      log("🚨 Error Response Headers: ${e.response?.headers}");
      log("🚨 Error Response Data: ${e.response?.data}");
      log("🚨 Error Message: ${e.message}");

      // Handle specific 400 status code with visitor already checked in message
      if (e.response?.statusCode == 400) {
        final responseData = e.response?.data;
        log("🔍 Processing 400 error - Response Data: $responseData");

        if (responseData is Map<String, dynamic>) {
          final message = responseData['message'] as String?;
          final statusCode = responseData['status_code'] as int?;

          log("🔍 Extracted message: $message");
          log("🔍 Extracted status_code: $statusCode");

          if (statusCode != 200 &&
              message != null &&
              message.contains(
                  "Visitor is already checked in within the last 3 minutes")) {
            log("✅ Throwing VisitorAlreadyCheckedInException");
            // Throw a specific exception for this case
            throw VisitorAlreadyCheckedInException(message);
          }
        }
      }

      // Re-throw the original exception for other cases
      rethrow;
    } catch (e) {
      log("Error searching visitor: $e");
      rethrow;
    }

    return null;
  }

  Future<List<PurposeCategory1>?> fetchPurpose() async {
    try {
      String apiUrl = "${ApiUrls.gateBaseUrl}/visitor/purposeCategory";

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${await _getAccessToken() ?? ''}",
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final purposesList = responseData['data'] as List;
          final purposes = purposesList
              .map((json) => PurposeCategory1.fromJson(json))
              .toList();

          for (var purpose in purposes) {
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
      _handleErrorResponse();

      debugPrint('Error fetching purposes: $e');
    }
    return null;
  }

  Future<void> fetchAndStoreFaceRecConfig() async {
    log("fetchAndStoreFaceRecConfig called");
    final url = Uri.parse(ApiUrls.facerecinfoUrl);

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final config = jsonDecode(response.body);
        await GateStorage().saveFaceRecConfig(config);
      } else {
        log("❌ Failed to fetch config: ${response.statusCode}");
      }
    } catch (e) {
      log("❗ Error fetching face recognition config: $e");
    }
  }

  /// Create a visitor
  Future<Visitor?> createVisitor(Visitor visitor) async {
    log("createVisitor called");
    try {
      final uploadImageUrl = await GateStorage().getImage();
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');
      final SharedPreferences prefs =
          await SharedPreferences.getInstance(); // Get SharedPreferences

      final selectedGateName =
          prefs.getString('selected_gate') ?? 'Default Gate';
      final comingFrom = await gateStorage.getComingFrom();
      // Prepare the data payload
      final data = {
        "name": visitor.name == "" ? "" : visitor.name,
        "mobile_number": visitor.mobile.toString(),
        "visitor_image": uploadImageUrl.toString(),
        "company_id": companyId,
        "in_gate": selectedGateName.toString(),
        "coming_from": comingFrom,
      };

      // Make the POST request to the API
      final response = await _getDio().post(
        ApiUrls.visitorEntry,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      final visitorData = response.data['data'];
      print(visitorData);
      final visitorId = visitorData['visitor_id'] as int;
      log("createvisitorresponse $response");

      await prefs.setString('visitorId', visitorId.toString());
      GlobalStorage.visitorId = visitorId.toString();

      print("$visitorId visitorId");
      log("createdVisitor:$response");

      return Visitor(
        id: visitorId,
        name: visitor.name,
        mobile: visitor.mobile,
        visitor_image: uploadImageUrl.toString(),
        isStaff: visitor.isStaff, // Preserve isStaff value from input visitor
      );
    } catch (error) {
      _handleErrorResponse();

      // Handle any errors
      log('Error creating visitor: $error');
      return null;
    }
  }

  // /// Create a visitor
  // Future<Visitor?> createVisitor(Visitor visitor) async {
  //   log("createVisitor called");
  //
  //   try {
  //     final uploadImageUrl = await GateStorage().getImage();
  //     final prefs = await SharedPreferences.getInstance();
  //     final name = prefs.getString('visitorName') ?? "";
  //
  //     final requestBody = {
  //       "name": visitor.name?.isEmpty == true ? name : visitor.name,
  //       "mobile_number": visitor.mobile.toString(),
  //       "visitor_image": uploadImageUrl,
  //       "company_id": 26,
  //     };
  //
  //     final response =
  //         await Dio().post(ApiUrls.visitorEntry, data: requestBody);
  //     final status = response.statusCode;
  //     final body = response.data;
  //
  //     log("HTTP ${status.toString()} → $body");
  //
  //     if (status == 200 && body['success'] == true && body['data'] != null) {
  //       final data = body['data'];
  //       final visitorId = (data['visitor_id'] ?? data['id']) as int;
  //       final visitorName = data['name'] ?? "Unknown";
  //       final visitorMobile = data['mobile'] ?? "";
  //       final visitorImage = data['visitor_image'] ?? "";
  //
  //       await prefs.setString('visitorId', visitorId.toString());
  //       GlobalStorage.visitorId = visitorId.toString();
  //
  //       return Visitor(
  //         id: visitorId,
  //         name: visitorName,
  //         mobile: visitorMobile,
  //         visitor_image: visitorImage,
  //         isStaff: data.containsKey("category"),
  //       );
  //     }
  //
  //     // FAILURE PATH
  //     final errorMessage = body['message'] ?? "Unknown error";
  //     log("❌ Visitor creation failed: $errorMessage");
  //     return null;
  //   } on DioError catch (dioErr) {
  //     log("❌ DioError: ${dioErr.response?.statusCode} → ${dioErr.response?.data}");
  //     return null;
  //   } catch (error) {
  //     log("❌ Unexpected error creating visitor: $error");
  //     return null;
  //   }
  // }

  Future<List<VisitorLog>?> fetchCardNumbers() async {
    try {
      final response = await fetchCheckInLogs();

      final filteredLogs =
          response.where((log) => log.visitor_card_number != null).toList();

      return filteredLogs;
    } catch (error) {
      _handleErrorResponse();

      log("Error fetching card numbers: $error");
      return null;
    }
  }

  /// Check-in a visitor
  Future<VisitorLog?> checkIn(VisitorLog visitorLog,
      [bool? statusallowed]) async {
    log("Attempting check-in...");

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
      final memberDetailsJson = prefs.getString('rows');
      List<dynamic> memberDetails = memberDetailsJson != null
          ? json.decode(memberDetailsJson) as List<dynamic>
          : [];
      final companyDetails = await gateStorage.getSocietyDetails();
      final companyName = companyDetails['societyName'] ?? "";
      var staff = prefs.getString('search_staff_info');
      print("staff $staff");

      data.addAll({
        'in_gate': selectedGateName,
        'company_name': companyName,
        'member_details': memberDetails,
        "is_always_allowed": statusallowed
      });

      // Make the POST request
      final Response response = await dio.post(
        apiUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization':
                'Bearer ${await _getAccessToken() ?? "accessToken"}',
            'Content-Type': 'application/json',
          },
        ),
      );
      log("Final Payload: $data");
      log("VisitorLog Response: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          final visitorLogResult = VisitorLog.fromJson(responseData['data']);
          log("Success - $visitorLogResult");

          final prefs = await SharedPreferences.getInstance();
          prefs.setString(
            "visitor_log",
            response.data["data"]["visitor_log_id"].toString(),
          );
          print("this is ${responseData['data']}");

          // await  gateStorage.clearStorage();åß
          return visitorLogResult;
        } else {
          _handleErrorResponse();

          log("API Response Error: ${responseData['message']}");
          _handleErrorResponse();
        }
      }
    } on DioException catch (e) {
      _handleErrorResponse();

      if (e.response != null) {
        print("Dio Error: ${e.response?.data}");
        print("Status Code: ${e.response?.statusCode}");
      } else {
        print("Dio Error: ${e.message}");
      }
    } catch (e, stackTrace) {
      _handleErrorResponse();

      print("Unexpected error during check-in: $e");
      print("Stack trace: $stackTrace");
    }

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
          headers: {
            "Content-Type": "application/json",
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
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
        _handleErrorResponse();

        log("Failed to export logs: ${response.statusMessage}");
        myFluttertoast(
          msg: "Failed to export logs: ${response.data}",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      _handleErrorResponse();

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
      final selectedGateType = prefs.getString('selected_gate_type') ?? 'both';
      final resolvedCompanyId = await gateStorage.getSocietyId();

      final String formattedDate =
          DateFormat('yyyy-MM-dd').format(DateTime.now());

      final requestBody = <String, dynamic>{
        'from_date': formattedDate,
        'to_date': formattedDate,
        'company_id': int.parse(resolvedCompanyId.toString()),
        'in_gate': selectedGateName,
        'gate_type': selectedGateType, // Include gate type in the request
      };

      if (onlyCheckout != null) {
        requestBody['only_checkout'] = onlyCheckout;
      }

      log("Fetching visitor logs with params: $requestBody");

      final accessToken = await _getAccessToken();
      final response = await http.post(
        Uri.parse(ApiUrls.visitorGetLog),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': accessToken != null ? 'Bearer $accessToken' : '',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['data']['data'] ?? [];
        log("data--$data");
        return data.map((item) => _mapToVisitorLog(item)).toList();
      } else {
        _handleErrorResponse();
        throw Exception(
            'Failed to fetch visitor logs: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  VisitorLog _mapToVisitorLog(Map<String, dynamic> item) {
    // Debug print before mapping
    print('Mapping VisitorLog from item: $item');

    // Safely parsing the visitor object
    final visitor = Visitor(
      id: item['visitor_id'] as int?,
      name: item['name'] as String? ?? '',
      mobile: item['mobile'] as String? ?? '',
      visitor_image: item['visitor_image'] as String? ?? '',
    );

    // Handling unit details as a list of BuildingAssignments
    final List<BuildingAssignment>? buildingAssignments =
        (item['unit_details'] as List<dynamic>?)?.map((unit) {
      return BuildingAssignment(
        id: null,
        // Assuming id is not provided in the unit details
        visitor_id: item['visitor_id'] as int?,
        visitor_log_id: item['visitor_log_id'] as int?,
        company_id: item['company_id'] as int? ?? 0,
        building_id: 0,
        // Default value as building_id is not provided
        unit_id: [unit['building_unit'] as String? ?? ''],
      );
    }).toList();

    // Safely handling additional details
    String? initiatedFrom;
    final additionalDetails = item['additional_details'];

    if (additionalDetails is Map<String, dynamic>) {
      initiatedFrom = additionalDetails['initiated_from'] as String?;
    }

    // Safely parsing the check-in and check-out times
    DateTime? checkInTime;
    DateTime? checkOutTime;
    if (item['visitor_check_in'] != null) {
      checkInTime = tryParseDate(item['visitor_check_in'] as String);
    }
    if (item['visitor_check_out'] != null) {
      checkOutTime = tryParseDate(item['visitor_check_out'] as String);
    }

    // Returning the mapped VisitorLog object
    final visitorLog = VisitorLog(
      id: item['visitor_log_id'] as int?,
      visitor_id: item['visitor_id'] as int? ?? 0,
      visitor: visitor,
      visitor_purpose_category_id:
          item['visitor_purpose_category_id'] as int? ?? 1,
      visitor_purpose_sub_category_id:
          item['visitor_purpose_sub_category_id'] as int?,
      visitor_building_assignment: buildingAssignments,
      visitor_count: item['visitor_count'] as int? ?? 0,
      visitor_check_in: checkInTime,
      visitor_check_out: checkOutTime,
      visitor_card_number: item['visitor_card_number'] as String?,
      visitor_coming_from: item['visitor_coming_from'] as String?,
      visitor_card_id: null,
      // Assuming null as visitor card id is not provided
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

    return visitorLog;
  }

  /// Safely attempts to parse a string into a DateTime object.
  DateTime? tryParseDate(String dateStr) {
    try {
      final parsedDate = DateFormat("yyyy-MM-dd hh:mm:ss").parse(dateStr);
      log('Successfully parsed date: $parsedDate');
      return parsedDate;
    } catch (e) {
      log('Error parsing date: $dateStr, error: $e');
      return null; // Return null if parsing fails
    }
  }

  /// Verify Guest Passcode
  Future<Map<String, dynamic>> verifyPasscode({
    required String companyId,
    String? passcode,
    int? id,
    String? mobile,
    bool? isStaff,
  }) async {
    try {
      final String url = ApiUrls.verifyGuestPasscode;
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName =
          prefs.getString('selected_gate') ?? 'Default Gate';
      final resolvedCompanyId = await gateStorage.getSocietyId();
      final Map<String, dynamic> requestData = {
        "company_id": resolvedCompanyId,
        "in_gate": selectedGateName,
        if (isStaff == false) "passcode": passcode,
        "mobile": mobile,
        //if (isStaff == false)
        "pass_id": id,
        if (isStaff == true) "is_staff": isStaff,
      };

      log("🔍 Sending request to verify passcode: $requestData");

      final response = await Dio().post(
        url,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        log("✅ Passcode verified successfully: ${response.data}");
        return response.data;
      } else {
        _handleErrorResponse();

        // log("❌ Failed to verify passcode. Status Code: ${response.statusCode}, Response: ${response.data}");
        Fluttertoast.showToast(
          msg: "Not a valid passcode!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        throw Exception('Failed to verify passcode');
      }
    } catch (e, stackTrace) {
      _handleErrorResponse();

      log("❌ Error verifying passcode: $e");
      log("StackTrace: $stackTrace");

      Fluttertoast.showToast(
        msg: "Not a valid passcode!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      throw Exception('Failed to verify passcode');
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
      _handleErrorResponse();

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
      _handleErrorResponse();

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
      _handleErrorResponse();

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
        options: Options(
          headers: {
            'Authorization': 'Bearer ${await _getAccessToken() ?? ''}',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data?['data'] ?? [];
    } catch (e) {
      log('Error fetching buildings list: $e');
      rethrow;
    }
  }

  //Otp verifiction for self checkin
  Future<Map<String, dynamic>> sendOtpForSelfCheckIn(
      String mobileNumber) async {
    final societyId = await gateStorage.getSocietyId();
    final int? companyId = int.tryParse(societyId.toString());

    if (companyId == null) {
      log('Invalid society ID: $societyId');
      throw Exception('Invalid society ID');
    }

    try {
      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/selfCheckin',
        data: {'mobile': mobileNumber, 'company_id': companyId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        log('OTP sent successfully. Response: ${response.data}');
        return response.data; // Return the response data (message and data)
      } else {
        _handleErrorResponse();

        log('Failed to send OTP: ${response.statusCode} - ${response.data}');
        throw Exception('Failed to send OTP');
      }
    } catch (e) {
      _handleErrorResponse();

      if (e is DioException) {
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
        '${ApiUrls.gateBaseUrl}/visitor/selfCheckin/verify',
        data: {
          'mobile': mobileNumber,
          'otp': otp,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        _handleErrorResponse();

        throw Exception(
            'Failed to verify self-checkin: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse();

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
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        final expiresIn = response.data?['data']['expires_in'];
        log('OTP sent successfully. Expires in: $expiresIn');
        return expiresIn;
      } else {
        _handleErrorResponse();

        log('Failed to send OTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _handleErrorResponse();

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
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        final message = response.data?['message'];
        log('OTP verified successfully. Message: $message');
        return message;
      } else {
        _handleErrorResponse();

        log('Failed to verify OTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _handleErrorResponse();

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

      final response = await Dio().patch(
        ApiUrls.visitorCheckout,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _handleErrorResponse();

        log('Check-out failed: ${response.statusCode} - ${response.data}');
        return false;
      }
    } catch (e) {
      _handleErrorResponse();

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
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      _handleErrorResponse();

      log('Error uploading parcel image: $e');
      return false;
    }
  }

  Future<List<VisitorInfo>> fetchApprovals(
      {String? logID, bool? isSecondary}) async {
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
        "to_date": formattedDate,
        "is_secondary": isSecondary ?? false,
      };

      final uri = Uri.parse(baseUrl);

      log("🔍 Sending request to: $baseUrl");
      log("📦 Request Body: ${jsonEncode(requestBody)}");

      // Try to refresh token before making the request
      String? accessToken;
      try {
        // First try to get a valid token using TokenRefreshUtil
        accessToken = await TokenRefreshUtil.getValidAccessToken();

        if (accessToken == null) {
          // If token refresh failed, try to get token from storage
          accessToken = await _gateStorage.getAccessToken();
          if (accessToken == null) {
            // If both methods fail, throw an error
            throw Exception("Expired refresh token");
          }
        }

        final response = await http.post(
          Uri.parse(baseUrl),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $accessToken",
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          log("Response data: $responseData");
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
              final dynamic unitDetailsValue = json['unit_details'];

              if (unitDetailsValue is String) {
                final String cleanedJsonString = unitDetailsValue
                    .replaceAll(r'\"', '"')
                    .replaceAll('"[', '[')
                    .replaceAll(']"', ']');

                final List<dynamic> decodedUnitDetails =
                    jsonDecode(cleanedJsonString);

                parsedUnitDetails =
                    decodedUnitDetails.map<UnitDetails>((unitJson) {
                  return UnitDetails(
                    unitId: parseToInt(unitJson['unit_id']),
                    building_unit: unitJson["building_unit"]?.toString() ?? '',
                  );
                }).toList();
              }
            } catch (e) {
              log("❌ Error decoding unit details: $e");
            }

            // ✅ Fix for `additional_details` JSON String Parsing

            Map<String, dynamic>? parsedAdditionalDetails;
            try {
              final dynamic additionalDetailsValue = json['additional_details'];

              if (additionalDetailsValue != null &&
                  additionalDetailsValue.toString().isNotEmpty) {
                if (additionalDetailsValue is String) {
                  String cleanedJson = additionalDetailsValue;

                  // ✅ Remove extra surrounding quotes if present
                  if (cleanedJson.startsWith('"') &&
                      cleanedJson.endsWith('"')) {
                    cleanedJson =
                        cleanedJson.substring(1, cleanedJson.length - 1);
                  }

                  // ✅ Fix incorrectly escaped JSON (`\"` → `"`)
                  cleanedJson = cleanedJson.replaceAll(r'\"', '"');

                  // ✅ Decode the cleaned JSON string
                  parsedAdditionalDetails = jsonDecode(cleanedJson);
                } else if (additionalDetailsValue is Map<String, dynamic>) {
                  parsedAdditionalDetails = additionalDetailsValue;
                }
              }
            } catch (e) {
              log("❌ Error parsing additional_details: $e");
              parsedAdditionalDetails =
                  {}; // Assign empty map to prevent null errors
            }

            return VisitorInfo(
              visitorId: parseToInt(json['visitor_id']),
              visitorName: json['visitor_name']?.toString() ?? '',
              visitorMobile: json['visitor_mobile']?.toString() ?? '',
              visitorImage: json['visitor_image']?.toString() ?? '',
              allowStatus: json['allow_status']?.toString() ?? '',
              visitorLogId: parseToInt(json['visitor_log_id']),
              companyId: parseToInt(json['company_id']),
              inGate: json['in_gate']?.toString() ?? '',
              visitorCount: json['visitor_count'],
              logCreatedAt: json['log_created_at']?.toString() ?? '',
              unitDetails: parsedUnitDetails.isNotEmpty
                  ? parsedUnitDetails.first
                  : UnitDetails(unitId: 0, building_unit: ''),
              memberInfo: MemberInfo(
                name: json['member_name']?.toString() ?? "",
                mobileNumber: json['memb_mobile_number']?.toString(),
                email: json['memb_email']?.toString(),
                memberId: parseToInt(json['memberid'] ?? json['member_id']),
                unitId: parseToInt(json['unitid'] ?? json['unit_id']),
                building_unit: json['building_unit']?.toString(),
                userId: json['user_id']?.toString(),
              ),
              visitorComingFrom: json['visitor_coming_from']?.toString(),
              visitorPurposeCategoryId: parseToInt(json['purpose_category_id']),
              purposeCategoryName: json['purpose_category_name']?.toString(),
              purposeSubCategoryName:
                  json['purpose_sub_category_name']?.toString(),
              additionalDetails: parsedAdditionalDetails, // ✅ Assigned here
            );
          }).toList();
          return visitorList;
        } else if (response.statusCode == 401) {
          // Handle authentication error
          await _handleAuthError("Expired refresh token");
          return [];
        } else {
          _handleErrorResponse();

          throw Exception(
              '❌ Failed to fetch approvals: ${response.statusCode}, ${response.body}');
        }
      } catch (e) {
        log("❌ Error refreshing token: $e");
        // Handle authentication error
        await _handleAuthError(e);
        // Return empty list since we can't proceed without a valid token
        return [];
      }
    } catch (e) {
      // Check if it's an authentication error
      if (e.toString().contains("Expired refresh token")) {
        await _handleAuthError(e);
        return [];
      }

      _handleErrorResponse();
      log('❌ Error fetching approvals: $e');
      rethrow;
    }
  }

  // Helper method to safely parse integers
  int parseToInt(dynamic value) {
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
      final accessToken = await _getAccessToken();
      final response = await Dio().post(
        ApiUrls.visitorSendLogs,
        data: visitorData,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer ${accessToken ?? ''}",
          },
        ),
      );

      if (response.statusCode == 200) {
        myFluttertoast(
          msg: "Visitor logs sent successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        _handleErrorResponse();

        log('Failed to send logs: ${response.statusMessage}');
      }
    } catch (e) {
      _handleErrorResponse();

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
      final accessToken = await _getAccessToken();

      final response = await Dio().post(
        ApiUrls.readStatus,
        data: {
          "member_id": memberID,
          "visitor_id": visitorId1,
        },
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer ${accessToken ?? ''}",
          },
        ),
      );

      if (response.statusCode == 200) {
        log("Success: ${response.data}");
        return response;
      } else {
        _handleErrorResponse();

        log('Failed to readStatus: ${response.statusMessage}');
        return null;
      }
    } catch (e) {
      _handleErrorResponse();

      log('Error readStatus: $e');
      return null;
    }
  }

  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // Adjust quality (0 - 100)
      minWidth: 800, // Adjust width if needed
      minHeight: 800,
    );

    return result != null
        ? File(result.path)
        : file; // Return original file if compression fails
  }

  /// Upload a file
  Future<String?> uploadFile(
      File thisfile, String userMobile, int companyId) async {
    try {
      log('File path: ${thisfile.path}');
      File file = await compressImage(thisfile);

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
        '${ApiUrls.gateBaseUrl}/visitor/uploadFile',
        data: data,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        log('Successfully uploaded: ${json.encode(response.data)}');

        var filePath = response.data['data']?['file_path'];
        if (filePath != null && filePath is String) {
          await GateStorage().saveImage(filePath);

          return filePath;
        } else {
          _handleErrorResponse();

          log('Unexpected response format: ${response.data}');
          return '';
        }
      } else {
        _handleErrorResponse();

        log('Upload failed: ${response.statusMessage}');
        return '';
      }
    } catch (e) {
      _handleErrorResponse();

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

  static const String cacheKey = 'members_list_cache';
  static const String cacheTimestampKey = 'members_list_cache_timestamp';
  static const Duration cacheDuration =
      Duration(minutes: 30); // Cache expiry time

  Future<Map<String, dynamic>> getMembersList({String? buildingName}) async {
    try {
      // Check if cached data is still valid and no building filter is applied
      if (buildingName == null) {
        final cachedData = await getCachedData();
        if (cachedData != null) {
          log('Using cached data.');
          return {'data': cachedData, 'meta': await getCachedMeta()};
        }
      }

      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final Map<String, String> queryParams = {
        "company_id": companyId,
      };

      // Add building_name parameter if provided
      if (buildingName != null && buildingName.isNotEmpty) {
        queryParams["building_name"] = buildingName;
      }

      final apiUrl = ApiUrls.memberList;
      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);
      log('API URL: $uri');

      // Ensure we have a valid token before making the request
      await TokenRefreshUtil.refreshTokenIfNeeded();

      // Get the valid access token
      final validToken = await TokenRefreshUtil.getValidAccessToken();

      if (validToken == null) {
        throw Exception('No valid access token available');
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $validToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final membersList = responseData['data'] ?? [];
        final meta = responseData['meta'] ?? {};
        log('Fetched members list: $membersList');
        log('Meta data: $meta');

        // Cache the new data only if no building filter is applied
        if (buildingName == null) {
          await cacheData(membersList);
          await cacheMeta(meta);
        }

        return {'data': membersList, 'meta': meta};
      } else {
        _handleErrorResponse();

        log('Failed to fetch member list: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch member list: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse();

      log('Error fetching member list: $e');
      rethrow;
    }
  }

  // Get cached data if it's still valid
  Future<List<dynamic>?> getCachedData() async {
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
      _handleErrorResponse();

      // Cache is expired
      return null;
    }
  }

  // Cache the data with a timestamp
  Future<void> cacheData(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(data);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString(cacheKey, jsonData);
    await prefs.setInt(cacheTimestampKey, timestamp);
  }

  // Cache meta data
  static const String metaCacheKey = 'members_meta_cache';

  Future<void> cacheMeta(Map<String, dynamic> meta) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(meta);
    await prefs.setString(metaCacheKey, jsonData);
  }

  // Get cached meta data
  Future<Map<String, dynamic>?> getCachedMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(metaCacheKey);
    if (cachedJson == null) return {};
    return jsonDecode(cachedJson) as Map<String, dynamic>;
  }

  /// Fetch units for a specific building
  Future<List<dynamic>> getUnitsList(int buildingId) async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      // Ensure we have a valid token before making the request
      await TokenRefreshUtil.refreshTokenIfNeeded();

      // Get the valid access token
      final validToken = await TokenRefreshUtil.getValidAccessToken();

      if (validToken == null) {
        throw Exception('No valid access token available');
      }

      final response = await Dio().get(
        ApiUrls.unitList,
        queryParameters: {
          'company_id': companyId,
          'building_id': buildingId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data?['data'] ?? [];
    } catch (e) {
      _handleErrorResponse();

      log('Error fetching unit list: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchStaffById(int staffId) async {
    try {
      final String? companyId = await gateStorage.getSocietyId();
      if (companyId == null) throw Exception('Company ID not found.');

      final String url =
          'https://societybackend.cubeone.in/api/admin/staffs/edit_staff/$staffId?company_id=$companyId';

      final accessToken = await _getAccessToken();
      final response = await Dio().get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${accessToken ?? ''}',
            'Content-Type': 'application/json',
          },
        ),
      );

      log("Staff by ID response: ${response.data}");

      if (response.statusCode == 200) {
        return response.data;
      } else {
        _handleErrorResponse();
        throw Exception('Failed to fetch staff by ID: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse();
      log('Error fetching staff by ID: $e');
      rethrow;
    }
  }

  /// Fetch staff list for a company
  Future<List<StaffModel>> fetchStaffList(String companyId) async {
    try {
      final accessToken = await _getAccessToken();
      final response = await Dio().get(
        ApiUrls.staffList,
        queryParameters: {'company_id': companyId},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${accessToken ?? ''}',
            'Content-Type': 'application/json',
          },
        ),
      );

      log("response--$response");
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data?['data'];
        log("data--$data");
        return data.map<StaffModel>((e) => StaffModel.fromJson(e)).toList();
      } else {
        _handleErrorResponse();

        throw Exception('Failed to fetch staff list: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse();

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
        options: Options(
          headers: {
            "Content-Type": "application/json",
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
        data: {
          'member_mobile_number': memberMobileNumber,
          'visitor_id': visitorId,
          'member_id': memberId,
          'visitor_log_id': visitorLogId,
          'purpose_category': purposeCategory,
        },
      );

      if (response.statusCode != 200) {
        _handleErrorResponse();

        throw Exception(
            'Failed to make Exotel call. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse();

      throw Exception('Error making Exotel call: $e');
    }
  }

  Future<List<dynamic>> fetchParcels() async {
    final String? companyId = await gateStorage.getSocietyId();

    String url = '${ApiUrls.gateBaseUrl}/visitor/parcelData/$companyId';
    log(url); // Changed from print to log
    try {
      // Ensure we have a valid token before making the request
      await TokenRefreshUtil.refreshTokenIfNeeded();

      // Get the valid access token
      final validToken = await TokenRefreshUtil.getValidAccessToken();

      if (validToken == null) {
        throw Exception('No valid access token available');
      }

      final response = await Dio().get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
        ),
      );
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
        _handleErrorResponse();

        log('Failed to fetch parcels: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _handleErrorResponse();

      log('Error fetching parcels: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> verifyParcelOtp(
      String parcelId, String otp) async {
    try {
      log("Starting verifyParcelOtp API call...");
      log("Request Data -> parcel_id: $parcelId, otp: $otp");

      final accessToken = await _getAccessToken();
      final response = await http.post(
        Uri.parse("${ApiUrls.gateBaseUrl}/visitor/parcelOtpVerify"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': accessToken != null ? 'Bearer $accessToken' : '',
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
        _handleErrorResponse();

        log("Failed to verify parcel OTP. Status Code: ${response.statusCode}, Response Body: ${response.body}");
        throw Exception('Failed to verify parcel OTP');
      }
    } catch (e, stackTrace) {
      _handleErrorResponse();

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
      final accessToken = await _getAccessToken();
      final response = await http.post(
        Uri.parse("${ApiUrls.gateBaseUrl}/visitor/parcelOtp"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': accessToken != null ? 'Bearer $accessToken' : '',
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
        _handleErrorResponse();

        log("Failed to load parcel OTP: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to load parcel OTP');
      }
    } catch (e) {
      _handleErrorResponse();

      log("Error in getParcelOtp: $e");
      throw Exception('Failed to load parcel OTP');
    }
  }

  Future<dynamic> fetchStaffCategory() async {
    final String? companyId = await gateStorage.getSocietyId();
    if (companyId == null) throw Exception('Company ID not found.');

    final String url =
        'https://socbackend.cubeone.in/api/admin/staffs/settings?company_id=$companyId&per_page=100';

    try {
      final accessToken = await _getAccessToken();
      final response = await Dio().get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${accessToken ?? ''}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        log("Categories${response.data.toString()}");
        return response.data;
      } else {
        _handleErrorResponse();

        throw Exception(
            'Failed to fetch staff category: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse();

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
        'https://socbackend.cubeone.in/api/admin/staffs/addStaff?company_id=$companyId';

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
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      log('Response status: ${response.statusCode}');
      log('Response data: ${response.data}');

      if (response.statusCode == 200) {
        log("Staff added successfully: ${response.data}");
        return response.data;
      } else {
        _handleErrorResponse();

        log('Error response: ${response.data}');
        throw Exception(
            'Server returned ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      _handleErrorResponse();

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
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
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
        _handleErrorResponse();

        log('Error response: ${response.data}');
        throw Exception(
            'Server returned ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      _handleErrorResponse();

      log('Error editing staff: $e');

      if (e is DioException && e.response?.statusCode == 400) {
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
        _handleErrorResponse();

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
        'https://socbackend.cubeone.in/api/admin/file-upload?company_id=$companyId';

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
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        print("images${response.data}");
        return response.data as Map<String, dynamic>;
      } else {
        _handleErrorResponse();

        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse();

      print('Error uploading image: $e');
      return null;
    }
  }

  /// Update visitor details
  Future<bool> updateVisitor(Visitor visitor) async {
    try {
      // Retrieve the visitor ID from SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var searchedVisitorId = prefs.getString('search_visitor_id');
      searchedVisitorId = prefs.getString('visitorId');
      if (searchedVisitorId == null) {
        throw Exception(
            'No visitor ID found. Please search for a visitor first.');
      }

      final comingFrom = await gateStorage.getComingFrom();
      log("updateVisitor : $comingFrom");
      // Prepare the API URL
      final url = '${ApiUrls.visitorEntry}/$searchedVisitorId';

      // Prepare the request payload
      final data = {
        "name": visitor.name,
        "mobile_number": visitor.mobile,
        // "coming_from": comingFrom, //to check here has saurav changed this
        "visitor_image": visitor.visitor_image,
        "isStaff": visitor.isStaff, // Include isStaff property in the update
      };

      log("comingFrom updateVisitor data: $data");

      // Send the PATCH request
      final response = await Dio().patch(
        url,
        data: data,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            'Authorization': await _getAccessToken() != null
                ? 'Bearer ${await _getAccessToken()}'
                : '',
          },
        ),
      );

      // Check for success response
      if (response.statusCode == 200) {
        log("Visitor updated successfully!");
        return true;
      } else {
        _handleErrorResponse();

        log("Failed to update visitor: ${response.statusCode} - ${response.data}");
        return false;
      }
    } catch (e) {
      _handleErrorResponse();

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
  // Complete implementation with **ALL METHODS** and utilities included.
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
