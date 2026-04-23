import 'dart:developer';

import '../../modules/household/intercom/models/call_model.dart';
import '../../modules/household/intercom/models/call_status.dart';
import '../../modules/household/intercom/models/call_type.dart';
import '../../modules/household/intercom/services/call_manager.dart';
import '../../modules/household/intercom/services/call_service.dart';
import 'call_coordinator.dart';
import 'keycloak_service.dart';

class IncomingCallPresenter {
  IncomingCallPresenter._();

  static final IncomingCallPresenter instance = IncomingCallPresenter._();

  Future<CallResult> acceptIncomingCall(Map<String, dynamic> payload) async {
    final call = _callFromPayload(payload);
    if (call == null) {
      return CallResult.failure(
        error: 'Invalid incoming call payload',
        message: 'Missing call_id or meeting details',
      );
    }

    final displayName = await _resolveDisplayName();
    final userEmail = await _resolveUserEmail();

    try {
      await CallService.instance.acceptCall(call.id);
    } catch (e) {
      log('⚠️ [IncomingCallPresenter] acceptCall failed for ${call.id}: $e');
    }

    try {
      await CallService.instance.updateCallStatus(
        callId: call.id,
        status: CallStatus.answered,
      );
    } catch (e) {
      log(
        '⚠️ [IncomingCallPresenter] updateCallStatus(answered) failed for ${call.id}: $e',
      );
    }

    await CallCoordinator.instance.acceptIncomingCall(payload);
    final result = await CallManager.instance.answerIncomingCall(
      call: call,
      displayName: displayName,
      userEmail: userEmail,
    );
    if (result.success) {
      await CallCoordinator.instance.markConnected(callId: call.id.toString());
    } else {
      await CallCoordinator.instance.markEnded(reason: 'incoming_accept_failed');
    }
    return result;
  }

  Future<void> declineIncomingCall(Map<String, dynamic> payload) async {
    final callId = _intValue(payload['call_id'] ?? payload['callId']);
    if (callId == null) {
      await CallCoordinator.instance.markEnded(reason: 'incoming_decline_missing_call');
      return;
    }

    try {
      await CallService.instance.rejectCall(callId, reason: 'declined');
    } catch (e) {
      log('⚠️ [IncomingCallPresenter] rejectCall failed for $callId: $e');
      try {
        await CallService.instance.updateCallStatus(
          callId: callId,
          status: CallStatus.declined,
        );
      } catch (inner) {
        log(
          '⚠️ [IncomingCallPresenter] updateCallStatus(declined) failed for $callId: $inner',
        );
      }
    }

    await CallCoordinator.instance.markEnded(reason: 'incoming_declined');
  }

  Call? _callFromPayload(Map<String, dynamic> payload) {
    final callId = _intValue(payload['call_id'] ?? payload['callId']);
    final meetingId =
        payload['meeting_id']?.toString().trim() ??
        payload['meetingId']?.toString().trim();
    final callType =
        CallType.tryFromString(payload['call_type']?.toString()) ??
        CallType.video;

    if (callId == null || meetingId == null || meetingId.isEmpty) return null;

    return Call(
      id: callId,
      meetingId: meetingId,
      jitsiMeetingUrl: payload['jitsi_url']?.toString(),
      callType: callType,
      status: CallStatus.initiated,
      toUserPhone: payload['caller_phone']?.toString(),
      fromUser: CallUser(
        id: _intValue(payload['caller_user_id']) ?? 0,
        name: payload['caller_name']?.toString(),
        phone: payload['caller_phone']?.toString(),
      ),
    );
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Future<String> _resolveDisplayName() async {
    try {
      final userData = await KeycloakService.getUserData();
      final name = userData?['name'] ?? userData?['preferred_username'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString().trim();
      }
    } catch (e) {
      log('⚠️ [IncomingCallPresenter] Failed to resolve display name: $e');
    }
    return 'User';
  }

  Future<String?> _resolveUserEmail() async {
    try {
      final userData = await KeycloakService.getUserData();
      final email = userData?['email'];
      if (email != null && email.toString().trim().isNotEmpty) {
        return email.toString().trim();
      }
    } catch (e) {
      log('⚠️ [IncomingCallPresenter] Failed to resolve email: $e');
    }
    return null;
  }
}
