import 'package:flutter_onegate/domain/entities/access_token_response.dart';

abstract class AuthenticationRepository {
  Future<AccessTokenResponse?> login(String username, String password, String method);
}