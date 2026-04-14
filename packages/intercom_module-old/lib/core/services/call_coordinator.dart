import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../../modules/household/intercom/models/call_model.dart';

enum CallFlowState {
  idle,
  ringing,
  connecting,
  connected,
  ended,
}

/// Lightweight coordinator used by the extracted module UI.
///
/// The original app has a deeper integration (CallKit, routing, lifecycle).
/// For reusability, host apps can build on top of this or replace it.
class CallCoordinator {
  CallCoordinator._();

  static final CallCoordinator instance = CallCoordinator._();

  final ValueNotifier<CallFlowState> state =
      ValueNotifier<CallFlowState>(CallFlowState.idle);

  String? _activeCallId;
  bool _outgoingCreateInFlight = false;

  String? get activeCallId => _activeCallId;

  bool tryLockOutgoingCallCreation() {
    if (state.value != CallFlowState.idle) return false;
    if (_outgoingCreateInFlight) return false;
    _outgoingCreateInFlight = true;
    return true;
  }

  void unlockOutgoingCallCreation() {
    _outgoingCreateInFlight = false;
  }

  void startOutgoingCall(Call call) {
    _activeCallId = call.id?.toString();
    state.value = CallFlowState.ringing;
    unlockOutgoingCallCreation();
    log('📞 [CallCoordinator] Outgoing call started id=$_activeCallId');
  }

  Future<void> acceptIncomingCall(Map<String, dynamic> payload) async {
    _activeCallId = payload['call_id']?.toString();
    state.value = CallFlowState.connecting;
    log('📞 [CallCoordinator] Incoming call accepted id=$_activeCallId');
  }

  Future<void> handleOutgoingCallAcceptedData(
    Map<String, dynamic> payload, {
    bool fromBackground = false,
  }) async {
    final callId = payload['call_id']?.toString();
    if (callId != null) _activeCallId = callId;
    state.value = CallFlowState.connecting;
    log(
      '📞 [CallCoordinator] Outgoing accepted id=$_activeCallId fromBackground=$fromBackground',
    );
  }

  Future<void> handleCallEndedData(
    Map<String, dynamic> payload, {
    bool fromBackground = false,
  }) async {
    state.value = CallFlowState.ended;
    log('📞 [CallCoordinator] Call ended fromBackground=$fromBackground payload=$payload');
  }

  Future<void> markEnded() async {
    state.value = CallFlowState.ended;
    _activeCallId = null;
    _outgoingCreateInFlight = false;
  }
}
