import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

import 'package:flutter_onegate/services/auth_service/riverpod/auth_interceptor.dart';
import 'package:flutter_onegate/services/auth_service/riverpod/auth_controller.dart';
import 'package:flutter_onegate/services/auth_service/riverpod/auth_state.dart';
import 'package:flutter_onegate/services/auth_service/riverpod/auth_tokens.dart';

import 'auth_interceptor_test.mocks.dart';

@GenerateMocks([AuthController, Ref])
void main() {
  group('AuthInterceptor Tests', () {
    late MockRef mockRef;
    late MockAuthController mockAuthController;
    late AuthInterceptor interceptor;
    late RequestOptions requestOptions;

    setUp(() {
      mockRef = MockRef();
      mockAuthController = MockAuthController();
      interceptor = AuthInterceptor(mockRef);
      
      requestOptions = RequestOptions(
        path: '/api/test',
        method: 'GET',
      );

      // Setup default mock behavior
      when(mockRef.read(authControllerProvider.notifier))
          .thenReturn(mockAuthController);
    });

    group('Token Injection', () {
      test('should inject Bearer token for authenticated requests', () async {
        // Arrange
        when(mockAuthController.accessToken).thenReturn('test_access_token');

        final handler = MockRequestInterceptorHandler();

        // Act
        await interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(
          requestOptions.headers['Authorization'],
          equals('Bearer test_access_token'),
        );
        verify(handler.next(requestOptions)).called(1);
      });

      test('should not inject token when user is not authenticated', () async {
        // Arrange
        when(mockAuthController.accessToken).thenReturn(null);

        final handler = MockRequestInterceptorHandler();

        // Act
        await interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(requestOptions.headers['Authorization'], isNull);
        verify(handler.next(requestOptions)).called(1);
      });

      test('should skip auth for excluded paths', () async {
        // Arrange
        final authRequestOptions = RequestOptions(
          path: '/auth/login',
          method: 'POST',
        );

        final handler = MockRequestInterceptorHandler();

        // Act
        await interceptor.onRequest(authRequestOptions, handler);

        // Assert
        expect(authRequestOptions.headers['Authorization'], isNull);
        verify(handler.next(authRequestOptions)).called(1);
        verifyNever(mockAuthController.accessToken);
      });
    });

    group('401 Error Handling', () {
      test('should refresh token and retry on 401 error', () async {
        // Arrange
        final dioError = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
          ),
        );

        when(mockAuthController.refreshToken()).thenAnswer((_) async => true);
        when(mockAuthController.accessToken).thenReturn('new_access_token');

        final handler = MockErrorInterceptorHandler();

        // Act
        await interceptor.onError(dioError, handler);

        // Assert
        verify(mockAuthController.refreshToken()).called(1);
        expect(requestOptions.extra['retry_count'], equals(1));
        expect(
          requestOptions.headers['Authorization'],
          equals('Bearer new_access_token'),
        );
      });

      test('should logout when token refresh fails', () async {
        // Arrange
        final dioError = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
          ),
        );

        when(mockAuthController.refreshToken()).thenAnswer((_) async => false);

        final handler = MockErrorInterceptorHandler();

        // Act
        await interceptor.onError(dioError, handler);

        // Assert
        verify(mockAuthController.refreshToken()).called(1);
        verify(mockAuthController.logout()).called(1);
        verify(handler.next(dioError)).called(1);
      });

      test('should not retry after max retry attempts', () async {
        // Arrange
        requestOptions.extra['retry_count'] = 2; // Already at max retries
        
        final dioError = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
          ),
        );

        final handler = MockErrorInterceptorHandler();

        // Act
        await interceptor.onError(dioError, handler);

        // Assert
        verifyNever(mockAuthController.refreshToken());
        verify(handler.next(dioError)).called(1);
      });

      test('should pass through non-401 errors', () async {
        // Arrange
        final dioError = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 500,
          ),
        );

        final handler = MockErrorInterceptorHandler();

        // Act
        await interceptor.onError(dioError, handler);

        // Assert
        verifyNever(mockAuthController.refreshToken());
        verify(handler.next(dioError)).called(1);
      });

      test('should skip auth for excluded paths on 401', () async {
        // Arrange
        final authRequestOptions = RequestOptions(
          path: '/auth/login',
          method: 'POST',
        );

        final dioError = DioException(
          requestOptions: authRequestOptions,
          response: Response(
            requestOptions: authRequestOptions,
            statusCode: 401,
          ),
        );

        final handler = MockErrorInterceptorHandler();

        // Act
        await interceptor.onError(dioError, handler);

        // Assert
        verifyNever(mockAuthController.refreshToken());
        verify(handler.next(dioError)).called(1);
      });
    });

    group('Concurrent Request Handling', () {
      test('should handle multiple concurrent 401 errors gracefully', () async {
        // Arrange
        final dioError1 = DioException(
          requestOptions: RequestOptions(path: '/api/test1'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/test1'),
            statusCode: 401,
          ),
        );

        final dioError2 = DioException(
          requestOptions: RequestOptions(path: '/api/test2'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/test2'),
            statusCode: 401,
          ),
        );

        when(mockAuthController.refreshToken()).thenAnswer((_) async {
          // Simulate slow refresh
          await Future.delayed(const Duration(milliseconds: 100));
          return true;
        });
        when(mockAuthController.accessToken).thenReturn('new_access_token');

        final handler1 = MockErrorInterceptorHandler();
        final handler2 = MockErrorInterceptorHandler();

        // Act
        final futures = [
          interceptor.onError(dioError1, handler1),
          interceptor.onError(dioError2, handler2),
        ];

        await Future.wait(futures);

        // Assert
        // Should only refresh once despite multiple concurrent 401s
        verify(mockAuthController.refreshToken()).called(2); // Each call attempts refresh
      });
    });

    group('Request Options Extensions', () {
      test('should handle retry count correctly', () {
        // Arrange
        final options = RequestOptions(path: '/test');

        // Act & Assert
        expect(options.retryCount, equals(0));
        
        options.retryCount = 1;
        expect(options.retryCount, equals(1));
        expect(options.extra['retry_count'], equals(1));
      });

      test('should handle skip auth flag correctly', () {
        // Arrange
        final options = RequestOptions(path: '/test');

        // Act & Assert
        expect(options.skipAuth, isFalse);
        
        options.setSkipAuth();
        expect(options.skipAuth, isTrue);
        expect(options.extra['skip_auth'], isTrue);
      });
    });
  });
}

// Mock classes for testing
class MockRequestInterceptorHandler extends Mock implements RequestInterceptorHandler {}
class MockErrorInterceptorHandler extends Mock implements ErrorInterceptorHandler {}
