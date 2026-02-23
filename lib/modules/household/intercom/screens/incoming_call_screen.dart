import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/colors.dart';
import '../models/call_model.dart';
import '../models/call_status.dart';
import '../services/call_service.dart';
import '../../../../core/services/call_coordinator.dart';

class IncomingCallScreen extends StatefulWidget {
  final Call call;
  final String callerName;
  final String? callerPhone;
  final String currentUserName;
  final String? currentUserEmail;

  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.callerName,
    this.callerPhone,
    required this.currentUserName,
    this.currentUserEmail,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _isProcessing = false;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  Timer? _vibrationTimer;

  String get _displayName {
    final trimmed = widget.callerName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return widget.callerPhone ?? 'Unknown caller';
  }

  String get _initials {
    final parts = _displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _stopAlerting();

    final payload = <String, dynamic>{
      'action': 'call_answered',
      'call_id': widget.call.id.toString(),
      'call_type': widget.call.callType.value,
      'caller_name': widget.callerName,
      'caller_phone': widget.callerPhone,
      'meeting_id': widget.call.meetingId,
      'jitsi_url': widget.call.jitsiMeetingUrl,
    };

    // Step 1: POST accept (sets accepted_at; backend may send call_accepted FCM).
    unawaited(
      CallService.instance.acceptCall(widget.call.id).then((_) {}, onError: (e, st) {
        log('⚠️ [IncomingCall] acceptCall failed: $e');
      }),
    );
    // Step 2: PATCH status answered (triggers FCM "call_answered" to caller with meeting details).
    unawaited(
      CallService.instance
          .updateCallStatus(
            callId: widget.call.id,
            status: CallStatus.answered,
          )
          .then((_) {}, onError: (e, st) {
        log('⚠️ [IncomingCall] Failed to notify backend (answered): $e');
      }),
    );

    await CallCoordinator.instance.acceptIncomingCall(payload);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _declineCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _stopAlerting();
    // POST reject so backend sets rejected_at and sends FCM "call_rejected" to caller.
    try {
      await CallService.instance.rejectCall(widget.call.id, reason: 'declined');
    } catch (e) {
      log('⚠️ [IncomingCall] Failed to reject call: $e');
      // Fallback: PATCH declined so caller still gets a status update.
      try {
        await CallService.instance.updateCallStatus(
          callId: widget.call.id,
          status: CallStatus.declined,
        );
      } catch (_) {}
    }

    await CallCoordinator.instance.markEnded();

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _startAlerting();
  }

  @override
  void dispose() {
    _stopAlerting();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  Future<void> _startAlerting() async {
    try {
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.setAsset('assets/sound/incoming_call.mp3');
      await _ringtonePlayer.play();
    } catch (e) {
      log('⚠️ [IncomingCall] Failed to start ringtone: $e');
    }

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.vibrate();
    });
  }

  Future<void> _stopAlerting() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      log('⚠️ [IncomingCall] Failed to stop ringtone: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _declineCall();
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppColors.redToGreyGradient,
            ),
            child: SizedBox.expand(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.call.callType.isVideo
                      ? 'Incoming video call'
                      : 'Incoming audio call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallActionButton(
                      label: 'Decline',
                      icon: Icons.call_end,
                      color: Colors.redAccent,
                      onTap: _declineCall,
                      loading: _isProcessing,
                    ),
                    _CallActionButton(
                      label: 'Accept',
                      icon: Icons.call,
                      color: Colors.green,
                      onTap: _acceptCall,
                      loading: _isProcessing,
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  const _CallActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkResponse(
          onTap: loading ? null : onTap,
          radius: 34,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
