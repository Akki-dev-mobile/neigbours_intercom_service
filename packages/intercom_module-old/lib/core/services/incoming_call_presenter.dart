import 'dart:developer';

import '../../modules/household/intercom/models/call_model.dart';
import '../../modules/household/intercom/models/call_status.dart';
import '../../modules/household/intercom/models/call_type.dart';
import '../../modules/household/intercom/services/call_manager.dart';
import '../../modules/household/intercom/services/call_service.dart';
import 'call_action_guard.dart';
import 'call_coordinator.dart';

class IncomingCallAcceptResult {
  final bool success;
  final String? error;

  const IncomingCallAcceptResult._({
    required this.success,
    this.error,
  });

  factory IncomingCallAcceptResult.success() =>
      const IncomingCallAcceptResult._(success: true);

  factory IncomingCallAcceptResult.failure(String error) =>
      IncomingCallAcceptResult._(success: false, error: error);
}

class IncomingCallPresenter {
  IncomingCallPresenter._();

  static final IncomingCallPresenter instance = IncomingCallPresenter._();

  Future<IncomingCallAcceptResult> acceptIncomingCall(
    Map<String, dynamic> payload,
  ) async {
    final callId = _resolveCallId(payload);
    if (callId == null || callId.isEmpty) {
      return IncomingCallAcceptResult.failure('Missing call id');
    }

    if (!CallActionGuard.instance.tryBeginAccept(callId)) {
      return IncomingCallAcceptResult.failure('Accept already in flight');
    }

    try {
      final call = await _resolveCall(payload);
      if (call == null) {
        return IncomingCallAcceptResult.failure('Unable to resolve call');
      }

      await CallCoordinator.instance.acceptIncomingCall(payload);

      final displayName = payload['receiver_name']?.toString().trim().isNotEmpty ==
              true
          ? payload['receiver_name'].toString().trim()
          : payload['callee_name']?.toString().trim().isNotEmpty == true
              ? payload['callee_name'].toString().trim()
              : 'Gate User';

      final result = await CallManager.instance.answerIncomingCall(
        call: call,
        displayName: displayName,
      );

      if (!result.success) {
        await CallCoordinator.instance.markEnded(
          reason: result.error ?? 'accept_failed',
          callId: callId,
        );
        return IncomingCallAcceptResult.failure(result.error ?? 'Accept failed');
      }

      await CallCoordinator.instance.markConnected(callId: callId);
      return IncomingCallAcceptResult.success();
    } catch (e, st) {
      log('❌ [IncomingCallPresenter] accept failed: $e', stackTrace: st);
      await CallCoordinator.instance.markEnded(
        reason: 'accept_exception',
        callId: callId,
      );
      return IncomingCallAcceptResult.failure('$e');
    } finally {
      CallActionGuard.instance.clearCall(callId);
      CallCoordinator.instance.setAcceptingIncomingHandoff(false);
    }
  }

  Future<void> declineIncomingCall(Map<String, dynamic> payload) async {
    final callId = _resolveCallId(payload);
    final call = await _resolveCall(payload);
    if (call != null) {
      await CallService.instance.updateCallStatus(
        callId: call.id,
        status: CallStatus.declined,
      );
    }
    await CallCoordinator.instance.markEnded(
      reason: 'declined',
      callId: callId,
    );
  }

  Future<Call?> _resolveCall(Map<String, dynamic> payload) async {
    final callIdRaw = _resolveCallId(payload);
    final callId = int.tryParse(callIdRaw ?? '');
    if (callId == null) return null;

    final fromApi = await CallService.instance.getCall(callId);
    if (fromApi != null) return fromApi;

    final meetingId = payload['meeting_id']?.toString().trim().isNotEmpty == true
        ? payload['meeting_id'].toString().trim()
        : payload['meetingId']?.toString().trim().isNotEmpty == true
            ? payload['meetingId'].toString().trim()
            : callId.toString();

    final callType = CallType.tryFromString(
          payload['call_type']?.toString() ?? payload['callType']?.toString(),
        ) ??
        CallType.audio;

    return Call(
      id: callId,
      meetingId: meetingId,
      jitsiMeetingUrl: payload['jitsi_url']?.toString() ??
          payload['jitsi_meeting_url']?.toString(),
      callType: callType,
      status: CallStatus.initiated,
    );
  }

  String? _resolveCallId(Map<String, dynamic> payload) {
    final raw = payload['call_id'] ?? payload['callId'] ?? payload['id'];
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
