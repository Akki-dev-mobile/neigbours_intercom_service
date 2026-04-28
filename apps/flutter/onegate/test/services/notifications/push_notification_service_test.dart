import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/services/notifications/push_notification_service.dart';
import 'package:intercom_module/core/services/call_coordinator.dart';

void main() {
  group('PushNotificationService missed callback gating', () {
    test('does not show missed callback after call has connected', () {
      final shouldOffer =
          PushNotificationService.shouldOfferMissedCallbackForTerminal(
        payload: const <String, dynamic>{
          'action': 'call_ended',
          'call_id': '42',
          'reason': 'ended',
        },
        callId: '42',
        normalizedAction: 'call_ended',
        isLocalTerminal: false,
        isDeclinedByUser: false,
        coordinatorState: CallFlowState.connected,
        activeCallId: '42',
        isAcceptingIncomingHandoff: false,
      );

      expect(shouldOffer, isFalse);
    });

    test('keeps missed callback for unanswered ringing call', () {
      final shouldOffer =
          PushNotificationService.shouldOfferMissedCallbackForTerminal(
        payload: const <String, dynamic>{
          'action': 'call_ended',
          'call_id': '42',
          'reason': 'ended_by_caller',
        },
        callId: '42',
        normalizedAction: 'call_ended',
        isLocalTerminal: false,
        isDeclinedByUser: false,
        coordinatorState: CallFlowState.ringing,
        activeCallId: '42',
        isAcceptingIncomingHandoff: false,
      );

      expect(shouldOffer, isTrue);
    });

    test('keeps missed callback for explicit missed event without active UI',
        () {
      final shouldOffer =
          PushNotificationService.shouldOfferMissedCallbackForTerminal(
        payload: const <String, dynamic>{
          'action': 'missed',
          'call_id': '42',
        },
        callId: '42',
        normalizedAction: 'missed',
        isLocalTerminal: false,
        isDeclinedByUser: false,
        coordinatorState: CallFlowState.idle,
        activeCallId: null,
        isAcceptingIncomingHandoff: false,
      );

      expect(shouldOffer, isTrue);
    });

    test('does not show missed callback for local or declined terminals', () {
      final localTerminal =
          PushNotificationService.shouldOfferMissedCallbackForTerminal(
        payload: const <String, dynamic>{
          'action': 'missed',
          'call_id': '42',
        },
        callId: '42',
        normalizedAction: 'missed',
        isLocalTerminal: true,
        isDeclinedByUser: false,
        coordinatorState: CallFlowState.ringing,
        activeCallId: '42',
        isAcceptingIncomingHandoff: false,
      );
      final declinedTerminal =
          PushNotificationService.shouldOfferMissedCallbackForTerminal(
        payload: const <String, dynamic>{
          'action': 'call_declined',
          'call_id': '42',
        },
        callId: '42',
        normalizedAction: 'call_declined',
        isLocalTerminal: false,
        isDeclinedByUser: true,
        coordinatorState: CallFlowState.ringing,
        activeCallId: '42',
        isAcceptingIncomingHandoff: false,
      );

      expect(localTerminal, isFalse);
      expect(declinedTerminal, isFalse);
    });
  });
}
