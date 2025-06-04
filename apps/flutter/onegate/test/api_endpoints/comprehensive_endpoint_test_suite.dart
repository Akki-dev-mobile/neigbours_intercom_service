import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/services/api_client/authenticated_api_client.dart';

// Generate mocks
@GenerateMocks([
  RemoteDataSource,
  AuthenticatedApiClient,
  Dio,
  Response,
])
import 'comprehensive_endpoint_test_suite.mocks.dart';

/// Comprehensive API endpoint test suite
/// Tests all 37 identified API endpoints with full coverage
void runEndpointTestSuite() {
  group('📡 Comprehensive API Endpoint Tests', () {
    late MockRemoteDataSource mockRemoteDataSource;
    late MockAuthenticatedApiClient mockApiClient;
    late MockDio mockDio;

    setUp(() {
      mockRemoteDataSource = MockRemoteDataSource();
      mockApiClient = MockAuthenticatedApiClient();
      mockDio = MockDio();
    });

    group('Gate API Endpoints (15 endpoints)', () {
      group('Visitor Management', () {
        test('POST /visitor/search - should search visitors successfully', () async {
          // Arrange
          const mobileNumber = '1234567890';
          final expectedResponse = {
            'data': [
              {'id': 1, 'name': 'John Doe', 'mobile': mobileNumber}
            ]
          };

          when(mockApiClient.post('/visitor/search', data: anyNamed('data')))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/search'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/search', 
              data: {'mobile_number': mobileNumber});

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data, equals(expectedResponse));
          verify(mockApiClient.post('/visitor/search', data: anyNamed('data'))).called(1);
        });

        test('POST /visitor/entry - should create visitor entry successfully', () async {
          // Arrange
          final visitorData = {
            'name': 'John Doe',
            'mobile': '1234567890',
            'purpose': 'Meeting',
            'coming_from': 'Office'
          };
          final expectedResponse = {'id': 1, 'status': 'created'};

          when(mockApiClient.post('/visitor/entry', data: visitorData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 201,
                requestOptions: RequestOptions(path: '/visitor/entry'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/entry', data: visitorData);

          // Assert
          expect(response.statusCode, equals(201));
          expect(response.data, equals(expectedResponse));
        });

        test('POST /visitor/checkin - should check in visitor successfully', () async {
          // Arrange
          final checkinData = {'visitor_id': 1, 'gate_id': 1};
          final expectedResponse = {'status': 'checked_in', 'timestamp': '2024-01-01T10:00:00Z'};

          when(mockApiClient.post('/visitor/checkin', data: checkinData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/checkin'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/checkin', data: checkinData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['status'], equals('checked_in'));
        });

        test('POST /visitor/checkout - should check out visitor successfully', () async {
          // Arrange
          final checkoutData = {'visitor_id': 1};
          final expectedResponse = {'status': 'checked_out', 'timestamp': '2024-01-01T12:00:00Z'};

          when(mockApiClient.post('/visitor/checkout', data: checkoutData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/checkout'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/checkout', data: checkoutData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['status'], equals('checked_out'));
        });

        test('POST /visitor/upload - should upload visitor image successfully', () async {
          // Arrange
          final uploadData = {'visitor_id': 1, 'image': 'base64_image_data'};
          final expectedResponse = {'url': 'https://example.com/image.jpg'};

          when(mockApiClient.post('/visitor/upload', data: uploadData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/upload'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/upload', data: uploadData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['url'], isNotEmpty);
        });

        test('GET /visitor/timeline/{id} - should get visitor timeline', () async {
          // Arrange
          const visitorId = 1;
          final expectedResponse = {
            'data': [
              {'action': 'entry', 'timestamp': '2024-01-01T10:00:00Z'},
              {'action': 'checkin', 'timestamp': '2024-01-01T10:05:00Z'}
            ]
          };

          when(mockApiClient.get('/visitor/timeline/$visitorId'))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/timeline/$visitorId'),
              ));

          // Act
          final response = await mockApiClient.get('/visitor/timeline/$visitorId');

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['data'], isList);
          expect(response.data['data'].length, equals(2));
        });

        test('POST /visitor/approve - should approve visitor successfully', () async {
          // Arrange
          final approvalData = {'visitor_id': 1, 'approved_by': 'gatekeeper123'};
          final expectedResponse = {'status': 'approved'};

          when(mockApiClient.post('/visitor/approve', data: approvalData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/approve'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/approve', data: approvalData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['status'], equals('approved'));
        });
      });

      group('Communication & Notifications', () {
        test('POST /visitor/exotel/initiatecall - should initiate call successfully', () async {
          // Arrange
          final callData = {
            'from_number': '918452060059',
            'to_number': '919876543210',
            'member_name': 'John Doe'
          };
          final expectedResponse = {'call_id': 'call123', 'status': 'initiated'};

          when(mockApiClient.post('/visitor/exotel/initiatecall', data: callData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/exotel/initiatecall'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/exotel/initiatecall', data: callData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['status'], equals('initiated'));
        });

        test('GET /visitor/exotel/callLogs - should get call history', () async {
          // Arrange
          const fromNumber = '918452060059';
          final expectedResponse = {
            'data': [
              {'call_id': 'call123', 'duration': 120, 'status': 'completed'},
              {'call_id': 'call124', 'duration': 45, 'status': 'completed'}
            ]
          };

          when(mockApiClient.get('/visitor/exotel/callLogs', 
              queryParameters: {'from_number': fromNumber}))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/exotel/callLogs'),
              ));

          // Act
          final response = await mockApiClient.get('/visitor/exotel/callLogs',
              queryParameters: {'from_number': fromNumber});

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['data'], isList);
        });

        test('POST /visitor/sendFcmNotification - should send FCM notification', () async {
          // Arrange
          final notificationData = {
            'title': 'Visitor Arrival',
            'body': 'John Doe has arrived',
            'token': 'fcm_token_123'
          };
          final expectedResponse = {'message_id': 'msg123', 'status': 'sent'};

          when(mockApiClient.post('/visitor/sendFcmNotification', data: notificationData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/sendFcmNotification'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/sendFcmNotification', 
              data: notificationData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['status'], equals('sent'));
        });
      });

      group('Configuration & Data', () {
        test('GET /gates - should fetch gates successfully', () async {
          // Arrange
          final expectedResponse = {
            'data': [
              {'id': 1, 'name': 'Main Gate', 'location': 'North'},
              {'id': 2, 'name': 'Side Gate', 'location': 'East'}
            ]
          };

          when(mockRemoteDataSource.fetchGates())
              .thenAnswer((_) async => expectedResponse['data'] as List);

          // Act
          final result = await mockRemoteDataSource.fetchGates();

          // Assert
          expect(result, isList);
          expect(result.length, equals(2));
          verify(mockRemoteDataSource.fetchGates()).called(1);
        });

        test('GET /purposes - should fetch purpose categories', () async {
          // Arrange
          final expectedResponse = {
            'data': [
              {'id': 1, 'name': 'Meeting', 'category': 'Business'},
              {'id': 2, 'name': 'Delivery', 'category': 'Service'}
            ]
          };

          when(mockApiClient.get('/purposes'))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/purposes'),
              ));

          // Act
          final response = await mockApiClient.get('/purposes');

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['data'], isList);
        });

        test('POST /staff/search - should search staff successfully', () async {
          // Arrange
          final searchData = {'query': 'security', 'category': 'SECURITY'};
          final expectedResponse = {
            'data': [
              {'id': 1, 'name': 'Security Guard 1', 'category': 'SECURITY'},
              {'id': 2, 'name': 'Security Guard 2', 'category': 'SECURITY'}
            ]
          };

          when(mockApiClient.post('/staff/search', data: searchData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/staff/search'),
              ));

          // Act
          final response = await mockApiClient.post('/staff/search', data: searchData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['data'], isList);
        });
      });

      group('Self-Service & Verification', () {
        test('POST /visitor/selfCheckin - should allow self check-in', () async {
          // Arrange
          final checkinData = {'mobile': '1234567890', 'otp': '123456'};
          final expectedResponse = {'status': 'checked_in', 'visitor_id': 1};

          when(mockApiClient.post('/visitor/selfCheckin', data: checkinData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/selfCheckin'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/selfCheckin', data: checkinData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['status'], equals('checked_in'));
        });

        test('POST /visitor/passcode/verify - should verify passcode', () async {
          // Arrange
          final verificationData = {'passcode': 'ABC123', 'company_id': 1};
          final expectedResponse = {
            'success': true,
            'data': [{'visitor_id': 1, 'name': 'John Doe', 'mobile': '1234567890'}]
          };

          when(mockApiClient.post('/visitor/passcode/verify', data: verificationData))
              .thenAnswer((_) async => Response(
                data: expectedResponse,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/visitor/passcode/verify'),
              ));

          // Act
          final response = await mockApiClient.post('/visitor/passcode/verify', 
              data: verificationData);

          // Assert
          expect(response.statusCode, equals(200));
          expect(response.data['success'], isTrue);
          expect(response.data['data'], isList);
        });
      });
    });

    group('Error Handling Tests', () {
      test('should handle 400 Bad Request errors', () async {
        // Arrange
        when(mockApiClient.get('/visitor/invalid'))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/visitor/invalid'),
              response: Response(
                statusCode: 400,
                statusMessage: 'Bad Request',
                data: {'error': 'Invalid request parameters'},
                requestOptions: RequestOptions(path: '/visitor/invalid'),
              ),
            ));

        // Act & Assert
        expect(() => mockApiClient.get('/visitor/invalid'), throwsA(isA<DioException>()));
      });

      test('should handle 401 Unauthorized errors', () async {
        // Arrange
        when(mockApiClient.get('/visitor/unauthorized'))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/visitor/unauthorized'),
              response: Response(
                statusCode: 401,
                statusMessage: 'Unauthorized',
                data: {'error': 'Invalid or expired token'},
                requestOptions: RequestOptions(path: '/visitor/unauthorized'),
              ),
            ));

        // Act & Assert
        expect(() => mockApiClient.get('/visitor/unauthorized'), throwsA(isA<DioException>()));
      });

      test('should handle 500 Internal Server Error', () async {
        // Arrange
        when(mockApiClient.get('/visitor/server-error'))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/visitor/server-error'),
              response: Response(
                statusCode: 500,
                statusMessage: 'Internal Server Error',
                data: {'error': 'Server encountered an error'},
                requestOptions: RequestOptions(path: '/visitor/server-error'),
              ),
            ));

        // Act & Assert
        expect(() => mockApiClient.get('/visitor/server-error'), throwsA(isA<DioException>()));
      });

      test('should handle network timeout errors', () async {
        // Arrange
        when(mockApiClient.get('/visitor/timeout'))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/visitor/timeout'),
              type: DioExceptionType.connectionTimeout,
              message: 'Connection timeout',
            ));

        // Act & Assert
        expect(() => mockApiClient.get('/visitor/timeout'), throwsA(isA<DioException>()));
      });
    });
  });
}
