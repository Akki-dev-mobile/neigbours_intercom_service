import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/services/auth_service/indefinite_session_manager.dart';

void main() {
  group('IndefiniteSessionManager', () {
    late IndefiniteSessionManager sessionManager;

    setUp(() {
      sessionManager = IndefiniteSessionManager();
    });

    tearDown(() {
      sessionManager.dispose();
    });

    group('Initialization', () {
      test('should initialize without errors', () {
        expect(() => IndefiniteSessionManager(), returnsNormally);
      });

      test('should be disabled by default', () {
        final status = sessionManager.getSessionStatus();
        expect(status['indefinite_sessions_enabled'], isFalse);
        expect(status['consecutive_failures'], equals(0));
        expect(status['background_refresh_active'], isFalse);
      });
    });

    group('Session Management', () {
      test('should enable indefinite sessions', () async {
        await sessionManager.enableIndefiniteSessions();
        
        final status = sessionManager.getSessionStatus();
        expect(status['indefinite_sessions_enabled'], isTrue);
        expect(status['consecutive_failures'], equals(0));
      });

      test('should disable indefinite sessions', () async {
        await sessionManager.enableIndefiniteSessions();
        sessionManager.disableIndefiniteSessions();
        
        final status = sessionManager.getSessionStatus();
        expect(status['indefinite_sessions_enabled'], isFalse);
        expect(status['background_refresh_active'], isFalse);
      });

      test('should handle multiple enable calls gracefully', () async {
        await sessionManager.enableIndefiniteSessions();
        await sessionManager.enableIndefiniteSessions();
        await sessionManager.enableIndefiniteSessions();
        
        final status = sessionManager.getSessionStatus();
        expect(status['indefinite_sessions_enabled'], isTrue);
      });
    });

    group('Session Status', () {
      test('should return correct session status', () {
        final status = sessionManager.getSessionStatus();
        
        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('indefinite_sessions_enabled'), isTrue);
        expect(status.containsKey('consecutive_failures'), isTrue);
        expect(status.containsKey('background_refresh_active'), isTrue);
        expect(status.containsKey('next_refresh_in_seconds'), isTrue);
      });

      test('should track consecutive failures', () {
        final initialStatus = sessionManager.getSessionStatus();
        expect(initialStatus['consecutive_failures'], equals(0));
      });
    });

    group('Auth State Handling', () {
      test('should handle auth state changes', () {
        expect(() => sessionManager.onAuthStateChanged(true), returnsNormally);
        expect(() => sessionManager.onAuthStateChanged(false), returnsNormally);
      });
    });

    group('Force Refresh', () {
      test('should handle force refresh without errors', () async {
        // This will likely fail in test environment, but should not throw
        final result = await sessionManager.forceRefresh();
        expect(result, isA<bool>());
      });
    });

    group('Disposal', () {
      test('should dispose without errors', () {
        expect(() => sessionManager.dispose(), returnsNormally);
        
        final status = sessionManager.getSessionStatus();
        expect(status['indefinite_sessions_enabled'], isFalse);
      });
    });
  });

  group('EnhancedUnifiedAuthService', () {
    late EnhancedUnifiedAuthService authService;

    setUp(() {
      authService = EnhancedUnifiedAuthService();
    });

    tearDown(() {
      authService.dispose();
    });

    group('Initialization', () {
      test('should initialize without errors', () {
        expect(() => EnhancedUnifiedAuthService(), returnsNormally);
      });
    });

    group('Session Management', () {
      test('should get session status', () {
        final status = authService.getSessionStatus();
        
        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('indefinite_sessions_enabled'), isTrue);
      });

      test('should handle indefinite sessions toggle', () async {
        await authService.setIndefiniteSessionsEnabled(true);
        var status = authService.getSessionStatus();
        expect(status['indefinite_sessions_enabled'], isTrue);

        await authService.setIndefiniteSessionsEnabled(false);
        status = authService.getSessionStatus();
        expect(status['indefinite_sessions_enabled'], isFalse);
      });

      test('should handle force token refresh', () async {
        final result = await authService.forceTokenRefresh();
        expect(result, isA<bool>());
      });
    });

    group('Disposal', () {
      test('should dispose without errors', () {
        expect(() => authService.dispose(), returnsNormally);
      });
    });
  });
}
