import 'dart:async';
import 'dart:developer';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../models/call_model.dart';
import '../models/call_status.dart';
import 'call_history_service.dart';
import 'call_service.dart';
import '../../../../core/constants.dart';

/// JitsiCallController handles all Jitsi SDK operations and call lifecycle events
///
/// This controller is responsible ONLY for:
/// - Joining Jitsi meetings via SDK
/// - Listening to Jitsi lifecycle events
/// - Updating backend status based on events
///
/// It does NOT handle:
/// - Permissions (use CallManager)
/// - Backend API calls directly (uses CallService)
/// - UI logic (handled by widgets)
///
/// Lifecycle Event → Backend Status Mapping:
/// - Conference joined → answered
/// - User hangs up / conference terminated → ended
/// - User cancels before join → declined
/// - No answer after timeout (≈30s) → missed
class JitsiCallController {
  static JitsiCallController? _instance;

  final JitsiMeet _jitsiMeet = JitsiMeet();
  final CallService _callService = CallService.instance;

  /// Jitsi server URL (without protocol - SDK handles it)
  String get _jitsiServerUrl => AppConstants.jitsiServerUrl;

  /// Timeout for missed call detection (in seconds)
  static const int _missedCallTimeoutSeconds = 30;

  /// Currently active call (null if no call in progress)
  Call? _activeCall;

  /// Whether the user has joined the conference
  bool _hasJoinedConference = false;

  /// Timer for missed call detection
  Timer? _missedCallTimer;

  /// Stream controller for call state changes
  final _callStateController = StreamController<CallStateEvent>.broadcast();

  JitsiCallController._();

  /// Get singleton instance
  static JitsiCallController get instance {
    _instance ??= JitsiCallController._();
    return _instance!;
  }

  /// Stream of call state events for UI updates
  Stream<CallStateEvent> get callStateStream => _callStateController.stream;

  /// Get the currently active call
  Call? get activeCall => _activeCall;

  /// Check if a call is in progress
  bool get isCallInProgress => _activeCall != null;

  /// Join a Jitsi meeting for the given call
  ///
  /// This method:
  /// 1. Configures Jitsi based on call type (audio/video)
  /// 2. Joins the meeting using meeting_id
  /// 3. Sets up lifecycle event listeners
  /// 4. Starts missed call timer
  ///
  /// [call] - The call object from backend with meeting_id
  /// [displayName] - User's display name for the meeting
  /// [avatarUrl] - Optional avatar URL for the user
  Future<void> joinCall({
    required Call call,
    required String displayName,
    String? avatarUrl,
    String? userEmail,
  }) async {
    try {
      log('📞 [JitsiCallController] Joining call: ${call.id}',
          name: 'JitsiCallController');
      log('   Meeting ID: ${call.meetingId}', name: 'JitsiCallController');
      log('   Call Type: ${call.callType.value}', name: 'JitsiCallController');
      log('   Jitsi Server URL: https://$_jitsiServerUrl',
          name: 'JitsiCallController');
      log('   Avatar URL: ${avatarUrl ?? "null"}', name: 'JitsiCallController');

      // Set active call
      _activeCall = call;
      _hasJoinedConference = false;

      // Configure Jitsi options based on call type
      final options = _buildJitsiOptions(
        call: call,
        displayName: displayName,
        avatarUrl: avatarUrl,
        userEmail: userEmail,
      );

      log('🔧 [JitsiCallController] Jitsi options configured:',
          name: 'JitsiCallController');
      log('   serverURL: ${options.serverURL}', name: 'JitsiCallController');
      log('   room: ${options.room}', name: 'JitsiCallController');

      // Build event listener
      final listener = _buildEventListener();

      // Start missed call timer
      _startMissedCallTimer();

      // Emit joining state
      _emitState(CallState.joining);

      // Join the meeting with event listener
      await _jitsiMeet.join(options, listener);

      log('✅ [JitsiCallController] Jitsi join initiated',
          name: 'JitsiCallController');
    } catch (e, stackTrace) {
      log('❌ [JitsiCallController] Error joining call: $e',
          name: 'JitsiCallController');
      log('   Stack trace: $stackTrace', name: 'JitsiCallController');

      // Join failures are not user declines; mark ended.
      await _updateBackendStatus(CallStatus.ended);
      _cleanup();

      _emitState(CallState.error, error: e.toString());
      rethrow;
    }
  }

  /// Cancel call before joining (user pressed cancel)
  Future<void> cancelCall() async {
    if (_activeCall == null) return;

    log('🚫 [JitsiCallController] Cancelling call: ${_activeCall!.id}',
        name: 'JitsiCallController');

    // Update backend status to declined
    await _updateBackendStatus(CallStatus.declined);

    // Hang up if already in call
    await hangUp();
  }

  /// Hang up the current call
  Future<void> hangUp() async {
    try {
      log('📴 [JitsiCallController] Hanging up call',
          name: 'JitsiCallController');
      await _jitsiMeet.hangUp();
    } catch (e) {
      log('⚠️ [JitsiCallController] Error hanging up: $e',
          name: 'JitsiCallController');
    } finally {
      _cleanup();
    }
  }

  /// Build Jitsi meeting options based on call type
  JitsiMeetConferenceOptions _buildJitsiOptions({
    required Call call,
    required String displayName,
    String? avatarUrl,
    String? userEmail,
  }) {
    // Configure feature flags based on call type
    final isVideoCall = call.callType.isVideo;
    final resolved = _resolveJitsiServerAndRoom(call);

    return JitsiMeetConferenceOptions(
      serverURL: resolved.serverUrl,
      room: resolved.room,
      configOverrides: {
        // Video configuration based on call type
        'startWithVideoMuted': !isVideoCall, // true for audio, false for video
        'startWithAudioMuted': false, // Always start with audio enabled
        'startAudioOnly': !isVideoCall, // true for audio calls

        // Disable features not needed
        'prejoinPageEnabled': false, // Skip pre-join page
        'disableDeepLinking': true,
        'enableClosePage': false,

        // Disable recording and streaming (for privacy)
        'liveStreamingEnabled': false,
        'recordingEnabled': false,

        // UI customization
        'disableInviteFunctions': true,
        'enableNoAudioDetection': true,
        'enableNoisyMicDetection': true,
      },
      featureFlags: {
        // Core call features
        FeatureFlags.callIntegrationEnabled: false,
        FeatureFlags.pipEnabled: true, // Picture-in-picture

        // Video features
        FeatureFlags.videoShareEnabled: isVideoCall,
        FeatureFlags.tileViewEnabled: isVideoCall,

        // Disabled features
        FeatureFlags.preJoinPageEnabled: false,
        FeatureFlags.welcomePageEnabled: false,
        FeatureFlags.inviteEnabled: false,
        FeatureFlags.meetingPasswordEnabled: false,
        FeatureFlags.recordingEnabled: false,
        FeatureFlags.liveStreamingEnabled: false,
        FeatureFlags.chatEnabled: false, // Disable in-call chat
        FeatureFlags.raiseHandEnabled: false,
        FeatureFlags.reactionsEnabled: false,
        FeatureFlags.filmstripEnabled: isVideoCall,
        FeatureFlags.overflowMenuEnabled: true,
        FeatureFlags.addPeopleEnabled: false,
        FeatureFlags.calenderEnabled: false,
        FeatureFlags.closeCaptionsEnabled: false,
        FeatureFlags.helpButtonEnabled: false,
        FeatureFlags.iosRecordingEnabled: false,
        FeatureFlags.kickOutEnabled: false,
        FeatureFlags.meetingNameEnabled: false,
        FeatureFlags.toolboxAlwaysVisible: false,
      },
      // Only set userInfo with valid values
      // IMPORTANT: Empty string for avatar causes "MalformedURLException: no protocol"
      userInfo: JitsiMeetUserInfo(
        displayName: displayName,
        email: userEmail,
        avatar: (avatarUrl != null &&
                avatarUrl.isNotEmpty &&
                (avatarUrl.startsWith('http://') ||
                    avatarUrl.startsWith('https://')))
            ? avatarUrl
            : null,
      ),
    );
  }

  /// Resolve server URL and room name from call data.
  ///
  /// Prefer the full jitsiMeetingUrl if provided (from backend/push payload),
  /// otherwise fall back to the default server + meetingId.
  _ResolvedJitsi _resolveJitsiServerAndRoom(Call call) {
    final fallback = _ResolvedJitsi(
      serverUrl: 'https://$_jitsiServerUrl',
      room: call.meetingId,
    );

    final rawUrl = call.jitsiMeetingUrl;
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return fallback;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty || uri.scheme.isEmpty) {
      return fallback;
    }

    if (uri.host != _jitsiServerUrl) {
      log(
        '⚠️ [JitsiCallController] Unexpected Jitsi host "${uri.host}". Forcing $_jitsiServerUrl.',
        name: 'JitsiCallController',
      );
      return fallback;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return _ResolvedJitsi(
        serverUrl:
            '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}',
        room: call.meetingId,
      );
    }

    final room = segments.removeLast();
    final serverUrl =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

    return _ResolvedJitsi(
      serverUrl: serverUrl,
      room: room,
    );
  }

  /// Build Jitsi event listener
  JitsiMeetEventListener _buildEventListener() {
    return JitsiMeetEventListener(
      conferenceJoined: _onConferenceJoined,
      conferenceTerminated: _onConferenceTerminated,
      conferenceWillJoin: _onConferenceWillJoin,
      participantJoined: _onParticipantJoined,
      participantLeft: _onParticipantLeft,
      audioMutedChanged: _onAudioMutedChanged,
      videoMutedChanged: _onVideoMutedChanged,
      endpointTextMessageReceived: _onEndpointTextMessageReceived,
      screenShareToggled: _onScreenShareToggled,
      chatMessageReceived: _onChatMessageReceived,
      chatToggled: _onChatToggled,
      participantsInfoRetrieved: _onParticipantsInfoRetrieved,
      readyToClose: _onReadyToClose,
    );
  }

  /// Conference joined event - Update status to "answered"
  void _onConferenceJoined(String url) {
    log('✅ [JitsiCallController] Conference joined: $url',
        name: 'JitsiCallController');

    _hasJoinedConference = true;
    _cancelMissedCallTimer();

    // Update backend status to answered
    _updateBackendStatus(CallStatus.answered);

    _emitState(CallState.connected);
  }

  /// Conference terminated event - Update status to "ended"
  void _onConferenceTerminated(String url, Object? error) {
    log('📴 [JitsiCallController] Conference terminated: $url',
        name: 'JitsiCallController');
    if (error != null) {
      log('   Error: $error', name: 'JitsiCallController');
    }

    // Conference termination is an end condition; "declined" must be explicit
    // (cancel button / remote decline) and not inferred from termination timing.
    _updateBackendStatus(CallStatus.ended);

    _cleanup();
    _emitState(CallState.ended);
  }

  /// Conference will join event
  void _onConferenceWillJoin(String url) {
    log('🔄 [JitsiCallController] Conference will join: $url',
        name: 'JitsiCallController');
    _emitState(CallState.connecting);
  }

  /// Participant joined event
  void _onParticipantJoined(
      String? email, String? name, String? role, String? participantId) {
    log('👤 [JitsiCallController] Participant joined: $name ($participantId)',
        name: 'JitsiCallController');
  }

  /// Participant left event
  void _onParticipantLeft(String? participantId) {
    log('👤 [JitsiCallController] Participant left: $participantId',
        name: 'JitsiCallController');
  }

  /// Audio muted changed event
  void _onAudioMutedChanged(bool muted) {
    log('🔇 [JitsiCallController] Audio muted: $muted',
        name: 'JitsiCallController');
  }

  /// Video muted changed event
  void _onVideoMutedChanged(bool muted) {
    log('📹 [JitsiCallController] Video muted: $muted',
        name: 'JitsiCallController');
  }

  /// Endpoint text message received event
  void _onEndpointTextMessageReceived(String senderId, String message) {
    log('💬 [JitsiCallController] Message from $senderId: $message',
        name: 'JitsiCallController');
  }

  /// Screen share toggled event
  void _onScreenShareToggled(String participantId, bool sharing) {
    log('🖥️ [JitsiCallController] Screen share by $participantId: $sharing',
        name: 'JitsiCallController');
  }

  /// Chat message received event
  void _onChatMessageReceived(
      String senderId, String message, bool isPrivate, String? timestamp) {
    log('💬 [JitsiCallController] Chat from $senderId: $message',
        name: 'JitsiCallController');
  }

  /// Chat toggled event
  void _onChatToggled(bool isOpen) {
    log('💬 [JitsiCallController] Chat toggled: $isOpen',
        name: 'JitsiCallController');
  }

  /// Participants info retrieved event
  void _onParticipantsInfoRetrieved(String participantsInfo) {
    log('👥 [JitsiCallController] Participants info: $participantsInfo',
        name: 'JitsiCallController');
  }

  /// Ready to close event
  void _onReadyToClose() {
    log('🚪 [JitsiCallController] Ready to close', name: 'JitsiCallController');
    _cleanup();
    _emitState(CallState.ended);
  }

  /// Start missed call timer
  void _startMissedCallTimer() {
    _cancelMissedCallTimer();

    _missedCallTimer = Timer(
      Duration(seconds: _missedCallTimeoutSeconds),
      () async {
        if (!_hasJoinedConference && _activeCall != null) {
          log('⏰ [JitsiCallController] Missed call timeout reached',
              name: 'JitsiCallController');

          // Update status to missed
          await _updateBackendStatus(CallStatus.missed);

          // Hang up and cleanup
          await hangUp();

          _emitState(CallState.missed);
        }
      },
    );
  }

  /// Cancel missed call timer
  void _cancelMissedCallTimer() {
    _missedCallTimer?.cancel();
    _missedCallTimer = null;
  }

  /// Update backend call status
  Future<void> _updateBackendStatus(CallStatus status) async {
    final active = _activeCall;
    if (active == null) return;

    try {
      log('📝 [JitsiCallController] Updating backend status: ${status.value}',
          name: 'JitsiCallController');

      final response = await _callService.updateCallStatus(
        callId: active.id,
        status: status,
      );

      if (response.success) {
        log('✅ [JitsiCallController] Backend status updated: ${status.value}',
            name: 'JitsiCallController');
        // Only update if this call is still the active one (avoid race with cleanup).
        if (_activeCall?.id == active.id) {
          _activeCall = active.copyWithStatus(status);
        }
      } else {
        log('⚠️ [JitsiCallController] Failed to update backend status: ${response.error}',
            name: 'JitsiCallController');
      }
    } catch (e) {
      log('❌ [JitsiCallController] Error updating backend status: $e',
          name: 'JitsiCallController');
      // Don't rethrow - we still want to cleanup even if backend update fails
    } finally {
      await _syncCallHistory(active.id, status);
    }
  }

  Future<void> _syncCallHistory(int callId, CallStatus status) async {
    try {
      await CallHistoryService.instance.updateCallStatus(
        callId: callId,
        status: status,
        endedAt: status.isTerminated ? DateTime.now() : null,
      );
    } catch (e) {
      log('📝 [JitsiCallController] Failed to sync call history: $e',
          name: 'JitsiCallController');
    }
  }

  /// Cleanup resources
  void _cleanup() {
    _cancelMissedCallTimer();
    _activeCall = null;
    _hasJoinedConference = false;
  }

  /// Emit state change event
  void _emitState(CallState state, {String? error}) {
    _callStateController.add(CallStateEvent(
      state: state,
      call: _activeCall,
      error: error,
    ));
  }

  /// Dispose resources
  void dispose() {
    _cancelMissedCallTimer();
    _callStateController.close();
  }
}

class _ResolvedJitsi {
  final String serverUrl;
  final String room;

  const _ResolvedJitsi({
    required this.serverUrl,
    required this.room,
  });
}

/// Call states for UI updates
enum CallState {
  idle,
  joining,
  connecting,
  connected,
  ended,
  missed,
  error,
}

/// Call state event for stream
class CallStateEvent {
  final CallState state;
  final Call? call;
  final String? error;

  CallStateEvent({
    required this.state,
    this.call,
    this.error,
  });
}
