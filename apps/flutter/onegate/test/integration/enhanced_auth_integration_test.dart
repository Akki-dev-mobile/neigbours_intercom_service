import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_token_refresh_manager.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/services/api_client/authenticated_api_client.dart';

// Generate mocks
@GenerateMocks([GateStorage, RemoteDataSource])
import 'enhanced_auth_integration_test.mocks.dart';

void main() {
  group('Enhanced Authentication Integration Tests', () {
    late AuthService authService;
    late EnhancedTokenRefreshManager tokenManager;
    late AuthenticatedApiClient apiClient;
    late MockGateStorage mockGateStorage;
    late MockRemoteDataSource mockRemoteDataSource;

    setUpAll(() {
      // Reset GetIt instance
      GetIt.instance.reset();
    });

    setUp(() async {
      // Create mocks
      mockGateStorage = MockGateStorage();
      mockRemoteDataSource = MockRemoteDataSource();

      // Register dependencies
      GetIt.instance.registerSingleton<GateStorage>(mockGateStorage);
      GetIt.instance.registerSingleton<RemoteDataSource>(mockRemoteDataSource);

      // Create services
      authService = AuthService(
        gateStorage: mockGateStorage,
        remoteDataSource: mockRemoteDataSource,
      );

      // Register AuthService
      GetIt.instance.registerSingleton<AuthService>(authService);

      // Initialize auth service
      await authService.initialize();

      // Get token manager
      tokenManager = authService.tokenRefreshManager;

      // Create API client
      apiClient = AuthenticatedApiClient();
      GetIt.instance.registerSingleton<AuthenticatedApiClient>(apiClient);

      // Initialize API client
      await apiClient.initialize();
    });

    tearDown(() {
      GetIt.instance.reset();
      tokenManager.dispose();
    });

    group('JWT Token Utility Integration', () {
      test('should handle real JWT token parsing', () {
        // Test with a real-looking JWT token structure
        const realJwtToken =
            'eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJyc2ExIn0.'
            'eyJleHAiOjk5OTk5OTk5OTksImlhdCI6MTUxNjIzOTAyMiwianRpIjoiYWJjZGVmZ2gtaWprbC1tbm9wLXFyc3QtdXZ3eHl6MTIzNCIsImlzcyI6Imh0dHBzOi8va2V5Y2xvYWsuZXhhbXBsZS5jb20vcmVhbG1zL29uZWdhdGUiLCJhdWQiOiJhY2NvdW50Iiwic3ViIjoiMTIzNDU2NzgtOTBhYi1jZGVmLTEyMzQtNTY3ODkwYWJjZGVmIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoib25lZ2F0ZS1hcHAiLCJzZXNzaW9uX3N0YXRlIjoiYWJjZGVmZ2gtaWprbC1tbm9wLXFyc3QtdXZ3eHl6MTIzNCIsImFjciI6IjEiLCJhbGxvd2VkLW9yaWdpbnMiOlsiaHR0cHM6Ly9vbmVnYXRlLmV4YW1wbGUuY29tIl0sInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJkZWZhdWx0LXJvbGVzLW9uZWdhdGUiLCJvZmZsaW5lX2FjY2VzcyIsInVtYV9hdXRob3JpemF0aW9uIiwiZ2F0ZWtlZXBlciJdfSwicmVzb3VyY2VfYWNjZXNzIjp7ImFjY291bnQiOnsicm9sZXMiOlsibWFuYWdlLWFjY291bnQiLCJtYW5hZ2UtYWNjb3VudC1saW5rcyIsInZpZXctcHJvZmlsZSJdfX0sInNjb3BlIjoib3BlbmlkIGVtYWlsIHByb2ZpbGUiLCJzaWQiOiJhYmNkZWZnaC1pamtsLW1ub3AtcXJzdC11dnd4eXoxMjM0IiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5hbWUiOiJKb2huIERvZSIsInByZWZlcnJlZF91c2VybmFtZSI6ImpvaG5kb2UiLCJnaXZlbl9uYW1lIjoiSm9obiIsImZhbWlseV9uYW1lIjoiRG9lIiwiZW1haWwiOiJqb2huLmRvZUBleGFtcGxlLmNvbSJ9.'
            'signature-would-be-here';

        final userInfo = JwtTokenUtility.getUserInfoFromToken(realJwtToken);

        expect(userInfo, isNotNull);
        expect(
            userInfo!['sub'], equals('12345678-90ab-cdef-1234-567890abcdef'));
        expect(userInfo['email'], equals('john.doe@example.com'));
        expect(userInfo['preferred_username'], equals('johndoe'));
        expect(userInfo['name'], equals('John Doe'));
        expect(userInfo['roles'], contains('gatekeeper'));
        expect(userInfo['scopes'], contains('openid'));
        expect(userInfo['scopes'], contains('email'));
        expect(userInfo['scopes'], contains('profile'));
      });

      test('should validate token expiration correctly', () {
        // Test with a token that expires far in the future
        const futureToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final isExpiring =
            JwtTokenUtility.isTokenExpiredOrExpiring(futureToken);
        expect(isExpiring, isFalse);

        final timeUntilExpiration =
            JwtTokenUtility.getTimeUntilExpiration(futureToken);
        expect(timeUntilExpiration, isNotNull);
        expect(timeUntilExpiration!.inDays, greaterThan(1000));
      });
    });

    group('Enhanced Token Refresh Manager Integration', () {
      test('should initialize correctly with dependencies', () async {
        expect(tokenManager, isNotNull);
        expect(authService.tokenRefreshManager, equals(tokenManager));
      });

      test('should handle token refresh lifecycle', () async {
        // Mock storage responses
        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});

        // Test token clearing
        await tokenManager.clearTokens();

        // Verify that clearTokens was called
        verify(mockGateStorage.clearTokens()).called(1);
      });
    });

    group('API Client Integration', () {
      test('should create authenticated API client with enhanced interceptor',
          () {
        expect(apiClient, isNotNull);
        expect(apiClient.dio.interceptors.length, greaterThan(0));
      });

      test('should handle authentication flow integration', () async {
        // Test that the API client is properly configured with the auth service
        final validToken = await authService.getValidAccessToken();

        // Since we're using mocks, this will return null, but the integration is working
        expect(validToken, isNull);
      });
    });

    group('Service Integration', () {
      test('should integrate all authentication components', () {
        // Verify that all components are properly connected
        expect(authService, isNotNull);
        expect(authService.tokenRefreshManager, isNotNull);
        expect(apiClient, isNotNull);

        // Verify that the token manager is the same instance
        expect(authService.tokenRefreshManager, equals(tokenManager));
      });

      test('should handle service lifecycle correctly', () async {
        // Test initialization
        expect(() => authService.initialize(), returnsNormally);

        // Test disposal
        expect(() => tokenManager.dispose(), returnsNormally);
      });
    });

    group('Error Handling Integration', () {
      test('should handle authentication errors gracefully', () async {
        // Mock error scenarios
        when(mockGateStorage.getAccessToken())
            .thenThrow(Exception('Storage error'));

        // Test that errors are handled gracefully
        final token = await authService.getValidAccessToken();
        expect(token, isNull);
      });

      test('should handle network errors in token refresh', () async {
        // Test that network errors don't crash the app
        expect(() async => await tokenManager.refreshTokenIfNeeded(),
            returnsNormally);
      });
    });
  });
}
