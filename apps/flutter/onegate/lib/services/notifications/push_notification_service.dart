import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/calls/callkit_service.dart';
import 'package:flutter_onegate/services/calls/call_callback_ux_service.dart';
import 'package:flutter_onegate/services/calls/incoming_call_processing_guard.dart';
import 'package:flutter_onegate/services/calls/pending_call_callback_store.dart';
import 'package:flutter_onegate/services/calls/pending_call_terminal_event_store.dart';
import 'package:flutter_onegate/services/intercom/onegate_intercom_bootstrap.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:intercom_module/core/services/call_coordinator.dart';
import 'package:intercom_module/core/services/local_terminal_origin_store.dart';
import 'package:intercom_module/modules/household/intercom/services/call_manager.dart';

@pragma('vm:entry-point')
Future<void> oneGateFirebaseMessagingBackgroundHandler(RemoteMessage message) {
  return PushNotificationService.firebaseMessagingBackgroundHandler(message);
}

@pragma('vm:entry-point')
class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static bool _didRotateTokenOnce = false;
  static bool _localNotificationsInitialized = false;
  static String? _lastSyncedToken;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _incomingCallsChannel =
      AndroidNotificationChannel(
    'onegate_incoming_calls',
    CallKitService.incomingCallChannelName,
    description: 'Incoming call alerts shown as full-screen notifications.',
    importance: Importance.max,
    playSound: true,
  );

  static const AndroidNotificationChannel _missedCallsChannel =
      AndroidNotificationChannel(
    'onegate_missed_calls',
    CallKitService.missedCallChannelName,
    description: 'Missed call alerts and callback actions.',
    importance: Importance.high,
    playSound: true,
  );
  static const Set<String> _terminalLikeActions = <String>{
    'call_ended',
    'ended',
    'call_terminated',
    'terminated',
    'remote_ended',
    'ended_by_caller',
    'ended_by_receiver',
    'declined',
    'call_declined',
    'rejected',
    'call_rejected',
    'missed',
    'timeout',
    'caller_cancel',
    'call_cancelled',
    'call_canceled',
    'cancelled',
    'canceled',
  };

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    await _initializeAndroidNotifications();
    await CallKitService.instance.initialize();

    log(
      '📩 [PushNotificationService][BG] messageId=${message.messageId} '
      'dataKeys=${message.data.keys.toList()}',
    );
    _logNotificationPayloadWarning(
      message,
      source: 'background_message',
    );

    await handleIncomingCallData(
      Map<String, dynamic>.from(message.data),
      source: 'background_message',
      fromBackground: true,
    );
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();
    await _initializeAndroidNotifications();
    await CallKitService.instance.initialize();

    FirebaseMessaging.onBackgroundMessage(
        oneGateFirebaseMessagingBackgroundHandler);

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    log('🔔 [PushNotificationService] permission=${permission.authorizationStatus}');

    final token = await _getCurrentToken(rotateOnce: true);
    if (token != null && token.isNotEmpty) {
      log('🔑 [PushNotificationService] token=$token');
      await _syncDeviceTokenWithBackend(token);
    } else {
      log('⚠️ [PushNotificationService] token unavailable');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((nextToken) async {
      log('🔄 [PushNotificationService] token refreshed=$nextToken');
      await _syncDeviceTokenWithBackend(nextToken);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      _logNotificationPayloadWarning(
        message,
        source: 'foreground_message',
      );
      await handleIncomingCallData(
        Map<String, dynamic>.from(message.data),
        source: 'foreground_message',
        fromBackground: false,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      _logNotificationPayloadWarning(
        message,
        source: 'message_opened_app',
      );
      await handleIncomingCallData(
        Map<String, dynamic>.from(message.data),
        source: 'message_opened_app',
        fromBackground: false,
      );
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _logNotificationPayloadWarning(
        initialMessage,
        source: 'initial_message',
      );
      await handleIncomingCallData(
        Map<String, dynamic>.from(initialMessage.data),
        source: 'initial_message',
        fromBackground: false,
      );
    }

    _initialized = true;
    log('✅ [PushNotificationService] initialized');
  }

  static Future<void> syncCurrentTokenWithBackend() async {
    try {
      final token = await _getCurrentToken(rotateOnce: false);
      if (token == null || token.isEmpty) {
        log('⚠️ [PushNotificationService] syncCurrentTokenWithBackend: token unavailable');
        return;
      }
      await _syncDeviceTokenWithBackend(token);
    } catch (e) {
      log('❌ [PushNotificationService] syncCurrentTokenWithBackend failed: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> handleIncomingCallData(
    Map<String, dynamic> rawData, {
    required String source,
    required bool fromBackground,
  }) async {
    try {
      final data = Map<String, dynamic>.from(rawData);
      if (data.isEmpty) return;

      final action = _normalizeAction(
        (data['action'] ??
                data['event'] ??
                data['type'] ??
                data['status'] ??
                data['reason'])
            ?.toString(),
      );
      const incomingLike = <String>{
        'incoming_call',
        'call_ringing',
        'ringing',
        'incoming',
        'call_initiated',
        'call_created',
        'call_ring',
      };
      final resolvedCallId = _resolveCallId(data);
      final hasCallId = resolvedCallId.isNotEmpty;
      final hasMeetingOrUrl =
          (data['meeting_id']?.toString().trim().isNotEmpty == true) ||
              (data['meetingId']?.toString().trim().isNotEmpty == true) ||
              (data['jitsi_url']?.toString().trim().isNotEmpty == true) ||
              (data['jitsi_meeting_url']?.toString().trim().isNotEmpty == true);

      final isIncomingByAction =
          action != null && incomingLike.contains(action);
      final isIncomingByShape =
          (action == null || action.isEmpty) && hasCallId && hasMeetingOrUrl;

      if (!isIncomingByAction && !isIncomingByShape) {
        if (action == 'call_callback' && hasCallId) {
          final callId = resolvedCallId;
          log(
            '📥 [PushNotificationService][$source] callback payload received call_id=$callId',
          );
          await PendingCallCallbackStore.save(data);
          await CallCallbackUxService.instance.replayPendingIfAny(
            source: source,
          );
          return;
        }
        if (action != null && _terminalLikeActions.contains(action) && hasCallId) {
          await handleTerminalCallEvent(
            data,
            source: source,
            fromBackground: fromBackground,
            normalizedAction: action,
          );
        }
        return;
      }
      if (isIncomingByShape) {
        log(
          'ℹ️ [PushNotificationService][$source] Treating payload as incoming call by shape (missing action)',
        );
      }

      final callId = _resolveCallId(data);
      if (callId.isEmpty) {
        log(
          '⚠️ [PushNotificationService][$source] Missing call_id action=$action data=$data',
        );
        return;
      }

      await _initializeAndroidNotifications();
      await CallKitService.instance.initialize();

      try {
        await OneGateIntercomBootstrap.ensureConfigured();
      } catch (e) {
        log('⚠️ [PushNotificationService][$source] Intercom bootstrap failed: $e');
      }

      final started = await IncomingCallProcessingGuard.tryStart(
        callId,
        ttl: const Duration(seconds: 60),
      );
      if (!started) return;

      final accepted = await CallCoordinator.instance.handleIncomingCallData(
        data,
        fromBackground: fromBackground,
      );
      if (!accepted) {
        await IncomingCallProcessingGuard.clear(callId);
        return;
      }

      log(
        '📞 [PushNotificationService][$source] incoming_call call_id=$callId '
        'state=${CallCoordinator.instance.state.value.name} fromBackground=$fromBackground',
      );

      final shown = await CallKitService.instance.showIncomingCall(
        data,
        fromBackground: fromBackground,
      );
      if (!shown) {
        log(
          '⚠️ [PushNotificationService][$source] Incoming UI failed to show call_id=$callId; resetting transient call state',
        );
        await IncomingCallProcessingGuard.clear(callId);
        await CallCoordinator.instance.markEnded(
          reason: 'incoming_ui_show_failed',
          callId: callId,
        );
      }
    } catch (e, st) {
      log(
        '❌ [PushNotificationService][$source] handleIncomingCallData failed: $e',
        stackTrace: st,
      );
    }
  }

  static Future<void> handleTerminalCallEvent(
    Map<String, dynamic> payload, {
    required String source,
    required bool fromBackground,
    String? normalizedAction,
  }) async {
    final rawActionValue = (payload['action'] ??
            payload['event'] ??
            payload['type'] ??
            payload['status'] ??
            payload['reason'])
        ?.toString();
    final action = normalizedAction ??
        _normalizeAction(
          rawActionValue,
        );
    final callId = _resolveCallId(payload);
    if (callId.isEmpty) return;

    final isLocalTerminal =
        await LocalTerminalOriginStore.wasRecentlyEmittedLocally(callId);
    final isDeclinedByUser =
        _isDeclinedByUser(payload, normalizedAction: action);
    final shouldOfferMissedCallback = !isLocalTerminal && !isDeclinedByUser;

    log(
      '📥 [PushNotificationService][$source] terminal event received '
      'call_id=$callId rawAction=${rawActionValue ?? "-"} normalizedAction=${action ?? "-"} '
      'status=${payload['status'] ?? "-"} reason=${payload['reason'] ?? "-"} '
      'ended_by=${payload['ended_by'] ?? payload['endedBy'] ?? "-"} '
      'fromBackground=$fromBackground localOrigin=$isLocalTerminal declinedByUser=$isDeclinedByUser '
      'showMissedCallback=$shouldOfferMissedCallback',
    );

    await PendingCallTerminalEventStore.saveCallEnded(payload);
    await CallCoordinator.instance.handleCallEndedData(
      payload,
      fromBackground: fromBackground,
    );
    await CallKitService.instance.dismissIncomingUi(
      callId,
      showMissedNotification: shouldOfferMissedCallback,
      payload: payload,
    );
    await CallManager.instance.endFromRemote(
      reason: _terminalReason(payload, action ?? ''),
    );
    await PendingCallTerminalEventStore.clearForCallId(callId);

    if (isDeclinedByUser) {
      Fluttertoast.showToast(
        msg: 'Receiver declined the call.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
    if (shouldOfferMissedCallback) {
      await CallCallbackUxService.instance.handleRemoteTerminalForCallback(
        payload,
        source: source,
      );
    }
  }

  static Future<void> simulateIncomingCallFromForeground({
    String callId = 'debug-call-1001',
    String callerName = 'OneGate Test',
    String callerPhone = '+91 9999999999',
    String callType = 'video',
  }) async {
    await handleIncomingCallData(
      <String, dynamic>{
        'action': 'incoming_call',
        'call_id': callId,
        'call_type': callType,
        'caller_name': callerName,
        'caller_phone': callerPhone,
        'meeting_id': 'debug-meeting-$callId',
        'jitsi_url': 'https://meet.jit.si/debug-$callId',
        'image': '',
      },
      source: 'foreground_test_helper',
      fromBackground: false,
    );
  }

  static Future<void> _initializeAndroidNotifications() async {
    if (_localNotificationsInitialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings);

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_incomingCallsChannel);
    await androidPlugin?.createNotificationChannel(_missedCallsChannel);

    _localNotificationsInitialized = true;
    log('✅ [PushNotificationService] Android notification channels ready');
  }

  static Future<String?> _getCurrentToken({required bool rotateOnce}) async {
    final messaging = FirebaseMessaging.instance;
    if (rotateOnce && !_didRotateTokenOnce) {
      try {
        await messaging.deleteToken();
        _didRotateTokenOnce = true;
        log('🔄 [PushNotificationService] previous token deleted; fetching fresh token');
      } catch (e) {
        log('⚠️ [PushNotificationService] token delete skipped: $e');
        _didRotateTokenOnce = true;
      }
    }
    return messaging.getToken();
  }

  static Future<int?> _resolveNumericUserId() async {
    final storage = GateStorage();

    final stored = await storage.getUserId();
    final fromStored = int.tryParse((stored ?? '').trim());
    if (fromStored != null) return fromStored;

    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      final payload = JwtTokenUtility.parseJwtToken(token);
      final dynamic raw = payload?['old_gate_user_id'] ??
          payload?['old_sso_user_id'] ??
          payload?['user_id'];
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw);
      if (raw is double) return raw.toInt();
    }

    return null;
  }

  static Future<void> _syncDeviceTokenWithBackend(String token) async {
    try {
      if (token.isEmpty) return;
      if (_lastSyncedToken == token) return;

      final userId = await _resolveNumericUserId();
      if (userId == null) {
        log('⚠️ [PushNotificationService] cannot sync token: numeric user id unavailable');
        return;
      }

      final headers = await Environment.getHeaders();
      final url = '${ApiUrls.gateBaseUrl}/member/deviceToken/$userId';

      await Dio().put(
        url,
        data: <String, dynamic>{
          'device_token': token,
          'app_type': 'onegate',
        },
        options: Options(headers: headers),
      );

      _lastSyncedToken = token;
      log('✅ [PushNotificationService] device token synced for userId=$userId');
    } catch (e) {
      log('❌ [PushNotificationService] failed to sync device token: $e');
    }
  }

  static void _logNotificationPayloadWarning(
    RemoteMessage message, {
    required String source,
  }) {
    if (message.notification == null) return;
    final data = message.data;
    final action = (data['action'] ?? data['event'] ?? data['type'])
        ?.toString()
        .trim()
        .toLowerCase();
    final hasCallLikeData =
        (data['call_id']?.toString().trim().isNotEmpty == true) ||
            (data['callId']?.toString().trim().isNotEmpty == true) ||
            (action != null && action.contains('call'));
    if (hasCallLikeData) return;

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final text = '$title $body'.toLowerCase();
    final looksCallLike = text.contains('call') || text.contains('incoming');
    if (!looksCallLike) return;

    log(
      '⚠️ [PushNotificationService][$source] '
      'Call-like notification payload received without data keys. '
      'Android may show tray notification and require tap. '
      'Use data-only FCM for immediate incoming call UI.',
    );
  }

  static String? _normalizeAction(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final snake = raw
        .trim()
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m.group(1)}_${m.group(2)}',
        )
        .replaceAll('-', '_')
        .toLowerCase();
    switch (snake) {
      case 'callended':
      case 'call_end':
      case 'hangup':
      case 'ended_by_caller':
      case 'ended_by_receiver':
      case 'remote_ended':
      case 'terminated':
      case 'call_terminated':
        return 'call_ended';
      case 'declined':
      case 'call_declined':
      case 'receiver_declined':
        return 'call_declined';
      case 'rejected':
      case 'call_rejected':
        return 'call_rejected';
      case 'caller_cancel':
      case 'call_cancelled':
      case 'call_canceled':
      case 'cancelled':
      case 'canceled':
        return 'call_ended';
      case 'missed':
        return 'missed';
      case 'timeout':
        return 'timeout';
      default:
        return snake;
    }
  }

  static String _resolveCallId(Map<String, dynamic> payload) {
    final value = payload['call_id'] ??
        payload['callId'] ??
        payload['id'] ??
        payload['uuid'];
    final text = value?.toString().trim() ?? '';
    return text;
  }

  static bool _isDeclinedByUser(
    Map<String, dynamic> payload, {
    String? normalizedAction,
  }) {
    const declinedLike = <String>{
      'declined',
      'call_declined',
      'rejected',
      'call_rejected',
      'ended_by_receiver',
      'receiver_declined',
    };
    if (normalizedAction != null &&
        normalizedAction.isNotEmpty &&
        declinedLike.contains(normalizedAction)) {
      return true;
    }

    for (final key in const <String>['action', 'event', 'type', 'status', 'reason']) {
      final raw = payload[key]?.toString().trim();
      if (raw == null || raw.isEmpty) continue;
      final snake = raw
          .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'),
            (m) => '${m.group(1)}_${m.group(2)}',
          )
          .replaceAll('-', '_')
          .toLowerCase();
      if (declinedLike.contains(snake)) {
        return true;
      }
    }
    return false;
  }

  static String _terminalReason(Map<String, dynamic> payload, String action) {
    final explicit = payload['reason']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    switch (action) {
      case 'call_declined':
      case 'declined':
        return 'declined';
      case 'call_rejected':
      case 'rejected':
        return 'rejected';
      case 'missed':
        return 'missed';
      case 'timeout':
        return 'timeout';
      default:
        return 'remote_ended';
    }
  }
}
