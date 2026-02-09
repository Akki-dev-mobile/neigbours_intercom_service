import 'package:flutter/foundation.dart';

@immutable
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.expiresAt,
    this.refresh,
  });

  final String accessToken;
  final DateTime? expiresAt;

  /// Optional token refresh callback owned by the host app (features never own auth flows).
  final Future<AuthSession> Function()? refresh;
}
