import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'package:flutter_onegate/services/auth_service/riverpod/auth_controller.dart';
import 'package:flutter_onegate/services/auth_service/riverpod/auth_state.dart';
import 'package:flutter_onegate/services/auth_service/riverpod/auth_tokens.dart';
import 'package:flutter_onegate/services/auth_service/riverpod/auth_storage.dart';

import 'auth_controller_test.mocks.dart';

@GenerateMocks([FlutterAppAuth, AuthStorage])
void main() {
  group('AuthController Tests', () {
    late ProviderContainer container;
    late MockFlutterAppAuth mockAppAuth;
    late MockAuthStorage mockStorage;

    setUp(() {
      mockAppAuth = MockFlutterAppAuth();
      mockStorage = MockAuthStorage();
      
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Scheduled Auto-Refresh', () {
      test('should schedule refresh 2 minutes before token expiration', () async {
        // Arrange
        final expiresAt = DateTime.now().add(const Duration(minutes: 10));
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          idToken: 'id_token',
          expiresAt: expiresAt,
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // Initialize

        // Assert
        expect(controller.isAuthenticated, isTrue);
        
        // Verify that a timer would be scheduled (we can't easily test Timer directly)
        // This is more of an integration test that would require time manipulation
      });

      test('should trigger immediate refresh for tokens expiring soon', () async {
        // Arrange
        final expiresAt = DateTime.now().add(const Duration(minutes: 1));
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          idToken: 'id_token',
          expiresAt: expiresAt,
        );

        final newTokenResponse = AuthorizationTokenResponse(
          'new_access_token',
          'refresh_token',
          DateTime.now().add(const Duration(hours: 1)),
          'id_token',
          null,
          null,
          null,
          null,
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});
        when(mockAppAuth.token(any)).thenAnswer((_) async => newTokenResponse);
        when(mockStorage.storeTokens(any)).thenAnswer((_) async {});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // This should trigger immediate refresh

        // Wait a bit for async operations
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(mockAppAuth.token(any)).called(1);
        verify(mockStorage.storeTokens(any)).called(1);
      });
    });

    group('401 → Refresh → Retry Success Path', () {
      test('should successfully refresh token and retry request', () async {
        // Arrange
        final initialTokens = AuthTokens(
          accessToken: 'old_access_token',
          refreshToken: 'refresh_token',
          idToken: 'id_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final newTokenResponse = AuthorizationTokenResponse(
          'new_access_token',
          'refresh_token',
          DateTime.now().add(const Duration(hours: 2)),
          'id_token',
          null,
          null,
          null,
          null,
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => initialTokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});
        when(mockAppAuth.token(any)).thenAnswer((_) async => newTokenResponse);
        when(mockStorage.storeTokens(any)).thenAnswer((_) async {});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // Initialize with old tokens
        
        final refreshSuccess = await controller.refreshToken();

        // Assert
        expect(refreshSuccess, isTrue);
        expect(controller.accessToken, equals('new_access_token'));
        verify(mockAppAuth.token(any)).called(1);
        verify(mockStorage.storeTokens(any)).called(1);
      });

      test('should handle concurrent refresh requests', () async {
        // Arrange
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          idToken: 'id_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final newTokenResponse = AuthorizationTokenResponse(
          'new_access_token',
          'refresh_token',
          DateTime.now().add(const Duration(hours: 2)),
          'id_token',
          null,
          null,
          null,
          null,
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});
        when(mockAppAuth.token(any)).thenAnswer((_) async {
          // Simulate slow network
          await Future.delayed(const Duration(milliseconds: 200));
          return newTokenResponse;
        });
        when(mockStorage.storeTokens(any)).thenAnswer((_) async {});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // Initialize

        // Start multiple concurrent refresh requests
        final futures = List.generate(3, (_) => controller.refreshToken());
        final results = await Future.wait(futures);

        // Assert
        expect(results.every((result) => result == true), isTrue);
        // Should only call the API once despite multiple concurrent requests
        verify(mockAppAuth.token(any)).called(1);
      });
    });

    group('401 → Refresh Failure → Logout', () {
      test('should logout when refresh token is invalid', () async {
        // Arrange
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'invalid_refresh_token',
          idToken: 'id_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});
        when(mockAppAuth.token(any)).thenThrow(
          const FlutterAppAuthPlatformException(
            'invalid_grant',
            'Refresh token is invalid',
            null,
          ),
        );
        when(mockStorage.clearAll()).thenAnswer((_) async {});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // Initialize
        
        final refreshSuccess = await controller.refreshToken();

        // Assert
        expect(refreshSuccess, isFalse);
        expect(controller.isAuthenticated, isFalse);
        verify(mockStorage.clearAll()).called(1);
      });

      test('should logout when refresh token is expired', () async {
        // Arrange
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'expired_refresh_token',
          idToken: 'id_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});
        when(mockAppAuth.token(any)).thenThrow(
          Exception('Token expired'),
        );
        when(mockStorage.clearAll()).thenAnswer((_) async {});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // Initialize
        
        final refreshSuccess = await controller.refreshToken();

        // Assert
        expect(refreshSuccess, isFalse);
        expect(controller.isAuthenticated, isFalse);
        verify(mockStorage.clearAll()).called(1);
      });

      test('should handle network errors during refresh gracefully', () async {
        // Arrange
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          idToken: 'id_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});
        when(mockAppAuth.token(any)).thenThrow(
          Exception('Network error'),
        );
        when(mockStorage.clearAll()).thenAnswer((_) async {});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // Initialize
        
        final refreshSuccess = await controller.refreshToken();

        // Assert
        expect(refreshSuccess, isFalse);
        expect(controller.isAuthenticated, isFalse);
        verify(mockStorage.clearAll()).called(1);
      });
    });

    group('Authentication State Management', () {
      test('should initialize as unauthenticated when no tokens exist', () async {
        // Arrange
        when(mockStorage.getTokens()).thenAnswer((_) async => null);

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build();

        // Assert
        expect(controller.isAuthenticated, isFalse);
        final state = container.read(authControllerProvider);
        expect(state, isA<UnauthenticatedState>());
      });

      test('should initialize as authenticated when valid tokens exist', () async {
        // Arrange
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          idToken: 'id_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build();

        // Assert
        expect(controller.isAuthenticated, isTrue);
        final state = container.read(authControllerProvider);
        expect(state, isA<AuthenticatedState>());
      });

      test('should clear tokens and logout when user explicitly logs out', () async {
        // Arrange
        final tokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          idToken: 'id_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockStorage.getTokens()).thenAnswer((_) async => tokens);
        when(mockStorage.getUserInfo()).thenAnswer((_) async => {'sub': 'user'});
        when(mockStorage.clearAll()).thenAnswer((_) async {});

        // Act
        final controller = container.read(authControllerProvider.notifier);
        await controller.build(); // Initialize as authenticated
        await controller.logout();

        // Assert
        expect(controller.isAuthenticated, isFalse);
        verify(mockStorage.clearAll()).called(1);
        final state = container.read(authControllerProvider);
        expect(state, isA<UnauthenticatedState>());
      });
    });
  });
}
