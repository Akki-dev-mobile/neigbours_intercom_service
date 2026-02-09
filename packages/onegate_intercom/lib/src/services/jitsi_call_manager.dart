import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';
import 'package:permission_handler/permission_handler.dart';

class JitsiCallManager {
  JitsiCallManager._(this._host, this._dio, this._jitsiServerUrl, this._callBaseUrl);

  final FeatureHost _host;
  final Dio _dio;
  final Uri _jitsiServerUrl;
  final Uri _callBaseUrl;

  static JitsiCallManager fromHost(FeatureHost host) {
    final flags = host.featureConfig().flags;

    final jitsiRaw = flags['onegate.jitsiServerUrl'];
    final callRaw = flags['onegate.callApiBaseUrl'];

    final jitsi = (jitsiRaw is String && jitsiRaw.trim().isNotEmpty)
        ? Uri.parse(jitsiRaw.trim())
        : Uri.parse('https://collab.cubeone.in');

    final callBase = (callRaw is String && callRaw.trim().isNotEmpty)
        ? Uri.parse(callRaw.trim())
        : Uri.parse('http://13.201.27.102:7071/api/v1');

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    return JitsiCallManager._(host, dio, jitsi, callBase);
  }

  Future<void> initiateVideoCall({
    required String displayName,
    String? toUserId,
    String? toUserPhone,
    String? toUserAvatarUrl,
  }) async {
    await _ensurePermissions(video: true);

    final token = (await _host.authSession()).accessToken;
    final xUserId = _resolveXUserIdFromToken(token) ?? _host.currentContext().userId;

    final payload = <String, Object?>{
      if (toUserPhone != null && toUserPhone.trim().isNotEmpty)
        'to_user_phone': _normalizePhone(toUserPhone),
      if (toUserId != null && toUserId.trim().isNotEmpty) 'to_user_id': toUserId,
      'call_type': 'video',
      if (toUserAvatarUrl != null && toUserAvatarUrl.trim().isNotEmpty)
        'image_avtar_url': toUserAvatarUrl.trim(),
    };

    final uri = _callBaseUrl.replace(path: _joinPath(_callBaseUrl.path, '/calls'));
    final res = await _dio.postUri(
      uri,
      data: payload,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'x-user-id': xUserId,
        },
      ),
    );

    final data = res.data;
    if (data is! Map) {
      throw Exception('Unexpected call response');
    }
    final callData = data['data'];
    if (callData is! Map) {
      throw Exception('Missing call data');
    }
    final meetingId = callData['meeting_id']?.toString();
    if (meetingId == null || meetingId.trim().isEmpty) {
      throw Exception('Missing meeting_id');
    }

    await _joinJitsi(meetingId: meetingId, displayName: displayName);
  }

  Future<void> _joinJitsi({
    required String meetingId,
    required String displayName,
  }) async {
    final jitsi = JitsiMeet();
    final options = JitsiMeetConferenceOptions(
      serverURL: _jitsiServerUrl.toString(),
      room: meetingId,
      configOverrides: const {
        'prejoinPageEnabled': false,
        'disableDeepLinking': true,
      },
      featureFlags: const {
        'chat.enabled': false,
        'invite.enabled': false,
        'meeting-password.enabled': false,
      },
      userInfo: JitsiMeetUserInfo(displayName: displayName),
    );

    final listener = JitsiMeetEventListener(
      conferenceJoined: (url) => log('Jitsi joined: $url'),
      conferenceTerminated: (url, error) =>
          log('Jitsi terminated: $url error=$error'),
      conferenceWillJoin: (url) => log('Jitsi will join: $url'),
    );

    await jitsi.join(options, listener);
  }

  Future<void> _ensurePermissions({required bool video}) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw Exception('Microphone permission required');
    }
    if (video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        throw Exception('Camera permission required');
      }
    }
  }
}

String _normalizePhone(String phone) => phone.replaceAll(RegExp(r'\\D'), '');

String? _resolveXUserIdFromToken(String token) {
  try {
    final decoded = JwtDecoder.decode(token);
    final candidates = [
      decoded['old_gate_user_id'],
      decoded['old_sso_user_id'],
      decoded['user_id'],
    ];
    for (final c in candidates) {
      final v = c?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  } catch (_) {
    return null;
  }
}

String _joinPath(String basePath, String nextPath) {
  final base = basePath.endsWith('/')
      ? basePath.substring(0, basePath.length - 1)
      : basePath;
  final next = nextPath.startsWith('/') ? nextPath : '/$nextPath';
  if (base.isEmpty) return next;
  return '$base$next';
}

