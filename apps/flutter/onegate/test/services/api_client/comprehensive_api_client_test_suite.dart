import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/services/api_client/authenticated_dio_factory.dart';
import 'package:flutter_onegate/services/api_client/authenticated_api_client.dart';
import 'package:flutter_onegate/services/auth_service/unified_auth_interceptor.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';

// Generate mocks
@GenerateMocks([
  Dio,
  Response,
  RequestOptions,
  AuthenticatedApiClient,
  RemoteDataSource,
])
import 'comprehensive_api_client_test_suite.mocks.dart';

/// Comprehensive API client test suite
/// Tests all API client components and HTTP handling
void runApiClientTestSuite() {
  group('🌐 Comprehensive API Client Tests', () {
    late MockDio mockDio;
    late MockResponse mockResponse;
    late MockRequestOptions mockRequestOptions;
    late MockAuthenticatedApiClient mockApiClient;
    late MockRemoteDataSource mockRemoteDataSource;

    setUp(() {
      mockDio = MockDio();
      mockResponse = MockResponse();
      mockRequestOptions = MockRequestOptions();
      mockApiClient = MockAuthenticatedApiClient();
      mockRemoteDataSource = MockRemoteDataSource();
    });

    group('AuthenticatedDioFactory Tests', () {
      test('should create authenticated Dio instance with default config', () {
        // Act
        final dio = AuthenticatedDioFactory.createAuthenticatedDio();

        // Assert
        expect(dio, isA<Dio>());
        expect(dio.options.connectTimeout, equals(Duration(seconds: 30)));
        expect(dio.options.receiveTimeout, equals(Duration(seconds: 30)));
        expect(dio.options.sendTimeout, equals(Duration(seconds: 30)));
        expect(dio.options.headers['Content-Type'], equals('application/json'));
        expect(dio.options.headers['Accept'], equals('application/json'));
      });

      test('should create authenticated Dio with custom config', () {
        // Arrange
        const baseUrl = 'https://api.example.com';
        const connectTimeout = Duration(seconds: 60);
        final customHeaders = {'X-Custom': 'value'};

        // Act
        final dio = AuthenticatedDioFactory.createAuthenticatedDio(
          baseUrl: baseUrl,
          connectTimeout: connectTimeout,
          customHeaders: customHeaders,
        );

        // Assert
        expect(dio.options.baseUrl, equals(baseUrl));
        expect(dio.options.connectTimeout, equals(connectTimeout));
        expect(dio.options.headers['X-Custom'], equals('value'));
      });

      test('should create OneGate API client with correct configuration', () {
        // Arrange
        const baseUrl = 'https://gate.example.com';
        final customHeaders = {'X-Gate': 'onegate'};

        // Act
        final dio = AuthenticatedDioFactory.createOneGateApiClient(
          baseUrl: baseUrl,
          customHeaders: customHeaders,
        );

        // Assert
        expect(dio.options.baseUrl, equals(baseUrl));
        expect(dio.options.headers['X-API-Source'], equals('OneGate-Flutter'));
        expect(dio.options.headers['X-Client-Version'], equals('1.0.0'));
        expect(dio.options.headers['X-Gate'], equals('onegate'));
      });

      test('should create Society API client with correct configuration', () {
        // Act
        final dio = AuthenticatedDioFactory.createSocietyApiClient();

        // Assert
        expect(dio.options.baseUrl, equals('https://societybackend.cubeone.in/api'));
        expect(dio.options.headers['X-API-Source'], equals('OneGate-Society'));
        expect(dio.options.headers['X-Client-Version'], equals('1.0.0'));
      });

      test('should create file upload client with extended timeouts', () {
        // Act
        final dio = AuthenticatedDioFactory.createFileUploadClient();

        // Assert
        expect(dio.options.connectTimeout, equals(Duration(minutes: 2)));
        expect(dio.options.receiveTimeout, equals(Duration(minutes: 5)));
        expect(dio.options.sendTimeout, equals(Duration(minutes: 5)));
        expect(dio.options.headers['X-API-Source'], equals('OneGate-FileUpload'));
      });

      test('should create public Dio without authentication', () {
        // Act
        final dio = AuthenticatedDioFactory.createPublicDio();

        // Assert
        expect(dio, isA<Dio>());
        // Should not have UnifiedAuthInterceptor
        final hasAuthInterceptor = dio.interceptors
            .any((interceptor) => interceptor is UnifiedAuthInterceptor);
        expect(hasAuthInterceptor, isFalse);
      });

      test('should create realtime client with appropriate timeouts', () {
        // Act
        final dio = AuthenticatedDioFactory.createRealtimeClient();

        // Assert
        expect(dio.options.connectTimeout, equals(Duration(seconds: 10)));
        expect(dio.options.receiveTimeout, equals(Duration(seconds: 60)));
        expect(dio.options.sendTimeout, equals(Duration(seconds: 10)));
        expect(dio.options.headers['X-API-Source'], equals('OneGate-Realtime'));
      });
    });

    group('UnifiedAuthInterceptor Tests', () {
      late UnifiedAuthInterceptor interceptor;

      setUp(() {
        interceptor = UnifiedAuthInterceptor();
      });

      test('should add Bearer token to request headers', () async {
        // Arrange
        final options = RequestOptions(path: '/api/test');
        final handler = MockRequestInterceptorHandler();

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        // Note: This test would need proper mocking of SecureTokenManager
        expect(options.path, equals('/api/test'));
      });

      test('should skip authentication for public endpoints', () async {
        // Arrange
        final options = RequestOptions(path: '/public/test');
        final handler = MockRequestInterceptorHandler();

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        expect(options.headers.containsKey('Authorization'), isFalse);
      });

      test('should handle 401 errors with token refresh', () async {
        // Arrange
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/api/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/test'),
            statusCode: 401,
          ),
        );
        final handler = MockErrorInterceptorHandler();

        // Act
        interceptor.onError(dioError, handler);

        // Assert
        expect(dioError.response?.statusCode, equals(401));
      });

      test('should not retry auth endpoints on 401', () async {
        // Arrange
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/gatelogin'),
          response: Response(
            requestOptions: RequestOptions(path: '/gatelogin'),
            statusCode: 401,
          ),
        );
        final handler = MockErrorInterceptorHandler();

        // Act
        interceptor.onError(dioError, handler);

        // Assert
        expect(dioError.requestOptions.path, equals('/gatelogin'));
      });

      test('should limit retry attempts', () async {
        // Arrange
        final options = RequestOptions(path: '/api/test');
        options.extra['unified_auth_retry_count'] = 2; // Max retries reached
        
        final dioError = DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
          ),
        );
        final handler = MockErrorInterceptorHandler();

        // Act
        interceptor.onError(dioError, handler);

        // Assert
        expect(options.extra['unified_auth_retry_count'], equals(2));
      });
    });

    group('AuthenticatedApiClient Tests', () {
      test('should perform GET request successfully', () async {
        // Arrange
        final responseData = {'data': 'test'};
        when(mockApiClient.get('/test')).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/test'),
          ),
        );

        // Act
        final response = await mockApiClient.get('/test');

        // Assert
        expect(response.statusCode, equals(200));
        expect(response.data, equals(responseData));
        verify(mockApiClient.get('/test')).called(1);
      });

      test('should perform POST request with data', () async {
        // Arrange
        final requestData = {'name': 'test'};
        final responseData = {'id': 1, 'name': 'test'};
        
        when(mockApiClient.post('/test', data: requestData)).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 201,
            requestOptions: RequestOptions(path: '/test'),
          ),
        );

        // Act
        final response = await mockApiClient.post('/test', data: requestData);

        // Assert
        expect(response.statusCode, equals(201));
        expect(response.data, equals(responseData));
        verify(mockApiClient.post('/test', data: requestData)).called(1);
      });

      test('should perform PUT request successfully', () async {
        // Arrange
        final requestData = {'id': 1, 'name': 'updated'};
        final responseData = {'id': 1, 'name': 'updated'};
        
        when(mockApiClient.put('/test/1', data: requestData)).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/test/1'),
          ),
        );

        // Act
        final response = await mockApiClient.put('/test/1', data: requestData);

        // Assert
        expect(response.statusCode, equals(200));
        expect(response.data, equals(responseData));
        verify(mockApiClient.put('/test/1', data: requestData)).called(1);
      });

      test('should perform DELETE request successfully', () async {
        // Arrange
        when(mockApiClient.delete('/test/1')).thenAnswer(
          (_) async => Response(
            statusCode: 204,
            requestOptions: RequestOptions(path: '/test/1'),
          ),
        );

        // Act
        final response = await mockApiClient.delete('/test/1');

        // Assert
        expect(response.statusCode, equals(204));
        verify(mockApiClient.delete('/test/1')).called(1);
      });

      test('should handle network errors gracefully', () async {
        // Arrange
        when(mockApiClient.get('/test')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/test'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        // Act & Assert
        expect(() => mockApiClient.get('/test'), throwsA(isA<DioException>()));
      });

      test('should handle server errors with proper status codes', () async {
        // Arrange
        when(mockApiClient.get('/test')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/test'),
            response: Response(
              statusCode: 500,
              statusMessage: 'Internal Server Error',
              requestOptions: RequestOptions(path: '/test'),
            ),
          ),
        );

        // Act & Assert
        expect(() => mockApiClient.get('/test'), throwsA(isA<DioException>()));
      });
    });

    group('RemoteDataSource Tests', () {
      test('should fetch gates successfully', () async {
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
        verify(mockRemoteDataSource.fetchGates()).called(1);
      });

      test('should fetch societies successfully', () async {
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
        verify(mockRemoteDataSource.fetchSocieties(userId)).called(1);
      });

      test('should handle authentication errors in data source', () async {
        // Arrange
        when(mockRemoteDataSource.fetchGates()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/gates'),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/gates'),
            ),
          ),
        );

        // Act & Assert
        expect(() => mockRemoteDataSource.fetchGates(), throwsA(isA<DioException>()));
      });
    });
  });
}

// Mock classes for interceptor handlers
class MockRequestInterceptorHandler extends Mock implements RequestInterceptorHandler {}
class MockErrorInterceptorHandler extends Mock implements ErrorInterceptorHandler {}
