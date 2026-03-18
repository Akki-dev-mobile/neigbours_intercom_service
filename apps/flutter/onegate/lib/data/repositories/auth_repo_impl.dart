import 'dart:developer';

import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';
import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/auth/user_info.dart';
import 'package:flutter_onegate/domain/mappers/auth/access_token_res_mapper.dart';
import 'package:flutter_onegate/domain/repositories/auth_repo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationRepositoryImpl implements AuthenticationRepository {
  final RemoteDataSource _remoteDataSource;
  final GateStorage _gateStorage = GateStorage();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _accessTokenSecureKey = 'access_token_secure';
  static const String _refreshTokenSecureKey = 'refresh_token_secure';

  AuthenticationRepositoryImpl(this._remoteDataSource);

  @override
  Future<AccessTokenResponse?> login(
      String username, String password, String method) async {
    try {
      // Use hybrid-auth login: POST apigw.cubeone.in/v2/hybrid-auth/login
      // Returns Keycloak tokens (access_token, refresh_token) + user data
      final response = await _remoteDataSource.loginWithHybridAuth(
        username: username,
        password: password,
      );

      final kcUserInfoRaw = response['user_info'] as Map<String, dynamic>? ?? {};
      final kcUserInfo = Map<String, dynamic>.from(kcUserInfoRaw);

      // Merge user-id claims from access token JWT (userinfo endpoint may not return them)
      final accessToken = response['access_token'] as String?;
      if (accessToken != null) {
        final payload = JwtTokenUtility.parseJwtToken(accessToken);
        if (payload != null) {
          if (kcUserInfo['old_sso_user_id'] == null &&
              payload['old_sso_user_id'] != null) {
            kcUserInfo['old_sso_user_id'] = payload['old_sso_user_id'];
          }
          if (kcUserInfo['old_gate_user_id'] == null &&
              payload['old_gate_user_id'] != null) {
            kcUserInfo['old_gate_user_id'] = payload['old_gate_user_id'];
          }
          if (kcUserInfo['sub'] == null && payload['sub'] != null) {
            kcUserInfo['sub'] = payload['sub'];
          }
        }
      }

      final sub = kcUserInfo['sub']?.toString() ?? '';
      final userIdStr =
          kcUserInfo['old_sso_user_id']?.toString() ?? sub;

      // Persist tokens first so fetchSocieties can use the access token
      final minimalUserInfo =
          _keycloakUserInfoToUserInfo(kcUserInfo, <String, List<Company>>{});
      final tokenResponse = AccessTokenResponse(
        accessToken: response['access_token'] as String?,
        refresh_token: response['refresh_token'] as String?,
        expires_in: (response['expires_in'] as num?)?.toInt(),
        refresh_expires_in:
            (response['refresh_expires_in'] as num?)?.toInt(),
        token_type: response['token_type'] as String?,
        id_token: response['id_token'] as String?,
        scope: response['scope'] as String?,
        userInfo: minimalUserInfo,
      );
      await _persistTokens(tokenResponse);

      // Fetch societies from gate API (same as WebView flow) and merge into user_info
      final societies = await _remoteDataSource.fetchSocieties(userIdStr);
      final companiesList = _societiesToCompanies(societies);
      final companiesMap = <String, List<Company>>{'0': companiesList};
      final userInfoMap = _keycloakUserInfoToMap(kcUserInfo, companiesMap);
      final fullResponse = {
        ...response,
        'user_info': userInfoMap,
      };
      return AccessTokenResponseMapper.fromJson(fullResponse);
    } catch (error) {
      rethrow;
    }
  }

  /// Map Keycloak userinfo + companies to UserInfo.
  /// Prefer old_gate_user_id for userId (gates use gate_user_id), then old_sso_user_id, then sub.
  UserInfo _keycloakUserInfoToUserInfo(
      Map<String, dynamic> kc, Map<String, List<Company>> companies) {
    final sub = kc['sub']?.toString();
    final oldGate = kc['old_gate_user_id']?.toString();
    final oldSso = kc['old_sso_user_id']?.toString();
    final userId = (oldGate != null && oldGate.isNotEmpty
            ? int.tryParse(oldGate)
            : null) ??
        (oldSso != null && oldSso.isNotEmpty ? int.tryParse(oldSso) : null) ??
        (sub != null ? int.tryParse(sub) : null);
    return UserInfo(
      userId: userId,
      firstName: kc['given_name'] as String?,
      lastName: kc['family_name'] as String?,
      username: (kc['preferred_username'] ?? kc['username']) as String?,
      mobile: kc['mobile'] as String?,
      email: kc['email'] as String?,
      companies: companies,
      uuid: sub,
    );
  }

  /// Map Keycloak userinfo + companies to map for AccessTokenResponseMapper
  Map<String, dynamic> _keycloakUserInfoToMap(
      Map<String, dynamic> kc, Map<String, List<Company>> companies) {
    final sub = kc['sub']?.toString();
    final oldGate = kc['old_gate_user_id']?.toString();
    final oldSso = kc['old_sso_user_id']?.toString();
    final userId = (oldGate != null && oldGate.isNotEmpty
            ? int.tryParse(oldGate)
            : null) ??
        (oldSso != null && oldSso.isNotEmpty ? int.tryParse(oldSso) : null) ??
        (sub != null ? int.tryParse(sub) : null);
    return {
      'user_id': userId,
      'first_name': kc['given_name'],
      'last_name': kc['family_name'],
      'username': kc['preferred_username'] ?? kc['username'],
      'mobile': kc['mobile'],
      'email': kc['email'],
      'uuid': sub,
      'companies': companies.map(
        (key, list) => MapEntry(key, list.map((c) => c.toJson()).toList()),
      ),
    };
  }

  List<Company> _societiesToCompanies(List<dynamic> societies) {
    final list = <Company>[];
    for (final s in societies) {
      if (s is Map<String, dynamic>) {
        try {
          list.add(Company.fromJson(s));
        } catch (_) {
          // skip malformed item
        }
      } else if (s is Map) {
        try {
          list.add(Company.fromJson(Map<String, dynamic>.from(s)));
        } catch (_) {}
      }
    }
    return list;
  }

  Future<void> _persistTokens(AccessTokenResponse response) async {
    try {
      final accessToken = response.accessToken;
      final refreshToken = response.refresh_token;

      // Record login time to suppress session expired modal briefly after login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_login_timestamp_ms', DateTime.now().millisecondsSinceEpoch);

      if (accessToken != null && accessToken.isNotEmpty) {
        await _secureStorage.write(
          key: _accessTokenSecureKey,
          value: accessToken,
        );
        await _gateStorage.saveAccessToken(accessToken);
      }

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: _refreshTokenSecureKey,
          value: refreshToken,
        );
        await _gateStorage.saveRefreshToken(refreshToken);
      }

      if (response.expires_in != null) {
        final expiry = DateTime.now()
            .add(Duration(seconds: response.expires_in!.toInt()));
        await _gateStorage.saveTokenExpiry(expiry);
      }

      if (response.userInfo != null) {
        final u = response.userInfo!;
        await _gateStorage.saveUserId(
            u.userId?.toString() ?? u.uuid ?? '');
        await _gateStorage.saveUsername(u.username ?? u.mobile ?? '');
      }

      log('✅ [AuthRepo] Tokens saved successfully (SecureStorage + GateStorage)');
    } catch (e) {
      log('❌ [AuthRepo] Token persistence failed: $e');
      // Don't rethrow - allow login flow to continue; API clients may still work via GateStorage
    }
  }
}
