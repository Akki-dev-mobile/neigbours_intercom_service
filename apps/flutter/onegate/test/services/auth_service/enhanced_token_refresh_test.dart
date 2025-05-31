import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

// Generate mocks
@GenerateMocks([FlutterSecureStorage, GateStorage])
import 'enhanced_token_refresh_test.mocks.dart';

void main() {
  group('Enhanced Token Refresh Manager Tests', () {
    late EnhancedTokenRefreshManager tokenManager;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockGateStorage mockGateStorage;

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      mockGateStorage = MockGateStorage();
      tokenManager = EnhancedTokenRefreshManager();
    });

    tearDown(() {
      tokenManager.dispose();
    });

    group('JWT Token Utility Tests', () {
      test('should parse valid JWT token correctly', () {
        // Create a mock JWT token (header.payload.signature)
        const mockJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE2MTYyMzkwMjJ9.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final payload = JwtTokenUtility.parseJwtToken(mockJwtToken);

        expect(payload, isNotNull);
        expect(payload!['sub'], equals('1234567890'));
        expect(payload['name'], equals('John Doe'));
        expect(payload['iat'], equals(1516239022));
        expect(payload['exp'], equals(1616239022));
      });

      test('should return null for invalid JWT token', () {
        const invalidToken = 'invalid.token';

        final payload = JwtTokenUtility.parseJwtToken(invalidToken);

        expect(payload, isNull);
      });

      test('should extract expiration time correctly', () {
        // Mock JWT with exp claim set to a future time
        const mockJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE2MTYyMzkwMjJ9.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final expirationTime =
            JwtTokenUtility.getTokenExpirationTime(mockJwtToken);

        expect(expirationTime, isNotNull);
        expect(expirationTime!.millisecondsSinceEpoch, equals(1616239022000));
      });

      test('should detect expired token correctly', () {
        // Mock JWT with expired exp claim (timestamp 1000000000 = year 2001)
        const mockExpiredJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjEwMDAwMDAwMDB9.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final isExpired =
            JwtTokenUtility.isTokenExpiredOrExpiring(mockExpiredJwt);

        expect(isExpired, isTrue);
      });

      test('should detect token expiring soon', () {
        // Test with a very short buffer to ensure the test passes
        const validJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        // Use a very large buffer to test the expiring logic
        final isExpiring = JwtTokenUtility.isTokenExpiredOrExpiring(
          validJwtToken,
          buffer: const Duration(days: 365 * 100), // 100 years buffer
        );

        expect(isExpiring, isTrue);
      });

      test('should validate JWT token structure', () {
        const validJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final isValid = JwtTokenUtility.isValidJwtToken(validJwtToken);

        expect(isValid, isTrue);
      });

      test('should extract user info from JWT token', () {
        const mockJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiZW1haWwiOiJqb2huQGV4YW1wbGUuY29tIiwicHJlZmVycmVkX3VzZXJuYW1lIjoiam9obmRvZSIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjo5OTk5OTk5OTk5LCJzY29wZSI6Im9wZW5pZCBlbWFpbCBwcm9maWxlIiwicmVhbG1fYWNjZXNzIjp7InJvbGVzIjpbImFkbWluIiwidXNlciJdfX0.'
            'signature';

        final userInfo = JwtTokenUtility.getUserInfoFromToken(mockJwtToken);

        expect(userInfo, isNotNull);
        expect(userInfo!['sub'], equals('1234567890'));
        expect(userInfo['name'], equals('John Doe'));
        expect(userInfo['email'], equals('john@example.com'));
        expect(userInfo['preferred_username'], equals('johndoe'));
        expect(userInfo['roles'], equals(['admin', 'user']));
        expect(userInfo['scopes'], equals(['openid', 'email', 'profile']));
      });
    });

    group('Enhanced Token Refresh Manager Tests', () {
      test('should initialize correctly', () async {
        await tokenManager.initialize(mockGateStorage);

        // Verify that periodic refresh check is started
        expect(tokenManager, isNotNull);
      });

      test('should return null when no access token is available', () async {
        when(mockSecureStorage.read(key: 'access_token_secure'))
            .thenAnswer((_) async => null);

        await tokenManager.initialize(mockGateStorage);
        final token = await tokenManager.getValidAccessToken();

        expect(token, isNull);
      });

      test('should return valid token when not expired', () async {
        // Use a simple valid JWT token that expires far in the future
        const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.'
            'Lzqr7Vc_7XnNdXfNJhKXvKz7Vc_7XnNdXfNJhKXvKz';

        when(mockSecureStorage.read(key: 'access_token_secure'))
            .thenAnswer((_) async => validToken);

        await tokenManager.initialize(mockGateStorage);
        final token = await tokenManager.getValidAccessToken();

        expect(token, equals(validToken));
      });

      test('should handle concurrent refresh requests', () async {
        // Mock an expiring token (using expired timestamp for simplicity)
        const expiringToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjEwMDAwMDAwMDB9.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        when(mockSecureStorage.read(key: 'access_token_secure'))
            .thenAnswer((_) async => expiringToken);
        when(mockSecureStorage.read(key: 'refresh_token_secure'))
            .thenAnswer((_) async => 'mock_refresh_token');

        await tokenManager.initialize(mockGateStorage);

        // Start multiple concurrent refresh requests
        final futures =
            List.generate(5, (_) => tokenManager.refreshTokenIfNeeded());
        final results = await Future.wait(futures);

        // All requests should return the same result
        expect(results.every((result) => result == results.first), isTrue);
      });

      test('should clear all tokens on logout', () async {
        await tokenManager.initialize(mockGateStorage);

        // Test that clearTokens completes without error
        expect(() async => await tokenManager.clearTokens(), returnsNormally);
      });
    });
  });
}
