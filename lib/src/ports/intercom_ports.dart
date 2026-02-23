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

@immutable
class IntercomEndpoints {
  final String societyBackendBaseUrl;
  final String apiGatewayBaseUrl;
  final String gateApiBaseUrl;

  const IntercomEndpoints({
    required this.societyBackendBaseUrl,
    required this.apiGatewayBaseUrl,
    required this.gateApiBaseUrl,
  });

  Uri societyBackend(String path) => Uri.parse('$societyBackendBaseUrl$path');
  Uri apiGateway(String path) => Uri.parse('$apiGatewayBaseUrl$path');
  Uri gateApi(String path) => Uri.parse('$gateApiBaseUrl$path');
}
