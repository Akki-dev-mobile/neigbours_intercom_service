import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_onegate/services/calls/call_callback_ux_service.dart';
import 'package:intercom_module/core/services/call_coordinator.dart';
import 'package:intercom_module/core/services/incoming_call_presenter.dart';
import 'package:intercom_module/modules/household/intercom/models/call_status.dart';
import 'package:intercom_module/modules/household/intercom/services/call_service.dart';

import 'incoming_call_processing_guard.dart';
import 'pending_call_callback_store.dart';
import 'pending_incoming_accept_store.dart';

class CallKitService {
  CallKitService._();

  static final CallKitService instance = CallKitService._();

  static const String incomingCallChannelName = 'Incoming Calls';
  static const String missedCallChannelName = 'Missed Calls';

  StreamSubscription<CallEvent?>? _eventSubscription;
  bool _initialized = false;
  String? _lastMissedNotificationCallId;
  DateTime? _lastMissedNotificationAt;
  static const Duration _missedNotificationDedupeWindow = Duration(seconds: 8);
  final Map<String, Timer> _incomingTerminalPollers = <String, Timer>{};
  final Map<String, DateTime> _incomingTerminalPollStartedAt =
      <String, DateTime>{};
  final Set<String> _incomingTerminalPollAnsweredCallIds = <String>{};
  static const Duration _incomingTerminalPollDuration = Duration(seconds: 60);

  Future<void> initialize() async {
    if (_initialized) return;

    _eventSubscription ??=
        FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);
    _initialized = true;

    if (Platform.isAndroid) {
      try {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      } catch (e) {
        log('⚠️ [CallKitService] requestFullIntentPermission failed: $e');
      }
    }

    log('✅ [CallKitService] Initialized');
  }

  Future<bool> showIncomingCall(
    Map<String, dynamic> rawData, {
    required bool fromBackground,
  }) async {
    if (!Platform.isAndroid) return false;

    final data = Map<String, dynamic>.from(rawData);
    final callId =
        data['call_id']?.toString() ?? data['callId']?.toString() ?? '';
    if (callId.isEmpty) {
      log(
        '⚠️ [CallKitService] Missing call_id fromBackground=$fromBackground data=$data',
      );
      return false;
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
        // We post a richer app-managed missed notification with callback.
        // Skip plugin's timeout-generated missed notification to avoid duplicates.
        'onegate_managed_missed_notification': true,
        'meeting_id':
            _stringValue(data['meeting_id']) ?? _stringValue(data['meetingId']),
        'meetingId':
            _stringValue(data['meetingId']) ?? _stringValue(data['meeting_id']),
        'jitsi_url': _stringValue(data['jitsi_url']) ??
            _stringValue(data['jitsi_meeting_url']),
        'jitsi_meeting_url': _stringValue(data['jitsi_meeting_url']) ??
            _stringValue(data['jitsi_url']),
        'image': image,
      },
      missedCallNotification: const NotificationParams(
        showNotification: false,
        isShowCallback: false,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      android: const AndroidParams(
        isShowFullLockedScreen: true,
        isImportant: true,
        incomingCallNotificationChannelName: incomingCallChannelName,
        missedCallNotificationChannelName: missedCallChannelName,
        ringtonePath: 'incoming_call',
        // Keep custom incoming template enabled so swipe-up affordance/animation
        // and call UI styling are rendered by the native callkit screen.
        isCustomNotification: true,
        isShowLogo: true,
        logoUrl: 'assets/media/images/oneapptm.png',
        backgroundColor: '#F26D6D',
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
      ),
    );

    try {
      log(
        '📲 [CallKitService] showIncomingCall call_id=$callId '
        'state=${CallCoordinator.instance.state.value.name} fromBackground=$fromBackground',
      );
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      _startIncomingTerminalPoll(callId, data);
      return true;
    } catch (e, st) {
      log(
        '❌ [CallKitService] showIncomingCall failed call_id=$callId error=$e',
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> dismissIncomingUi(
    String? callId, {
    bool showMissedNotification = false,
    Map<String, dynamic>? payload,
  }) async {
    if (callId == null || callId.isEmpty) return;
    try {
      _stopIncomingTerminalPoll(callId);
      await FlutterCallkitIncoming.endCall(callId);
      log('🧹 [CallKitService] Dismissed incoming UI call_id=$callId');
      if (showMissedNotification &&
          payload != null &&
          !_isDuplicateMissedNotification(callId)) {
        await _showMissedCallNotification(payload, callId: callId);
        _lastMissedNotificationCallId = callId;
        _lastMissedNotificationAt = DateTime.now();
      }
    } catch (e) {
      log('⚠️ [CallKitService] Failed to dismiss incoming UI call_id=$callId: $e');
    }
  }

  void _startIncomingTerminalPoll(
    String callId,
    Map<String, dynamic> payload,
  ) {
    final numericCallId = int.tryParse(callId);
    if (numericCallId == null) {
      return;
    }
    _stopIncomingTerminalPoll(callId);
    _incomingTerminalPollStartedAt[callId] = DateTime.now();
    _incomingTerminalPollers[callId] = Timer.periodic(
      const Duration(seconds: 2),
      (timer) async {
        final startedAt = _incomingTerminalPollStartedAt[callId];
        if (startedAt == null ||
            DateTime.now().difference(startedAt) >
                _incomingTerminalPollDuration) {
          _stopIncomingTerminalPoll(callId);
          return;
        }
        try {
          final call = await CallService.instance.getCall(numericCallId);
          if (call == null) return;
          final status = call.status;
          if (status == CallStatus.answered) {
            _incomingTerminalPollAnsweredCallIds.add(callId);
            return;
          }
          if (status == CallStatus.initiated) {
            return;
          }
          log(
            '📥 [CallKitService] Terminal poll hit call_id=$callId status=${status.value}',
          );
          final terminalPayload = <String, dynamic>{
            ...payload,
            'call_id': callId,
            'status': status.value,
            'action': status == CallStatus.declined
                ? 'call_declined'
                : (status == CallStatus.missed ? 'missed' : 'call_ended'),
          };
          final isDeclinedByUser = status == CallStatus.declined;
          final shouldShowMissedNotification =
              _shouldShowMissedNotificationForPolledTerminal(
            callId: callId,
            status: status,
          );
          await dismissIncomingUi(
            callId,
            showMissedNotification:
                !isDeclinedByUser && shouldShowMissedNotification,
            payload: terminalPayload,
          );
          if (isDeclinedByUser) {
            Fluttertoast.showToast(
              msg: 'Receiver declined the call.',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
          await CallCoordinator.instance.handleCallEndedData(
            terminalPayload,
            fromBackground: false,
          );
          await PendingIncomingAcceptStore.clear();
          await IncomingCallProcessingGuard.clear(callId);
          if (!isDeclinedByUser && shouldShowMissedNotification) {
            await CallCallbackUxService.instance
                .handleRemoteTerminalForCallback(
              terminalPayload,
              source: 'incoming_terminal_poll',
            );
          }
          _stopIncomingTerminalPoll(callId);
        } catch (_) {
          // Keep polling on transient parsing/network failures.
        }
      },
    );
  }

  void _stopIncomingTerminalPoll(String callId) {
    _incomingTerminalPollers.remove(callId)?.cancel();
    _incomingTerminalPollStartedAt.remove(callId);
    _incomingTerminalPollAnsweredCallIds.remove(callId);
  }

  bool _shouldShowMissedNotificationForPolledTerminal({
    required String callId,
    required CallStatus status,
  }) {
    if (status == CallStatus.declined) return false;
    if (_incomingTerminalPollAnsweredCallIds.contains(callId)) return false;
    if (CallCoordinator.instance.isAcceptingIncomingHandoff ||
        CallCoordinator.instance.state.value == CallFlowState.connecting ||
        CallCoordinator.instance.state.value == CallFlowState.connected) {
      return false;
    }

    final activeCallId = CallCoordinator.instance.activeCallId?.trim();
    final matchesActiveCall = activeCallId == null ||
        activeCallId.isEmpty ||
        activeCallId == callId.trim();
    if (matchesActiveCall &&
        CallCoordinator.instance.state.value == CallFlowState.ringing) {
      return true;
    }

    return status == CallStatus.missed;
  }

  bool _isDuplicateMissedNotification(String callId) {
    if (_lastMissedNotificationCallId != callId) return false;
    final at = _lastMissedNotificationAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _missedNotificationDedupeWindow;
  }

  Future<void> _showMissedCallNotification(
    Map<String, dynamic> rawData, {
    required String callId,
  }) async {
    try {
      final data = Map<String, dynamic>.from(rawData);
      final numericCallId = int.tryParse(callId);
      if (numericCallId != null) {
        try {
          final call = await CallService.instance.getCall(numericCallId);
          if (call != null) {
            final fromUserIdRaw =
                call.fromUser?.userId?.toString().trim().isNotEmpty == true
                    ? call.fromUser!.userId!.toString().trim()
                    : (call.fromUserId?.toString() ?? '');
            final toUserIdRaw =
                call.toUser?.userId?.toString().trim().isNotEmpty == true
                    ? call.toUser!.userId!.toString().trim()
                    : (call.toUserId?.toString() ?? '');
            if (fromUserIdRaw.isNotEmpty) {
              data['caller_user_id'] = fromUserIdRaw;
              data['from_user_id'] = fromUserIdRaw;
            }
            if (toUserIdRaw.isNotEmpty) {
              data['to_user_id'] = toUserIdRaw;
            }
            data['caller_name'] = data['caller_name'] ?? call.fromUser?.name;
            data['caller_phone'] = data['caller_phone'] ?? call.fromUser?.phone;
          }
        } catch (e) {
          log('⚠️ [CallKitService] callback identity enrich failed call_id=$callId: $e');
        }
      }
      final callerName =
          _resolveMissedCallDisplayName(data, fallback: 'Missed call');
      final image =
          _stringValue(data['image']) ?? _stringValue(data['image_avatar_url']);
      final action =
          _stringValue(data['action']) ?? _stringValue(data['status']);
      final subtitle = _terminalSubtitle(action);
      final params = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'OneGate',
        avatar: image,
        handle: '',
        type: 0,
        duration: 0,
        textAccept: 'Call back',
        textDecline: 'Dismiss',
        extra: data,
        missedCallNotification: NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: subtitle,
          callbackText: 'Call back',
        ),
        android: const AndroidParams(
          isImportant: true,
          missedCallNotificationChannelName: missedCallChannelName,
          isShowLogo: true,
          logoUrl: 'assets/media/images/oneapptm.png',
          actionColor: '#4CAF50',
          textColor: '#7A1E1E',
          backgroundColor: '#FDE7E7',
        ),
      );
      await FlutterCallkitIncoming.showMissCallNotification(params);
      log('🔔 [CallKitService] Missed call notification shown call_id=$callId');
    } catch (e) {
      log('⚠️ [CallKitService] Failed to show missed notification call_id=$callId: $e');
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

    final coordinatorState = CallCoordinator.instance.state.value;
    final isTerminalEvent =
        eventName == 'actionCallTimeout' || eventName == 'actionCallEnded';
    final isAcceptedCallTerminalEcho = isTerminalEvent &&
        CallCoordinator.instance.activeCallId == callId &&
        (CallCoordinator.instance.isAcceptingIncomingHandoff ||
            coordinatorState == CallFlowState.connecting ||
            coordinatorState == CallFlowState.connected);
    if (isAcceptedCallTerminalEcho) {
      log(
        '⏭️ [CallKitService] Ignoring terminal echo event=$eventName call_id=$callId after accept handoff',
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
        await PendingIncomingAcceptStore.save(payload);
        try {
          final handled =
              await _processAcceptPayload(payload, source: 'callkit_event');
          if (!handled) {
            log(
              '⏳ [CallKitService] Accept deferred call_id=$callId '
              '(likely cold-start/session not ready)',
            );
          }
        } catch (e, st) {
          log(
            '❌ [CallKitService] Accept failed call_id=$callId error=$e',
            stackTrace: st,
          );
        }
        return;
      case 'actionCallDecline':
        try {
          await PendingIncomingAcceptStore.clear();
          await IncomingCallPresenter.instance.declineIncomingCall(payload);
        } catch (e, st) {
          log(
            '⚠️ [CallKitService] Decline callback failed call_id=$callId error=$e',
            stackTrace: st,
          );
        } finally {
          await dismissIncomingUi(callId);
          await CallCoordinator.instance.markEnded(
            reason: 'callkit_decline',
            callId: callId,
          );
          await IncomingCallProcessingGuard.clear(callId);
        }
        return;
      case 'actionCallTimeout':
        await PendingIncomingAcceptStore.clear();
        await dismissIncomingUi(
          callId,
          showMissedNotification: true,
          payload: payload,
        );
        await CallCoordinator.instance.markEnded(
          reason: 'callkit_timeout',
          callId: callId,
        );
        await IncomingCallProcessingGuard.clear(callId);
        return;
      case 'actionCallEnded':
        await PendingIncomingAcceptStore.clear();
        await dismissIncomingUi(callId);
        await CallCoordinator.instance.markEnded(
          reason: 'callkit_ended',
          callId: callId,
        );
        await IncomingCallProcessingGuard.clear(callId);
        return;
      case 'actionCallCallback':
        log('ℹ️ [CallKitService] Callback action tapped call_id=$callId');
        final callbackPayload = <String, dynamic>{
          ...payload,
          'callback_action': 'notification_tap',
        };
        await PendingCallCallbackStore.save(callbackPayload);
        await CallCallbackUxService.instance.replayPendingIfAny(
          source: 'callkit_callback_tap',
        );
        return;
      default:
        return;
    }
  }

  Future<void> replayPendingAcceptIfAny({required String source}) async {
    final pending = await PendingIncomingAcceptStore.takeIfFresh();
    if (pending == null || pending.isEmpty) return;
    final callId =
        pending['call_id']?.toString() ?? pending['callId']?.toString() ?? '-';
    log('🔁 [CallKitService] Replaying pending accept call_id=$callId source=$source');
    await _processAcceptPayload(pending, source: source);
  }

  Future<bool> _processAcceptPayload(
    Map<String, dynamic> payload, {
    required String source,
  }) async {
    final callId =
        payload['call_id']?.toString() ?? payload['callId']?.toString() ?? '';
    if (callId.isEmpty) return false;

    try {
      await IncomingCallPresenter.instance.acceptIncomingCall(payload);
      await dismissIncomingUi(callId);
      await IncomingCallProcessingGuard.clear(callId);
      await PendingIncomingAcceptStore.clear();
      log('✅ [CallKitService] Accept processed call_id=$callId source=$source');
      return true;
    } catch (e, st) {
      // Keep pending payload for retry on authenticated/resume paths.
      await PendingIncomingAcceptStore.save(payload);
      log(
        '⚠️ [CallKitService] Accept processing deferred call_id=$callId source=$source error=$e',
        stackTrace: st,
      );
      return false;
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

  String _terminalSubtitle(String? rawAction) {
    final action = rawAction?.trim().toLowerCase();
    const declinedLike = <String>{
      'call_declined',
      'declined',
      'call_rejected',
      'rejected',
      'ended_by_receiver',
    };
    if (action != null && declinedLike.contains(action)) {
      return 'Declined by user';
    }
    return 'Missed call';
  }

  String? _resolveMissedCallDisplayName(
    Map<String, dynamic> data, {
    String? fallback,
  }) {
    final callerName = _stringValue(data['caller_name']);
    if (callerName != null && !_looksLikePhoneNumber(callerName)) {
      return callerName;
    }
    final fromUser = data['from_user'];
    if (fromUser is Map) {
      final nestedName = _stringValue(Map<String, dynamic>.from(fromUser)['name']);
      if (nestedName != null && !_looksLikePhoneNumber(nestedName)) {
        return nestedName;
      }
    }
    return fallback;
  }

  bool _looksLikePhoneNumber(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    return normalized.length >= 7;
  }
}
