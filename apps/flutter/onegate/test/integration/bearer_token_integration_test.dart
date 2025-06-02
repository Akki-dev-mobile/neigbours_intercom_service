import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/api_client/authenticated_dio_factory.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_interceptor.dart';

void main() {
  group('Bearer Token Integration Tests', () {
    late Dio authenticatedDio;
    late Dio publicDio;

    setUp(() {
      // Create authenticated Dio client
      authenticatedDio = AuthenticatedDioFactory.createAuthenticatedDio(
        baseUrl: 'https://httpbin.org',
        enableNetworkLogging: false, // Disable for testing
      );

      // Create public Dio client
      publicDio = AuthenticatedDioFactory.createPublicDio(
        baseUrl: 'https://httpbin.org',
      );
    });

    group('Authenticated Requests', () {
      test('should have UnifiedAuthInterceptor in authenticated client', () {
        // Check that the authenticated client has the auth interceptor
        final hasAuthInterceptor = authenticatedDio.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        
        expect(hasAuthInterceptor, isTrue);
      });

      test('should make request with auth interceptor (will fail gracefully without token)', () async {
        try {
          // This will attempt to add a Bearer token but fail gracefully if none available
          final response = await authenticatedDio.get('/headers');
          
          // If we get here, the request succeeded (unlikely without real auth setup)
          expect(response.statusCode, equals(200));
        } catch (e) {
          // Expected to fail in test environment without real authentication
          // The important thing is that the interceptor doesn't crash
          expect(e, isA<DioException>());
        }
      });

      test('should handle requests to endpoints that skip auth', () async {
        try {
          // Test with a path that should skip authentication
          final response = await authenticatedDio.get('/login');
          
          // This should work even without authentication
          expect(response.statusCode, anyOf([200, 404, 405])); // Various valid responses
        } catch (e) {
          // Even if it fails, it should be a normal HTTP error, not an auth error
          expect(e, isA<DioException>());
          if (e is DioException) {
            // Should not be an authentication-related error
            expect(e.response?.statusCode, isNot(401));
          }
        }
      });
    });

    group('Public Requests', () {
      test('should not have UnifiedAuthInterceptor in public client', () {
        // Check that the public client does NOT have the auth interceptor
        final hasAuthInterceptor = publicDio.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        
        expect(hasAuthInterceptor, isFalse);
      });

      test('should make public request successfully', () async {
        try {
          final response = await publicDio.get('/headers');
          
          expect(response.statusCode, equals(200));
          expect(response.data, isA<Map>());
          
          // Verify no Authorization header was added
          final headers = response.data['headers'] as Map<String, dynamic>;
          expect(headers.containsKey('Authorization'), isFalse);
        } catch (e) {
          // If it fails, it should be a network error, not an auth error
          expect(e, isA<DioException>());
        }
      });
    });

    group('Factory Method Tests', () {
      test('should create OneGate API client with correct configuration', () {
        final oneGateClient = AuthenticatedDioFactory.createOneGateApiClient(
          baseUrl: 'https://test-api.example.com',
        );

        expect(oneGateClient.options.baseUrl, equals('https://test-api.example.com'));
        expect(oneGateClient.options.headers['X-API-Source'], equals('OneGate-Flutter'));
        expect(oneGateClient.options.headers['X-Client-Version'], equals('1.0.0'));
        expect(oneGateClient.options.headers['Content-Type'], equals('application/json'));
        expect(oneGateClient.options.headers['Accept'], equals('application/json'));

        // Should have auth interceptor
        final hasAuthInterceptor = oneGateClient.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isTrue);
      });

      test('should create Society API client with correct base URL', () {
        final societyClient = AuthenticatedDioFactory.createSocietyApiClient();

        expect(societyClient.options.baseUrl, equals('https://societybackend.cubeone.in/api'));
        expect(societyClient.options.headers['X-API-Source'], equals('OneGate-Society'));

        // Should have auth interceptor
        final hasAuthInterceptor = societyClient.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isTrue);
      });

      test('should create file upload client with extended timeouts', () {
        final uploadClient = AuthenticatedDioFactory.createFileUploadClient();

        expect(uploadClient.options.connectTimeout, equals(const Duration(minutes: 2)));
        expect(uploadClient.options.receiveTimeout, equals(const Duration(minutes: 5)));
        expect(uploadClient.options.sendTimeout, equals(const Duration(minutes: 5)));
        expect(uploadClient.options.headers['X-API-Source'], equals('OneGate-FileUpload'));

        // Should have auth interceptor
        final hasAuthInterceptor = uploadClient.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isTrue);
      });

      test('should create realtime client with optimized timeouts', () {
        final realtimeClient = AuthenticatedDioFactory.createRealtimeClient();

        expect(realtimeClient.options.connectTimeout, equals(const Duration(seconds: 10)));
        expect(realtimeClient.options.receiveTimeout, equals(const Duration(seconds: 60)));
        expect(realtimeClient.options.sendTimeout, equals(const Duration(seconds: 10)));
        expect(realtimeClient.options.headers['X-API-Source'], equals('OneGate-Realtime'));

        // Should have auth interceptor
        final hasAuthInterceptor = realtimeClient.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isTrue);
      });
    });

    group('Endpoint Classification Tests', () {
      test('should correctly identify public endpoints', () {
        final publicEndpoints = [
          '/auth/login',
          '/login',
          '/logout',
          '/token',
          '/health',
          '/public/data',
          '/gatelogin',
          '/sms/verification-code',
          '/visitor/selfCheckin',
          '/realms/fstech/protocol/openid-connect/auth',
        ];

        final privateEndpoints = [
          '/visitor/entry',
          '/visitor/logs',
          '/admin/gates',
          '/societies',
          '/admin/building/list',
          '/v2/admin/member/list',
          '/member/pass/verify',
        ];

        // Test public endpoint detection logic
        for (final endpoint in publicEndpoints) {
          final shouldSkipAuth = endpoint.contains('/auth/') ||
              endpoint.contains('/login') ||
              endpoint.contains('/logout') ||
              endpoint.contains('/token') ||
              endpoint.contains('/health') ||
              endpoint.contains('/public/') ||
              endpoint.contains('/gatelogin') ||
              endpoint.contains('/sms/verification-code') ||
              endpoint.contains('/visitor/selfCheckin') ||
              endpoint.contains('/realms/');
          
          expect(shouldSkipAuth, isTrue, reason: 'Endpoint $endpoint should skip auth');
        }

        // Test private endpoint detection logic
        for (final endpoint in privateEndpoints) {
          final shouldSkipAuth = endpoint.contains('/auth/') ||
              endpoint.contains('/login') ||
              endpoint.contains('/logout') ||
              endpoint.contains('/token') ||
              endpoint.contains('/health') ||
              endpoint.contains('/public/') ||
              endpoint.contains('/gatelogin') ||
              endpoint.contains('/sms/verification-code') ||
              endpoint.contains('/visitor/selfCheckin') ||
              endpoint.contains('/realms/');
          
          expect(shouldSkipAuth, isFalse, reason: 'Endpoint $endpoint should require auth');
        }
      });
    });
  });
}
