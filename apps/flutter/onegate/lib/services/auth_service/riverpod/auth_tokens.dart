import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_tokens.freezed.dart';
part 'auth_tokens.g.dart';

/// Immutable data class representing authentication tokens
@freezed
class AuthTokens with _$AuthTokens {
  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    required String idToken,
    @Default(false) bool isExpired,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);

  /// Create AuthTokens from flutter_appauth response
  factory AuthTokens.fromAuthResponse({
    required String accessToken,
    required String refreshToken,
    required String idToken,
    required DateTime accessTokenExpirationDateTime,
  }) {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAt: accessTokenExpirationDateTime,
      isExpired: DateTime.now().isAfter(accessTokenExpirationDateTime),
    );
  }

  /// Create empty/invalid tokens
  factory AuthTokens.empty() {
    return AuthTokens(
      accessToken: '',
      refreshToken: '',
      idToken: '',
      expiresAt: DateTime.now(),
      isExpired: true,
    );
  }
}

extension AuthTokensExtension on AuthTokens {
  /// Check if tokens are valid (not empty and not expired)
  bool get isValid => 
      accessToken.isNotEmpty && 
      refreshToken.isNotEmpty && 
      !isExpired;

  /// Check if access token will expire within the given buffer
  bool willExpireWithin(Duration buffer) {
    return DateTime.now().add(buffer).isAfter(expiresAt);
  }

  /// Get time until expiration
  Duration? get timeUntilExpiration {
    if (isExpired) return null;
    return expiresAt.difference(DateTime.now());
  }

  /// Create a copy with updated expiration status
  AuthTokens withExpirationCheck() {
    final now = DateTime.now();
    return copyWith(isExpired: now.isAfter(expiresAt));
  }

  /// Create a copy with new tokens (for refresh)
  AuthTokens withNewTokens({
    required String newAccessToken,
    required DateTime newExpiresAt,
    String? newIdToken,
  }) {
    return copyWith(
      accessToken: newAccessToken,
      expiresAt: newExpiresAt,
      idToken: newIdToken ?? idToken,
      isExpired: false,
    );
  }
}
