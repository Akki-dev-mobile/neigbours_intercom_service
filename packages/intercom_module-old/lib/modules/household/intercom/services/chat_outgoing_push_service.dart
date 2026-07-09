import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../core/services/auth_token_manager.dart';
import '../../../../src/config/intercom_module_config.dart';
import 'chat_push_notification_config.dart';

/// Best-effort FCM fan-out after a chat message is sent over WebSocket.
///
/// Failures are logged and swallowed so chat delivery is never blocked.
class ChatOutgoingPushService {
  ChatOutgoingPushService._();

  static final ChatOutgoingPushService instance = ChatOutgoingPushService._();

  static const String _logName = 'ChatOutgoingPushService';

  Future<void> notifyRoomMessageSent({
    required String roomId,
    required String content,
    String messageType = 'text',
    String chatType = '1-1',
    int? companyId,
  }) async {
    final trimmed = content.trim();
    if (roomId.trim().isEmpty || trimmed.isEmpty) return;

    try {
      if (!IntercomModule.isConfigured) return;

      final token = await AuthTokenManager.getBestAvailableToken();
      if (token == null || token.isEmpty) return;

      final localAppType = ChatPushNotificationConfig.resolveAppType();
      final targetAppType = ChatPushNotificationConfig.crossAppTargetType(
        localAppType,
      );
      final resolvedCompanyId =
          companyId ??
          await IntercomModule.config.contextPort.getSelectedSocietyId();

      final payload = <String, dynamic>{
        'type': 'message',
        'room_id': roomId.trim(),
        'chat_type': chatType,
        'chat_message_type': messageType,
        'app_type': targetAppType,
        'sender_app_type': localAppType,
        'content': trimmed,
        if (resolvedCompanyId != null)
          'company_id': resolvedCompanyId.toString(),
      };

      final url =
          '${IntercomModule.config.endpoints.gateApiBaseUrl}/visitor/sendUserFcmNotification';

      await Dio().post(
        url,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      log(
        '✅ [$_logName] push requested room=$roomId targetAppType=$targetAppType',
        name: _logName,
      );
    } catch (e) {
      log('⚠️ [$_logName] push failed (non-fatal): $e', name: _logName);
    }
  }
}
