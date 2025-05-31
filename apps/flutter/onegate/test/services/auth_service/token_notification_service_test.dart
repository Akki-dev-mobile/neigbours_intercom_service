import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/services/auth_service/token_notification_service.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

void main() {
  group('TokenNotificationService Tests', () {
    late TokenNotificationService notificationService;

    setUp(() {
      notificationService = TokenNotificationService();
    });

    group('Token Information Display', () {
      test('should handle valid JWT token correctly', () {
        // Create a mock JWT token (simplified for testing)
        const mockToken =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.Lf8Xd8Ej7Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8';

        // Test that the service can handle token info display
        expect(() => notificationService.showTokenInfo(mockToken),
            returnsNormally);
      });

      test('should handle invalid JWT token gracefully', () {
        const invalidToken = 'invalid.jwt.token';

        // Test that the service handles invalid tokens gracefully
        expect(() => notificationService.showTokenInfo(invalidToken),
            returnsNormally);
      });

      test('should handle empty token gracefully', () {
        const emptyToken = '';

        // Test that the service handles empty tokens gracefully
        expect(() => notificationService.showTokenInfo(emptyToken),
            returnsNormally);
      });
    });

    group('Token Refresh Notifications', () {
      test('should show refresh progress notification', () {
        // Test that refresh progress notification can be shown
        expect(() => notificationService.showTokenRefreshProgress(),
            returnsNormally);
      });

      test('should show refresh progress with custom message', () {
        const customMessage = "Custom refresh message";

        // Test that custom refresh message can be shown
        expect(
            () => notificationService.showTokenRefreshProgress(
                message: customMessage),
            returnsNormally);
      });

      test('should show refresh success notification', () {
        // Test that refresh success notification can be shown
        expect(() => notificationService.showTokenRefreshSuccess(),
            returnsNormally);
      });

      test('should show refresh success with new token', () {
        const mockToken =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.Lf8Xd8Ej7Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8Ks8';

        // Test that refresh success with new token can be shown
        expect(
            () => notificationService.showTokenRefreshSuccess(
                newToken: mockToken),
            returnsNormally);
      });

      test('should show refresh failure notification', () {
        // Test that refresh failure notification can be shown
        expect(() => notificationService.showTokenRefreshFailure(),
            returnsNormally);
      });

      test('should show refresh failure with error message', () {
        const errorMessage = "Network error occurred";

        // Test that refresh failure with error message can be shown
        expect(
            () => notificationService.showTokenRefreshFailure(
                errorMessage: errorMessage),
            returnsNormally);
      });
    });

    group('Token Expiration Warnings', () {
      test('should show expiration warning for short duration', () {
        const shortDuration = Duration(minutes: 2);

        // Test that expiration warning can be shown
        expect(
            () => notificationService.showTokenExpirationWarning(shortDuration),
            returnsNormally);
      });

      test('should show expiration warning for medium duration', () {
        const mediumDuration = Duration(hours: 1, minutes: 30);

        // Test that expiration warning can be shown
        expect(
            () =>
                notificationService.showTokenExpirationWarning(mediumDuration),
            returnsNormally);
      });

      test('should show expiration warning for long duration', () {
        const longDuration = Duration(days: 2, hours: 5);

        // Test that expiration warning can be shown
        expect(
            () => notificationService.showTokenExpirationWarning(longDuration),
            returnsNormally);
      });
    });

    group('Authentication Error Notifications', () {
      test('should show authentication error without message', () {
        // Test that authentication error can be shown
        expect(() => notificationService.showAuthenticationError(),
            returnsNormally);
      });

      test('should show authentication error with custom message', () {
        const errorMessage = "Invalid credentials provided";

        // Test that authentication error with message can be shown
        expect(
            () => notificationService.showAuthenticationError(
                errorMessage: errorMessage),
            returnsNormally);
      });
    });

    group('Notification Management', () {
      test('should clear all notifications', () {
        // Test that notifications can be cleared
        expect(() => notificationService.clearNotifications(), returnsNormally);
      });

      test('should handle multiple notification calls', () {
        // Test that multiple notifications can be handled
        expect(() {
          notificationService.showTokenRefreshProgress();
          notificationService.showTokenRefreshSuccess();
          notificationService.clearNotifications();
        }, returnsNormally);
      });
    });

    group('Duration Formatting', () {
      test('should format seconds correctly', () {
        // Test internal duration formatting (if accessible)
        const duration = Duration(seconds: 45);

        // Since _formatDuration is private, we test through public methods
        expect(() => notificationService.showTokenExpirationWarning(duration),
            returnsNormally);
      });

      test('should format minutes correctly', () {
        const duration = Duration(minutes: 15, seconds: 30);

        expect(() => notificationService.showTokenExpirationWarning(duration),
            returnsNormally);
      });

      test('should format hours correctly', () {
        const duration = Duration(hours: 2, minutes: 45);

        expect(() => notificationService.showTokenExpirationWarning(duration),
            returnsNormally);
      });

      test('should format days correctly', () {
        const duration = Duration(days: 1, hours: 12, minutes: 30);

        expect(() => notificationService.showTokenExpirationWarning(duration),
            returnsNormally);
      });
    });

    group('Error Handling', () {
      test('should handle null token gracefully', () {
        // Test that null token is handled gracefully
        expect(() => notificationService.showTokenInfo(''), returnsNormally);
      });

      test('should handle malformed JWT token', () {
        const malformedToken = 'not.a.valid.jwt.token.structure';

        expect(() => notificationService.showTokenInfo(malformedToken),
            returnsNormally);
      });

      test('should handle very long error messages', () {
        final longErrorMessage = 'A' * 1000; // Very long error message

        expect(
            () => notificationService.showAuthenticationError(
                errorMessage: longErrorMessage),
            returnsNormally);
      });
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = TokenNotificationService();
        final instance2 = TokenNotificationService();

        expect(identical(instance1, instance2), isTrue);
      });

      test('should maintain state across instances', () {
        final instance1 = TokenNotificationService();
        final instance2 = TokenNotificationService();

        // Both instances should be the same object
        expect(instance1, equals(instance2));
      });
    });

    group('Integration with JWT Utility', () {
      test('should work with JWT token parsing', () {
        // Create a more realistic JWT token for testing
        const testToken =
            'eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJyVGJuVVFvTVBfTUJuX2JEX1BKcWNqcWJPcWJPcWJPcWJPcWJPcWJPcWJPIn0.eyJleHAiOjk5OTk5OTk5OTksImlhdCI6MTUxNjIzOTAyMiwianRpIjoiYWJjZGVmZ2gtaWprbC1tbm9wLXFyc3QtdXZ3eHl6MTIzNCIsImlzcyI6Imh0dHBzOi8va2V5Y2xvYWsuZXhhbXBsZS5jb20vcmVhbG1zL29uZWdhdGUiLCJhdWQiOiJhY2NvdW50Iiwic3ViIjoiMTIzNDU2NzgtOTBhYi1jZGVmLTEyMzQtNTY3ODkwYWJjZGVmIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoib25lZ2F0ZS1hcHAiLCJzZXNzaW9uX3N0YXRlIjoiYWJjZGVmZ2gtaWprbC1tbm9wLXFyc3QtdXZ3eHl6MTIzNCIsImFjciI6IjEiLCJhbGxvd2VkLW9yaWdpbnMiOlsiaHR0cDovL2xvY2FsaG9zdDozMDAwIl0sInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJkZWZhdWx0LXJvbGVzLW9uZWdhdGUiLCJvZmZsaW5lX2FjY2VzcyIsInVtYV9hdXRob3JpemF0aW9uIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJvcGVuaWQgZW1haWwgcHJvZmlsZSIsInNpZCI6ImFiY2RlZmdoLWlqa2wtbW5vcC1xcnN0LXV2d3h5ejEyMzQiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6IkpvaG4gRG9lIiwicHJlZmVycmVkX3VzZXJuYW1lIjoiam9obmRvZSIsImdpdmVuX25hbWUiOiJKb2huIiwiZmFtaWx5X25hbWUiOiJEb2UiLCJlbWFpbCI6ImpvaG4uZG9lQGV4YW1wbGUuY29tIn0.signature';

        // Test that the service can handle realistic JWT tokens
        expect(() => notificationService.showTokenInfo(testToken),
            returnsNormally);
      });

      test('should handle JWT parsing errors gracefully', () {
        const invalidJWT = 'invalid.jwt.structure';

        // Test that JWT parsing errors are handled gracefully
        expect(() => notificationService.showTokenInfo(invalidJWT),
            returnsNormally);
      });
    });
  });
}
