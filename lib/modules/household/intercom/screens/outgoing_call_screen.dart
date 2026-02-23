import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/call_coordinator.dart';
import '../../../../core/services/outgoing_call_acceptance_store.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/profile_data_helper.dart';
import '../models/call_model.dart';
import '../models/call_status.dart';
import '../services/call_history_service.dart';
import '../services/call_service.dart';

class OutgoingCallScreen extends StatefulWidget {
  final Call call;
  final String calleeName;
  final String? calleePhone;
  final String? calleeAvatarUrl;

  /// How long we keep the caller in "Calling..." before marking missed.
  final Duration timeout;

  const OutgoingCallScreen({
    super.key,
    required this.call,
    required this.calleeName,
    this.calleePhone,
    this.calleeAvatarUrl,
    this.timeout = const Duration(seconds: 45),
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  bool _isEnding = false;
  Timer? _timeoutTimer;
  Timer? _acceptPollTimer;
  Timer? _endedPollTimer;
  Timer? _statusPollTimer;
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  String get _callId => widget.call.id.toString();

  bool get _isActiveCallForThisScreen =>
      CallCoordinator.instance.activeCallId?.trim() == _callId.trim();

  String get _displayName {
    final trimmed = widget.calleeName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return widget.calleePhone ?? 'Unknown';
  }

  String get _initials {
    final parts = _displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }

  String? get _resolvedCalleeAvatarUrl {
    final raw = widget.calleeAvatarUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return ProfileDataHelper.resolveAvatarUrl({'avatar': raw});
  }

  @override
  void initState() {
    super.initState();

    // Outgoing call UX must be outside Jitsi. Do NOT open Jitsi here.
    // Caller joins only after receiving `call_accepted` and transitioning to
    // CallCoordinator -> connecting.
    CallCoordinator.instance.startOutgoingCall(widget.call);

    _startRingtone();

    // Auto-cancel after timeout.
    _timeoutTimer = Timer(widget.timeout, _autoCancelDueToTimeout);

    // If backend ever sends a "call_answered" signal, coordinator will open Jitsi.
    // We just dismiss this screen once state moves to connected.
    CallCoordinator.instance.state.addListener(_onCoordinatorState);

    // Poll for pending accept (e.g. FCM was handled in background isolate and persisted).
    _acceptPollTimer = Timer.periodic(const Duration(seconds: 2), _pollPendingAccept);
    // Poll for pending call_ended (receiver rejected while FCM was in background).
    _endedPollTimer = Timer.periodic(const Duration(seconds: 2), _pollPendingEnded);
    // Fallback: poll backend call status so we connect even if FCM is never received.
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), _pollCallStatus);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _acceptPollTimer?.cancel();
    _endedPollTimer?.cancel();
    _statusPollTimer?.cancel();
    CallCoordinator.instance.state.removeListener(_onCoordinatorState);
    _stopRingtone();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  /// Fallback when FCM is not received: poll backend for call status. If status is
  /// "answered", treat as call_accepted and join so the call connects.
  Future<void> _pollCallStatus(Timer _) async {
    if (!mounted || _isEnding || !_isActiveCallForThisScreen) return;
    if (CallCoordinator.instance.state.value != CallFlowState.ringing) return;
    try {
      final call = await CallService.instance.getCall(widget.call.id);
      if (call == null || !mounted) return;
      if (call.status != CallStatus.answered) return;
      log(
        '📞 [OutgoingCall] Call status=answered from API (callId=${call.id}); joining without FCM',
      );
      final payload = <String, dynamic>{
        'action': 'call_accepted',
        'call_id': call.id.toString(),
        'meeting_id': call.meetingId,
        'jitsi_url': call.jitsiMeetingUrl ?? 'https://collab.cubeone.in',
        'call_type': call.callType.value,
        'status': 'answered',
      };
      await CallCoordinator.instance.handleOutgoingCallAcceptedData(
        payload,
        fromBackground: false,
      );
    } catch (e) {
      log('⚠️ [OutgoingCall] Status poll error: $e');
    }
  }

  Future<void> _pollPendingAccept(Timer _) async {
    if (!mounted || _isEnding || !_isActiveCallForThisScreen) return;
    if (CallCoordinator.instance.state.value != CallFlowState.ringing) return;
    // Prefer per-call key (backend may have saved under our call id).
    Map<String, dynamic>? pending = await OutgoingCallAcceptanceStore.takeIfFreshForCallId(_callId);
    // Fallback: legacy single slot or any per-call key (e.g. accept saved under other id).
    if (pending == null || pending.isEmpty) {
      pending = await OutgoingCallAcceptanceStore.takeIfFresh();
    }
    if (pending == null || pending.isEmpty) {
      final all = await OutgoingCallAcceptanceStore.takeAllIfFresh();
      pending = all.isNotEmpty ? all.first : null;
    }
    if (pending == null || pending.isEmpty) return;
    log(
      '📞 [OutgoingCall] Replaying persisted call_accepted from store (callId=$_callId)',
    );
    await CallCoordinator.instance.handleOutgoingCallAcceptedData(
      pending,
      fromBackground: false,
    );
  }

  /// Pops the outgoing call screen so the user is never stuck. Prefer pop() over
  /// maybePop() so we always close when the user ends the call.
  void _popOutgoingScreen() {
    if (!mounted) return;
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
        log('📞 [OutgoingCall] Screen popped');
      } else {
        navigator.maybePop();
        log('📞 [OutgoingCall] maybePop (canPop was false)');
      }
    } catch (e, st) {
      log('⚠️ [OutgoingCall] Pop failed: $e');
      log('   $st');
    }
  }

  Future<void> _pollPendingEnded(Timer _) async {
    if (!mounted || _isEnding || !_isActiveCallForThisScreen) return;
    if (CallCoordinator.instance.state.value != CallFlowState.ringing) return;
    final pending = await OutgoingCallAcceptanceStore.takeCallEndedIfFresh();
    if (pending == null || pending.isEmpty) return;
    final payloadCallId = pending['call_id']?.toString() ?? pending['callId']?.toString();
    if (payloadCallId != null && payloadCallId.trim().isNotEmpty && payloadCallId.trim() != _callId.trim()) {
      await OutgoingCallAcceptanceStore.saveCallEnded(pending);
      return;
    }
    log(
      '📞 [OutgoingCall] Replaying persisted call_ended from store (callId=$_callId)',
    );
    await CallCoordinator.instance.handleCallEndedData(pending);
  }

  void _onCoordinatorState() {
    if (!mounted) return;
    final s = CallCoordinator.instance.state.value;

    // If this screen is for a stale/duplicate call id, close immediately to
    // avoid auto-decline affecting another active call.
    if (!_isActiveCallForThisScreen &&
        (CallCoordinator.instance.activeCallId?.trim().isNotEmpty == true)) {
      log(
        '🧹 [OutgoingCall] Closing stale outgoing UI. screenCallId=$_callId activeCallId=${CallCoordinator.instance.activeCallId} state=$s',
      );
      _timeoutTimer?.cancel();
      _stopRingtone();
      _popOutgoingScreen();
      return;
    }

    if (s == CallFlowState.connecting || s == CallFlowState.connected) {
      _timeoutTimer?.cancel();
      _stopRingtone();
      _popOutgoingScreen();
    }
    if (s == CallFlowState.ended) {
      _timeoutTimer?.cancel();
      _stopRingtone();
      _popOutgoingScreen();
    }
  }

  Future<void> _startRingtone() async {
    try {
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.setAsset('assets/sound/phone_ringing.mp3');
      await _ringtonePlayer.play();
    } catch (e) {
      log('⚠️ [OutgoingCall] Failed to start ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _autoCancelDueToTimeout() async {
    // Timeout is a caller-side UX rule: stop ringing and cancel the call.
    if (!mounted || _isEnding) return;
    if (!_isActiveCallForThisScreen) {
      log(
        '⏭️ [OutgoingCall] Timeout ignored (stale UI). screenCallId=$_callId activeCallId=${CallCoordinator.instance.activeCallId}',
      );
      return;
    }
    if (CallCoordinator.instance.state.value != CallFlowState.ringing) return;
    await _cancelCall(reason: 'timeout');
  }

  Future<void> _cancelCall({required String reason}) async {
    if (_isEnding) return;
    if (!_isActiveCallForThisScreen) {
      log(
        '⏭️ [OutgoingCall] Cancel ignored (stale UI). reason=$reason screenCallId=$_callId activeCallId=${CallCoordinator.instance.activeCallId}',
      );
      if (mounted) _popOutgoingScreen();
      return;
    }
    setState(() => _isEnding = true);
    await _stopRingtone();

    // Pop the screen first so the user is never stuck; use pop() so we always close.
    if (mounted) {
      log('📞 [OutgoingCall] End call: reason=$reason, popping screen');
      _popOutgoingScreen();
    }

    // Cleanup in background; must not block or throw.
    unawaited(
      CallCoordinator.instance.markEnded().then((_) {}, onError: (e, st) {
        log('⚠️ [OutgoingCall] markEnded failed: $e');
      }),
    );

    final terminalStatus = _resolveTerminalStatus(reason);

    unawaited(
      CallHistoryService.instance
          .updateCallStatus(
            callId: widget.call.id,
            status: terminalStatus,
            endedAt: DateTime.now(),
          )
          .then((_) {}, onError: (e, st) {
        log('⚠️ [OutgoingCall] Failed to update local call history: $e');
      }),
    );

    unawaited(
      CallService.instance
          .updateCallStatus(
            callId: widget.call.id,
            status: terminalStatus,
          )
          .then((_) {}, onError: (e, st) {
        log('⚠️ [OutgoingCall] Failed to notify backend ($terminalStatus): $e');
      }),
    );
  }

  CallStatus _resolveTerminalStatus(String reason) {
    if (reason == 'timeout') return CallStatus.missed;

    final isStillRinging =
        CallCoordinator.instance.state.value == CallFlowState.ringing;
    if (isStillRinging) {
      return CallStatus.missed;
    }

    return CallStatus.declined;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _cancelCall(reason: 'back');
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppColors.blackToGreyGradient,
            ),
            child: SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Image.asset(
                      'assets/icons/oneapp_icon.png',
                      width: 64,
                      height: 64,
                    ),
                    const SizedBox(height: 20),
                    const Spacer(flex: 1),
                    _CalleeAvatar(
                      initials: _initials,
                      avatarUrl: _resolvedCalleeAvatarUrl,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _displayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.call.callType.isVideo
                          ? 'Calling (video)'
                          : 'Calling (audio)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(flex: 3),
                    _EndButton(
                      label: 'Cancel',
                      icon: Icons.call_end,
                      color: const Color(0xFFFF4D4D),
                      onTap: _isEnding ? null : () => _cancelCall(reason: 'user'),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalleeAvatar extends StatelessWidget {
  final String initials;
  final String? avatarUrl;

  const _CalleeAvatar({
    required this.initials,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 56;
    final resolved = avatarUrl?.trim();
    final hasAvatar = resolved != null &&
        resolved.isNotEmpty &&
        (resolved.startsWith('http://') || resolved.startsWith('https://'));

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withOpacity(0.22),
        backgroundImage: hasAvatar ? NetworkImage(resolved) : null,
        child: hasAvatar
            ? null
            : Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class _EndButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _EndButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkResponse(
          onTap: onTap,
          radius: 34,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
