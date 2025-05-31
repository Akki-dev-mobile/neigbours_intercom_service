import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_logout_service.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

// Generate mocks
@GenerateMocks([
  FlutterAppAuth,
  FlutterSecureStorage,
  GateStorage,
])
import 'enhanced_logout_service_test.mocks.dart';

void main() {
  group('EnhancedLogoutService Tests', () {
    late EnhancedLogoutService logoutService;
    late MockFlutterAppAuth mockAppAuth;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockGateStorage mockGateStorage;

    setUpAll(() {
      // Initialize Flutter binding for tests
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      // Create mocks
      mockAppAuth = MockFlutterAppAuth();
      mockSecureStorage = MockFlutterSecureStorage();
      mockGateStorage = MockGateStorage();

      // Get singleton instance
      logoutService = EnhancedLogoutService();

      // Setup SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
    });

    group('Complete Logout Flow', () {
      testWidgets('should perform complete logout successfully',
          (WidgetTester tester) async {
        // Setup mocks
        when(mockSecureStorage.read(key: 'id_token_secure'))
            .thenAnswer((_) async => 'mock_id_token');
        when(mockSecureStorage.read(key: 'refresh_token_secure'))
            .thenAnswer((_) async => 'mock_refresh_token');

        when(mockAppAuth.endSession(any))
            .thenAnswer((_) async => EndSessionResponse(null));

        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});

        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});
        when(mockGateStorage.clearStorage(any)).thenAnswer((_) async {});

        // Perform logout
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: true,
        );

        // Verify results
        expect(result.success, isTrue);
        expect(result.keycloakEndSessionResult, isTrue);
        expect(result.secureStorageCleared, isTrue);
        expect(result.sharedPreferencesCleared, isTrue);
        expect(result.additionalDataCleared, isTrue);

        // Verify method calls
        verify(mockAppAuth.endSession(any)).called(1);
        verify(mockSecureStorage.deleteAll()).called(1);
        verify(mockGateStorage.clearTokens()).called(1);
      });

      testWidgets('should handle Keycloak end session failure gracefully',
          (WidgetTester tester) async {
        // Setup mocks - Keycloak end session fails
        when(mockSecureStorage.read(key: 'id_token_secure'))
            .thenAnswer((_) async => 'mock_id_token');

        when(mockAppAuth.endSession(any))
            .thenThrow(Exception('Keycloak end session failed'));

        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});

        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});
        when(mockGateStorage.clearStorage(any)).thenAnswer((_) async {});

        // Perform logout
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: true,
        );

        // Should still succeed overall even if Keycloak end session fails
        expect(result.success, isTrue);
        expect(result.keycloakEndSessionResult, isFalse);
        expect(result.secureStorageCleared, isTrue);
        expect(result.sharedPreferencesCleared, isTrue);
        expect(result.additionalDataCleared, isTrue);
      });

      testWidgets('should handle missing ID token',
          (WidgetTester tester) async {
        // Setup mocks - no ID token available
        when(mockSecureStorage.read(key: 'id_token_secure'))
            .thenAnswer((_) async => null);

        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});

        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});
        when(mockGateStorage.clearStorage(any)).thenAnswer((_) async {});

        // Perform logout
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: true,
        );

        // Should succeed but skip Keycloak end session
        expect(result.success, isTrue);
        expect(result.keycloakEndSessionResult, isFalse);
        expect(result.secureStorageCleared, isTrue);

        // Verify Keycloak end session was not called
        verifyNever(mockAppAuth.endSession(any));
      });
    });

    group('Storage Clearing', () {
      testWidgets('should clear all secure storage',
          (WidgetTester tester) async {
        // Setup mocks
        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});

        // Test secure storage clearing
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: true,
        );

        // Verify secure storage operations
        verify(mockSecureStorage.deleteAll()).called(1);
        expect(result.secureStorageCleared, isTrue);
      });

      testWidgets('should clear SharedPreferences selectively',
          (WidgetTester tester) async {
        // Setup SharedPreferences with test data
        SharedPreferences.setMockInitialValues({
          'access_token': 'test_token',
          'user_id': 'test_user',
          'some_other_pref': 'keep_this',
        });

        // Setup other mocks
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});
        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});
        when(mockGateStorage.clearStorage(any)).thenAnswer((_) async {});

        // Perform logout with selective clearing
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: false, // Selective clearing
        );

        expect(result.sharedPreferencesCleared, isTrue);
      });

      testWidgets('should clear all SharedPreferences when requested',
          (WidgetTester tester) async {
        // Setup SharedPreferences with test data
        SharedPreferences.setMockInitialValues({
          'access_token': 'test_token',
          'user_id': 'test_user',
          'some_other_pref': 'should_be_cleared',
        });

        // Setup other mocks
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});
        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});
        when(mockGateStorage.clearStorage(any)).thenAnswer((_) async {});

        // Perform logout with complete clearing
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: true, // Complete clearing
        );

        expect(result.sharedPreferencesCleared, isTrue);
      });
    });

    group('Quick Logout', () {
      testWidgets('should perform quick logout successfully',
          (WidgetTester tester) async {
        // Setup mocks
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});

        // Setup SharedPreferences
        SharedPreferences.setMockInitialValues({
          'access_token': 'test_token',
          'user_id': 'test_user',
        });

        // Perform quick logout
        final result = await logoutService.performQuickLogout();

        expect(result, isTrue);
        verify(mockSecureStorage.deleteAll()).called(1);
      });

      testWidgets('should handle quick logout errors',
          (WidgetTester tester) async {
        // Setup mocks to throw error
        when(mockSecureStorage.deleteAll())
            .thenThrow(Exception('Storage error'));

        // Perform quick logout
        final result = await logoutService.performQuickLogout();

        expect(result, isFalse);
      });
    });

    group('Verification', () {
      testWidgets('should verify complete cleanup correctly',
          (WidgetTester tester) async {
        // Setup mocks for successful cleanup
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);
        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});
        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});
        when(mockGateStorage.clearStorage(any)).thenAnswer((_) async {});

        // Setup clean SharedPreferences
        SharedPreferences.setMockInitialValues({});

        // Perform logout
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: true,
        );

        expect(result.verificationPassed, isTrue);
      });

      testWidgets('should detect incomplete cleanup',
          (WidgetTester tester) async {
        // Setup mocks with remaining tokens
        when(mockSecureStorage.read(key: 'access_token_secure'))
            .thenAnswer((_) async => 'remaining_token');
        when(mockSecureStorage.read(key: 'refresh_token_secure'))
            .thenAnswer((_) async => null);
        when(mockSecureStorage.read(key: 'id_token_secure'))
            .thenAnswer((_) async => null);

        when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});
        when(mockGateStorage.clearTokens()).thenAnswer((_) async {});
        when(mockGateStorage.clearStorage(any)).thenAnswer((_) async {});

        // Setup clean SharedPreferences
        SharedPreferences.setMockInitialValues({});

        // Perform logout
        final result = await logoutService.performCompleteLogout(
          showNotifications: false,
          clearAllPreferences: true,
        );

        expect(result.verificationPassed, isFalse);
      });
    });

    group('LogoutResult', () {
      test('should identify issues correctly', () {
        final result = LogoutResult();
        result.success = false;
        result.keycloakEndSessionResult = false;
        result.secureStorageCleared = true;
        result.sharedPreferencesCleared = false;
        result.additionalDataCleared = true;
        result.verificationPassed = false;
        result.error = 'Test error';

        final issues = result.getIssues();

        expect(issues, contains('Keycloak end session failed or skipped'));
        expect(issues, contains('SharedPreferences clearing failed'));
        expect(issues, contains('Cleanup verification failed'));
        expect(issues, contains('Error occurred: Test error'));
      });

      test('should check complete success correctly', () {
        final successResult = LogoutResult();
        successResult.success = true;
        successResult.keycloakEndSessionResult = true;
        successResult.verificationPassed = true;

        expect(successResult.isCompleteSuccess, isTrue);

        final partialResult = LogoutResult();
        partialResult.success = true;
        partialResult.keycloakEndSessionResult = false;
        partialResult.verificationPassed = true;

        expect(partialResult.isCompleteSuccess, isFalse);
      });
    });
  });
}
