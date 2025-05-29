import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/api_client/authenticated_api_client.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:get_it/get_it.dart';

/// OneGate API service with automatic authentication
class OneGateApiService {
  static final OneGateApiService _instance = OneGateApiService._internal();

  factory OneGateApiService() {
    return _instance;
  }

  OneGateApiService._internal();

  late final AuthenticatedApiClient _apiClient;
  late final GateStorage _gateStorage;

  bool _isInitialized = false;

  /// Initialize the API service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _apiClient = AuthenticatedApiClient();
    await _apiClient.initialize();

    _gateStorage = GetIt.I<GateStorage>();

    _isInitialized = true;
    log("✅ OneGateApiService initialized");
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // ==================== USER MANAGEMENT ====================

  /// Get current user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    await _ensureInitialized();

    try {
      final userId = await _gateStorage.getUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      final response =
          await _apiClient.get('${ApiUrls.gateBaseUrl}/user/profile/$userId');

      if (response.statusCode == 200) {
        log("✅ User profile fetched successfully");
        return response.data;
      } else {
        throw Exception('Failed to fetch user profile: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching user profile: $e");
      rethrow;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    await _ensureInitialized();

    try {
      final userId = await _gateStorage.getUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      final response = await _apiClient.put(
        '${ApiUrls.gateBaseUrl}/user/profile/$userId',
        data: profileData,
      );

      if (response.statusCode == 200) {
        log("✅ User profile updated successfully");
        return true;
      } else {
        throw Exception(
            'Failed to update user profile: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error updating user profile: $e");
      return false;
    }
  }

  // ==================== SOCIETY MANAGEMENT ====================

  /// Fetch societies for current user
  Future<List<dynamic>> fetchSocieties() async {
    await _ensureInitialized();

    try {
      final userId = await _gateStorage.getUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      final response = await _apiClient.get(
        '${ApiUrls.gateBaseUrl}/societies',
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        log("✅ Societies fetched successfully");
        return response.data['data'] ?? [];
      } else {
        throw Exception('Failed to fetch societies: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching societies: $e");
      rethrow;
    }
  }

  /// Get society details
  Future<Map<String, dynamic>?> getSocietyDetails(String societyId) async {
    await _ensureInitialized();

    try {
      final response =
          await _apiClient.get('${ApiUrls.gateBaseUrl}/society/$societyId');

      if (response.statusCode == 200) {
        log("✅ Society details fetched successfully");
        return response.data;
      } else {
        throw Exception(
            'Failed to fetch society details: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching society details: $e");
      rethrow;
    }
  }

  // ==================== VISITOR MANAGEMENT ====================

  /// Create visitor entry
  Future<Map<String, dynamic>?> createVisitorEntry(
      Map<String, dynamic> visitorData) async {
    await _ensureInitialized();

    try {
      final societyId = await _gateStorage.getSocietyId();
      if (societyId == null) {
        throw Exception('Society ID not found');
      }

      // Add society ID to visitor data
      visitorData['society_id'] = societyId;

      final response = await _apiClient.post(
        '${ApiUrls.gateBaseUrl}/visitor/entry',
        data: visitorData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log("✅ Visitor entry created successfully");
        return response.data;
      } else {
        throw Exception(
            'Failed to create visitor entry: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error creating visitor entry: $e");
      rethrow;
    }
  }

  /// Get visitor logs
  Future<List<dynamic>> getVisitorLogs({
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await _ensureInitialized();

    try {
      final societyId = await _gateStorage.getSocietyId();
      if (societyId == null) {
        throw Exception('Society ID not found');
      }

      final queryParams = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
      };

      if (status != null) queryParams['status'] = status;
      if (fromDate != null)
        queryParams['from_date'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to_date'] = toDate.toIso8601String();

      final response = await _apiClient.get(
        '${ApiUrls.gateBaseUrl}/visitor/logs',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        log("✅ Visitor logs fetched successfully");
        return response.data['data'] ?? [];
      } else {
        throw Exception('Failed to fetch visitor logs: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching visitor logs: $e");
      rethrow;
    }
  }

  /// Update visitor status
  Future<bool> updateVisitorStatus(String visitorLogId, String status,
      {String? remarks}) async {
    await _ensureInitialized();

    try {
      final updateData = <String, dynamic>{
        'status': status,
      };

      if (remarks != null) {
        updateData['remarks'] = remarks;
      }

      final response = await _apiClient.put(
        '${ApiUrls.gateBaseUrl}/visitor/status/$visitorLogId',
        data: updateData,
      );

      if (response.statusCode == 200) {
        log("✅ Visitor status updated successfully");
        return true;
      } else {
        throw Exception(
            'Failed to update visitor status: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error updating visitor status: $e");
      return false;
    }
  }

  // ==================== MEMBER MANAGEMENT ====================

  /// Get member list
  Future<List<dynamic>> getMemberList({
    String? buildingId,
    String? unitId,
    String? searchQuery,
  }) async {
    await _ensureInitialized();

    try {
      final societyId = await _gateStorage.getSocietyId();
      if (societyId == null) {
        throw Exception('Society ID not found');
      }

      final queryParams = <String, dynamic>{
        'society_id': societyId,
      };

      if (buildingId != null) queryParams['building_id'] = buildingId;
      if (unitId != null) queryParams['unit_id'] = unitId;
      if (searchQuery != null) queryParams['search'] = searchQuery;

      final response = await _apiClient.get(
        '${ApiUrls.gateBaseUrl}/members',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        log("✅ Member list fetched successfully");
        return response.data['data'] ?? [];
      } else {
        throw Exception('Failed to fetch member list: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching member list: $e");
      rethrow;
    }
  }

  // ==================== GATE MANAGEMENT ====================

  /// Get gates list
  Future<List<dynamic>> getGates() async {
    await _ensureInitialized();

    try {
      final societyId = await _gateStorage.getSocietyId();
      if (societyId == null) {
        throw Exception('Society ID not found');
      }

      final response = await _apiClient.get(
        '${ApiUrls.gateBaseUrl}/gates',
        queryParameters: {'society_id': societyId},
      );

      if (response.statusCode == 200) {
        log("✅ Gates fetched successfully");
        return response.data['data'] ?? [];
      } else {
        throw Exception('Failed to fetch gates: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching gates: $e");
      rethrow;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Generic API call method
  Future<Response<T>> makeApiCall<T>({
    required String method,
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureInitialized();

    switch (method.toUpperCase()) {
      case 'GET':
        return await _apiClient.get<T>(path,
            queryParameters: queryParameters, options: options);
      case 'POST':
        return await _apiClient.post<T>(path,
            data: data, queryParameters: queryParameters, options: options);
      case 'PUT':
        return await _apiClient.put<T>(path,
            data: data, queryParameters: queryParameters, options: options);
      case 'DELETE':
        return await _apiClient.delete<T>(path,
            data: data, queryParameters: queryParameters, options: options);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }
}
