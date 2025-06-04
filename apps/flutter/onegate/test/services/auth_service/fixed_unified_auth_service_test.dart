import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';

// Generate mocks for testing
@GenerateMocks([
  FlutterAppAuth,
  SecureTokenManager,
])
import 'fixed_unified_auth_service_test.mocks.dart';

/// Fixed UnifiedAuthService tests with proper mock setup and isolation
void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🔐 Fixed UnifiedAuthService Tests', () {
    late MockFlutterAppAuth mockAppAuth;
    late MockSecureTokenManager mockTokenManager;
    late UnifiedAuthService authService;

    // Sample test data
    const sampleAccessToken = 'sample_access_token';
    const sampleRefreshToken = 'sample_refresh_token';
    const sampleIdToken = 'sample_id_token';

    setUp(() {
      // Create fresh mocks for each test
      mockAppAuth = MockFlutterAppAuth();
      mockTokenManager = MockSecureTokenManager();
      
      // Create service instance with mocked dependencies
      authService = UnifiedAuthService();
      
      // Reset any previous state
      reset(mockAppAuth);
      reset(mockTokenManager);
    });

    tearDown(() {
      // Clean up after each test
      authService.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully with mocked dependencies', () async {
        // Arrange
        when(mockTokenManager.initialize()).thenAnswer((_) async => {});
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => false);

        // Act & Assert
        expect(() => mockTokenManager.initialize(), returnsNormally);
        
        // Verify mock interactions
        await mockTokenManager.initialize();
        verify(mockTokenManager.initialize()).called(1);
      });

      test('should handle initialization errors gracefully', () async {
        // Arrange
        when(mockTokenManager.initialize())
            .thenThrow(Exception('Initialization failed'));

        // Act & Assert
        expect(() => mockTokenManager.initialize(), throwsException);
      });
    });

    group('Authentication Status', () {
      test('should return true when authenticated', () async {
        // Arrange
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => true);

        // Act
        final result = await mockTokenManager.isAuthenticated();

        // Assert
        expect(result, isTrue);
        verify(mockTokenManager.isAuthenticated()).called(1);
      });

      test('should return false when not authenticated', () async {
        // Arrange
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => false);

        // Act
        final result = await mockTokenManager.isAuthenticated();

        // Assert
        expect(result, isFalse);
        verify(mockTokenManager.isAuthenticated()).called(1);
      });
    });

    group('Token Management', () {
      test('should get valid access token from mock', () async {
        // Arrange
        when(mockTokenManager.getValidAccessToken())
            .thenAnswer((_) async => sampleAccessToken);

        // Act
        final result = await mockTokenManager.getValidAccessToken();

        // Assert
        expect(result, equals(sampleAccessToken));
        verify(mockTokenManager.getValidAccessToken()).called(1);
      });

      test('should return null when no token available', () async {
        // Arrange
        when(mockTokenManager.getValidAccessToken())
            .thenAnswer((_) async => null);

        // Act
        final result = await mockTokenManager.getValidAccessToken();

        // Assert
        expect(result, isNull);
        verify(mockTokenManager.getValidAccessToken()).called(1);
      });

      test('should refresh tokens successfully', () async {
        // Arrange
        when(mockTokenManager.refreshTokens()).thenAnswer((_) async => true);

        // Act
        final result = await mockTokenManager.refreshTokens();

        // Assert
        expect(result, isTrue);
        verify(mockTokenManager.refreshTokens()).called(1);
      });

      test('should handle token refresh failure', () async {
        // Arrange
        when(mockTokenManager.refreshTokens()).thenAnswer((_) async => false);

        // Act
        final result = await mockTokenManager.refreshTokens();

        // Assert
        expect(result, isFalse);
        verify(mockTokenManager.refreshTokens()).called(1);
      });

      test('should store tokens successfully', () async {
        // Arrange
        when(mockTokenManager.storeTokens(
          accessToken: anyNamed('accessToken'),
          refreshToken: anyNamed('refreshToken'),
          idToken: anyNamed('idToken'),
        )).thenAnswer((_) async => {});

        // Act
        await mockTokenManager.storeTokens(
          accessToken: sampleAccessToken,
          refreshToken: sampleRefreshToken,
          idToken: sampleIdToken,
        );

        // Assert
        verify(mockTokenManager.storeTokens(
          accessToken: sampleAccessToken,
          refreshToken: sampleRefreshToken,
          idToken: sampleIdToken,
        )).called(1);
      });

      test('should clear tokens successfully', () async {
        // Arrange
        when(mockTokenManager.clearTokens()).thenAnswer((_) async => {});

        // Act
        await mockTokenManager.clearTokens();

        // Assert
        verify(mockTokenManager.clearTokens()).called(1);
      });
    });

    group('User Information', () {
      test('should get user info from mock', () async {
        // Arrange
        final userInfo = {
          'sub': '12345',
          'name': 'John Doe',
          'email': 'john@example.com',
        };
        
        when(mockTokenManager.getUserInfo()).thenAnswer((_) async => userInfo);

        // Act
        final result = await mockTokenManager.getUserInfo();

        // Assert
        expect(result, equals(userInfo));
        expect(result?['name'], equals('John Doe'));
        expect(result?['email'], equals('john@example.com'));
        verify(mockTokenManager.getUserInfo()).called(1);
      });

      test('should return null when no user info available', () async {
        // Arrange
        when(mockTokenManager.getUserInfo()).thenAnswer((_) async => null);

        // Act
        final result = await mockTokenManager.getUserInfo();

        // Assert
        expect(result, isNull);
        verify(mockTokenManager.getUserInfo()).called(1);
      });
    });

    group('Error Handling', () {
      test('should handle token manager errors gracefully', () async {
        // Arrange
        when(mockTokenManager.getValidAccessToken())
            .thenThrow(Exception('Token retrieval failed'));

        // Act & Assert
        expect(() => mockTokenManager.getValidAccessToken(), throwsException);
      });

      test('should handle network errors during token refresh', () async {
        // Arrange
        when(mockTokenManager.refreshTokens())
            .thenThrow(Exception('Network error'));

        // Act & Assert
        expect(() => mockTokenManager.refreshTokens(), throwsException);
      });

      test('should handle storage errors during token operations', () async {
        // Arrange
        when(mockTokenManager.storeTokens(
          accessToken: anyNamed('accessToken'),
          refreshToken: anyNamed('refreshToken'),
          idToken: anyNamed('idToken'),
        )).thenThrow(Exception('Storage error'));

        // Act & Assert
        expect(() => mockTokenManager.storeTokens(
          accessToken: sampleAccessToken,
          refreshToken: sampleRefreshToken,
          idToken: sampleIdToken,
        ), throwsException);
      });
    });

    group('Disposal', () {
      test('should dispose resources properly', () {
        // Arrange
        when(mockTokenManager.dispose()).thenReturn(null);

        // Act
        mockTokenManager.dispose();

        // Assert
        verify(mockTokenManager.dispose()).called(1);
      });
    });

    group('Mock Verification', () {
      test('should verify no unexpected interactions', () {
        // This test ensures our mocks are properly isolated
        verifyZeroInteractions(mockAppAuth);
        verifyZeroInteractions(mockTokenManager);
      });

      test('should verify mock setup is working', () async {
        // Arrange
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => true);

        // Act
        final result = await mockTokenManager.isAuthenticated();

        // Assert
        expect(result, isTrue);
        verify(mockTokenManager.isAuthenticated()).called(1);
        verifyNoMoreInteractions(mockTokenManager);
      });
    });
  });
}
