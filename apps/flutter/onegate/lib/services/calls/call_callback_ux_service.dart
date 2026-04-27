import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:flutter_onegate/presentation/features/dashboard/commons/intercom_services_launcher.dart';
import 'package:flutter_onegate/services/calls/pending_call_callback_store.dart';

class CallCallbackUxService {
  CallCallbackUxService._();

  static final CallCallbackUxService instance = CallCallbackUxService._();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _lastHandledCallId;
  DateTime? _lastHandledAt;
  bool _retryScheduled = false;

  static const Duration _dedupeWindow = Duration(seconds: 12);

  void bindNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  Future<void> handleRemoteTerminalForCallback(
    Map<String, dynamic> payload, {
    required String source,
  }) async {
    final callId =
        payload['call_id']?.toString() ?? payload['callId']?.toString() ?? '';
    if (callId.isEmpty) return;
    if (_isDuplicate(callId)) {
      log('⏭️ [Callback] suppressed duplicate call_id=$callId source=$source');
      return;
    }

    final nav = _navigatorKey?.currentState;
    final context = nav?.context;
    final inForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (context != null && context.mounted && inForeground) {
      await _handleCallbackPayloadWithoutBottomSheet(
        context,
        payload,
        source: source,
      );
      _markHandled(callId);
      return;
    }

    // Intentionally skip deferred bottom-sheet UX for remote terminal events.
    log('ℹ️ [Callback] no deferred UI for call_id=$callId source=$source');
  }

  Future<void> replayPendingIfAny({required String source}) async {
    final pending = await PendingCallCallbackStore.consumeIfFresh();
    if (pending == null || pending.isEmpty) return;
    final callbackAction = pending['callback_action']?.toString();
    final callId =
        pending['call_id']?.toString() ?? pending['callId']?.toString() ?? '';
    if (callId.isEmpty) return;
    // Never dedupe explicit notification callback taps; user intent should win.
    if (callbackAction != 'notification_tap' && _isDuplicate(callId)) return;

    final nav = _navigatorKey?.currentState;
    final context = nav?.context;
    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (context == null || !context.mounted || !inForeground) {
      // Put it back if UI is still unavailable.
      await PendingCallCallbackStore.save(pending);
      _scheduleReplayRetry();
      return;
    }
    if (callbackAction == 'notification_tap') {
      await IntercomServicesLauncher.open(
        context,
        callbackPayload: pending,
      );
      _markHandled(callId);
      return;
    }
    await _handleCallbackPayloadWithoutBottomSheet(
      context,
      pending,
      source: source,
    );
    _markHandled(callId);
  }

  void _scheduleReplayRetry() {
    if (_retryScheduled) return;
    _retryScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      _retryScheduled = false;
      await replayPendingIfAny(source: 'deferred_retry');
    });
  }

  Future<void> _handleCallbackPayloadWithoutBottomSheet(
    BuildContext context,
    Map<String, dynamic> payload, {
    required String source,
  }) async {
    final callId =
        payload['call_id']?.toString() ?? payload['callId']?.toString() ?? '-';
    final callbackAction = payload['callback_action']?.toString();
    if (callbackAction == 'notification_tap') {
      await IntercomServicesLauncher.open(
        context,
        callbackPayload: payload,
      );
      log('📲 [Callback] launched from notification call_id=$callId source=$source');
      return;
    }
    log('⏭️ [Callback] bottom-sheet UX suppressed call_id=$callId source=$source');
  }

  bool _isDuplicate(String callId) {
    if (_lastHandledCallId != callId) return false;
    if (_lastHandledAt == null) return false;
    return DateTime.now().difference(_lastHandledAt!) < _dedupeWindow;
  }

  void _markHandled(String callId) {
    _lastHandledCallId = callId;
    _lastHandledAt = DateTime.now();
  }
}
