import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/mappers/auth/user_info_mapper.dart';

class AccessTokenResponseMapper {
  static AccessTokenResponse fromJson(Map<String, dynamic> json) {
    return AccessTokenResponse(
      accessToken: json['access_token'],
      uuid: json['uuid'],
      userInfo: UserInfoMapper.fromJson(json['user_info']),
    );
  }
}
