import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/services/base_api_service.dart';
import '../../../../core/services/keycloak_service.dart';
import '../../../../core/models/api_response.dart';
import '../models/call_model.dart';
import '../models/call_type.dart';
import '../models/call_status.dart';
import '../../../../core/constants.dart';

/// CallService handles all backend API calls for call functionality
///
/// This service is responsible ONLY for backend communication.
/// It does NOT handle:
/// - Jitsi SDK operations (use JitsiCallController)
/// - Permissions (use CallManager)
/// - UI logic (handled by widgets)
///
/// API Endpoints:
/// - POST /calls → Initiate a new call
/// - PATCH /calls/{id}/status → Update call status
///
/// Backend Call Flow:
/// 1. Token Decoding: Extract logged-in user info from JWT token
/// 2. Caller User Storage: Create/update caller user record with token data
/// 3. Recipient User Upsert: Create recipient user if doesn't exist (using phone number)
/// 4. Meeting ID Generation: Generate random 10-digit meeting identifier
/// 5. Simple Jitsi URL: Combine base Jitsi URL + 10-digit meeting ID
/// 6. Call Log Storage: Save call record in database for history tracking
///
/// Phone Number Format:
/// Frontend sends only what it actually knows.
/// This service only strips formatting and leading "+".
class CallService extends BaseApiService {
  static CallService? _instance;

  CallService._()
      : super(
          baseUrl: AppConstants.callServiceBaseUrl,
          serviceName: 'CallService',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        );

  /// Get singleton instance
  static CallService get instance {
    _instance ??= CallService._();
    return _instance!;
  }

  /// Normalize phone number for API payload
  ///
  /// This method:
  /// - Removes all non-digit characters (spaces, dashes, parentheses, +, etc.)
  ///
  /// Examples:
  /// - "9137394257" → "9137394257"
  /// - "+91 9137394257" → "919137394257"
  /// - "919137394257" → "919137394257"
  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// Basic validation to avoid sending clearly invalid phone values.
  /// Does not guess country code or identifiers.
  static bool isLikelyPhone(String phone) {
    final normalized = normalizePhone(phone);
    return normalized.length >= 8;
  }

  /// Override getAuthHeaders to use old_gate_user_id for x-user-id header
  /// This ensures consistency with the backend API requirements
  /// CRITICAL: The x-user-id header must match the user_id expected by the meet service
  @override
  Future<Map<String, String>> getAuthHeaders() async {
    try {
      // Get base headers from parent class (includes Authorization token)
      final headers = await super.getAuthHeaders();

      // Get user data from Keycloak token
      final userData = await KeycloakService.getUserData();
      if (userData != null) {
        // DEBUG: Log all available user ID fields
        log('🔍 [CallService] User data keys: ${userData.keys.toList()}',
            name: serviceName);
        log('🔍 [CallService] old_gate_user_id: ${userData['old_gate_user_id']}',
            name: serviceName);
        log('🔍 [CallService] old_sso_user_id: ${userData['old_sso_user_id']}',
            name: serviceName);
        log('🔍 [CallService] user_id: ${userData['user_id']}',
            name: serviceName);

        // CRITICAL FIX: Use old_gate_user_id for x-user-id header
        // This matches the user_id expected by the meet service backend
        // Priority: old_gate_user_id > old_sso_user_id > user_id
        final userId = userData['old_gate_user_id']?.toString() ??
            userData['old_sso_user_id']?.toString() ??
            userData['user_id']?.toString();

        if (userId != null && userId.isNotEmpty) {
          headers['x-user-id'] = userId;
          log('✅ [CallService] Set x-user-id header: $userId (from old_gate_user_id)',
              name: serviceName);
        } else {
          log('⚠️ [CallService] No valid user_id found in token for x-user-id header',
              name: serviceName);
        }
      } else {
        log('⚠️ [CallService] User data is null, cannot set x-user-id header',
            name: serviceName);
      }

      return headers;
    } catch (e, stackTrace) {
      log('❌ [CallService] Error getting auth headers: $e', name: serviceName);
      log('❌ [CallService] Stack trace: $stackTrace', name: serviceName);
      // Fallback to parent implementation on error
      return await super.getAuthHeaders();
    }
  }

  /// Initiate a new call with automatic user management
  ///
  /// POST /calls
  ///
  /// Backend Flow:
  /// 1. Decodes JWT token to extract logged-in user info
  /// 2. Creates or updates caller user record with token data
  /// 3. Upserts recipient user in database (creates if doesn't exist using phone)
  /// 4. Generates random 10-digit meeting ID
  /// 5. Creates simple Jitsi URL (base URL + meeting ID)
  /// 6. Saves call log in database
  ///
  /// Request body:
  /// ```json
  /// {
  ///   "to_user_id": "93673",
  ///   "call_type": "video",
  ///   "platform": "android",
  ///   "image_avatar_url": "https://..."
  /// }
  /// ```
  ///
  /// Response:
  /// ```json
  /// {
  ///   "data": {
  ///     "id": 123,
  ///     "meeting_id": "abc-def-ghi",
  ///     "call_type": "video",
  ///     "call_status": "initiated"
  ///   },
  ///   "message": "Call initiated successfully",
  ///   "status": "success",
  ///   "status_code": 201
  /// }
  /// ```
  Future<ApiResponse<Call>> initiateCall({
    String? toUserPhone,
    String? toUserId,
    String? imageAvatarUrl,
    required CallType callType,
  }) async {
    try {
      String? normalizedPhone;
      if (toUserPhone != null && toUserPhone.isNotEmpty) {
        normalizedPhone = normalizePhone(toUserPhone);
        if (normalizedPhone.isEmpty || !isLikelyPhone(normalizedPhone)) {
          log('❌ [CallService] Invalid phone number: "$toUserPhone"',
              name: serviceName);
          return ApiResponse.error(
            'Invalid phone number. Please update the contact phone.',
            statusCode: 400,
          );
        }
      }

      if ((toUserId == null || toUserId.isEmpty) &&
          (normalizedPhone == null || normalizedPhone.isEmpty)) {
        return ApiResponse.error(
          'Recipient identifier missing. Please try again.',
          statusCode: 400,
        );
      }

      log('📞 [CallService] Initiating ${callType.value} call '
          'to_user_id: ${toUserId ?? "null"}, '
          'to_user_phone: ${normalizedPhone ?? "null"}',
          name: serviceName);

      final request = InitiateCallRequest(
        toUserPhone: normalizedPhone,
        toUserId: toUserId,
        imageAvatarUrl: imageAvatarUrl,
        callType: callType,
        platform: _platformForApi(),
      );
      final requestJson = request.toJson();
      log(
        '📤 [CallService] InitiateCall payload keys=${requestJson.keys.toList()} '
        'has_image_avatar_url=${requestJson.containsKey('image_avatar_url')}',
        name: serviceName,
      );

      final response = await post<Call>(
        '/calls',
        data: requestJson,
        fromJson: (json) {
          if (json == null) {
            throw Exception('Response data is null');
          }

          // Log the raw response for debugging
          log('🔍 [CallService] Raw response data type: ${json.runtimeType}',
              name: serviceName);
          if (json is Map<String, dynamic>) {
            log('🔍 [CallService] Response keys: ${json.keys.toList()}',
                name: serviceName);
          }

          return Call.fromJson(json as Map<String, dynamic>);
        },
      );

      if (response.success && response.data != null) {
        log('✅ [CallService] Call initiated successfully: ${response.data!.id}',
            name: serviceName);
        log('   Meeting ID: ${response.data!.meetingId}', name: serviceName);
        log('   Call Type: ${response.data!.callType.value}',
            name: serviceName);
      } else {
        log('❌ [CallService] Failed to initiate call: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e, stackTrace) {
      log('❌ [CallService] Exception initiating call: $e', name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to initiate call: $e',
        statusCode: 0,
      );
    }
  }

  /// Fetch a single call by id (for status polling when FCM may not be received).
  ///
  /// GET /api/v1/calls/{id} or equivalent. Returns null if endpoint is not
  /// available or call not found.
  Future<Call?> getCall(int callId) async {
    try {
      final response = await get<Call>(
        '/calls/$callId',
        fromJson: (json) {
          if (json == null) throw Exception('Response data is null');
          final map = json is Map<String, dynamic>
              ? json
              : (json is Map ? Map<String, dynamic>.from(json) : null);
          if (map == null) throw Exception('Invalid response shape');
          final callData = map['call'] is Map<String, dynamic>
              ? map['call'] as Map<String, dynamic>
              : map;
          return Call.fromJson(callData);
        },
      );
      if (response.success && response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      log('❌ [CallService] getCall failed: $e', name: serviceName);
      return null;
    }
  }

  /// Accept incoming call (receiver). Sets accepted_at on backend and allows
  /// backend to send FCM to caller. Call this before or with updateCallStatus(answered).
  ///
  /// POST /api/v1/calls/{call_id}/accept
  Future<ApiResponse<void>> acceptCall(int callId) async {
    try {
      log('📞 [CallService] Accepting call $callId', name: serviceName);
      final response = await post<void>(
        '/calls/$callId/accept',
        data: <String, dynamic>{},
        fromJson: (_) {},
      );
      if (response.success) {
        log('✅ [CallService] Call accepted: $callId', name: serviceName);
      } else {
        log('❌ [CallService] Failed to accept call: ${response.error}',
            name: serviceName);
      }
      return response;
    } catch (e, st) {
      log('❌ [CallService] acceptCall failed: $e', name: serviceName);
      log('   $st', name: serviceName);
      return ApiResponse.error('Failed to accept call: $e', statusCode: 0);
    }
  }

  /// Reject incoming call (receiver). Sets rejected_at and triggers FCM
  /// "call_rejected" to caller. Prefer this over only PATCH declined when
  /// backend uses POST reject to send FCM.
  ///
  /// POST /api/v1/calls/{call_id}/reject
  Future<ApiResponse<void>> rejectCall(int callId, {String? reason}) async {
    try {
      log('📞 [CallService] Rejecting call $callId', name: serviceName);
      final response = await post<void>(
        '/calls/$callId/reject',
        data: reason != null
            ? <String, dynamic>{'reason': reason}
            : <String, dynamic>{},
        fromJson: (_) {},
      );
      if (response.success) {
        log('✅ [CallService] Call rejected: $callId', name: serviceName);
      } else {
        log('❌ [CallService] Failed to reject call: ${response.error}',
            name: serviceName);
      }
      return response;
    } catch (e, st) {
      log('❌ [CallService] rejectCall failed: $e', name: serviceName);
      log('   $st', name: serviceName);
      return ApiResponse.error('Failed to reject call: $e', statusCode: 0);
    }
  }

  /// Update call status
  ///
  /// PATCH /api/v1/calls/{id}/status
  ///
  /// Request body:
  /// ```json
  /// {
  ///   "status": "answered"
  /// }
  /// ```
  ///
  /// Response:
  /// ```json
  /// {
  ///   "data": {
  ///     "id": 123,
  ///     "call_status": "answered"
  ///   },
  ///   "message": "Call status updated successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  /// ```
  ///
  /// Status transitions (managed by Flutter, not backend):
  /// - initiated → answered (Jitsi conference joined)
  /// - initiated → declined (user cancelled before join)
  /// - initiated → missed (no answer after timeout)
  /// - answered → ended (call terminated normally)
  Future<ApiResponse<void>> updateCallStatus({
    required int callId,
    required CallStatus status,
  }) async {
    try {
      log('📝 [CallService] Updating call $callId status to: ${status.value}',
          name: serviceName);

      final request = UpdateCallStatusRequest(
        status: status,
        platform: _platformForApi(),
      );

      final response = await patch<void>(
        '/calls/$callId/status',
        data: request.toJson(),
        fromJson: (_) {},
      );

      if (response.success) {
        log('✅ [CallService] Call status updated successfully: $callId → ${status.value}',
            name: serviceName);
      } else {
        log('❌ [CallService] Failed to update call status: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e, stackTrace) {
      log('❌ [CallService] Exception updating call status: $e',
          name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to update call status: $e',
        statusCode: 0,
      );
    }
  }

  String _platformForApi() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  /// PATCH request implementation (not in base class)
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Map<String, String>? headers,
  }) async {
    try {
      final authHeaders = await getAuthHeaders();
      final dio = await _getDio();

      final response = await dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            ...authHeaders,
            ...?headers,
          },
        ),
      );

      return _parseResponse<T>(response, fromJson);
    } catch (e) {
      log('❌ [CallService] PATCH request failed: $e', name: serviceName);
      return ApiResponse.error('Request failed: $e');
    }
  }

  /// Get Dio instance for custom requests
  Future<Dio> _getDio() async {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    return dio;
  }

  /// Parse response helper
  ApiResponse<T> _parseResponse<T>(
    Response response,
    T Function(dynamic)? fromJson,
  ) {
    try {
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final success = (data['success'] == true) ||
            (data['status'] == 'success') ||
            (response.statusCode == 200 || response.statusCode == 201);

        if (success) {
          if (fromJson != null &&
              data.containsKey('data') &&
              data['data'] != null) {
            final parsedData = fromJson(data['data']);
            return ApiResponse.success(
              parsedData,
              message: data['message'] as String?,
              statusCode: response.statusCode,
            );
          } else if (fromJson != null) {
            final parsedData = fromJson(data);
            return ApiResponse.success(
              parsedData,
              message: data['message'] as String?,
              statusCode: response.statusCode,
            );
          } else {
            return ApiResponse.success(
              null as T,
              message: data['message'] as String?,
              statusCode: response.statusCode,
            );
          }
        } else {
          return ApiResponse.error(
            data['error'] as String? ??
                data['message'] as String? ??
                'Request failed',
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse.success(null as T, statusCode: response.statusCode);
    } catch (e) {
      log('Response parsing error: $e', name: serviceName);
      return ApiResponse.error('Failed to parse response: $e');
    }
  }
}
