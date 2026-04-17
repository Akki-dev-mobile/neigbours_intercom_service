import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) {
  return PushNotificationService.firebaseMessagingBackgroundHandler(message);
}

class IncomingCallPushService {
  IncomingCallPushService._();

  static Future<void> initialize() => PushNotificationService.initialize();

  static Future<void> syncCurrentTokenWithBackend() =>
      PushNotificationService.syncCurrentTokenWithBackend();

  static Future<void> handleIncomingCallData(
    Map<String, dynamic> data, {
    required String source,
    required bool fromBackground,
  }) {
    return PushNotificationService.handleIncomingCallData(
      data,
      source: source,
      fromBackground: fromBackground,
    );
  }

  static Future<void> simulateIncomingCallFromForeground({
    String callId = 'debug-call-1001',
    String callerName = 'OneGate Test',
    String callerPhone = '+91 9999999999',
    String callType = 'video',
  }) {
    return PushNotificationService.simulateIncomingCallFromForeground(
      callId: callId,
      callerName: callerName,
      callerPhone: callerPhone,
      callType: callType,
    );
  }
}
