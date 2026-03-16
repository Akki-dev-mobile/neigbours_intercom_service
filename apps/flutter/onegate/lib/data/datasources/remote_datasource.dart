import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/config/gate_config.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';

import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor_log_response.dart';
import 'package:flutter_onegate/domain/exceptions/visitor_exceptions.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/data/visitor_info.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/visitor_sorting_utility.dart';

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

  /// Login user with username/password against backend auth endpoint
  ///
  /// This uses the public (unauthenticated) API client and expects the backend
  /// to return a Keycloak-style access token response with embedded user_info,
  /// matching `AccessTokenResponse` / `AccessTokenResponseMapper`.
  Future<Map<String, dynamic>> loginWithCredentials({
    required String username,
    required String password,
    String method = 'password',
  }) async {
    try {
      final dio = _getPublicDio();

      final response = await dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'method': method,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        log('✅ LoginWithCredentials successful');
        return data;
      }

      log(
        '❌ LoginWithCredentials failed: ${response.statusCode} ${response.statusMessage}',
      );
      throw Exception(
        'Login failed with status ${response.statusCode}: ${response.statusMessage}',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      log('❌ DioException during loginWithCredentials: $status $body');
      throw Exception(
        'Login request failed${status != null ? ' (HTTP $status)' : ''}',
      );
    } catch (e) {
      log('❌ Unexpected error during loginWithCredentials: $e');
      rethrow;
    }
  }

  /// Login using the same Keycloak API as browser/WebView flow:
  /// token endpoint (password grant) + userinfo endpoint.
  /// Returns a map compatible with AccessTokenResponseMapper after merging
  /// companies from the gate API (caller should add user_info.companies).
  Future<Map<String, dynamic>> loginWithKeycloakCredentials({
    required String username,
    required String password,
  }) async {
    try {
      final tokenUri = Uri.parse(AppAuthConfigManager.tokenEndpoint);
      final body = {
        'grant_type': 'password',
        'client_id': AppAuthConfigManager.clientId,
        'client_secret': AppAuthConfigManager.clientSecret,
        'username': username,
        'password': password,
        'scope': AppAuthConfigManager.scopes.join(' '),
      };
      final response = await http.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&'),
      );

      if (response.statusCode != 200) {
        log(
            '❌ Keycloak token failed: ${response.statusCode} ${response.body}');
        throw Exception(
            'Login failed: ${response.statusCode} ${response.body}');
      }

      final tokenData =
          jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No access token in Keycloak response');
      }

      final userinfoUri = Uri.parse(AppAuthConfigManager.userInfoEndpoint);
      final userinfoResponse = await http.get(
        userinfoUri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (userinfoResponse.statusCode != 200) {
        log(
            '❌ Keycloak userinfo failed: ${userinfoResponse.statusCode} ${userinfoResponse.body}');
        throw Exception(
            'Failed to get user info: ${userinfoResponse.statusCode}');
      }

      final userInfo =
          jsonDecode(userinfoResponse.body) as Map<String, dynamic>;
      log('✅ Keycloak login (token + userinfo) successful');

      return {
        'access_token': accessToken,
        'refresh_token': tokenData['refresh_token'],
        'expires_in': tokenData['expires_in'],
        'refresh_expires_in': tokenData['refresh_expires_in'],
        'token_type': tokenData['token_type'],
        'id_token': tokenData['id_token'],
        'scope': tokenData['scope'],
        'user_info': userInfo,
      };
    } catch (e) {
      log('❌ loginWithKeycloakCredentials failed: $e');
      rethrow;
    }
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

  /// Fetches gates for the given [companyId] (society). When [companyId] is
  /// provided and valid, it is used; otherwise falls back to GateStorage society_id.
  /// This ensures the selected company (e.g. DEMO CUBE ONE) is used for the API call.
  Future<List<dynamic>> fetchGates([int? companyId]) async {
    final String? storedSocietyId = await gateStorage.getSocietyId();
    final String companyIdStr = (companyId != null && companyId > 0)
        ? companyId.toString()
        : (storedSocietyId ?? '');
    if (companyIdStr.isEmpty) {
      throw Exception('Company ID not found. Please select a society first.');
    }

    try {
      // Use AuthenticatedApiClient for consistent token management.
      // Send company_id as string; some backends return 400 when given an int.
      final apiClient = _getAuthenticatedApiClient();
      final response = await apiClient.get(
        ApiUrls.gates,
        queryParameters: {'company_id': companyIdStr},
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

      // Fallback 1: retry /admin/gates with legacy headers (string company_id)
      try {
        log('🔄 Falling back to legacy method');
        final commonHeaders = await Environment.getHeaders();
        final response = await _getDio().get(
          ApiUrls.gates,
          queryParameters: {'company_id': companyIdStr},
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

        // Fallback 2: try /gates (non-admin) with society_id; used successfully elsewhere
        try {
          log('🔄 Trying /gates with society_id');
          final apiClient = _getAuthenticatedApiClient();
          final response = await apiClient.get(
            '${ApiUrls.gateBaseUrl}/gates',
            queryParameters: {'society_id': companyIdStr},
          );
          final responseData = response.data;
          if (responseData == null) throw Exception('Response data is null');
          if (responseData is List) {
            log("✅ Gates fetched successfully via /gates?society_id");
            return responseData;
          }
          if (responseData is Map && responseData.containsKey('data')) {
            final data = responseData['data'];
            if (data is List) {
              log("✅ Gates fetched successfully via /gates?society_id (wrapped)");
              return data;
            }
          }
        } catch (altError) {
          log('❌ /gates fallback failed: $altError');
        }

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

          // Only store coming from if it's not empty
          if (comingFrom.isNotEmpty) {
            await gateStorage.setComingFrom(comingFrom);
            final myComingFrom = await gateStorage.getComingFrom();
            log("comingFrom pref $myComingFrom");
          } else {
            // Clear any existing coming from value
            await gateStorage.setComingFrom("");
          }

          GateStorage().saveImage(
            visitorData['visitor_image'] as String? ?? "",
          );

          final visitorId = visitorData['id']?.toString() ?? "";
          await prefs.setString('search_visitor_id', visitorId);
        } else {
          // Clear any existing coming from value if no visitor data found
          await gateStorage.setComingFrom("");
        }

        if (visitorData != null) {
          Visitor visitor = Visitor.fromJson(visitorData);
          visitor.isStaff = visitor.isStaff;
          return visitor;
        } else {
          log("No visitor found in the response data.");
        }
      } else {
        // Clear any existing coming from value if no data found
        await gateStorage.setComingFrom("");
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

      // Clear any existing coming from value on error
      await gateStorage.setComingFrom("");

      // Re-throw the original exception for other cases
      rethrow;
    } catch (e) {
      log("Error searching visitor: $e");

      // Clear any existing coming from value on error
      await gateStorage.setComingFrom("");

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

      // Ensure additional_details contains initiated_from (API-driven, not SharedPreferences)
      final Map<String, dynamic> additionalDetails = <String, dynamic>{};
      if (visitorLog.initiated_from != null) {
        additionalDetails['initiated_from'] = visitorLog.initiated_from;
      }
      if (additionalDetails.isNotEmpty) {
        data['additional_details'] = additionalDetails;
      }

      // Override datetime formatting to match API expectations (YYYY-MM-DD HH:MM:SS)
      data['visitor_check_in'] =
          _formatDateTime(visitorLog.visitor_check_in ?? DateTime.now());

      if (visitorLog.visitor_check_out != null) {
        data['visitor_check_out'] =
            _formatDateTime(visitorLog.visitor_check_out!);
      } else {
        data['visitor_check_out'] = null; // Explicitly set to null for API
      }

      // Ensure visitor_card_number has a default value if null
      if (data['visitor_card_number'] == null ||
          data['visitor_card_number'] == '') {
        data['visitor_card_number'] = 'V0'; // Default value as per API spec
      }

      // Ensure vehicle_number is empty string if null
      if (data['vehicle_number'] == null) {
        data['vehicle_number'] = '';
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

      // Enhanced logging for debugging
      log("=== VISITOR LOG API DEBUG ===");
      log("API URL: $apiUrl");
      log("Initiated From: ${data['initiated_from']}");
      log("Visitor ID: ${data['visitor_id']}");
      log("Purpose Category ID: ${data['visitor_purpose_category_id']}");
      log("Check-in Time: ${data['visitor_check_in']}");
      log("Company ID: ${data['company_id']}");
      log("Member Details Count: ${memberDetails.length}");
      log("Final Payload: ${json.encode(data)}");

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
      log("VisitorLog Response Status: ${response.statusCode}");
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

          // Trigger PATCH API for self entry visitors to sync with Gatekeeper dashboard
          if (visitorLog.initiated_from == "self_entry" &&
              visitorLog.visitor_id != null) {
            log("Triggering PATCH API for self entry visitor log sync using visitor_id: ${visitorLog.visitor_id}");
            await _updateVisitorLogForSelfEntry(
                visitorLog.visitor_id.toString());
          }

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

      // Handle response
      if (response.statusCode == 200) {
        log("Export Logs Response: ${response.data}");
        try {
          final data = response.data;
          if (data is Map<String, dynamic>) {
            final success = data['success'] == true;
            final statusCode = data['status_code'];
            final message = data['message']?.toString();
            if (!success || (statusCode is int && statusCode != 200)) {
              // Surface backend message (e.g., "No data found")
              throw Exception(message ?? 'Export failed');
            }
          }
        } catch (e) {
          // If parsing fails, assume success already handled
        }
      } else {
        _handleErrorResponse();
        log("Failed to export logs: ${response.statusMessage}");
        throw Exception('Failed to export logs');
      }
    } catch (e) {
      _handleErrorResponse();

      // Handle errors during log export
      log("Error exporting logs: $e");
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchCheckInLogs({
    int currentPage = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    debugPrint(
        "🔍 [FETCH] fetchCheckInLogs() called - will use onlyCheckout: false, page: $currentPage, perPage: $perPage, search: '${searchQuery ?? 'none'}'");
    return _fetchVisitorLogs(
      onlyCheckout: false, // Explicitly set to false for Visitor-In
      currentPage: currentPage,
      perPage: perPage,
      searchQuery: searchQuery,
    );
  }

  Future<List<VisitorLog>> fetchAllLogs({
    int currentPage = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    debugPrint(
        "🔍 [FETCH] fetchAllLogs() called - will NOT pass onlyCheckout parameter (shows all visitors), page: $currentPage, perPage: $perPage, search: '${searchQuery ?? 'none'}'");
    return _fetchVisitorLogs(
      currentPage: currentPage,
      perPage: perPage,
      searchQuery: searchQuery,
    );
  }

  Future<List<VisitorLog>> fetchCheckOutLogs({
    int currentPage = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    debugPrint(
        "🚨 [FETCH] fetchCheckOutLogs() called - will use onlyCheckout: true, page: $currentPage, perPage: $perPage, search: '${searchQuery ?? 'none'}'");
    debugPrint("🚨 [FETCH] This will only show checked-out visitors!");
    return _fetchVisitorLogs(
      onlyCheckout: true, // Explicitly set to true for Visitor-Out
      currentPage: currentPage,
      perPage: perPage,
      searchQuery: searchQuery,
    );
  }

  /// Fetch visitor counts using V2 API
  /// Returns counts for In-Out, Visitor-In, and Visitor-Out
  Future<Map<String, int>> fetchVisitorCounts({
    String? fromDate,
    String? toDate,
  }) async {
    try {
      // Step 1: Fetch gate information
      final gateInfo = await fetchAndUpdateGateInfo('visitor counts');
      final selectedGateName = gateInfo['gateName']!;

      debugPrint("🎯 VISITOR COUNTS V2 - Using gate: '$selectedGateName'");

      // Step 2: Get company ID
      final resolvedCompanyId = await gateStorage.getSocietyId();

      final String defaultDate =
          DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Build query parameters for GET request
      final queryParams = <String, String>{
        'company_id': resolvedCompanyId.toString(),
        'in_gate': selectedGateName,
        'gate_type': gateInfo['gateType']!,
        'from_date': fromDate ?? defaultDate,
        'to_date': toDate ?? defaultDate,
        'per_page': '1', // We only need counts, not data
        'current_page': '1',
      };

      // Build URL with query parameters
      final uri = Uri.parse(ApiUrls.visitorGetLogV2).replace(
        queryParameters: queryParams,
      );

      debugPrint("🌐 Fetching visitor counts V2 from: $uri");

      final accessToken = await _getAccessToken();
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': accessToken != null ? 'Bearer $accessToken' : '',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Log the raw response for debugging
        debugPrint("🔍 Raw API Response: $responseData");
        debugPrint("🔍 Response Type: ${responseData.runtimeType}");

        // Try to parse safely without throwing type errors
        Map<String, int> counts;
        try {
          // Attempt to use VisitorLogResponse for consistency, but with error handling
          final visitorLogResponse = VisitorLogResponse.fromJson(responseData);

          counts = <String, int>{
            'total': visitorLogResponse.total,
            'visitor_in': visitorLogResponse.checkedInCount,
            'visitor_out': visitorLogResponse.checkedOutCount,
          };
        } catch (parseError) {
          debugPrint("⚠️ VisitorLogResponse parsing failed: $parseError");
          debugPrint("🔄 Falling back to direct field extraction...");

          // Fallback: Count visitors manually from the response data
          counts = _countVisitorsFromResponse(responseData);
        }

        log("📊 VISITOR COUNTS FETCHED:");
        log("📈 Total (In-Out): ${counts['total']}");
        log("📥 Visitor-In: ${counts['visitor_in']}");
        log("📤 Visitor-Out: ${counts['visitor_out']}");

        return counts;
      } else {
        _handleErrorResponse();
        throw Exception(
            'Failed to fetch visitor counts V2: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      log('❌ Error fetching visitor counts: $e');

      // Return default counts instead of failing completely
      log('🔄 Returning default visitor counts due to error');
      return <String, int>{
        'total': 0,
        'visitor_in': 0,
        'visitor_out': 0,
      };
    }
  }

  /// Helper method to safely extract integer values from API response data
  int _extractIntSafely(Map<String, dynamic> data, String key) {
    try {
      final value = data[key];
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    } catch (e) {
      debugPrint("⚠️ Error extracting $key: $e");
      return 0;
    }
  }

  /// Helper method to count visitors from the API response data
  Map<String, int> _countVisitorsFromResponse(
      Map<String, dynamic> responseData) {
    try {
      debugPrint("🔍 Counting visitors from response data...");

      // Navigate to the visitors array: response.data.data
      final data = responseData['data'];
      if (data == null) {
        debugPrint("⚠️ No 'data' field in response");
        return {'total': 0, 'visitor_in': 0, 'visitor_out': 0};
      }

      final visitors = data['data'];
      if (visitors == null || visitors is! List) {
        debugPrint("⚠️ No visitors array found in response data");
        return {'total': 0, 'visitor_in': 0, 'visitor_out': 0};
      }

      debugPrint("🔍 Found ${visitors.length} visitors to count");

      int totalCount = visitors.length;
      int checkedInCount = 0;
      int checkedOutCount = 0;

      // Count visitors by their check-in/check-out status
      for (final visitor in visitors) {
        if (visitor is Map<String, dynamic>) {
          final isCheckedOut = visitor['is_checked_out'] ?? false;
          if (isCheckedOut == true || isCheckedOut == 'true') {
            checkedOutCount++;
          } else {
            checkedInCount++;
          }

          // Log each visitor for debugging
          debugPrint(
              "🔍 Visitor: ${visitor['name']} - Checked out: $isCheckedOut");
        }
      }

      debugPrint("📊 Manual count results:");
      debugPrint("📈 Total visitors: $totalCount");
      debugPrint("📥 Checked-in visitors: $checkedInCount");
      debugPrint("📤 Checked-out visitors: $checkedOutCount");

      return {
        'total': totalCount,
        'visitor_in': checkedInCount,
        'visitor_out': checkedOutCount,
      };
    } catch (e) {
      debugPrint("❌ Error counting visitors from response: $e");
      return {'total': 0, 'visitor_in': 0, 'visitor_out': 0};
    }
  }

  /// Helper method to extract visitor data directly from API response when parsing fails
  List<dynamic> _extractVisitorDataFromResponse(
      Map<String, dynamic> responseData) {
    try {
      debugPrint("🔍 Extracting visitor data from response...");

      // Navigate to the visitors array: response.data.data
      final data = responseData['data'];
      if (data == null) {
        debugPrint("⚠️ No 'data' field in response");
        return [];
      }

      final visitors = data['data'];
      if (visitors == null || visitors is! List) {
        debugPrint("⚠️ No visitors array found in response data");
        return [];
      }

      debugPrint(
          "✅ Successfully extracted ${visitors.length} visitors from response");

      // Log the first visitor for debugging
      if (visitors.isNotEmpty) {
        debugPrint("🔍 First visitor: ${visitors[0]}");
      }

      return visitors;
    } catch (e) {
      debugPrint("❌ Error extracting visitor data from response: $e");
      return [];
    }
  }

  /// Helper method to fetch and update gate information from API before making visitor-related calls
  ///
  /// This method ensures that visitor logs and approvals are always fetched with the most up-to-date
  /// gate information from the server rather than relying on potentially stale cached values.
  ///
  /// Flow:
  /// 1. Calls the gates API (AppUrls.gates) to fetch current gate data
  /// 2. Updates selectedGateName and selectedGateType from the API response
  /// 3. Saves the updated gate information to SharedPreferences
  /// 4. Falls back to cached values if the gates API call fails
  ///
  /// Returns a Map with 'gateName' and 'gateType' keys

  // In-memory cache for gate information
  Future<Map<String, String>>? _gateInfoFuture;
  DateTime? _cacheTimestamp;

  Future<Map<String, String>> fetchAndUpdateGateInfo(String context) {
    if (_gateInfoFuture != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!).inMinutes < 1) {
      debugPrint("🚪 Using cached gate information future for $context");
      return _gateInfoFuture!;
    }

    debugPrint("🚪 Fetching new gate information for $context");
    _gateInfoFuture = _fetchAndUpdateGateInfoInternal(context);
    return _gateInfoFuture!;
  }

  Future<Map<String, String>> _fetchAndUpdateGateInfoInternal(
      String context) async {
    String selectedGateName = 'Default Gate';
    String selectedGateType = 'both';

    try {
      final gatesData = await fetchGates();
      debugPrint("✅ Gates API response for $context: $gatesData");
      debugPrint("🔍 Gates API response type: ${gatesData.runtimeType}");
      debugPrint("🔍 Gates API response length: ${gatesData.length}");

      if (gatesData.isNotEmpty) {
        // Log all gates for debugging with detailed structure analysis
        debugPrint("🔍 ===== COMPLETE GATES API RESPONSE ANALYSIS =====");
        for (int i = 0; i < gatesData.length; i++) {
          final gate = gatesData[i];
          debugPrint("🔍 Gate $i COMPLETE DATA: $gate");
          debugPrint("🔍 Gate $i TYPE: ${gate.runtimeType}");

          if (gate is Map<String, dynamic>) {
            debugPrint("🔍 Gate $i ALL KEYS: ${gate.keys.toList()}");
            debugPrint("🔍 Gate $i ALL VALUES: ${gate.values.toList()}");

            // Check every possible field that might contain the gate name
            gate.forEach((key, value) {
              debugPrint(
                  "🔍 Gate $i Field '$key': '$value' (type: ${value.runtimeType})");
            });
          }
        }
        debugPrint("🔍 ===== END GATES API RESPONSE ANALYSIS =====");

        // Find the appropriate gate instead of just taking the first one
        Map<String, dynamic>? selectedGate;

        // Strategy 1: Check if there's a cached gate name and find matching gate
        final prefs = await SharedPreferences.getInstance();
        final cachedGateName = prefs.getString('selected_gate');
        debugPrint(
            "🔍 Cached gate name from SharedPreferences: '$cachedGateName'");

        if (cachedGateName != null && cachedGateName != 'Default Gate') {
          // Try to find a gate that matches the cached name
          for (final gate in gatesData) {
            if (gate is Map<String, dynamic>) {
              final gateName = gate['gate_name']?.toString() ??
                  gate['name']?.toString() ??
                  gate['gateName']?.toString();
              if (gateName == cachedGateName) {
                selectedGate = gate;
                debugPrint(
                    "🎯 Found matching gate for cached name '$cachedGateName': $gate");
                break;
              }
            }
          }
        }

        // Strategy 2: If no cached match, look for active/default gate
        if (selectedGate == null) {
          for (final gate in gatesData) {
            if (gate is Map<String, dynamic>) {
              // Check for active, default, or primary flags
              final isActive =
                  gate['is_active'] == true || gate['active'] == true;
              final isDefault =
                  gate['is_default'] == true || gate['default'] == true;
              final isPrimary =
                  gate['is_primary'] == true || gate['primary'] == true;

              if (isActive || isDefault || isPrimary) {
                selectedGate = gate;
                debugPrint("🎯 Found active/default/primary gate: $gate");
                break;
              }
            }
          }
        }

        // Strategy 3: If still no gate found, use the first valid gate as fallback
        if (selectedGate == null && gatesData.isNotEmpty) {
          for (final gate in gatesData) {
            if (gate is Map<String, dynamic>) {
              selectedGate = gate;
              debugPrint("🎯 Using first valid gate as fallback: $gate");
              break;
            }
          }
        }

        if (selectedGate == null) {
          debugPrint("❌ No valid gate found in gates API response");
          throw Exception("No valid gate found in gates API response");
        }

        debugPrint("🔍 SELECTED GATE for extraction: $selectedGate");
        debugPrint("🔍 Selected gate type: ${selectedGate.runtimeType}");

        // Log all available keys in the gate object
        debugPrint(
            "🔍 Available keys in selected gate object: ${selectedGate.keys.toList()}");

        // Check ALL possible field names that might contain gate name
        final possibleGateNameFields = [
          'gate_name',
          'name',
          'gateName',
          'gate',
          'title',
          'label',
          'display_name',
          'gate_title',
          'gate_label',
          'description',
          'gate_description',
          'identifier',
          'gate_identifier'
        ];

        debugPrint("🔍 ===== CHECKING ALL POSSIBLE GATE NAME FIELDS =====");
        String? gateNameFromApi;
        String? selectedFieldName;

        for (String fieldName in possibleGateNameFields) {
          final fieldValue = selectedGate[fieldName];
          debugPrint(
              "🔍 Field '$fieldName': '$fieldValue' (type: ${fieldValue.runtimeType})");

          // Look for a field that contains "Gate 777" or similar pattern
          if (fieldValue != null && fieldValue.toString().isNotEmpty) {
            final fieldStr = fieldValue.toString();
            if (fieldStr.toLowerCase().contains('gate') &&
                fieldStr.length > 4) {
              debugPrint(
                  "🎯 POTENTIAL GATE NAME FIELD FOUND: '$fieldName' = '$fieldStr'");
              if (gateNameFromApi == null) {
                gateNameFromApi = fieldStr;
                selectedFieldName = fieldName;
              }
            }
          }
        }

        // If no field with "gate" pattern found, try the standard fields
        if (gateNameFromApi == null) {
          gateNameFromApi = selectedGate['gate_name']?.toString() ??
              selectedGate['name']?.toString() ??
              selectedGate['gateName']?.toString();
          selectedFieldName = gateNameFromApi != null
              ? (selectedGate['gate_name'] != null
                  ? 'gate_name'
                  : selectedGate['name'] != null
                      ? 'name'
                      : 'gateName')
              : null;
        }

        log("🔍 ===== GATE NAME EXTRACTION RESULT =====");
        log("🔍 Selected field: '$selectedFieldName'");
        log("🔍 Extracted gate name: '$gateNameFromApi'");

        // Check for different possible key names for gate type
        final possibleGateTypeFields = [
          'gate_type',
          'type',
          'gateType',
          'category',
          'kind'
        ];

        log("🔍 ===== CHECKING ALL POSSIBLE GATE TYPE FIELDS =====");
        String? gateTypeFromApi;

        for (String fieldName in possibleGateTypeFields) {
          final fieldValue = selectedGate[fieldName];
          debugPrint("🔍 Type field '$fieldName': '$fieldValue'");
          if (fieldValue != null &&
              fieldValue.toString().isNotEmpty &&
              gateTypeFromApi == null) {
            gateTypeFromApi = fieldValue.toString();
          }
        }

        debugPrint("🔍 Final extracted gate_name: '$gateNameFromApi'");
        debugPrint("🔍 Final extracted gate_type: '$gateTypeFromApi'");

        // Validate that we got valid values
        if (gateNameFromApi != null && gateNameFromApi.isNotEmpty) {
          selectedGateName = gateNameFromApi;
          debugPrint("✅ Successfully extracted gate name: '$selectedGateName'");
        } else {
          debugPrint("⚠️ Could not extract gate name, using default");
          selectedGateName = 'Default Gate';
        }

        if (gateTypeFromApi != null && gateTypeFromApi.isNotEmpty) {
          selectedGateType = gateTypeFromApi;
          debugPrint("✅ Successfully extracted gate type: '$selectedGateType'");
        } else {
          debugPrint("⚠️ Could not extract gate type, using default");
          selectedGateType = 'both';
        }

        debugPrint(
            "📝 Final gate info from API for $context - Name: '$selectedGateName', Type: '$selectedGateType'");

        // Additional validation: Check if extracted gate name makes sense
        if (selectedGateName.toLowerCase() == 'gate' ||
            selectedGateName.length < 4) {
          debugPrint(
              "⚠️ WARNING: Extracted gate name '$selectedGateName' seems too generic!");
          debugPrint(
              "⚠️ This might indicate we're extracting from the wrong field");
          debugPrint(
              "⚠️ Expected something like 'Gate 777' but got '$selectedGateName'");
        }

        // Save updated gate information to SharedPreferences (reuse existing prefs instance)
        await prefs.setString('selected_gate', selectedGateName);
        await prefs.setString('selected_gate_type', selectedGateType);
        debugPrint(
            "💾 Gate information saved to SharedPreferences for $context");

        // Verify what was actually saved
        final savedGateName = prefs.getString('selected_gate');
        final savedGateType = prefs.getString('selected_gate_type');
        debugPrint(
            "✅ Verified saved gate info - Name: '$savedGateName', Type: '$savedGateType'");

        // Cross-reference with expected pattern
        if (savedGateName != null &&
            savedGateName.toLowerCase().contains('gate') &&
            savedGateName.length > 4) {
          debugPrint("✅ Gate name looks valid: '$savedGateName'");
        } else {
          debugPrint(
              "❌ Gate name looks suspicious: '$savedGateName' - may need field mapping adjustment");
        }
      } else {
        debugPrint("⚠️ Gates API returned empty list");
      }
    } catch (gatesError) {
      debugPrint(
          "⚠️ Gates API call failed for $context, using fallback values: $gatesError");
      // Fallback to existing cached values if gates API fails
      final prefs = await SharedPreferences.getInstance();
      selectedGateName = prefs.getString('selected_gate') ?? 'Default Gate';
      selectedGateType = prefs.getString('selected_gate_type') ?? 'both';
      debugPrint(
          "📱 Using cached gate values for $context - Name: $selectedGateName, Type: $selectedGateType");
    }

    // Final verification and return
    debugPrint("🎯 FINAL RESULT for $context:");
    debugPrint("🎯 Returning gateName: '$selectedGateName'");
    debugPrint("🎯 Returning gateType: '$selectedGateType'");
    debugPrint("🎯 Expected in visitor logs: gate names like 'Gate 777'");

    // If API succeeds, update cache before returning
    _cacheTimestamp = DateTime.now();
    debugPrint("✅ Gate information cached for $context");

    return {
      'gateName': selectedGateName,
      'gateType': selectedGateType,
    };
  }

  Future<List<VisitorLog>> _fetchVisitorLogs({
    bool? onlyCheckout,
    int currentPage = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    debugPrint(
        "🚀 [VISITOR_LOGS] _fetchVisitorLogs() called with onlyCheckout: $onlyCheckout");
    debugPrint("🚀 [VISITOR_LOGS] Starting visitor logs API call...");

    try {
      // Step 1: Fetch and update gate information using helper method
      final gateInfo = await fetchAndUpdateGateInfo('visitor logs');
      final selectedGateName = gateInfo['gateName']!;
      final selectedGateType = gateInfo['gateType']!;

      debugPrint(
          "🎯 VISITOR LOGS V2 - Using gate info: Name='$selectedGateName', Type='$selectedGateType'");

      // Step 2: Get company ID (keep existing logic)
      final resolvedCompanyId = await gateStorage.getSocietyId();

      // Use current date for visitor logs
      final now = DateTime.now();
      final String formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      debugPrint("📅 Using current date for visitor logs:");
      debugPrint("   Current date: $now");
      debugPrint("   Formatted: $formattedDate");

      // Build query parameters for GET request
      Map<String, String> queryParams = {
        'company_id': resolvedCompanyId.toString(),
        'in_gate': selectedGateName,
        'gate_type': selectedGateType,
        'from_date': formattedDate,
        'to_date': formattedDate,
        'per_page': perPage.toString(),
        'current_page': currentPage.toString(),
      };

      // Add onlyCheckout parameter if provided
      if (onlyCheckout != null) {
        // Send explicit boolean strings expected by the backend ('true' or 'false')
        queryParams['only_checkout'] = onlyCheckout.toString();
        debugPrint(
            "🔍 [DEBUG] onlyCheckout value type: ${queryParams['only_checkout'].runtimeType}");
        debugPrint(
            "🔍 [DEBUG] onlyCheckout value: ${queryParams['only_checkout']}");
      }

      // Add search query if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      debugPrint("🔍 [PARAMS] Query parameters: $queryParams");

      // Build the URL with query parameters
      final uri = Uri.parse(ApiUrls.visitorGetLogV2)
          .replace(queryParameters: queryParams);
      debugPrint("🔍 [DEBUG] Final URI: $uri");
      debugPrint("🔍 [DEBUG] Raw query parameters: ${uri.queryParameters}");

      // Get access token
      final accessToken = await _getAccessToken();

      // Make the API request
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': accessToken != null ? 'Bearer $accessToken' : '',
        },
      );

      debugPrint(
          "🚀 [VISITOR_LOGS] HTTP response received with status: ${response.statusCode}");
      debugPrint(
          "🚀 [VISITOR_LOGS] Response body length: ${response.body.length}");
      debugPrint("🚀 [REQUEST] Complete request details:");
      debugPrint("🚀 [REQUEST] URL: $uri");
      debugPrint("🚀 [REQUEST] Method: GET");
      debugPrint("🚀 [REQUEST] Headers: ${{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${accessToken?.substring(0, 20) ?? ''}...'
      }}");
      debugPrint("🚀 [REQUEST] Query parameters: $queryParams");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint("🔍 Raw API Response: $responseData");
        debugPrint("🔍 Response Type: ${responseData.runtimeType}");

        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data']['data'] as List;
          final visitorLogs =
              data.map((item) => _mapToVisitorLog(item)).toList();
          return visitorLogs;
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        debugPrint(
            "❌ [VISITOR_LOGS] API call failed with status ${response.statusCode}");
        debugPrint("❌ [VISITOR_LOGS] Error response: ${response.body}");
        throw Exception(
            'Failed to fetch visitor logs V2: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint("💥 [VISITOR_LOGS] Exception in _fetchVisitorLogs: $e");
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

    // Debug logging for initiated_from field
    print(
        '🔍 [DEBUG] _mapToVisitorLog - additional_details: $additionalDetails');
    print('🔍 [DEBUG] _mapToVisitorLog - item keys: ${item.keys.toList()}');

    if (additionalDetails is Map<String, dynamic>) {
      // Check for invited_guest field first
      final invitedGuest = additionalDetails['invited_guest'] as bool?;
      print('🔍 [DEBUG] _mapToVisitorLog - invited_guest: $invitedGuest');

      if (invitedGuest == true) {
        initiatedFrom = "invited_guest";
        print(
            '🔍 [DEBUG] _mapToVisitorLog - Set initiated_from to invited_guest');
      } else {
        // Fallback to original initiated_from field
        initiatedFrom = additionalDetails['initiated_from'] as String?;
        print(
            '🔍 [DEBUG] _mapToVisitorLog - initiated_from from additional_details: $initiatedFrom');
      }
    } else {
      print(
          '🔍 [DEBUG] _mapToVisitorLog - additional_details is not a Map or is null');
    }

    // Fallback: Check for direct initiated_from field in the main item
    if (initiatedFrom == null && item['initiated_from'] != null) {
      initiatedFrom = item['initiated_from'] as String?;
      print(
          '🔍 [DEBUG] _mapToVisitorLog - initiated_from from direct field: $initiatedFrom');
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

    // Debug logging for final VisitorLog
    print(
        '🔍 [DEBUG] _mapToVisitorLog - Final VisitorLog initiated_from: ${visitorLog.initiated_from}');
    print(
        '🔍 [DEBUG] _mapToVisitorLog - Visitor name: ${visitorLog.visitor?.name}');

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
        "company_id": int.parse(resolvedCompanyId ?? "412"),
        "in_gate": selectedGateName,
        "passcode": passcode,
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
        // Fluttertoast.showToast(
        //   msg: "Not a valid passcode!",
        //   toastLength: Toast.LENGTH_SHORT,
        //   gravity: ToastGravity.BOTTOM,
        //   backgroundColor: Colors.red,
        //   textColor: Colors.white,
        // );
        throw Exception('Failed to verify passcode');
      }
    } catch (e, stackTrace) {
      _handleErrorResponse();

      log("❌ Error verifying passcode: $e");
      log("StackTrace: $stackTrace");

      // Fluttertoast.showToast(
      //   msg: "Not a valid passcode!",
      //   toastLength: Toast.LENGTH_SHORT,
      //   gravity: ToastGravity.BOTTOM,
      //   backgroundColor: Colors.red,
      //   textColor: Colors.white,
      // );

      throw Exception('Failed to verify passcode');
    }
  }

  /// Verify Member Pass using mobile number from QR
  Future<Map<String, dynamic>> verifyMemberPass({
    required String mobile,
    required String companyId,
    required String gateName,
    int? passId,
  }) async {
    try {
      const String url = 'https://gateapi.cubeone.in/api/member/pass/verify';
      final prefs = await SharedPreferences.getInstance();
      final selectedGateName = prefs.getString('selected_gate') ?? gateName;
      final resolvedCompanyId = await gateStorage.getSocietyId();

      final Map<String, dynamic> requestData = {
        "company_id": int.parse(resolvedCompanyId ?? companyId),
        "in_gate": selectedGateName,
        "passcode": null,
        "mobile": mobile,
        if (passId != null) "pass_id": passId,
      };

      log("🔍 Sending request to verify member pass: $requestData");

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
        log("✅ Member pass verified successfully: ${response.data}");
        return response.data;
      } else {
        _handleErrorResponse();
        log("❌ Failed to verify member pass. Status Code: ${response.statusCode}, Response: ${response.data}");
        throw Exception('Failed to verify member pass');
      }
    } catch (e, stackTrace) {
      _handleErrorResponse();
      log("❌ Error verifying member pass: $e");
      log("StackTrace: $stackTrace");
      throw Exception('Failed to verify member pass');
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

  /// Helper method to extract host from URL for consistent host header
  String _getHostFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      log('Error parsing URL for host: $e');
      // Fallback to current environment's host
      return ApiUrls.currentEnvironment == 'staging'
          ? 'stggateapi.cubeone.in'
          : 'gateapi.cubeone.in';
    }
  }

  /// Helper method to format card number with "V " prefix
  String _formatCardNumber(String cardNumber) {
    // Remove any existing "V " prefix and whitespace
    String cleanNumber = cardNumber.trim();
    if (cleanNumber.startsWith('V ')) {
      cleanNumber = cleanNumber.substring(2);
    } else if (cleanNumber.startsWith('V')) {
      cleanNumber = cleanNumber.substring(1);
    }

    // Add "V " prefix to the clean number
    return 'V $cleanNumber';
  }

  /// Update visitor log for self entry visitors to sync with Gatekeeper dashboard
  /// Uses visitor_id in the PATCH endpoint with allow_status payload
  Future<void> _updateVisitorLogForSelfEntry(String visitorId,
      {int retryCount = 0}) async {
    try {
      log("=== VISITOR LOG PATCH API DEBUG ===");
      log("Visitor ID: $visitorId");
      log("Retry Count: $retryCount");

      final Dio dio = Dio();
      final String apiUrl =
          '${ApiUrls.gateBaseUrl}/visitor/visitorLog/$visitorId';

      log("PATCH API URL: $apiUrl");

      // Prepare payload with allow_status as per API specification
      final Map<String, dynamic> patchData = {
        "allow_status": "allowed_by_gatekeeper"
      };

      log("PATCH Payload: ${json.encode(patchData)}");

      // Make the PATCH request using visitor_id
      final Response response = await dio.patch(
        apiUrl,
        data: patchData,
        options: Options(
          headers: {
            'user-agent': 'Dart/3.9 (dart:io)',
            'content-type': 'application/json',
            'accept-encoding': 'gzip',
            'authorization':
                'Bearer ${await _getAccessToken() ?? "accessToken"}',
            'host': _getHostFromUrl(apiUrl),
          },
        ),
      );

      log("PATCH Response Status: ${response.statusCode}");
      log("PATCH Response: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("✅ Self Entry visitor log PATCH successful - visitor_id: $visitorId");
        log("✅ Visitor status updated to 'allowed_by_gatekeeper'");
      } else {
        log("❌ PATCH API returned unexpected status: ${response.statusCode}");
        throw Exception("PATCH API failed with status: ${response.statusCode}");
      }
    } on DioException catch (e) {
      log("❌ Dio Error in PATCH API: ${e.message}");
      if (e.response != null) {
        log("PATCH Error Response: ${e.response?.data}");
        log("PATCH Error Status: ${e.response?.statusCode}");
      }

      // Retry once if this is the first attempt
      if (retryCount == 0) {
        log("🔄 Retrying PATCH API with visitor_id: $visitorId (attempt 2/2)");
        await Future.delayed(
            const Duration(seconds: 1)); // Brief delay before retry
        await _updateVisitorLogForSelfEntry(visitorId, retryCount: 1);
      } else {
        log("❌ PATCH API failed after retry. Continuing with flow to not block user experience.");
      }
    } catch (e, stackTrace) {
      log("❌ Unexpected error in PATCH API: $e");
      log("Stack trace: $stackTrace");

      // Retry once if this is the first attempt
      if (retryCount == 0) {
        log("🔄 Retrying PATCH API after unexpected error with visitor_id: $visitorId (attempt 2/2)");
        await Future.delayed(
            const Duration(seconds: 1)); // Brief delay before retry
        await _updateVisitorLogForSelfEntry(visitorId, retryCount: 1);
      } else {
        log("❌ PATCH API failed after retry due to unexpected error. Continuing with flow to not block user experience.");
      }
    }
  }

  /// Update visitor card number for Express Entry visitors
  Future<bool> updateVisitorCardNumber(int visitorId, String cardNumber) async {
    try {
      log("=== ASSIGN CARD PATCH API DEBUG ===");
      log("Visitor ID: $visitorId");
      log("Card Number (raw): $cardNumber");

      final Dio dio = Dio();
      final String apiUrl =
          '${ApiUrls.gateBaseUrl}/visitor/visitorLog/$visitorId';

      log("PATCH API URL: $apiUrl");

      // Format card number with "V " prefix
      final String formattedCardNumber = _formatCardNumber(cardNumber);
      log("Card Number (formatted): $formattedCardNumber");

      // Prepare payload with formatted card_number as per API specification
      final Map<String, dynamic> patchData = {
        "card_number": formattedCardNumber
      };

      log("PATCH Payload: ${json.encode(patchData)}");

      // Make the PATCH request
      final Response response = await dio.patch(
        apiUrl,
        data: patchData,
        options: Options(
          headers: {
            'user-agent': 'Dart/3.9 (dart:io)',
            'content-type': 'application/json',
            'accept-encoding': 'gzip',
            'authorization':
                'Bearer ${await _getAccessToken() ?? "accessToken"}',
            'host': _getHostFromUrl(apiUrl),
          },
        ),
      );

      log("PATCH Response Status: ${response.statusCode}");
      log("PATCH Response: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("✅ Visitor card number updated successfully - visitor_id: $visitorId");
        return true;
      } else {
        log("❌ PATCH API returned unexpected status: ${response.statusCode}");
        return false;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        log("PATCH Error Response: ${e.response?.data}");
        log("PATCH Error Status: ${e.response?.statusCode}");
      }
      log("❌ PATCH API failed: ${e.message}");
      return false;
    } catch (e, stackTrace) {
      log("❌ Unexpected error in PATCH API: $e");
      log("Stack trace: $stackTrace");
      return false;
    }
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
      // Step 1: Fetch and update gate information using helper method
      final gateInfo = await fetchAndUpdateGateInfo('approvals');
      final rawGateName = gateInfo['gateName']!;

      // Format gate name to ensure consistent "TOWER NO XX" format
      final selectedGateName = _formatGateName(rawGateName);
      // Note: Gate name is dynamically fetched and formatted to match API requirements

      log("🎯 APPROVALS - Raw gate name: '$rawGateName'");
      log("🎯 APPROVALS - Formatted gate name: '$selectedGateName'");

      // Step 2: Get company ID (keep existing logic)
      final resolvedCompanyId = await gateStorage.getSocietyId();

      final String baseUrl = '${ApiUrls.gateBaseUrl}/visitor/approvals/';
      final DateTime now = DateTime.now();
      // Updated: Use current date for both from_date and to_date
      final String currentDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final String fromDate = currentDate;
      final String toDate = currentDate;

      // Construct Request Body
      final Map<String, dynamic> requestBody = {
        "company_id": resolvedCompanyId,
        "in_gate": selectedGateName,
        "from_date": fromDate,
        "to_date": toDate,
        "is_secondary": isSecondary ?? true,
      };

      if (logID != null) {
        requestBody["log_id"] = logID;
      }

      log("🔍 Step 3: APPROVALS REQUEST BODY:");
      log("📦 in_gate parameter: '${requestBody['in_gate']}'");
      log("📦 company_id parameter: '${requestBody['company_id']}'");
      log("📦 from_date parameter: '${requestBody['from_date']}'");
      log("📦 to_date parameter: '${requestBody['to_date']}'");
      log("📦 Complete request body: ${jsonEncode(requestBody)}");
      log("🌐 Sending approvals request with updated gate context to: $baseUrl");
      log("📅 Date range: ${requestBody['from_date']} to ${requestBody['to_date']} (current date)");

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

  // Helper method to format gate name to ensure consistent "TOWER NO XX" format
  String _formatGateName(String rawGateName) {
    if (rawGateName.isEmpty) return "TOWER NO 01";

    // Convert to uppercase and clean up
    String formatted = rawGateName.toUpperCase().trim();

    // Handle different possible formats and normalize them
    // Examples: "Gate 777" -> "TOWER NO 777", "tower no 01" -> "TOWER NO 01"

    // If it already contains "TOWER NO", just clean it up
    if (formatted.contains("TOWER NO")) {
      // Clean up extra spaces
      formatted = formatted.replaceAll(RegExp(r'\s+'), ' ');
      return formatted;
    }

    // If it contains "GATE" followed by a number, convert to "TOWER NO"
    if (formatted.contains("GATE")) {
      // Extract number from patterns like "GATE 777", "GATE777", etc.
      final numberMatch = RegExp(r'(\d+)').firstMatch(formatted);
      if (numberMatch != null) {
        final number = numberMatch.group(1)!;
        return "TOWER NO ${number.padLeft(2, '0')}";
      }
    }

    // If it's just a number, assume it's the tower number
    final numberMatch = RegExp(r'^(\d+)$').firstMatch(formatted);
    if (numberMatch != null) {
      final number = numberMatch.group(1)!;
      return "TOWER NO ${number.padLeft(2, '0')}";
    }

    // Default fallback
    return "TOWER NO 01";
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
