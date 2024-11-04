import 'package:flutter_onegate/domain/entities/auth/user_info.dart';

class AccessTokenResponse {
  final String? accessToken;
  final int? expires_in;
  final int? refresh_expires_in;
  final String? refresh_token;
  final String? token_type;
  final String? id_token;
  final int? not_before_policy;
  final String? session_state;
  final String? scope;
  final UserInfo? userInfo;

  AccessTokenResponse({
     this.accessToken,
     this.expires_in,
     this.refresh_expires_in,
     this.refresh_token,
     this.token_type,
     this.id_token,
     this.not_before_policy,
     this.session_state,
     this.scope,
     this.userInfo,
  });

  factory AccessTokenResponse.fromJson(Map<String, dynamic> json) {
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
      userInfo: UserInfo.fromJson(json['user_info']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'expires_in': expires_in,
      'refresh_expires_in': refresh_expires_in,
      'refresh_token': refresh_token,
      'token_type': token_type,
      'id_token': id_token,
      'not-before-policy': not_before_policy,
      'session_state': session_state,
      'scope': scope,
      'user_info': userInfo?.toJson(),
    };
  }
}