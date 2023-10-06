import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/mappers/auth/user_info_mapper.dart';

class AccessTokenResponseMapper {
  static AccessTokenResponse fromJson(Map<String, dynamic> json) {
    return AccessTokenResponse(
      accessToken: json['access_token'],
      expires_in: json['expires_in'],
      refresh_expires_in: json['refresh_expires_in'],
      refresh_token: json['refresh_token'],
      token_type: json['token_type'],
      id_token: json['id_token'],
      not_before_policy: json['not-before-policy'],
      session_state: json['session_state'],
      scope: json['scope'],
      userInfo: UserInfoMapper.fromJson(json['user_info']),
    );
  }
}
