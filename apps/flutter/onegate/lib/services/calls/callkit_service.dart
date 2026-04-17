import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:intercom_module/core/services/call_coordinator.dart';
import 'package:intercom_module/core/services/incoming_call_presenter.dart';

import 'incoming_call_processing_guard.dart';

class CallKitService {
  CallKitService._();

  static final CallKitService instance = CallKitService._();

  static const String incomingCallChannelName = 'Incoming Calls';
  static const String missedCallChannelName = 'Missed Calls';

  StreamSubscription<CallEvent?>? _eventSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;

    _eventSubscription ??=
        FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);
    _initialized = true;

    try {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (e) {
      log('⚠️ [CallKitService] requestFullIntentPermission failed: $e');
    }

    log('✅ [CallKitService] Initialized');
  }

  Future<void> showIncomingCall(
    Map<String, dynamic> rawData, {
    required bool fromBackground,
  }) async {
    if (!Platform.isAndroid) return;

    final data = Map<String, dynamic>.from(rawData);
    final callId =
        data['call_id']?.toString() ?? data['callId']?.toString() ?? '';
    if (callId.isEmpty) {
      log(
        '⚠️ [CallKitService] Missing call_id fromBackground=$fromBackground data=$data',
      );
      return;
    }

    final callerName =
        _stringValue(data['caller_name'], fallback: 'Incoming Call');
    final callerPhone = _stringValue(data['caller_phone'], fallback: 'OneGate');
    final image =
        _stringValue(data['image']) ?? _stringValue(data['image_avatar_url']);
    final callType = _stringValue(data['call_type'], fallback: 'video');

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'OneGate',
      avatar: image,
      handle: callerPhone,
      type: callType == 'audio' ? 0 : 1,
      duration: 60000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: <String, dynamic>{
        'call_id': callId,
        'call_type': callType,
        'caller_name': callerName,
        'caller_phone': callerPhone,
        'meeting_id': _stringValue(data['meeting_id']),
        'jitsi_url': _stringValue(data['jitsi_url']),
        'image': image,
      },
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      android: const AndroidParams(
        isShowFullLockedScreen: true,
        isImportant: true,
        incomingCallNotificationChannelName: incomingCallChannelName,
        missedCallNotificationChannelName: missedCallChannelName,
        ringtonePath: 'incoming_call',
        isCustomNotification: true,
        isShowLogo: false,
        backgroundColor: '#B71C1C',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
      ),
    );

    try {
      log(
        '📲 [CallKitService] showIncomingCall call_id=$callId '
        'state=${CallCoordinator.instance.state.value.name} fromBackground=$fromBackground',
      );
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e, st) {
      log(
        '❌ [CallKitService] showIncomingCall failed call_id=$callId error=$e',
        stackTrace: st,
      );
    }
  }

  Future<void> dismissIncomingUi(String? callId) async {
    if (!Platform.isAndroid) return;
    if (callId == null || callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
      log('🧹 [CallKitService] Dismissed incoming UI call_id=$callId');
    } catch (e) {
      log('⚠️ [CallKitService] Failed to dismiss incoming UI call_id=$callId: $e');
    }
  }

  Future<void> _handleCallKitEvent(CallEvent? event) async {
    if (event == null) return;

    final eventName = _normalizeEventName(event.event);
    final payload = _extractPayload(event.body);
    final callId =
        payload['call_id']?.toString() ?? payload['id']?.toString() ?? '';

    log(
      '📟 [CallKitService] event=$eventName call_id=${callId.isEmpty ? "-" : callId} '
      'state=${CallCoordinator.instance.state.value.name}',
    );

    if (callId.isEmpty) return;

    final isStaleTerminalEvent =
        (eventName == 'actionCallTimeout' || eventName == 'actionCallEnded') &&
            CallCoordinator.instance.isNavigationLocked &&
            CallCoordinator.instance.activeCallId == callId;
    if (isStaleTerminalEvent) {
      log(
        '⏭️ [CallKitService] Ignoring stale terminal event=$eventName call_id=$callId during accept handoff',
      );
      return;
    }

    switch (eventName) {
      case 'actionCallAccept':
        if (CallCoordinator.instance.isAcceptingIncomingHandoff ||
            CallCoordinator.instance.state.value == CallFlowState.connected) {
          log('⏭️ [CallKitService] Duplicate accept ignored call_id=$callId');
          return;
        }
        try {
          await IncomingCallPresenter.instance.acceptIncomingCall(payload);
          await dismissIncomingUi(callId);
          await IncomingCallProcessingGuard.clear(callId);
        } catch (e, st) {
          log(
            '❌ [CallKitService] Accept failed call_id=$callId error=$e',
            stackTrace: st,
          );
        }
        return;
      case 'actionCallDecline':
        try {
          await IncomingCallPresenter.instance.declineIncomingCall(payload);
        } catch (e, st) {
          log(
            '⚠️ [CallKitService] Decline callback failed call_id=$callId error=$e',
            stackTrace: st,
          );
        } finally {
          await dismissIncomingUi(callId);
          await CallCoordinator.instance.markEnded(reason: 'callkit_decline');
          await IncomingCallProcessingGuard.clear(callId);
        }
        return;
      case 'actionCallTimeout':
        await dismissIncomingUi(callId);
        await CallCoordinator.instance.markEnded(reason: 'callkit_timeout');
        await IncomingCallProcessingGuard.clear(callId);
        return;
      case 'actionCallEnded':
        await dismissIncomingUi(callId);
        await CallCoordinator.instance.markEnded(reason: 'callkit_ended');
        await IncomingCallProcessingGuard.clear(callId);
        return;
      case 'actionCallCallback':
        log('ℹ️ [CallKitService] Callback action tapped call_id=$callId');
        return;
      default:
        return;
    }
  }

  Map<String, dynamic> _extractPayload(dynamic body) {
    if (body is Map) {
      final raw = Map<String, dynamic>.from(body);
      final extra = raw['extra'];
      if (extra is Map) {
        return <String, dynamic>{...raw, ...Map<String, dynamic>.from(extra)};
      }
      return raw;
    }
    return <String, dynamic>{};
  }

  String _normalizeEventName(dynamic event) {
    final raw = event?.toString() ?? '';
    if (raw.contains('.')) {
      return raw.split('.').last;
    }
    return raw;
  }

  String? _stringValue(dynamic value, {String? fallback}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }
}
