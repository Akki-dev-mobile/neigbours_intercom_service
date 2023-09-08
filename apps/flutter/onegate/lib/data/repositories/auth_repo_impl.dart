import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/mappers/auth/access_token_res_mapper.dart';
import 'package:flutter_onegate/domain/repositories/auth_repo.dart';

class AuthenticationRepositoryImpl implements AuthenticationRepository {
  final RemoteDataSource _remoteDataSource;

  AuthenticationRepositoryImpl(this._remoteDataSource);

  @override
  Future<AccessTokenResponse?> login(
      String username, String password, String method) async {
    try {
      final response =
          await _remoteDataSource.loginUser(username, password, method);
      final accessTokenResponse = AccessTokenResponseMapper.fromJson(response);
      return accessTokenResponse;
    } catch (error) {
      return null; // Handle error or authentication failure
    }
  }
}
