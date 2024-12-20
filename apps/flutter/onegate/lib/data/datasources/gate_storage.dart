import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class GateStorage {
  static const _accessTokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _roleKey = 'role';
  static const _societyIdKey = 'society_id';
  static const _visitorLogIdKey = 'visitorLogId';

  static final GateStorage _instance = GateStorage._internal();

  factory GateStorage() {
    return _instance;
  }

  GateStorage._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  Future<void> saveSocietyDetails(int societyId, String societyName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_societyIdKey, societyId);
    await prefs.setString('societyName', societyName);
  }

  Future<Map<String, dynamic>> getSocietyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final societyId = prefs.getInt('societyId');
    final societyName = prefs.getString('societyName');
    return {_societyIdKey: societyId, 'societyName': societyName};
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<void> saveSocietyId(int societyId) async {
    await _prefs?.setInt(_societyIdKey, societyId);
    log("Society ID saved successfully: $societyId");
  }

  Future<int?> getSocietyId() async {
    final id = _prefs?.getInt(_societyIdKey);
    log("Retrieved Society ID: $id");
    return id;
  }

  Future<void> saveMemberDetails(Map<String, dynamic> memberDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedMemberDetails', jsonEncode(memberDetails));
      print("Member details successfully saved to SharedPreferences");
    } catch (e) {
      print("Error saving member details to SharedPreferences: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getMemberDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final details = prefs.getString('selectedMemberDetails');
      if (details != null) {
        return jsonDecode(details);
      }
    } catch (e) {
      print("Error retrieving member details: $e");
    }
    return null;
  }

  Future<void> clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> saveVisitorLogId(String visitorLogId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Remove the existing visitor log ID
    await prefs.remove(_visitorLogIdKey);

    // Save the new visitor log ID
    await prefs.setString(_visitorLogIdKey, visitorLogId);
    print("VisitorLog ID stored in SharedPreferences: $visitorLogId");
  }

  /// Retrieve the current visitor log ID
  Future<String?> getVisitorLogId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_visitorLogIdKey);
  }

  /// Clear the visitor log ID
  Future<void> clearVisitorLogId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_visitorLogIdKey);
    print("VisitorLog ID removed from SharedPreferences");
  }
}
