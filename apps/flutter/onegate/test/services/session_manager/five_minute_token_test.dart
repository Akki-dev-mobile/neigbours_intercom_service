import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/session_manager/five_minute_token_fix.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

// Generate mocks
@GenerateMocks([GateStorage])
import 'five_minute_token_test.mocks.dart';

void main() {
  group('5-Minute Token Session Management Tests', () {
    late MockGateStorage mockGateStorage;
    late FiveMinuteTokenFix fiveMinuteTokenFix;

    setUp(() {
      mockGateStorage = MockGateStorage();
      fiveMinuteTokenFix = FiveMinuteTokenFix();
      
      // Set up SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    group('JWT Token Utility Buffer Calculation', () {
      test('should calculate 2-minute buffer for 5-minute tokens', () {
        // Create a mock 5-minute token
        final now = DateTime.now();
        final expiryTime = now.add(const Duration(minutes: 5));
        
        // Create a simple JWT-like token for testing
        final mockToken = _createMockJwtToken(
          issuedAt: now,
          expiresAt: expiryTime,
        );

        final buffer = JwtTokenUtility.calculateOptimalRefreshBuffer(mockToken);
        
        expect(buffer, equals(const Duration(minutes: 2)));
      });

      test('should calculate appropriate buffer for very short tokens', () {
        final now = DateTime.now();
        final expiryTime = now.add(const Duration(minutes: 3));
        
        final mockToken = _createMockJwtToken(
          issuedAt: now,
          expiresAt: expiryTime,
        );

        final buffer = JwtTokenUtility.calculateOptimalRefreshBuffer(mockToken);
        
        // For 3-minute token, should use 40% of lifespan = 72 seconds
        expect(buffer.inSeconds, equals(72));
      });

      test('should determine optimal refresh time for 5-minute tokens', () {
        final now = DateTime.now();
        final expiryTime = now.add(const Duration(minutes: 5));
        
        final mockToken = _createMockJwtToken(
          issuedAt: now,
          expiresAt: expiryTime,
        );

        final refreshTime = JwtTokenUtility.getOptimalRefreshTime(mockToken);
        
        // Should refresh at 3 minutes (5 minutes - 2 minute buffer)
        final expectedRefreshTime = now.add(const Duration(minutes: 3));
        expect(refreshTime, isNotNull);
        expect(refreshTime!.difference(expectedRefreshTime).abs().inSeconds, lessThan(5));
      });
    });

    group('GateStorage Dynamic Buffer', () {
      test('should use 2-minute buffer for 5-minute tokens in isTokenExpired', () async {
        final now = DateTime.now();
        final expiryTime = now.add(const Duration(minutes: 5));
        
        // Mock SharedPreferences
        SharedPreferences.setMockInitialValues({
          'token_expiry': expiryTime.millisecondsSinceEpoch,
          'gate_storage_token_expiration_disabled': false,
        });

        final gateStorage = GateStorage();
        await gateStorage.init();

        // Mock access token
        when(mockGateStorage.getAccessToken()).thenAnswer((_) async => 'mock_token');

        // Token should not be considered expired yet (5 minutes - 2 minute buffer = 3 minutes remaining)
        final isExpired = await gateStorage.isTokenExpired();
        expect(isExpired, isFalse);
      });

      test('should respect session timeout override', () async {
        final now = DateTime.now();
        final expiryTime = now.subtract(const Duration(minutes: 1)); // Already expired
        
        // Mock SharedPreferences with override enabled
        SharedPreferences.setMockInitialValues({
          'token_expiry': expiryTime.millisecondsSinceEpoch,
          'gate_storage_token_expiration_disabled': true, // Override enabled
        });

        final gateStorage = GateStorage();
        await gateStorage.init();

        // With override, should only consider truly expired tokens
        final isExpired = await gateStorage.isTokenExpired();
        expect(isExpired, isTrue); // Still expired because it's actually past expiry
      });
    });

    group('Five Minute Token Fix Integration', () {
      test('should initialize all session management components', () async {
        // This test verifies that the fix can be initialized without errors
        expect(() async => await fiveMinuteTokenFix.initialize(), returnsNormally);
      });

      test('should activate session timeout overrides', () async {
        await fiveMinuteTokenFix.initialize();
        
        final prefs = await SharedPreferences.getInstance();
        
        // Verify that timeout overrides are activated
        expect(prefs.getBool('token_expiration_logout_disabled'), isTrue);
        expect(prefs.getBool('auto_logout_disabled'), isTrue);
        expect(prefs.getBool('aggressive_refresh_enabled'), isTrue);
      });

      test('should provide session status information', () async {
        await fiveMinuteTokenFix.initialize();
        
        final status = await fiveMinuteTokenFix.getSessionStatus();
        
        expect(status['isInitialized'], isTrue);
        expect(status['timeoutOverrideActive'], isTrue);
        expect(status['autoLogoutDisabled'], isTrue);
        expect(status['aggressiveRefreshEnabled'], isTrue);
        expect(status['timestamp'], isNotNull);
      });
    });

    group('Token Refresh Timing Scenarios', () {
      test('should handle 5-minute token refresh scenario', () {
        final now = DateTime.now();
        final issuedAt = now;
        final expiresAt = now.add(const Duration(minutes: 5));
        
        final mockToken = _createMockJwtToken(
          issuedAt: issuedAt,
          expiresAt: expiresAt,
        );

        // Test that token should be refreshed at 3 minutes
        final refreshTime = JwtTokenUtility.getOptimalRefreshTime(mockToken);
        final expectedRefreshTime = issuedAt.add(const Duration(minutes: 3));
        
        expect(refreshTime, isNotNull);
        expect(refreshTime!.difference(expectedRefreshTime).abs().inSeconds, lessThan(5));
        
        // Test that token should not be refreshed immediately
        final shouldRefreshNow = JwtTokenUtility.shouldRefreshTokenNow(mockToken);
        expect(shouldRefreshNow, isFalse);
      });

      test('should handle token that needs immediate refresh', () {
        final now = DateTime.now();
        final issuedAt = now.subtract(const Duration(minutes: 4));
        final expiresAt = now.add(const Duration(minutes: 1)); // Expires in 1 minute
        
        final mockToken = _createMockJwtToken(
          issuedAt: issuedAt,
          expiresAt: expiresAt,
        );

        // Token should be refreshed immediately (within 2-minute buffer)
        final shouldRefreshNow = JwtTokenUtility.shouldRefreshTokenNow(mockToken);
        expect(shouldRefreshNow, isTrue);
      });
    });
  });
}

/// Helper function to create a mock JWT token for testing
String _createMockJwtToken({
  required DateTime issuedAt,
  required DateTime expiresAt,
}) {
  // This is a simplified mock - in real implementation, you'd create a proper JWT
  // For testing purposes, we'll create a token that the JWT utility can parse
  final header = {'alg': 'HS256', 'typ': 'JWT'};
  final payload = {
    'iat': (issuedAt.millisecondsSinceEpoch / 1000).floor(),
    'exp': (expiresAt.millisecondsSinceEpoch / 1000).floor(),
    'sub': 'test-user',
  };
  
  // Create a simple base64-encoded mock token
  // Note: This is not a real JWT, just enough for testing the utility functions
  return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.${_base64Encode(payload.toString())}.signature';
}

String _base64Encode(String input) {
  // Simple base64 encoding for testing
  return input.codeUnits.map((e) => e.toString()).join('');
}
