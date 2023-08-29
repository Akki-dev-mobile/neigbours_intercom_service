import 'package:flutter_onegate/domain/entities/access_token_response.dart';
import 'package:flutter_onegate/domain/mappers/user_info_mapper.dart';

class AccessTokenResponseMapper {
  static AccessTokenResponse fromJson(Map<String, dynamic> json) {
    return AccessTokenResponse(
      accessToken: json['access_token'],
      uuid: json['uuid'],
      userInfo: UserInfoMapper.fromJson(json['user_info']),
    );
  }
}