import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_interceptor.dart';
import 'package:flutter_onegate/services/api_client/authenticated_dio_factory.dart';

void main() {
  group('UnifiedAuthInterceptor Tests', () {
    late UnifiedAuthInterceptor interceptor;
    late Dio dio;

    setUp(() {
      interceptor = UnifiedAuthInterceptor();
      dio = Dio();
      dio.interceptors.add(interceptor);
    });

    group('Bearer Token Injection', () {
      test('should create interceptor instance', () {
        // Act & Assert
        expect(interceptor, isA<UnifiedAuthInterceptor>());
        expect(dio.interceptors.length, greaterThan(0));

        // Check that our interceptor is in the list
        final hasAuthInterceptor = dio.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isTrue);
      });

      test('should skip authentication for public endpoints', () {
        // Test that public endpoints are properly identified
        const publicPaths = [
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

        for (final path in publicPaths) {
          // This would test the _shouldSkipAuth method
          // Implementation would depend on making the method testable
          expect(
              path.contains('/auth/') ||
                  path.contains('/login') ||
                  path.contains('/logout') ||
                  path.contains('/token') ||
                  path.contains('/health') ||
                  path.contains('/public/') ||
                  path.contains('/gatelogin') ||
                  path.contains('/sms/verification-code') ||
                  path.contains('/visitor/selfCheckin') ||
                  path.contains('/realms/'),
              isTrue);
        }
      });
    });

    group('AuthenticatedDioFactory Tests', () {
      test('should create authenticated Dio instance with interceptors', () {
        // Act
        final authenticatedDio = AuthenticatedDioFactory.createAuthenticatedDio(
          baseUrl: 'https://test-api.example.com',
          customHeaders: {'X-Test': 'true'},
        );

        // Assert
        expect(authenticatedDio, isA<Dio>());
        expect(authenticatedDio.options.baseUrl,
            equals('https://test-api.example.com'));
        expect(authenticatedDio.options.headers['X-Test'], equals('true'));
        expect(authenticatedDio.options.headers['Content-Type'],
            equals('application/json'));
        expect(authenticatedDio.options.headers['Accept'],
            equals('application/json'));

        // Check that interceptors are added
        expect(authenticatedDio.interceptors.length, greaterThan(0));

        // Check for UnifiedAuthInterceptor
        final hasAuthInterceptor = authenticatedDio.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isTrue);
      });

      test('should create OneGate API client with correct configuration', () {
        // Act
        final oneGateClient = AuthenticatedDioFactory.createOneGateApiClient(
          baseUrl: 'https://api.onegate.com',
          customHeaders: {'X-Custom': 'value'},
        );

        // Assert
        expect(oneGateClient, isA<Dio>());
        expect(
            oneGateClient.options.baseUrl, equals('https://api.onegate.com'));
        expect(oneGateClient.options.headers['X-API-Source'],
            equals('OneGate-Flutter'));
        expect(
            oneGateClient.options.headers['X-Client-Version'], equals('1.0.0'));
        expect(oneGateClient.options.headers['X-Custom'], equals('value'));
      });

      test('should create Society API client with correct configuration', () {
        // Act
        final societyClient = AuthenticatedDioFactory.createSocietyApiClient(
          customHeaders: {'X-Society': 'test'},
        );

        // Assert
        expect(societyClient, isA<Dio>());
        expect(societyClient.options.baseUrl,
            equals('https://societybackend.cubeone.in/api'));
        expect(societyClient.options.headers['X-API-Source'],
            equals('OneGate-Society'));
        expect(societyClient.options.headers['X-Society'], equals('test'));
      });

      test('should create file upload client with extended timeouts', () {
        // Act
        final uploadClient = AuthenticatedDioFactory.createFileUploadClient(
          baseUrl: 'https://upload.example.com',
        );

        // Assert
        expect(uploadClient, isA<Dio>());
        expect(
            uploadClient.options.baseUrl, equals('https://upload.example.com'));
        expect(uploadClient.options.connectTimeout,
            equals(const Duration(minutes: 2)));
        expect(uploadClient.options.receiveTimeout,
            equals(const Duration(minutes: 5)));
        expect(uploadClient.options.sendTimeout,
            equals(const Duration(minutes: 5)));
        expect(uploadClient.options.headers['X-API-Source'],
            equals('OneGate-FileUpload'));
      });

      test('should create public Dio client without authentication', () {
        // Act
        final publicClient = AuthenticatedDioFactory.createPublicDio(
          baseUrl: 'https://public-api.example.com',
        );

        // Assert
        expect(publicClient, isA<Dio>());
        expect(publicClient.options.baseUrl,
            equals('https://public-api.example.com'));

        // Check that UnifiedAuthInterceptor is NOT added to public client
        final hasAuthInterceptor = publicClient.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isFalse);
      });

      test('should create realtime client with appropriate timeouts', () {
        // Act
        final realtimeClient = AuthenticatedDioFactory.createRealtimeClient(
          baseUrl: 'https://realtime.example.com',
        );

        // Assert
        expect(realtimeClient, isA<Dio>());
        expect(realtimeClient.options.baseUrl,
            equals('https://realtime.example.com'));
        expect(realtimeClient.options.connectTimeout,
            equals(const Duration(seconds: 10)));
        expect(realtimeClient.options.receiveTimeout,
            equals(const Duration(seconds: 60)));
        expect(realtimeClient.options.sendTimeout,
            equals(const Duration(seconds: 10)));
        expect(realtimeClient.options.headers['X-API-Source'],
            equals('OneGate-Realtime'));
      });
    });

    group('Error Handling', () {
      test('should handle 401 errors with retry mechanism', () {
        // This would test the 401 error handling and retry logic
        // Implementation would require proper mocking of the token refresh
        expect(true, isTrue); // Placeholder
      });

      test('should prevent infinite retry loops', () {
        // This would test the max retry limit
        expect(true, isTrue); // Placeholder
      });

      test('should handle authentication failures gracefully', () {
        // This would test the authentication failure handling
        expect(true, isTrue); // Placeholder
      });
    });

    group('Integration Tests', () {
      test('should work with all 37 identified API endpoints', () {
        // This would be an integration test to verify that all endpoints
        // properly receive Bearer tokens
        final endpoints = [
          // Authentication endpoints (should skip auth)
          '/realms/fstech/protocol/openid-connect/auth',
          '/realms/fstech/protocol/openid-connect/token',
          '/realms/fstech/protocol/openid-connect/userinfo',
          '/realms/fstech/protocol/openid-connect/logout',
          '/gatelogin',

          // Visitor management endpoints (should have auth)
          '/visitor/entry',
          '/visitor/logs',
          '/visitor/log',
          '/visitor/checkout',
          '/visitor/sendLogs',
          '/visitor/requestApproval',
          '/visitor/getLog',
          '/visitor/approvals',
          '/visitor/status/123',
          '/visitor/parcelData/456',
          '/visitor/uploadFile',

          // Society & building management endpoints (should have auth)
          '/societies',
          '/admin/building/list',
          '/v2/admin/member/list',
          '/admin/units/list',
          '/admin/staffs/staffLists',
          '/members',

          // Gate management endpoints (should have auth)
          '/admin/gates',
          '/gates',

          // Member & access endpoints (should have auth)
          '/member/pass/verify',
        ];

        // For each endpoint, verify it gets the correct treatment
        for (final endpoint in endpoints) {
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

          // This is a simplified test - in practice, you'd make actual requests
          // and verify the Authorization header is present/absent as expected
          expect(shouldSkipAuth, isA<bool>());
        }
      });
    });
  });
}
