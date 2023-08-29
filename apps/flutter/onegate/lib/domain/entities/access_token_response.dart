

import 'package:flutter_onegate/domain/entities/user_info.dart';

class AccessTokenResponse {
  final String accessToken;
  final String uuid;
  final UserInfo userInfo;

  AccessTokenResponse({
    required this.accessToken,
    required this.uuid,
    required this.userInfo,
  });

  factory AccessTokenResponse.fromJson(Map<String, dynamic> json) {
    return AccessTokenResponse(
      accessToken: json['access_token'],
      uuid: json['uuid'],
      userInfo: UserInfo.fromJson(json['user_info']),
    );
  }
}