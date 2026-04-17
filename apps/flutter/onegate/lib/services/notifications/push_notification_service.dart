import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/calls/callkit_service.dart';
import 'package:flutter_onegate/services/calls/incoming_call_processing_guard.dart';
import 'package:flutter_onegate/services/intercom/onegate_intercom_bootstrap.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:intercom_module/core/services/call_coordinator.dart';

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

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
      await handleIncomingCallData(
        Map<String, dynamic>.from(message.data),
        source: 'foreground_message',
        fromBackground: false,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await handleIncomingCallData(
        Map<String, dynamic>.from(message.data),
        source: 'message_opened_app',
        fromBackground: false,
      );
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
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

  static Future<void> handleIncomingCallData(
    Map<String, dynamic> rawData, {
    required String source,
    required bool fromBackground,
  }) async {
    try {
      final data = Map<String, dynamic>.from(rawData);
      if (data.isEmpty) return;

      final action = (data['action'] ?? data['event'] ?? data['type'])
          ?.toString()
          .trim()
          .toLowerCase();
      const incomingLike = <String>{
        'incoming_call',
        'call_ringing',
        'ringing',
        'incoming',
        'call_initiated',
        'call_created',
        'call_ring',
      };
      if (action == null || !incomingLike.contains(action)) {
        return;
      }

      final callId =
          data['call_id']?.toString() ?? data['callId']?.toString() ?? '';
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

      await CallKitService.instance.showIncomingCall(
        data,
        fromBackground: fromBackground,
      );
    } catch (e, st) {
      log(
        '❌ [PushNotificationService][$source] handleIncomingCallData failed: $e',
        stackTrace: st,
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
}
