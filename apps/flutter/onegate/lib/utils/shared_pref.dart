import 'dart:convert';
import 'package:flutter_onegate/domain/entities/access_token_response.dart';
import 'package:flutter_onegate/domain/entities/company.dart';
import 'package:flutter_onegate/domain/entities/user_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceUtils {
  final SharedPreferences _preferences;

  PreferenceUtils(this._preferences);

  static Future<PreferenceUtils> getInstance() async {
    final preferences = await SharedPreferences.getInstance();
    return PreferenceUtils(preferences);
  }

  static const String _accessTokenKey = 'access_token';
  static const String _userInfoKey = 'user_info';
  static const String _selectedCompanyKey = 'selected_company';
  static const String _roles='roles';

  Future<void> saveAccessTokenResponse(AccessTokenResponse accessToken) async {
    _preferences.setString(_accessTokenKey, jsonEncode(accessToken.toJson()));
  }

  Future<void> saveRoles(List<String> roles) async {
    _preferences.setStringList(_roles, roles);
  }

  Future<void> saveUserInfo(UserInfo userInfo) async {
    _preferences.setString(_userInfoKey, jsonEncode(userInfo.toJson()));
  }

  Future<void> saveSelectedCompany(Company selectedCompany) async {
    _preferences.setString(
        _selectedCompanyKey, jsonEncode(selectedCompany.toJson()));
  }

  AccessTokenResponse? getAccessToken() {
    final accessTokenJson = _preferences.getString(_accessTokenKey);
    if (accessTokenJson != null) {
      final accessTokenMap = jsonDecode(accessTokenJson);
      return AccessTokenResponse.fromJson(accessTokenMap);
    }
    return null;
  }

  List<String> getRoles()  {
    final roles = _preferences.getStringList(_roles);
    if (roles != null) {
      return roles;
    }
    return [];
  }

  UserInfo? getUserInfo() {
    final userInfoJson = _preferences.getString(_userInfoKey);
    if (userInfoJson != null) {
      final userInfoMap = jsonDecode(userInfoJson);
      return UserInfo.fromJson(userInfoMap);
    }
    return null;
  }

  Company? getSelectedCompany() {
    final selectedCompanyJson = _preferences.getString(_selectedCompanyKey);
    if (selectedCompanyJson != null) {
      final selectedCompanyMap = jsonDecode(selectedCompanyJson);
      return Company.fromJson(selectedCompanyMap);
    }
    return null;
  }
}
