import 'package:flutter/foundation.dart';

@immutable
class IntercomAuthTokens {
  final String accessToken;
  final String? idToken;

  const IntercomAuthTokens({
    required this.accessToken,
    this.idToken,
  });
}

/// Host app supplies auth/session tokens used for all API calls.
abstract class IntercomAuthPort {
  Future<IntercomAuthTokens?> getTokens();
}

/// Host app supplies "current context" (selected society/building/user).
abstract class IntercomContextPort {
  Future<int?> getSelectedSocietyId();

  /// Optional but used for presence + "self" filtering.
  Future<String?> getCurrentUserUuid() async => null;

  /// Optional but used by some APIs.
  Future<int?> getCurrentUserNumericId() async => null;
}

/// Host app supplies file upload behavior (images/docs/audio).
///
/// The legacy module used a "posts" API for uploads; for reuse this is
/// app-specific.
abstract class IntercomUploadPort {
  Future<String?> uploadImage({
    required String filename,
    required List<int> bytes,
    String? contentType,
  });
}

@immutable
class IntercomEndpoints {
  final String societyBackendBaseUrl;
  final String apiGatewayBaseUrl;
  final String gateApiBaseUrl;
  final String roomServiceBaseUrl;
  final String callServiceBaseUrl;
  final String jitsiServerUrl;

  const IntercomEndpoints({
    required this.societyBackendBaseUrl,
    required this.apiGatewayBaseUrl,
    required this.gateApiBaseUrl,
    required this.roomServiceBaseUrl,
    required this.callServiceBaseUrl,
    required this.jitsiServerUrl,
  });

  /// Default CubeOne endpoints used by the legacy module.
  static const IntercomEndpoints cubeOne = IntercomEndpoints(
    societyBackendBaseUrl: 'https://societybackend.cubeone.in/api',
    apiGatewayBaseUrl: 'https://apigw.cubeone.in/api',
    gateApiBaseUrl: 'https://gateapi.cubeone.in/api',
    roomServiceBaseUrl: 'http://13.201.27.102:7071/api/v1',
    callServiceBaseUrl: 'http://13.201.27.102:7071/api',
    jitsiServerUrl: 'collab.cubeone.in',
  );

  Uri societyBackend(String path) => Uri.parse('$societyBackendBaseUrl$path');
  Uri apiGateway(String path) => Uri.parse('$apiGatewayBaseUrl$path');
  Uri gateApi(String path) => Uri.parse('$gateApiBaseUrl$path');

  Uri roomService(String path) => Uri.parse('$roomServiceBaseUrl$path');
  Uri callService(String path) => Uri.parse('$callServiceBaseUrl$path');

  /// Converts `roomServiceBaseUrl` into a websocket base URL for `/ws`.
  String get roomWebSocketBaseUrl {
    final base = roomServiceBaseUrl;
    if (base.startsWith('https://')) return base.replaceFirst('https://', 'wss://');
    if (base.startsWith('http://')) return base.replaceFirst('http://', 'ws://');
    return base;
  }
}
