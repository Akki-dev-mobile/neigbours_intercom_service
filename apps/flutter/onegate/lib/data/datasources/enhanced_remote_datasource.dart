import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/api_client/authenticated_dio_factory.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Enhanced RemoteDataSource with unified authentication using Dio factory
/// This ensures all API calls go through the unified authentication system
class EnhancedRemoteDataSource {
  static final EnhancedRemoteDataSource _instance =
      EnhancedRemoteDataSource._internal();
  factory EnhancedRemoteDataSource() => _instance;
  EnhancedRemoteDataSource._internal();

  late final Dio _gateApiClient;
  late final Dio _societyApiClient;
  late final Dio _publicApiClient;
  late final GateStorage _gateStorage;
  bool _isInitialized = false;

  /// Initialize the enhanced remote data source
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Create authenticated Dio clients using the factory
    _gateApiClient = AuthenticatedDioFactory.createOneGateApiClient(
      baseUrl: ApiUrls.gateBaseUrl,
      customHeaders: {
        'X-Service': 'EnhancedRemoteDataSource-Gate',
      },
    );

    _societyApiClient = AuthenticatedDioFactory.createSocietyApiClient(
      customHeaders: {
        'X-Service': 'EnhancedRemoteDataSource-Society',
      },
    );

    _publicApiClient = AuthenticatedDioFactory.createPublicDio(
      baseUrl: ApiUrls.gateBaseUrl,
      customHeaders: {
        'X-Service': 'EnhancedRemoteDataSource-Public',
      },
    );

    _gateStorage = GetIt.I<GateStorage>();

    _isInitialized = true;
    log("✅ EnhancedRemoteDataSource initialized with unified authentication");
  }

  /// Ensure the data source is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // ==================== GATE OPERATIONS ====================

  /// Fetch gates list using enhanced authentication
  Future<List<dynamic>> fetchGates() async {
    await _ensureInitialized();

    try {
      final String? companyId = await _gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception('Company ID not found.');
      }

      final response = await _gateApiClient.get(
        '/admin/gates',
        queryParameters: {'company_id': int.parse(companyId.toString())},
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData == null) {
          throw Exception('Response data is null');
        }

        log("✅ Gates fetched successfully using enhanced auth");
        return responseData['data'] ?? [];
      } else {
        throw Exception('Failed to fetch gates: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching gates: $e");
      rethrow;
    }
  }

  // ==================== BUILDING OPERATIONS ====================

  /// Fetch buildings list using enhanced authentication
  Future<List<dynamic>> getBuildingsList() async {
    await _ensureInitialized();

    try {
      final String? companyId = await _gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception('Company ID not found. Please select a company.');
      }

      final response = await _societyApiClient.get(
        '/admin/building/list',
        queryParameters: {'company_id': companyId},
      );

      if (response.statusCode == 200) {
        log("✅ Buildings list fetched successfully using enhanced auth");
        return response.data?['data'] ?? [];
      } else {
        throw Exception('Failed to fetch buildings: ${response.statusCode}');
      }
    } catch (e) {
      log('❌ Error fetching buildings list: $e');
      rethrow;
    }
  }

  // ==================== VISITOR OPERATIONS ====================

  /// Fetch parcels using enhanced authentication
  Future<List<dynamic>> fetchParcels() async {
    await _ensureInitialized();

    try {
      final String? companyId = await _gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception('Company ID not found');
      }

      log("🔍 Fetching parcels for company: $companyId");

      final response =
          await _gateApiClient.get('/visitor/parcelData/$companyId');

      if (response.statusCode == 200) {
        log("✅ Parcels fetched successfully using enhanced auth");
        return response.data?['data'] ?? [];
      } else {
        throw Exception('Failed to fetch parcels: ${response.statusCode}');
      }
    } catch (e) {
      log('❌ Error fetching parcels: $e');
      rethrow;
    }
  }

  /// Make Exotel call using enhanced authentication
  Future<void> makeExotelCall({
    required String memberMobileNumber,
    required int visitorId,
    required int memberId,
    required int visitorLogId,
    required String purposeCategory,
  }) async {
    await _ensureInitialized();

    try {
      final response = await _gateApiClient.post(
        '/visitor/exotel/call',
        data: {
          'member_mobile_number': memberMobileNumber,
          'visitor_id': visitorId,
          'member_id': memberId,
          'visitor_log_id': visitorLogId,
          'purpose_category': purposeCategory,
        },
      );

      if (response.statusCode == 200) {
        log("✅ Exotel call initiated successfully using enhanced auth");
      } else {
        throw Exception(
            'Failed to make Exotel call. Status code: ${response.statusCode}');
      }
    } catch (e) {
      log('❌ Error making Exotel call: $e');
      rethrow;
    }
  }

  // ==================== MEMBER OPERATIONS ====================

  /// Fetch member list using enhanced authentication
  Future<List<dynamic>> fetchMemberList({
    required String companyId,
    String? buildingId,
    String? unitId,
    String? searchQuery,
    int page = 1,
    int perPage = 20,
  }) async {
    await _ensureInitialized();

    try {
      final queryParams = <String, dynamic>{
        'company_id': companyId,
        'page': page,
        'per_page': perPage,
      };

      if (buildingId != null) queryParams['building_id'] = buildingId;
      if (unitId != null) queryParams['unit_id'] = unitId;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      final response = await _societyApiClient.get(
        '/v2/admin/member/list',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        log("✅ Member list fetched successfully using enhanced auth");
        return response.data?['data'] ?? [];
      } else {
        throw Exception('Failed to fetch member list: ${response.statusCode}');
      }
    } catch (e) {
      log('❌ Error fetching member list: $e');
      rethrow;
    }
  }

  // ==================== VISITOR LOG OPERATIONS ====================

  /// Submit visitor log using enhanced authentication
  Future<Map<String, dynamic>> submitVisitorLog(
      Map<String, dynamic> requestBody) async {
    await _ensureInitialized();

    try {
      log("🔍 Submitting visitor log with enhanced auth");
      log("📦 Request Body: $requestBody");

      final response = await _gateApiClient.post(
        '/visitor/log',
        data: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log("✅ Visitor log submitted successfully using enhanced auth");
        return response.data ?? {};
      } else {
        throw Exception('Failed to submit visitor log: ${response.statusCode}');
      }
    } catch (e) {
      log('❌ Error submitting visitor log: $e');
      rethrow;
    }
  }

  // ==================== PUBLIC ENDPOINTS (No Auth Required) ====================

  /// Send OTP (public endpoint)
  Future<String?> sendOTP(String mobileNumber) async {
    await _ensureInitialized();

    try {
      // Use skip auth option for public endpoints
      final options = Options(
        extra: {'skip_auth': true},
      );

      final response = await _publicApiClient.get(
        '/sms/verification-code',
        queryParameters: {'phoneNumber': '91$mobileNumber'},
        options: options,
      );

      if (response.statusCode == 200) {
        final expiresIn = response.data?['data']['expires_in'];
        log('✅ OTP sent successfully. Expires in: $expiresIn');
        return expiresIn;
      } else {
        log('❌ Failed to send OTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('❌ Error sending OTP: $e');
      rethrow;
    }
  }

  /// Send self check-in OTP (public endpoint)
  Future<Map<String, dynamic>?> sendSelfCheckinOTP(String mobileNumber) async {
    await _ensureInitialized();

    try {
      final String? companyId = await _gateStorage.getSocietyId();
      if (companyId == null) {
        throw Exception('Company ID not found');
      }

      // Use skip auth option for public endpoints
      final options = Options(
        extra: {'skip_auth': true},
      );

      final response = await _publicApiClient.post(
        '/visitor/selfCheckin',
        data: {'mobile': mobileNumber, 'company_id': companyId},
        options: options,
      );

      if (response.statusCode == 200) {
        log('✅ Self check-in OTP sent successfully');
        return response.data;
      } else {
        log('❌ Failed to send self check-in OTP: ${response.statusCode}');
        throw Exception('Failed to send OTP');
      }
    } catch (e) {
      log('❌ Error sending self check-in OTP: $e');
      rethrow;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Get the gate API client for advanced usage
  Dio get gateApiClient => _gateApiClient;

  /// Get the society API client for advanced usage
  Dio get societyApiClient => _societyApiClient;

  /// Get the public API client for advanced usage
  Dio get publicApiClient => _publicApiClient;

  /// Check if the data source is initialized
  bool get isInitialized => _isInitialized;
}
