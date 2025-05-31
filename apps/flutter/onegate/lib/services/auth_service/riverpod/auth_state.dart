import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_tokens.dart';

part 'auth_state.freezed.dart';

/// Authentication state for the application
@freezed
class AuthState with _$AuthState {
  /// User is not authenticated
  const factory AuthState.unauthenticated() = UnauthenticatedState;
  
  /// Authentication is in progress
  const factory AuthState.loading() = LoadingState;
  
  /// User is authenticated with valid tokens
  const factory AuthState.authenticated({
    required AuthTokens tokens,
    required Map<String, dynamic> userInfo,
  }) = AuthenticatedState;
  
  /// Authentication error occurred
  const factory AuthState.error({
    required String message,
  }) = ErrorState;
}

/// Extension methods for AuthState
extension AuthStateExtension on AuthState {
  /// Check if the user is authenticated
  bool get isAuthenticated => maybeWhen(
    authenticated: (_, __) => true,
    orElse: () => false,
  );

  /// Check if authentication is loading
  bool get isLoading => maybeWhen(
    loading: () => true,
    orElse: () => false,
  );

  /// Check if there's an error
  bool get hasError => maybeWhen(
    error: (_) => true,
    orElse: () => false,
  );

  /// Get the access token if authenticated
  String? get accessToken => maybeWhen(
    authenticated: (tokens, _) => tokens.accessToken,
    orElse: () => null,
  );

  /// Get the user info if authenticated
  Map<String, dynamic>? get userInfo => maybeWhen(
    authenticated: (_, userInfo) => userInfo,
    orElse: () => null,
  );

  /// Get the tokens if authenticated
  AuthTokens? get tokens => maybeWhen(
    authenticated: (tokens, _) => tokens,
    orElse: () => null,
  );

  /// Get error message if in error state
  String? get errorMessage => maybeWhen(
    error: (message) => message,
    orElse: () => null,
  );

  /// Check if tokens will expire within the given duration
  bool willExpireWithin(Duration duration) => maybeWhen(
    authenticated: (tokens, _) => tokens.willExpireWithin(duration),
    orElse: () => false,
  );

  /// Get time until token expiration
  Duration? get timeUntilExpiration => maybeWhen(
    authenticated: (tokens, _) => tokens.timeUntilExpiration,
    orElse: () => null,
  );
}
