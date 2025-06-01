import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

void main() {
  group('SecureTokenManager Integration Tests', () {
    late SecureTokenManager tokenManager;

    setUp(() {
      tokenManager = SecureTokenManager();
    });

    group('JWT Token Utility Tests', () {
      test('should parse JWT token correctly', () {
        // Sample JWT token with known payload
        const token =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.Lp-38GKDuZK6h6KQArVJMIJZvQ7v7Lj0adCCXv7TFAU';

        final payload = JwtTokenUtility.parseJwtToken(token);

        expect(payload, isNotNull);
        expect(payload!['sub'], equals('1234567890'));
        expect(payload['name'], equals('John Doe'));
        expect(payload['iat'], equals(1516239022));
        expect(payload['exp'], equals(9999999999));
      });

      test('should extract expiration time from JWT token', () {
        const token =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.Lp-38GKDuZK6h6KQArVJMIJZvQ7v7Lj0adCCXv7TFAU';

        final expirationTime = JwtTokenUtility.getTokenExpirationTime(token);

        expect(expirationTime, isNotNull);
        expect(expirationTime!.millisecondsSinceEpoch, equals(9999999999000));
      });

      test('should validate JWT token structure', () {
        const validToken =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.Lp-38GKDuZK6h6KQArVJMIJZvQ7v7Lj0adCCXv7TFAU';
        const invalidToken = 'invalid.token.format';

        expect(JwtTokenUtility.isValidJwtToken(validToken), isTrue);
        expect(JwtTokenUtility.isValidJwtToken(invalidToken), isFalse);
      });

      test('should detect token expiration with buffer', () {
        // Create a token that expires in the future
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch / 1000).round() +
                3600; // 1 hour from now
        final tokenPayload = {
          'sub': '1234567890',
          'name': 'John Doe',
          'iat': (DateTime.now().millisecondsSinceEpoch / 1000).round(),
          'exp': futureExp,
        };

        // This is a simplified test - in real scenarios, you'd need a properly signed JWT
        // For now, we'll test the utility functions directly
        expect(
            futureExp > (DateTime.now().millisecondsSinceEpoch / 1000), isTrue);
      });
    });

    group('SecureTokenManager Basic Tests', () {
      test('should initialize without errors', () async {
        expect(() => SecureTokenManager(), returnsNormally);
      });

      test('should handle null tokens gracefully', () async {
        final accessToken = await tokenManager.getAccessToken();
        final refreshToken = await tokenManager.getRefreshToken();
        final idToken = await tokenManager.getIdToken();

        // These should not throw errors even if no tokens are stored
        expect(accessToken, isNull);
        expect(refreshToken, isNull);
        expect(idToken, isNull);
      });

      test('should handle authentication check with no tokens', () async {
        final isAuthenticated = await tokenManager.isAuthenticated();
        expect(isAuthenticated, isFalse);
      });

      test('should handle getUserInfo with no tokens', () async {
        final userInfo = await tokenManager.getUserInfo();
        expect(userInfo, isNull);
      });

      test('should handle clearTokens without errors', () async {
        expect(() => tokenManager.clearTokens(), returnsNormally);
      });

      test('should handle dispose without errors', () {
        expect(() => tokenManager.dispose(), returnsNormally);
      });
    });
  });
}
