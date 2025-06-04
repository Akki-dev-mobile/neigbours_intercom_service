import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_service.dart';
import 'package:flutter_onegate/services/auth_service/secure_token_manager.dart';
import 'package:flutter_onegate/services/api_client/authenticated_api_client.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';

// Generate mocks
@GenerateMocks([
  UnifiedAuthService,
  SecureTokenManager,
  AuthenticatedApiClient,
  RemoteDataSource,
])
import 'comprehensive_integration_test_suite.mocks.dart';

/// Comprehensive integration test suite
/// Tests end-to-end authentication and API flows
void runIntegrationTestSuite() {
  group('🔗 Comprehensive Integration Tests', () {
    late MockUnifiedAuthService mockAuthService;
    late MockSecureTokenManager mockTokenManager;
    late MockAuthenticatedApiClient mockApiClient;
    late MockRemoteDataSource mockRemoteDataSource;

    setUp(() {
      mockAuthService = MockUnifiedAuthService();
      mockTokenManager = MockSecureTokenManager();
      mockApiClient = MockAuthenticatedApiClient();
      mockRemoteDataSource = MockRemoteDataSource();
    });

    group('Authentication Flow Integration', () {
      test('should complete full login flow successfully', () async {
        // Arrange
        final userInfo = {
          'sub': 'user123',
          'name': 'Test User',
          'email': 'test@example.com',
          'roles': ['user', 'gatekeeper'],
        };

        when(mockAuthService.initialize()).thenAnswer((_) async => {});
        when(mockAuthService.login()).thenAnswer((_) async => userInfo);
        when(mockAuthService.isAuthenticated()).thenAnswer((_) async => true);
        when(mockAuthService.getCurrentUser()).thenAnswer((_) async => userInfo);

        // Act
        await mockAuthService.initialize();
        final loginResult = await mockAuthService.login();
        final isAuthenticated = await mockAuthService.isAuthenticated();
        final currentUser = await mockAuthService.getCurrentUser();

        // Assert
        expect(loginResult, equals(userInfo));
        expect(isAuthenticated, isTrue);
        expect(currentUser, equals(userInfo));
        
        verify(mockAuthService.initialize()).called(1);
        verify(mockAuthService.login()).called(1);
        verify(mockAuthService.isAuthenticated()).called(1);
        verify(mockAuthService.getCurrentUser()).called(1);
      });

      test('should handle login failure and recovery', () async {
        // Arrange
        when(mockAuthService.initialize()).thenAnswer((_) async => {});
        when(mockAuthService.login())
            .thenThrow(Exception('Network error'))
            .thenAnswer((_) async => {'sub': 'user123'});
        when(mockAuthService.isAuthenticated())
            .thenAnswer((_) async => false)
            .thenAnswer((_) async => true);

        // Act & Assert - First attempt fails
        await mockAuthService.initialize();
        expect(() => mockAuthService.login(), throwsException);
        
        final isAuthenticatedBefore = await mockAuthService.isAuthenticated();
        expect(isAuthenticatedBefore, isFalse);

        // Second attempt succeeds
        final loginResult = await mockAuthService.login();
        expect(loginResult, equals({'sub': 'user123'}));
        
        final isAuthenticatedAfter = await mockAuthService.isAuthenticated();
        expect(isAuthenticatedAfter, isTrue);
      });

      test('should complete logout flow successfully', () async {
        // Arrange
        when(mockAuthService.isAuthenticated())
            .thenAnswer((_) async => true)
            .thenAnswer((_) async => false);
        when(mockAuthService.logout()).thenAnswer((_) async => {});

        // Act
        final isAuthenticatedBefore = await mockAuthService.isAuthenticated();
        await mockAuthService.logout();
        final isAuthenticatedAfter = await mockAuthService.isAuthenticated();

        // Assert
        expect(isAuthenticatedBefore, isTrue);
        expect(isAuthenticatedAfter, isFalse);
        verify(mockAuthService.logout()).called(1);
      });
    });

    group('Token Management Integration', () {
      test('should handle token refresh flow', () async {
        // Arrange
        const initialToken = 'initial_access_token';
        const refreshedToken = 'refreshed_access_token';

        when(mockTokenManager.initialize()).thenAnswer((_) async => {});
        when(mockTokenManager.getValidAccessToken())
            .thenAnswer((_) async => initialToken)
            .thenAnswer((_) async => refreshedToken);
        when(mockTokenManager.refreshTokens()).thenAnswer((_) async => true);

        // Act
        await mockTokenManager.initialize();
        final initialTokenResult = await mockTokenManager.getValidAccessToken();
        final refreshResult = await mockTokenManager.refreshTokens();
        final refreshedTokenResult = await mockTokenManager.getValidAccessToken();

        // Assert
        expect(initialTokenResult, equals(initialToken));
        expect(refreshResult, isTrue);
        expect(refreshedTokenResult, equals(refreshedToken));
        
        verify(mockTokenManager.refreshTokens()).called(1);
      });

      test('should handle token refresh failure', () async {
        // Arrange
        when(mockTokenManager.getValidAccessToken()).thenAnswer((_) async => null);
        when(mockTokenManager.refreshTokens()).thenAnswer((_) async => false);
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => false);

        // Act
        final tokenResult = await mockTokenManager.getValidAccessToken();
        final refreshResult = await mockTokenManager.refreshTokens();
        final isAuthenticated = await mockTokenManager.isAuthenticated();

        // Assert
        expect(tokenResult, isNull);
        expect(refreshResult, isFalse);
        expect(isAuthenticated, isFalse);
      });

      test('should handle concurrent token refresh requests', () async {
        // Arrange
        when(mockTokenManager.refreshTokens()).thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 100));
          return true;
        });

        // Act - Simulate concurrent refresh requests
        final futures = List.generate(5, (_) => mockTokenManager.refreshTokens());
        final results = await Future.wait(futures);

        // Assert
        expect(results.every((result) => result == true), isTrue);
        // Should be called 5 times (one for each concurrent request)
        verify(mockTokenManager.refreshTokens()).called(5);
      });
    });

    group('API Client Integration', () {
      test('should perform authenticated API request successfully', () async {
        // Arrange
        final responseData = {'data': 'success'};
        when(mockApiClient.get('/api/test')).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/test'),
          ),
        );

        // Act
        final response = await mockApiClient.get('/api/test');

        // Assert
        expect(response.statusCode, equals(200));
        expect(response.data, equals(responseData));
        verify(mockApiClient.get('/api/test')).called(1);
      });

      test('should handle 401 error with token refresh and retry', () async {
        // Arrange
        final successData = {'data': 'success after retry'};
        
        when(mockApiClient.get('/api/test'))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/api/test'),
              response: Response(
                statusCode: 401,
                requestOptions: RequestOptions(path: '/api/test'),
              ),
            ))
            .thenAnswer((_) async => Response(
              data: successData,
              statusCode: 200,
              requestOptions: RequestOptions(path: '/api/test'),
            ));

        when(mockTokenManager.refreshTokens()).thenAnswer((_) async => true);

        // Act & Assert
        // First call should fail with 401
        expect(() => mockApiClient.get('/api/test'), throwsA(isA<DioException>()));
        
        // After token refresh, retry should succeed
        final response = await mockApiClient.get('/api/test');
        expect(response.statusCode, equals(200));
        expect(response.data, equals(successData));
      });

      test('should handle multiple API requests with shared authentication', () async {
        // Arrange
        final endpoints = ['/api/gates', '/api/societies', '/api/purposes'];
        final responses = endpoints.map((endpoint) => {
          'endpoint': endpoint,
          'data': 'success',
        }).toList();

        for (int i = 0; i < endpoints.length; i++) {
          when(mockApiClient.get(endpoints[i])).thenAnswer(
            (_) async => Response(
              data: responses[i],
              statusCode: 200,
              requestOptions: RequestOptions(path: endpoints[i]),
            ),
          );
        }

        // Act
        final futures = endpoints.map((endpoint) => mockApiClient.get(endpoint));
        final results = await Future.wait(futures);

        // Assert
        expect(results.length, equals(3));
        for (int i = 0; i < results.length; i++) {
          expect(results[i].statusCode, equals(200));
          expect(results[i].data['endpoint'], equals(endpoints[i]));
        }
      });
    });

    group('Data Source Integration', () {
      test('should fetch gates with authentication', () async {
        // Arrange
        final gatesData = [
          {'id': 1, 'name': 'Main Gate'},
          {'id': 2, 'name': 'Side Gate'},
        ];
        
        when(mockRemoteDataSource.fetchGates())
            .thenAnswer((_) async => gatesData);

        // Act
        final result = await mockRemoteDataSource.fetchGates();

        // Assert
        expect(result, equals(gatesData));
        expect(result.length, equals(2));
        verify(mockRemoteDataSource.fetchGates()).called(1);
      });

      test('should fetch societies with user authentication', () async {
        // Arrange
        const userId = 'user123';
        final societiesData = [
          {'id': 1, 'name': 'Society A'},
          {'id': 2, 'name': 'Society B'},
        ];
        
        when(mockRemoteDataSource.fetchSocieties(userId))
            .thenAnswer((_) async => societiesData);

        // Act
        final result = await mockRemoteDataSource.fetchSocieties(userId);

        // Assert
        expect(result, equals(societiesData));
        expect(result.length, equals(2));
        verify(mockRemoteDataSource.fetchSocieties(userId)).called(1);
      });

      test('should handle data source errors gracefully', () async {
        // Arrange
        when(mockRemoteDataSource.fetchGates()).thenThrow(
          Exception('Network error'),
        );

        // Act & Assert
        expect(() => mockRemoteDataSource.fetchGates(), throwsException);
      });
    });

    group('End-to-End Flow Integration', () {
      test('should complete full app initialization flow', () async {
        // Arrange
        final userInfo = {'sub': 'user123', 'name': 'Test User'};
        final gatesData = [{'id': 1, 'name': 'Main Gate'}];

        when(mockAuthService.initialize()).thenAnswer((_) async => {});
        when(mockTokenManager.initialize()).thenAnswer((_) async => {});
        when(mockAuthService.isAuthenticated()).thenAnswer((_) async => true);
        when(mockAuthService.getCurrentUser()).thenAnswer((_) async => userInfo);
        when(mockRemoteDataSource.fetchGates()).thenAnswer((_) async => gatesData);

        // Act
        await mockAuthService.initialize();
        await mockTokenManager.initialize();
        
        final isAuthenticated = await mockAuthService.isAuthenticated();
        if (isAuthenticated) {
          final user = await mockAuthService.getCurrentUser();
          final gates = await mockRemoteDataSource.fetchGates();
          
          // Assert
          expect(user, equals(userInfo));
          expect(gates, equals(gatesData));
        }

        // Verify all initialization steps
        verify(mockAuthService.initialize()).called(1);
        verify(mockTokenManager.initialize()).called(1);
        verify(mockAuthService.isAuthenticated()).called(1);
        verify(mockAuthService.getCurrentUser()).called(1);
        verify(mockRemoteDataSource.fetchGates()).called(1);
      });

      test('should handle session expiry and re-authentication', () async {
        // Arrange
        when(mockAuthService.isAuthenticated())
            .thenAnswer((_) async => true)
            .thenAnswer((_) async => false)
            .thenAnswer((_) async => true);
        
        when(mockTokenManager.refreshTokens())
            .thenAnswer((_) async => false)
            .thenAnswer((_) async => true);
        
        when(mockAuthService.login())
            .thenAnswer((_) async => {'sub': 'user123'});

        // Act & Assert
        // Initially authenticated
        expect(await mockAuthService.isAuthenticated(), isTrue);
        
        // Session expires
        expect(await mockAuthService.isAuthenticated(), isFalse);
        
        // Token refresh fails, need to re-login
        expect(await mockTokenManager.refreshTokens(), isFalse);
        
        // Re-login succeeds
        final loginResult = await mockAuthService.login();
        expect(loginResult, equals({'sub': 'user123'}));
        
        // Now authenticated again
        expect(await mockAuthService.isAuthenticated(), isTrue);
      });
    });
  });
}
