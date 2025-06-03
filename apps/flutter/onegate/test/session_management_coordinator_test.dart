import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

// Mock GateStorage for testing
class MockGateStorage implements GateStorage {
  String? _accessToken;
  bool _isTokenExpired = false;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void setTokenExpired(bool expired) {
    _isTokenExpired = expired;
  }

  @override
  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  @override
  Future<bool> isTokenExpired() async {
    return _isTokenExpired;
  }

  // Implement other required methods with default behavior
  @override
  Future<void> init() async {}

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveAccessToken(String token) async {}

  @override
  Future<void> saveRefreshToken(String token) async {}

  @override
  Future<void> saveTokenExpiry(DateTime expiryTime) async {}

  @override
  Future<void> saveUserId(String userId) async {}

  @override
  Future<String?> getUserId() async => null;

  @override
  Future<void> saveUsername(String username) async {}

  @override
  Future<String?> getUsername() async => null;

  @override
  Future<void> saveRole(String role) async {}

  @override
  Future<String?> getRole() async => null;

  @override
  Future<void> saveSocietyId(String societyId) async {}

  @override
  Future<String?> getSocietyId() async => null;

  @override
  Future<void> clearTokens() async {}

  @override
  Future<void> saveUserEmail(String email) async {}

  @override
  Future<String?> getUserEmail() async => null;

  @override
  Future<void> saveUserFullName(String fullName) async {}

  @override
  Future<String?> getUserFullName() async => null;

  @override
  Future<void> saveUserRoles(List<String> roles) async {}

  @override
  Future<List<String>> getUserRoles() async => [];

  @override
  Future<void> saveSessionTimestamp(DateTime timestamp) async {}

  @override
  Future<DateTime?> getSessionTimestamp() async => null;

  @override
  Future<void> saveSocietyDetails(
      String societyId, String? societyName) async {}

  @override
  Future<Map> getSocietyDetails() async => {};

  @override
  Future<void> saveMemberDetails(Map<String, dynamic> memberDetails) async {}

  @override
  Future<Map<String, dynamic>?> getMemberDetails() async => null;

  @override
  Future<void> clearStorage(String key) async {}

  @override
  Future<void> saveVisitorLogId(String visitorLogId) async {}

  @override
  Future<String?> getVisitorLogId() async => null;

  @override
  Future<void> clearVisitorLogId() async {}

  @override
  Future<void> saveImage(String image) async {}

  @override
  Future<String?> getImage() async => null;

  @override
  Future<void> clearVisitorImage() async {}

  @override
  Future<void> setComingFrom(String comingFrom) async {}

  @override
  Future<String?> getComingFrom() async => null;

  @override
  Future<void> removeComingFrom() async {}

  @override
  bool? getTooglevalue(String key) => null;

  @override
  Future<void> setToogleValue(String key, bool value) async {}

  @override
  Future<void> saveMemberList(List<dynamic> memberList) async {}

  @override
  Future<List<dynamic>?> getMemberList() async => null;

  @override
  Future<void> saveMemberApproval(bool approval) async {}

  @override
  Future<bool?> getMemberApproval() async => null;

  @override
  Future<void> saveSelectedGate(
      String gateName, String gateId, String gateType) async {}

  @override
  Future<Map<String, String?>> getSelectedGate() async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SessionManagementCoordinator Tests', () {
    late MockGateStorage mockGateStorage;

    setUp(() async {
      // Clear any existing GetIt registrations
      if (GetIt.I.isRegistered<GateStorage>()) {
        GetIt.I.unregister<GateStorage>();
      }

      // Register mock
      mockGateStorage = MockGateStorage();
      GetIt.I.registerSingleton<GateStorage>(mockGateStorage);

      // Clear SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      // Clean up
      SessionManagementCoordinator.dispose();
      GetIt.I.reset();
    });

    test('should block session expired modal when on login screen', () async {
      // Arrange: Set up login screen state (no access token)
      mockGateStorage.setAccessToken(null);

      // Initialize coordinator
      await SessionManagementCoordinator.initialize();

      // Wait a moment for the coordinator to detect login state
      await Future.delayed(const Duration(milliseconds: 100));

      // Act: Check if session expired modal should be shown
      final shouldShow =
          await SessionManagementCoordinator.shouldShowSessionExpiredModal();

      // Assert: Modal should be blocked
      expect(shouldShow, false);
    });

    test('should allow session expired modal when not on login screen',
        () async {
      // Arrange: Set up authenticated state (has access token, not expired)
      mockGateStorage.setAccessToken('valid_token');
      mockGateStorage.setTokenExpired(false);

      // Initialize coordinator
      await SessionManagementCoordinator.initialize();

      // Wait a moment for the coordinator to detect state
      await Future.delayed(const Duration(milliseconds: 100));

      // Act: Check if session expired modal should be shown
      final shouldShow =
          await SessionManagementCoordinator.shouldShowSessionExpiredModal();

      // Assert: Modal should be allowed (assuming continuous session is not active)
      expect(shouldShow, true);
    });

    test('should pause session monitoring when on login screen', () async {
      // Arrange: Set up login screen state
      mockGateStorage.setAccessToken(null);

      // Initialize coordinator
      await SessionManagementCoordinator.initialize();

      // Wait a moment for the coordinator to detect login state
      await Future.delayed(const Duration(milliseconds: 100));

      // Act: Check if session monitoring should be paused
      final shouldPause =
          await SessionManagementCoordinator.shouldPauseSessionMonitoring();

      // Assert: Monitoring should be paused
      expect(shouldPause, true);
    });

    test('should not pause session monitoring when authenticated', () async {
      // Arrange: Set up authenticated state
      mockGateStorage.setAccessToken('valid_token');
      mockGateStorage.setTokenExpired(false);

      // Initialize coordinator
      await SessionManagementCoordinator.initialize();

      // Wait a moment for the coordinator to detect state
      await Future.delayed(const Duration(milliseconds: 100));

      // Act: Check if session monitoring should be paused
      final shouldPause =
          await SessionManagementCoordinator.shouldPauseSessionMonitoring();

      // Assert: Monitoring should not be paused
      expect(shouldPause, false);
    });

    test('should apply emergency login fix correctly', () async {
      // Act: Apply emergency fix
      await SessionManagementCoordinator.applyEmergencyLoginFix();

      // Assert: Check that the correct preferences are set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('session_expired_modal_disabled'), true);
      expect(prefs.getBool('session_monitoring_paused'), true);
      expect(prefs.getBool('token_refresh_paused'), true);
      expect(prefs.getBool('login_screen_aware_session_management'), true);
      expect(prefs.getBool('prevent_session_modal_during_login'), true);
    });

    test('should track navigation to login state', () async {
      // Act: Set navigation to login
      SessionManagementCoordinator.setNavigatingToLogin(true);

      // Assert: Check that modal is blocked during navigation
      final shouldShow =
          await SessionManagementCoordinator.shouldShowSessionExpiredModal();
      expect(shouldShow, false);

      // Act: Clear navigation state
      SessionManagementCoordinator.setNavigatingToLogin(false);

      // Assert: Check that modal can be shown again (if other conditions allow)
      mockGateStorage.setAccessToken('valid_token');
      final shouldShowAfter =
          await SessionManagementCoordinator.shouldShowSessionExpiredModal();
      expect(shouldShowAfter, true);
    });

    test('should respect continuous session mode', () async {
      // Arrange: Enable continuous session mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('continuous_session_active', true);

      // Set up authenticated state
      mockGateStorage.setAccessToken('valid_token');
      mockGateStorage.setTokenExpired(false);

      // Act: Check if session expired modal should be shown
      final shouldShow =
          await SessionManagementCoordinator.shouldShowSessionExpiredModal();

      // Assert: Modal should be blocked due to continuous session
      expect(shouldShow, false);
    });

    test('should handle initialization and disposal correctly', () async {
      // Act: Initialize
      await SessionManagementCoordinator.initialize();

      // Assert: Should be initialized
      expect(SessionManagementCoordinator.isOnLoginScreen, isA<bool>());

      // Act: Dispose
      SessionManagementCoordinator.dispose();

      // Assert: Should handle disposal without errors
      expect(() => SessionManagementCoordinator.dispose(), returnsNormally);
    });
  });
}
