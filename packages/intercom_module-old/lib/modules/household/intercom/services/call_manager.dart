import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../../../core/services/keycloak_service.dart';
import '../../../../core/utils/profile_data_helper.dart';
import '../../../../utils/storage/sso_storage.dart';
import '../models/call_model.dart';
import '../models/call_type.dart';
import 'call_service.dart';
import 'jitsi_call_controller.dart';

/// CallManager orchestrates the entire call flow
///
/// This manager is responsible for:
/// - Permission handling (microphone, camera, bluetooth)
/// - Coordinating between CallService and JitsiCallController
/// - Error handling and user feedback
///
/// It does NOT handle:
/// - Backend API calls directly (uses CallService)
/// - Jitsi SDK operations directly (uses JitsiCallController)
/// - UI components (returns results for UI to handle)
///
/// Call Flow:
/// 1. Request permissions
/// 2. Call backend to create call record
/// 3. Join Jitsi meeting via SDK
/// 4. Handle lifecycle events and update backend status
class CallManager {
  static CallManager? _instance;

  final CallService _callService = CallService.instance;
  final JitsiCallController _jitsiController = JitsiCallController.instance;

  CallManager._();

  /// Get singleton instance
  static CallManager get instance {
    _instance ??= CallManager._();
    return _instance!;
  }

  /// Stream of call state events (from JitsiCallController)
  Stream<CallStateEvent> get callStateStream =>
      _jitsiController.callStateStream;

  /// Check if a call is currently in progress
  bool get isCallInProgress => _jitsiController.isCallInProgress;

  /// Get the currently active call
  Call? get activeCall => _jitsiController.activeCall;

  /// Initiate a call to a user
  ///
  /// This method:
  /// 1. Checks and requests required permissions
  /// 2. Calls backend to create call record
  /// 3. Joins Jitsi meeting
  ///
  /// [toUserPhone] - Phone number of the recipient
  /// [callType] - Type of call (audio or video)
  /// [displayName] - Current user's display name
  /// [avatarUrl] - Current user's avatar URL (optional)
  /// [userEmail] - Current user's email (optional)
  ///
  /// Returns [CallResult] with success status and call/error details
  Future<CallResult> initiateCall({
    String? toUserPhone,
    String? toUserId,
    String? toUserAvatarUrl,
    required CallType callType,
    required String displayName,
    String? avatarUrl,
    String? userEmail,
    bool joinJitsiImmediately = true,
  }) async {
    try {
      log('📞 [CallManager] Initiating ${callType.displayName} to: $toUserPhone',
          name: 'CallManager');

      // Step 1: Check/request permissions only if we are about to join Jitsi now.
      // Outgoing ringing UX must happen outside Jitsi; permissions will be
      // requested at join time (after accept) by CallCoordinator.
      if (joinJitsiImmediately) {
        final permissionResult = await _checkAndRequestPermissions(callType);
        if (!permissionResult.granted) {
          log('❌ [CallManager] Permissions denied: ${permissionResult.deniedPermissions}',
              name: 'CallManager');
          return CallResult.failure(
            error: 'Permissions required',
            message: permissionResult.message,
            permissionsDenied: true,
          );
        }
        log('✅ [CallManager] Permissions granted', name: 'CallManager');
      } else {
        log(
          '⏭️ [CallManager] joinJitsiImmediately=false; skipping permission prompt until accept',
          name: 'CallManager',
        );
      }

      final callerAvatarUrl =
          (avatarUrl != null && avatarUrl.trim().isNotEmpty)
              ? avatarUrl.trim()
              : await _resolveCurrentUserAvatarUrl();
      log(
        '🖼️ [CallManager] Caller avatar resolved: ${(callerAvatarUrl != null && callerAvatarUrl.isNotEmpty) ? "yes" : "no"}',
        name: 'CallManager',
      );

      final recipientAvatarUrl = _resolveRecipientAvatarUrl(
        toUserAvatarUrl: toUserAvatarUrl,
        toUserId: toUserId,
      );
      log(
        '🖼️ [CallManager] Recipient avatar resolved: ${(recipientAvatarUrl != null && recipientAvatarUrl.isNotEmpty) ? "yes" : "no"}',
        name: 'CallManager',
      );

      // Step 2: Call backend to create call record
      log('📡 [CallManager] Creating call record on backend...',
          name: 'CallManager');
      final response = await _callService.initiateCall(
        toUserPhone: toUserPhone,
        toUserId: toUserId,
        callType: callType,
        // IMPORTANT: backend uses this image for the *caller* avatar in the
        // receiver's incoming call UI / notification. Never send the recipient
        // avatar here (that would show the receiver's own avatar).
        imageAvatarUrl: callerAvatarUrl,
      );

      if (!response.success || response.data == null) {
        log('❌ [CallManager] Backend call failed: ${response.error}',
            name: 'CallManager');
        return CallResult.failure(
          error: response.error ?? 'Failed to create call',
          message: response.message,
        );
      }

      final call = response.data!;
      log('✅ [CallManager] Call created: ${call.id}, meeting: ${call.meetingId}',
          name: 'CallManager');

      if (joinJitsiImmediately) {
        // Step 3: Join Jitsi meeting
        log('🎥 [CallManager] Joining Jitsi meeting...', name: 'CallManager');
        await _jitsiController.joinCall(
          call: call,
          displayName: displayName,
          avatarUrl: callerAvatarUrl,
          userEmail: userEmail,
        );
      } else {
        // WhatsApp-style behavior: caller should not open Jitsi immediately.
        // Caller should join only after callee accepts (requires server-side accept signal).
        log('⏸️ [CallManager] joinJitsiImmediately=false, not opening Jitsi yet',
            name: 'CallManager');
      }

      log('✅ [CallManager] Call initiated successfully', name: 'CallManager');
      return CallResult.success(call: call);
    } catch (e, stackTrace) {
      log('❌ [CallManager] Error initiating call: $e', name: 'CallManager');
      log('   Stack trace: $stackTrace', name: 'CallManager');
      return CallResult.failure(
        error: 'Failed to initiate call',
        message: e.toString(),
      );
    }
  }

  Future<String?> _resolveCurrentUserAvatarUrl() async {
    try {
      final userData = await KeycloakService.getUserData();
      final ssoProfile = await SsoStorage.getUserProfile();

      Map<String, dynamic> tokenClaims = <String, dynamic>{};
      try {
        final token = await KeycloakService.getAccessToken() ??
            await SsoStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          tokenClaims = JwtDecoder.decode(token);
        }
      } catch (_) {
        tokenClaims = <String, dynamic>{};
      }

      final merged = <String, dynamic>{
        ...?ssoProfile,
        ...?userData,
        ...tokenClaims,
      };

      final normalized = ProfileDataHelper.normalizeProfile(merged);
      final direct = ProfileDataHelper.resolveAvatarUrl(normalized);
      if (direct != null && direct.trim().isNotEmpty) return direct.trim();

      final fallbackUserId = _resolveNumericUserId(normalized);
      final built = ProfileDataHelper.buildAvatarUrlFromUserId(
        fallbackUserId,
        size: 'large',
      );
      return (built != null && built.trim().isNotEmpty) ? built.trim() : null;
    } catch (_) {
      return null;
    }
  }

  dynamic _resolveNumericUserId(Map<String, dynamic>? data) {
    if (data == null) return null;
    final candidates = [
      data['old_gate_user_id'],
      data['old_sso_user_id'],
      data['user_id'],
      data['vendor_user_id'],
      data['user_account_id'],
      data['member_id'],
      data['memberId'],
    ];
    for (final id in candidates) {
      if (id == null) continue;
      final idStr = id.toString().trim();
      if (idStr.isNotEmpty && !idStr.contains('-') && int.tryParse(idStr) != null) {
        return idStr;
      }
    }
    return null;
  }

  String? _resolveRecipientAvatarUrl({
    required String? toUserAvatarUrl,
    required String? toUserId,
  }) {
    final fromContact = toUserAvatarUrl?.trim();
    if (fromContact != null && fromContact.isNotEmpty) {
      final resolved = ProfileDataHelper.resolveAvatarUrl({'avatar': fromContact});
      return resolved?.trim().isNotEmpty == true ? resolved!.trim() : fromContact;
    }

    final built = ProfileDataHelper.buildAvatarUrlFromUserId(
      toUserId,
      size: 'large',
    );
    return built?.trim().isNotEmpty == true ? built!.trim() : null;
  }

  /// Cancel the current call before joining
  Future<void> cancelCall() async {
    await _jitsiController.cancelCall();
  }

  /// Hang up the current call
  Future<void> hangUp() async {
    await _jitsiController.hangUp();
  }

  /// Answer an incoming call (from push notification)
  ///
  /// This method:
  /// 1. Requests required permissions based on call type
  /// 2. Joins the Jitsi meeting using call data
  Future<CallResult> answerIncomingCall({
    required Call call,
    required String displayName,
    String? avatarUrl,
    String? userEmail,
  }) async {
    try {
      if (isCallInProgress) {
        log('⚠️ [CallManager] Call already in progress, ignoring incoming call',
            name: 'CallManager');
        return CallResult.failure(
          error: 'Call in progress',
          message: 'A call is already active',
        );
      }

      final permissionResult = await _checkAndRequestPermissions(call.callType);
      if (!permissionResult.granted) {
        return CallResult.failure(
          error: 'Permissions required',
          message: permissionResult.message,
          permissionsDenied: true,
        );
      }

      await _jitsiController.joinCall(
        call: call,
        displayName: displayName,
        avatarUrl: avatarUrl,
        userEmail: userEmail,
      );

      return CallResult.success(call: call);
    } catch (e, stackTrace) {
      log('❌ [CallManager] Error answering call: $e', name: 'CallManager');
      log('   Stack trace: $stackTrace', name: 'CallManager');
      return CallResult.failure(
        error: 'Failed to answer call',
        message: e.toString(),
      );
    }
  }

  /// Check and request required permissions for the call
  ///
  /// Required permissions:
  /// - Microphone: Always required
  /// - Camera: Required for video calls only
  /// - Bluetooth: Required on Android 12+ for audio routing
  Future<PermissionResult> _checkAndRequestPermissions(
      CallType callType) async {
    final List<Permission> requiredPermissions = [
      Permission.microphone,
    ];

    // Add camera permission for video calls
    if (callType.isVideo) {
      requiredPermissions.add(Permission.camera);
    }

    // Add Bluetooth permission for Android 12+ (API 31+)
    if (Platform.isAndroid) {
      requiredPermissions.add(Permission.bluetoothConnect);
    }

    // Check current status
    final Map<Permission, PermissionStatus> statuses = {};
    for (final permission in requiredPermissions) {
      statuses[permission] = await permission.status;
    }

    // Find permissions that need to be requested
    final permissionsToRequest = statuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key)
        .toList();

    if (permissionsToRequest.isEmpty) {
      return PermissionResult.granted();
    }

    // Request permissions
    log('🔐 [CallManager] Requesting permissions: ${permissionsToRequest.map((p) => p.toString()).join(", ")}',
        name: 'CallManager');

    final results = await permissionsToRequest.request();

    // Check results
    final deniedPermissions = <Permission>[];
    final permanentlyDeniedPermissions = <Permission>[];

    for (final entry in results.entries) {
      if (entry.value.isDenied) {
        deniedPermissions.add(entry.key);
      } else if (entry.value.isPermanentlyDenied) {
        permanentlyDeniedPermissions.add(entry.key);
      }
    }

    if (deniedPermissions.isEmpty && permanentlyDeniedPermissions.isEmpty) {
      return PermissionResult.granted();
    }

    // Build error message
    String message;
    if (permanentlyDeniedPermissions.isNotEmpty) {
      message = _buildPermissionDeniedMessage(permanentlyDeniedPermissions,
          isPermanent: true);
    } else {
      message =
          _buildPermissionDeniedMessage(deniedPermissions, isPermanent: false);
    }

    return PermissionResult.denied(
      deniedPermissions: [
        ...deniedPermissions,
        ...permanentlyDeniedPermissions
      ],
      permanentlyDenied: permanentlyDeniedPermissions.isNotEmpty,
      message: message,
    );
  }

  /// Build a user-friendly message for denied permissions
  String _buildPermissionDeniedMessage(List<Permission> permissions,
      {required bool isPermanent}) {
    final permissionNames = permissions.map((p) {
      if (p == Permission.microphone) return 'Microphone';
      if (p == Permission.camera) return 'Camera';
      if (p == Permission.bluetoothConnect) return 'Bluetooth';
      return p.toString();
    }).join(', ');

    if (isPermanent) {
      return '$permissionNames permission(s) are permanently denied. '
          'Please enable them in app settings to make calls.';
    } else {
      return '$permissionNames permission(s) are required to make calls. '
          'Please grant the required permissions.';
    }
  }

  /// Open app settings for the user to enable permissions
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }
}

/// Result of a call initiation
class CallResult {
  final bool success;
  final Call? call;
  final String? error;
  final String? message;
  final bool permissionsDenied;

  CallResult._({
    required this.success,
    this.call,
    this.error,
    this.message,
    this.permissionsDenied = false,
  });

  factory CallResult.success({required Call call}) {
    return CallResult._(
      success: true,
      call: call,
    );
  }

  factory CallResult.failure({
    required String error,
    String? message,
    bool permissionsDenied = false,
  }) {
    return CallResult._(
      success: false,
      error: error,
      message: message,
      permissionsDenied: permissionsDenied,
    );
  }
}

/// Result of permission check
class PermissionResult {
  final bool granted;
  final List<Permission> deniedPermissions;
  final bool permanentlyDenied;
  final String message;

  PermissionResult._({
    required this.granted,
    this.deniedPermissions = const [],
    this.permanentlyDenied = false,
    this.message = '',
  });

  factory PermissionResult.granted() {
    return PermissionResult._(granted: true);
  }

  factory PermissionResult.denied({
    required List<Permission> deniedPermissions,
    required bool permanentlyDenied,
    required String message,
  }) {
    return PermissionResult._(
      granted: false,
      deniedPermissions: deniedPermissions,
      permanentlyDenied: permanentlyDenied,
      message: message,
    );
  }
}
