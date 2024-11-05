import 'dart:convert';
import 'package:flutter_onegate/domain/entities/auth/access_token_response.dart';
import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/auth/user_info.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
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
  static const String _isAdmin='is_admin';
  static const String _isLogin='is_login';
  static const String _isAppIntroShown = 'is_app_intro_shown';
  static const String _isSelfTapIn = 'is_self_tap_in';

  Future<void> setIsAppIntroShown(bool isAppIntroShown) async {
    _preferences.setBool(_isAppIntroShown, isAppIntroShown);
  }

  Future<void> setIsLogin(bool isLogin) async {
    _preferences.setBool(_isLogin, isLogin);
  }

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

  Future<void>setIsAdmin(bool isAdmin)async {
    _preferences.setBool(_isAdmin, isAdmin);
  }

  Future<void> setIsSelfTapIn(bool isSelfTapIn) async {
    await _preferences.setBool(_isSelfTapIn,isSelfTapIn);
  }

  bool? getIsAppIntroShown() {
    final isAppIntroShown = _preferences.getBool(_isAppIntroShown);
    if (isAppIntroShown != null) {
      return isAppIntroShown;
    }
    return false;
  }

  bool? getIsAdmin() {
    final isAdmin = _preferences.getBool(_isAdmin);
    if (isAdmin != null) {
      return isAdmin;
    }
    return false;
  }

  bool? getIsSelfTapIn(){
    final isSelfTapIn = _preferences.getBool(_isSelfTapIn);
    if (isSelfTapIn != null) {
      return isSelfTapIn;
    }
    return false;
  }

  bool? getIsLogin() {
    final isLogin = _preferences.getBool(_isLogin);
    if (isLogin != null) {
      return isLogin;
    }
    return false;
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
      print("User Info UserInfo.fromJson(userInfoMap) ${UserInfo}");
      return UserInfo.fromJson(userInfoMap);
      
    }
    return null;
  }

  Company? getSelectedCompany() {
    final selectedCompanyJson = _preferences.getString(_selectedCompanyKey);
    if (selectedCompanyJson != null) {
      final selectedCompanyMap = jsonDecode(selectedCompanyJson);
      print( "Selected Gate selectedCompanyMap ${Company.fromJson(selectedCompanyMap)}");
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
      print( " Selected Gate ${Gate.fromJson(selectedGateMap)}");
      return Gate.fromJson(selectedGateMap);
    }
    return null;
  }
}
