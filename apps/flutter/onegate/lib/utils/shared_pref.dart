import 'dart:convert';
import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/auth/user_info.dart';
import 'package:flutter_onegate/domain/entities/gate/gate.dart';
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
  static const String _roles = 'roles';
  static const String _gatesList = 'gates_list';

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

  Future<void> saveGatesList(List<Gate> gatesList) async {
    final gatesListJson = gatesList.map((gate) => gate.toJson()).toList();
    _preferences.setString(_gatesList, jsonEncode(gatesListJson));
  }

  Future<void> setSelectedGate(Gate gate) async {
    _preferences.setString('selected_gate', jsonEncode(gate.toJson()));
  }

  AccessTokenResponse? getAccessToken() {
    final accessTokenJson = _preferences.getString(_accessTokenKey);
    if (accessTokenJson != null) {
      final accessTokenMap = jsonDecode(accessTokenJson);
      return AccessTokenResponse.fromJson(accessTokenMap);
    }
    return null;
  }

  List<String> getRoles() {
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

  Future<List<Gate>> getGatesList() async {
    final gatesListJson = _preferences.getString('gates_list');
    if (gatesListJson != null) {
      final gatesListData = json.decode(gatesListJson) as List<dynamic>;
      return gatesListData.map((data) => Gate.fromJson(data)).toList();
    } else {
      return []; // Return an empty list if no data is found
    }
  }

  Gate? getSelectedGate() {
    final selectedGateJson = _preferences.getString('selected_gate');
    if (selectedGateJson != null) {
      final selectedGateMap = jsonDecode(selectedGateJson);
      return Gate.fromJson(selectedGateMap);
    }
    return null;
  }
}
