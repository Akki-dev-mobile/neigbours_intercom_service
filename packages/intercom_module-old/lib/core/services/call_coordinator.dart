import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../../modules/household/intercom/models/call_model.dart';

enum CallFlowState { idle, ringing, connecting, connected, ended }

/// Coordinates call lifecycle state shared by OneGate and the intercom module.
class CallCoordinator {
  CallCoordinator._();

  static final CallCoordinator instance = CallCoordinator._();

  final ValueNotifier<CallFlowState> state = ValueNotifier<CallFlowState>(
    CallFlowState.idle,
  );

  String? _activeCallId;
  bool _outgoingCreateInFlight = false;
  bool _acceptingIncomingHandoff = false;

  String? get activeCallId => _activeCallId;

  bool get isAcceptingIncomingHandoff => _acceptingIncomingHandoff;

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
    _activeCallId = call.id.toString();
    state.value = CallFlowState.ringing;
    unlockOutgoingCallCreation();
    log('📞 [CallCoordinator] Outgoing call started id=$_activeCallId');
  }

  Future<bool> handleIncomingCallData(
    Map<String, dynamic> payload, {
    bool fromBackground = false,
  }) async {
    final callId = _resolveCallId(payload);
    if (callId == null || callId.isEmpty) return false;

    if (state.value != CallFlowState.idle &&
        _activeCallId != null &&
        _activeCallId != callId) {
      log(
        '⏭️ [CallCoordinator] Ignoring incoming call id=$callId '
        'active=$_activeCallId state=${state.value.name}',
      );
      return false;
    }

    _activeCallId = callId;
    state.value = CallFlowState.ringing;
    log(
      '📞 [CallCoordinator] Incoming call ringing id=$callId '
      'fromBackground=$fromBackground',
    );
    return true;
  }

  Future<void> acceptIncomingCall(Map<String, dynamic> payload) async {
    _activeCallId = _resolveCallId(payload) ?? _activeCallId;
    _acceptingIncomingHandoff = true;
    state.value = CallFlowState.connecting;
    log('📞 [CallCoordinator] Incoming call accepted id=$_activeCallId');
  }

  Future<void> handleOutgoingCallAcceptedData(
    Map<String, dynamic> payload, {
    bool fromBackground = false,
  }) async {
    final callId = _resolveCallId(payload);
    if (callId != null) _activeCallId = callId;
    state.value = CallFlowState.connecting;
    log(
      '📞 [CallCoordinator] Outgoing accepted id=$_activeCallId '
      'fromBackground=$fromBackground',
    );
  }

  Future<void> handleCallEndedData(
    Map<String, dynamic> payload, {
    bool fromBackground = false,
  }) async {
    final callId = _resolveCallId(payload);
    if (callId != null &&
        _activeCallId != null &&
        _activeCallId!.isNotEmpty &&
        _activeCallId != callId) {
      log(
        '⏭️ [CallCoordinator] Ignoring ended for stale call id=$callId '
        'active=$_activeCallId',
      );
      return;
    }
    await markEnded(reason: 'remote_terminal', callId: callId);
    log(
      '📞 [CallCoordinator] Call ended fromBackground=$fromBackground '
      'payload=$payload',
    );
  }

  Future<void> markConnected({String? callId}) async {
    if (callId != null && callId.isNotEmpty) {
      _activeCallId = callId;
    }
    _acceptingIncomingHandoff = false;
    state.value = CallFlowState.connected;
    log('📞 [CallCoordinator] Connected id=$_activeCallId');
  }

  Future<void> markEnded({String? reason, String? callId}) async {
    if (callId != null &&
        _activeCallId != null &&
        _activeCallId!.isNotEmpty &&
        _activeCallId != callId) {
      return;
    }
    state.value = CallFlowState.ended;
    _activeCallId = null;
    _outgoingCreateInFlight = false;
    _acceptingIncomingHandoff = false;
    log(
      '📞 [CallCoordinator] markEnded reason=${reason ?? "-"} callId=$callId',
    );
    if (state.value == CallFlowState.ended) {
      state.value = CallFlowState.idle;
    }
  }

  void setAcceptingIncomingHandoff(bool value) {
    _acceptingIncomingHandoff = value;
  }

  String? _resolveCallId(Map<String, dynamic> payload) {
    final raw = payload['call_id'] ?? payload['callId'] ?? payload['id'];
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
