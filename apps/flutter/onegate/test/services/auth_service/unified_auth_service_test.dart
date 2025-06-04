import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';

// Generate mocks
@GenerateMocks([FlutterAppAuth, SecureTokenManager])
import 'unified_auth_service_test.mocks.dart';

void main() {
  group('UnifiedAuthService', () {
    late UnifiedAuthService authService;
    late MockFlutterAppAuth mockAppAuth;
    late MockSecureTokenManager mockTokenManager;

    const String sampleAccessToken = 'sample_access_token';
    const String sampleRefreshToken = 'sample_refresh_token';
    const String sampleIdToken = 'sample_id_token';

    setUp(() {
      authService = UnifiedAuthService();
      mockAppAuth = MockFlutterAppAuth();
      mockTokenManager = MockSecureTokenManager();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Arrange
        when(mockTokenManager.initialize()).thenAnswer((_) async {});
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => true);

        // Act
        await authService.initialize();

        // Assert
        verify(mockTokenManager.initialize());
        verify(mockTokenManager.isAuthenticated());
      });

      test('should handle initialization errors', () async {
        // Arrange
        when(mockTokenManager.initialize()).thenThrow(Exception('Init failed'));

        // Act & Assert
        expect(() => authService.initialize(), throwsException);
      });
    });

    group('Login', () {
      test('should login successfully', () async {
        // Arrange
        final authResponse = AuthorizationTokenResponse(
          sampleAccessToken,
          sampleRefreshToken,
          DateTime.now().add(const Duration(hours: 1)),
          sampleIdToken,
          'Bearer',
          <String>[],
          <String, dynamic>{},
          <String, dynamic>{},
        );

        when(mockAppAuth.authorizeAndExchangeCode(any))
            .thenAnswer((_) async => authResponse);

        when(mockTokenManager.storeTokens(
          accessToken: anyNamed('accessToken'),
          refreshToken: anyNamed('refreshToken'),
          idToken: anyNamed('idToken'),
        )).thenAnswer((_) async {});

        // Act
        final result = await authService.login();

        // Assert
        expect(result, isNotNull);
        verify(mockAppAuth.authorizeAndExchangeCode(any));
        verify(mockTokenManager.storeTokens(
          accessToken: sampleAccessToken,
          refreshToken: sampleRefreshToken,
          idToken: sampleIdToken,
        ));
      });

      test('should handle login failure when no access token received',
          () async {
        // Arrange
        final authResponse = AuthorizationTokenResponse(
          null, // No access token
          sampleRefreshToken,
          DateTime.now().add(const Duration(hours: 1)),
          sampleIdToken,
          'Bearer',
          <String>[],
          <String, dynamic>{},
          <String, dynamic>{},
        );

        when(mockAppAuth.authorizeAndExchangeCode(any))
            .thenAnswer((_) async => authResponse);

        // Act & Assert
        expect(() => authService.login(), throwsException);
      });

      test('should handle login exception', () async {
        // Arrange
        when(mockAppAuth.authorizeAndExchangeCode(any))
            .thenThrow(Exception('Login failed'));

        // Act & Assert
        expect(() => authService.login(), throwsException);
      });
    });

    group('Logout', () {
      test('should logout successfully', () async {
        // Arrange
        when(mockTokenManager.clearTokens()).thenAnswer((_) async {});

        // Act
        await authService.logout();

        // Assert
        verify(mockTokenManager.clearTokens());
      });

      test('should handle logout errors', () async {
        // Arrange
        when(mockTokenManager.clearTokens())
            .thenThrow(Exception('Clear failed'));

        // Act & Assert
        expect(() => authService.logout(), throwsException);
      });
    });

    group('Authentication Status', () {
      test('should return authentication status', () async {
        // Arrange
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => true);

        // Act
        final result = await authService.isAuthenticated();

        // Assert
        expect(result, isTrue);
        verify(mockTokenManager.isAuthenticated());
      });

      test('should return false when not authenticated', () async {
        // Arrange
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => false);

        // Act
        final result = await authService.isAuthenticated();

        // Assert
        expect(result, isFalse);
      });
    });

    group('Token Management', () {
      test('should get valid access token', () async {
        // Arrange
        when(mockTokenManager.getValidAccessToken())
            .thenAnswer((_) async => sampleAccessToken);

        // Act
        final result = await authService.getValidAccessToken();

        // Assert
        expect(result, equals(sampleAccessToken));
        verify(mockTokenManager.getValidAccessToken());
      });

      test('should refresh tokens successfully', () async {
        // Arrange
        when(mockTokenManager.refreshTokens()).thenAnswer((_) async => true);

        // Act
        final result = await authService.refreshTokens();

        // Assert
        expect(result, isTrue);
        verify(mockTokenManager.refreshTokens());
      });

      test('should handle token refresh failure', () async {
        // Arrange
        when(mockTokenManager.refreshTokens()).thenAnswer((_) async => false);

        // Act
        final result = await authService.refreshTokens();

        // Assert
        expect(result, isFalse);
      });
    });

    group('User Information', () {
      test('should get current user info', () async {
        // Arrange
        final userInfo = {
          'sub': '12345',
          'name': 'John Doe',
          'email': 'john@example.com',
        };

        when(mockTokenManager.getUserInfo()).thenAnswer((_) async => userInfo);

        // Act
        final result = await authService.getCurrentUser();

        // Assert
        expect(result, equals(userInfo));
        verify(mockTokenManager.getUserInfo());
      });

      test('should return null when no user info available', () async {
        // Arrange
        when(mockTokenManager.getUserInfo()).thenAnswer((_) async => null);

        // Act
        final result = await authService.getCurrentUser();

        // Assert
        expect(result, isNull);
      });
    });

    group('Auth State Stream', () {
      test('should emit authentication state changes', () async {
        // Arrange
        when(mockTokenManager.initialize()).thenAnswer((_) async {});
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => true);

        // Act
        await authService.initialize();

        // Assert
        expect(authService.authStateStream, emits(true));
      });
    });

    group('Disposal', () {
      test('should dispose resources properly', () {
        // Arrange
        when(mockTokenManager.dispose()).thenReturn(null);

        // Act
        authService.dispose();

        // Assert
        verify(mockTokenManager.dispose());
      });
    });
  });
}
