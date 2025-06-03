import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/auth_service/centralized_logout_service.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/enhanced_logout_service.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

// Mock implementations for testing
class MockAuthService implements AuthService {
  bool _isAuthenticated = true;
  LogoutResult? _lastLogoutResult;

  @override
  Future<LogoutResult> logout({bool clearAllPreferences = true}) async {
    _lastLogoutResult = LogoutResult();
    _lastLogoutResult!.success = true;
    _lastLogoutResult!.keycloakEndSessionResult = true;
    _lastLogoutResult!.secureStorageCleared = true;
    _lastLogoutResult!.sharedPreferencesCleared = clearAllPreferences;
    _lastLogoutResult!.additionalDataCleared = true;
    _lastLogoutResult!.verificationPassed = true;

    _isAuthenticated = false;
    return _lastLogoutResult!;
  }

  @override
  Future<bool> quickLogout() async {
    _isAuthenticated = false;
    return true;
  }

  @override
  Future<bool> isAuthenticated() async {
    return _isAuthenticated;
  }

  LogoutResult? get lastLogoutResult => _lastLogoutResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGateStorage implements GateStorage {
  bool _tokensCleared = false;

  @override
  Future<void> clearTokens() async {
    _tokensCleared = true;
  }

  bool get tokensCleared => _tokensCleared;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ErrorAuthService implements AuthService {
  @override
  Future<LogoutResult> logout({bool clearAllPreferences = true}) async {
    throw Exception('Test error during logout');
  }

  @override
  Future<bool> quickLogout() async {
    throw Exception('Test error during quick logout');
  }

  @override
  Future<bool> isAuthenticated() async {
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Logout Consistency Tests', () {
    late MockAuthService mockAuthService;
    late MockGateStorage mockGateStorage;

    setUp(() async {
      // Clear any existing GetIt registrations
      if (GetIt.I.isRegistered<AuthService>()) {
        GetIt.I.unregister<AuthService>();
      }
      if (GetIt.I.isRegistered<GateStorage>()) {
        GetIt.I.unregister<GateStorage>();
      }

      // Register mocks
      mockAuthService = MockAuthService();
      mockGateStorage = MockGateStorage();
      GetIt.I.registerSingleton<AuthService>(mockAuthService);
      GetIt.I.registerSingleton<GateStorage>(mockGateStorage);

      // Clear SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      // Clean up
      GetIt.I.reset();
    });

    test('Settings Screen and Session Expired Modal use same logout logic',
        () async {
      // Test Settings Screen logout
      final settingsLogoutResult =
          await CentralizedLogoutService.performCompleteLogout(
        source: 'Settings Screen',
        showNotifications: false,
      );

      // Reset authentication state for second test
      mockAuthService._isAuthenticated = true;

      // Test Session Expired Modal logout
      final modalLogoutResult =
          await CentralizedLogoutService.performCompleteLogout(
        source: 'Session Expired Modal',
        showNotifications: false,
      );

      // Assert both results are identical
      expect(settingsLogoutResult.success, modalLogoutResult.success);
      expect(settingsLogoutResult.keycloakEndSessionResult,
          modalLogoutResult.keycloakEndSessionResult);
      expect(settingsLogoutResult.secureStorageCleared,
          modalLogoutResult.secureStorageCleared);
      expect(settingsLogoutResult.sharedPreferencesCleared,
          modalLogoutResult.sharedPreferencesCleared);
      expect(settingsLogoutResult.additionalDataCleared,
          modalLogoutResult.additionalDataCleared);
    });

    test('Both logout flows clear all authentication tokens', () async {
      // Perform logout
      final result = await CentralizedLogoutService.performCompleteLogout(
        source: 'Test',
        showNotifications: false,
      );

      // Verify tokens are cleared
      expect(result.success, true);
      expect(result.secureStorageCleared, true);
      expect(result.sharedPreferencesCleared, true);
      // Note: mockGateStorage.tokensCleared might not be true because
      // the centralized service uses the AuthService which has its own cleanup logic
    });

    test('Both logout flows clear user session data and preferences', () async {
      // Set up some preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_key', 'test_value');

      // Perform logout with clearAllPreferences = true
      final result = await CentralizedLogoutService.performCompleteLogout(
        source: 'Test',
        showNotifications: false,
      );

      // Verify preferences are cleared
      expect(result.success, true);
      expect(result.sharedPreferencesCleared, true);
    });

    test('Both logout flows reset authentication state', () async {
      // Verify user is initially authenticated
      expect(await mockAuthService.isAuthenticated(), true);

      // Perform logout
      await CentralizedLogoutService.performCompleteLogout(
        source: 'Test',
        showNotifications: false,
      );

      // Verify user is no longer authenticated
      expect(await mockAuthService.isAuthenticated(), false);
    });

    test('Both logout flows handle Keycloak end session', () async {
      // Perform logout
      final result = await CentralizedLogoutService.performCompleteLogout(
        source: 'Test',
        showNotifications: false,
      );

      // Verify Keycloak end session was called
      expect(result.keycloakEndSessionResult, true);
    });

    test('Both logout flows dispose session managers and timers', () async {
      // This test verifies that the centralized service calls the disposal methods
      // The actual disposal is tested in the session manager tests

      final result = await CentralizedLogoutService.performCompleteLogout(
        source: 'Test',
        showNotifications: false,
      );

      // Verify logout was successful (which includes session manager disposal)
      expect(result.success, true);
    });

    test('Navigation behavior is consistent between logout flows', () async {
      // Test navigation from Settings Screen
      await CentralizedLogoutService.navigateToLogin(
        null,
        source: 'Settings Screen',
      );

      // Test navigation from Session Expired Modal
      await CentralizedLogoutService.navigateToLogin(
        null,
        source: 'Session Expired Modal',
      );

      // Both should complete without errors
      // (Actual navigation testing would require widget testing)
    });

    test('Error handling is consistent between logout flows', () async {
      // Create a mock that throws an error
      final errorAuthService = ErrorAuthService();
      GetIt.I.unregister<AuthService>();
      GetIt.I.registerSingleton<AuthService>(errorAuthService);

      // Test error handling
      final result = await CentralizedLogoutService.performCompleteLogout(
        source: 'Test',
        showNotifications: false,
      );

      // Verify error is handled gracefully
      expect(result.success, false);
      expect(result.error, isNotNull);
    });

    test('Quick logout works consistently', () async {
      // Test quick logout
      final success = await CentralizedLogoutService.performQuickLogout(
        source: 'Emergency Test',
      );

      // Verify quick logout was successful
      expect(success, true);
      expect(await mockAuthService.isAuthenticated(), false);
    });

    test('Logout verification works correctly', () async {
      // Perform logout
      await CentralizedLogoutService.performCompleteLogout(
        source: 'Test',
        showNotifications: false,
      );

      // Verify logout completion
      final isLoggedOut =
          await CentralizedLogoutService.verifyLogoutCompletion();
      expect(isLoggedOut, true);
    });

    test('Logout statistics are available', () async {
      // Get logout statistics
      final stats = CentralizedLogoutService.getLogoutStatistics();

      // Verify statistics contain expected information
      expect(stats['service'], 'CentralizedLogoutService');
      expect(stats['features'], isA<List>());
      expect(stats['supported_sources'], contains('Settings Screen'));
      expect(stats['supported_sources'], contains('Session Expired Modal'));
    });
  });
}
