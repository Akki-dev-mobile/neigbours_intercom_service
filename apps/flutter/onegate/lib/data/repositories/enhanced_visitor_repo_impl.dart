import 'dart:developer';
import 'dart:io';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/repositories/visitor_repo.dart';
import 'package:flutter_onegate/services/api_service/onegate_api_service.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:get_it/get_it.dart';

/// Enhanced visitor repository using the new authenticated API service
class EnhancedVisitorRepoImpl extends VisitorRepository {
  late final OneGateApiService _apiService;
  late final UserSessionManager _sessionManager;

  bool _isInitialized = false;

  EnhancedVisitorRepoImpl() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    _apiService = GetIt.I<OneGateApiService>();
    _sessionManager = GetIt.I<UserSessionManager>();

    await _apiService.initialize();
    await _sessionManager.initialize();

    _isInitialized = true;
    log("✅ EnhancedVisitorRepoImpl initialized");
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  @override
  Future<Visitor?> searchVisitor(String mobileNumber) async {
    await _ensureInitialized();

    try {
      // Check if user has permission to search visitors
      final hasPermission =
          await _sessionManager.hasPermission('view_visitors');
      if (!hasPermission) {
        log("❌ User doesn't have permission to search visitors");
        throw Exception('Insufficient permissions to search visitors');
      }

      final response = await _apiService.makeApiCall(
        method: 'GET',
        path: '/visitor/search',
        queryParameters: {'mobile': mobileNumber},
      );

      if (response.statusCode == 200 && response.data != null) {
        log("✅ Visitor found for mobile: $mobileNumber");
        return Visitor.fromJson(response.data);
      } else {
        log("ℹ️ No visitor found for mobile: $mobileNumber");
        return null;
      }
    } catch (e) {
      log("❌ Error searching visitor: $e");
      return null;
    }
  }

  @override
  Future<Visitor?> createVisitor(Visitor visitor) async {
    await _ensureInitialized();

    try {
      // Check if user has permission to create visitors
      final hasPermission =
          await _sessionManager.hasPermission('create_visitor_entry');
      if (!hasPermission) {
        log("❌ User doesn't have permission to create visitors");
        throw Exception('Insufficient permissions to create visitor entry');
      }

      final visitorData = visitor.toJson();

      final response = await _apiService.createVisitorEntry(visitorData);

      if (response != null) {
        log("✅ Visitor created successfully: ${visitor.name}");
        return Visitor.fromJson(response);
      } else {
        throw Exception('Failed to create visitor');
      }
    } catch (e) {
      log("❌ Error creating visitor: $e");
      return null;
    }
  }

  @override
  Future<bool> updateVisitor(Visitor visitor) async {
    await _ensureInitialized();

    try {
      // Check if user has permission to update visitors
      final hasPermission =
          await _sessionManager.hasPermission('update_visitor_status');
      if (!hasPermission) {
        log("❌ User doesn't have permission to update visitors");
        throw Exception('Insufficient permissions to update visitor');
      }

      final visitorData = visitor.toJson();

      final response = await _apiService.makeApiCall(
        method: 'PUT',
        path: '/visitor/${visitor.id}',
        data: visitorData,
      );

      if (response.statusCode == 200) {
        log("✅ Visitor updated successfully: ${visitor.name}");
        return true;
      } else {
        throw Exception('Failed to update visitor: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error updating visitor: $e");
      return false;
    }
  }

  @override
  Future<List<dynamic>?> getMembersList(int companyId) async {
    await _ensureInitialized();

    try {
      // Check if user has permission to view members
      final hasPermission =
          await _sessionManager.hasPermission('view_visitors');
      if (!hasPermission) {
        log("❌ User doesn't have permission to view members");
        return null;
      }

      final members = await _apiService.getMemberList();

      log("✅ Members list fetched successfully: ${members.length} members");
      return members;
    } catch (e) {
      log("❌ Error fetching members list: $e");
      return null;
    }
  }

  @override
  Future<List<dynamic>?> getBuildingList(int companyId) async {
    await _ensureInitialized();

    try {
      final response = await _apiService.makeApiCall(
        method: 'GET',
        path: '/buildings',
        queryParameters: {'company_id': companyId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final buildings = response.data['data'] as List<dynamic>?;
        log("✅ Buildings list fetched successfully: ${buildings?.length ?? 0} buildings");
        return buildings;
      } else {
        throw Exception('Failed to fetch buildings: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching buildings list: $e");
      return null;
    }
  }

  @override
  Future<List<dynamic>?> getUnitList(int companyId) async {
    await _ensureInitialized();

    try {
      final response = await _apiService.makeApiCall(
        method: 'GET',
        path: '/units',
        queryParameters: {'company_id': companyId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final units = response.data['data'] as List<dynamic>?;
        log("✅ Units list fetched successfully: ${units?.length ?? 0} units");
        return units;
      } else {
        throw Exception('Failed to fetch units: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching units list: $e");
      return null;
    }
  }

  @override
  Future<String?> uploadImage(
      File file, String userMobile, int companyId) async {
    await _ensureInitialized();

    try {
      // Check if user has permission to upload images
      final hasPermission =
          await _sessionManager.hasPermission('create_visitor_entry');
      if (!hasPermission) {
        log("❌ User doesn't have permission to upload images");
        return null;
      }

      // Create form data for file upload
      final formData = {
        'file': file,
        'user_mobile': userMobile,
        'company_id': companyId,
      };

      final response = await _apiService.makeApiCall(
        method: 'POST',
        path: '/upload/visitor-image',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final imageUrl = response.data['image_url'] as String?;
        log("✅ Image uploaded successfully: $imageUrl");
        return imageUrl;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error uploading image: $e");
      return null;
    }
  }

  @override
  Future<String?> sendOTP(String mobileNumber) async {
    await _ensureInitialized();

    try {
      final response = await _apiService.makeApiCall(
        method: 'POST',
        path: '/auth/send-otp',
        data: {'mobile_number': mobileNumber},
      );

      if (response.statusCode == 200 && response.data != null) {
        final message = response.data['message'] as String?;
        log("✅ OTP sent successfully to: $mobileNumber");
        return message ?? 'OTP sent successfully';
      } else {
        throw Exception('Failed to send OTP: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error sending OTP: $e");
      return e.toString();
    }
  }

  @override
  Future<String?> verifyOTP(String mobileNumber, String otp) async {
    await _ensureInitialized();

    try {
      final response = await _apiService.makeApiCall(
        method: 'POST',
        path: '/auth/verify-otp',
        data: {
          'mobile_number': mobileNumber,
          'otp': otp,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final message = response.data['message'] as String?;
        log("✅ OTP verified successfully for: $mobileNumber");
        return message ?? 'OTP verified successfully';
      } else {
        throw Exception('Failed to verify OTP: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error verifying OTP: $e");
      return e.toString();
    }
  }

  @override
  Future<List<PurposeCategory1>?>? fetchPurposeCategory() async {
    await _ensureInitialized();

    try {
      final response = await _apiService.makeApiCall(
        method: 'GET',
        path: '/visitor/purpose-categories',
      );

      if (response.statusCode == 200 && response.data != null) {
        final categories = response.data['data'] as List<dynamic>?;
        log("✅ Purpose categories fetched successfully: ${categories?.length ?? 0} categories");

        // Convert to PurposeCategory1 objects
        if (categories != null) {
          return categories
              .map((json) => PurposeCategory1.fromJson(json))
              .toList();
        }
        return null;
      } else {
        throw Exception(
            'Failed to fetch purpose categories: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ Error fetching purpose categories: $e");
      return null;
    }
  }

  /// Enhanced method: Get visitor logs with authentication and permissions
  Future<List<dynamic>> getVisitorLogs({
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await _ensureInitialized();

    try {
      // Check if user has permission to view visitor logs
      final hasPermission =
          await _sessionManager.hasPermission('view_visitors');
      if (!hasPermission) {
        log("❌ User doesn't have permission to view visitor logs");
        throw Exception('Insufficient permissions to view visitor logs');
      }

      final logs = await _apiService.getVisitorLogs(
        page: page,
        limit: limit,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
      );

      log("✅ Visitor logs fetched successfully: ${logs.length} logs");
      return logs;
    } catch (e) {
      log("❌ Error fetching visitor logs: $e");
      rethrow;
    }
  }

  /// Enhanced method: Update visitor status with authentication and permissions
  Future<bool> updateVisitorStatus(String visitorLogId, String status,
      {String? remarks}) async {
    await _ensureInitialized();

    try {
      // Check if user has permission to update visitor status
      final hasPermission =
          await _sessionManager.hasPermission('update_visitor_status');
      if (!hasPermission) {
        log("❌ User doesn't have permission to update visitor status");
        return false;
      }

      final success = await _apiService
          .updateVisitorStatus(visitorLogId, status, remarks: remarks);

      if (success) {
        log("✅ Visitor status updated successfully: $visitorLogId → $status");
      } else {
        log("❌ Failed to update visitor status: $visitorLogId");
      }

      return success;
    } catch (e) {
      log("❌ Error updating visitor status: $e");
      return false;
    }
  }
}
