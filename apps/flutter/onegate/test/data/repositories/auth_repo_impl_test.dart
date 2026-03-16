// Unit tests for native backend login repository.
// Run with: flutter test test/data/repositories/auth_repo_impl_test.dart
// (Requires project codegen to be up to date: build_runner for .g.dart files.)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/auth_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';

/// Minimal mock that returns a fixed response or throws.
class _MockRemoteDataSource extends RemoteDataSource {
  Map<String, dynamic>? response;
  Object? throwError;

  @override
  Future<Map<String, dynamic>> loginWithCredentials({
    required String username,
    required String password,
    String method = 'password',
  }) async {
    if (throwError != null) throw throwError!;
    if (response != null) return response!;
    throw StateError('Mock response or throwError not set');
  }
}

void main() {
  late AuthenticationRepositoryImpl repository;
  late _MockRemoteDataSource mockRemote;

  setUp(() {
    mockRemote = _MockRemoteDataSource();
    repository = AuthenticationRepositoryImpl(mockRemote);
  });

  group('AuthenticationRepositoryImpl', () {
    test('login returns AccessTokenResponse when backend returns valid data', () async {
      mockRemote.response = {
        'access_token': 'at',
        'refresh_token': 'rt',
        'expires_in': 3600,
        'user_info': {
          'user_id': 1,
          'username': 'u',
          'mobile': '9',
          'email': 'e@e.com',
          'first_name': 'F',
          'last_name': 'L',
        },
      };

      final result = await repository.login('user', 'pass', 'password');

      expect(result, isA<AccessTokenResponse>());
      expect(result!.accessToken, 'at');
      expect(result.refresh_token, 'rt');
    });

    test('login throws when backend throws', () async {
      mockRemote.throwError = Exception('Invalid credentials');
      mockRemote.response = null;

      expect(
        () => repository.login('user', 'pass', 'password'),
        throwsException,
      );
    });
  });
}
