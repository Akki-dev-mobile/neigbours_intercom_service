import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/repositories/auth_repo.dart';

class LoginUseCase {
  final AuthenticationRepository _repository;

  LoginUseCase(this._repository);

  Future<AccessTokenResponse?> login(
    String username,
    String password,
    String method,
  ) async {
    return await _repository.login(username, password, method);
  }
}
