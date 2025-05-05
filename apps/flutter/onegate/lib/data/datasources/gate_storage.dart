import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GateStorage {
  static const _accessTokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _roleKey = 'role';
  static const _societyIdKey = 'society_id';
  static const _visitorLogIdKey = 'visitorLogId';
  static const String _memberApprovalKey = 'member_approval';
  static const _visitorImageKey = 'visitor_image';
  static const _faceRecConfigKey = 'face_rec_config';

  static final GateStorage _instance = GateStorage._internal();

  factory GateStorage() {
    return _instance;
  }

  GateStorage._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save face recognition config from API response as JSON
  Future<void> saveFaceRecConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config);
    await prefs.setString(_faceRecConfigKey, jsonString);
    log("✅ Face recognition config saved: $jsonString");
  }

  /// Retrieve face recognition config from SharedPreferences
  Future<Map<String, dynamic>?> getFaceRecConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_faceRecConfigKey);
    if (jsonString != null) {
      try {
        return jsonDecode(jsonString);
      } catch (e) {
        log("❌ Failed to parse face rec config: $e");
      }
    }
    return null;
  }

  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  // static const String _societyIdKey = 'society_id';
  static const String _societyNameKey = 'society_name';
  Future<void> saveVisitorImageBase64(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);
    await prefs.setString(_visitorImageKey, base64Image);
  }

  Future<void> removeVisitorImage() async {
    final prefs = await SharedPreferences.getInstance();
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = '${tempDir.path}/visitor_image.png';
    File imageFile = File(tempPath);

    if (await imageFile.exists()) {
      await imageFile.delete();
      print("Visitor image deleted from temporary directory.");
    }

    await prefs.remove(_visitorImageKey);
    print("Visitor image data removed from SharedPreferences.");
  }

  Future<File?> getVisitorImageBase64() async {
    final prefs = await SharedPreferences.getInstance();
    String? base64Image = prefs.getString(_visitorImageKey);

    if (base64Image != null) {
      List<int> imageBytes = base64Decode(base64Image);
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = '${tempDir.path}/visitor_image.png';
      File imageFile = File(tempPath);
      await imageFile.writeAsBytes(imageBytes);
      return imageFile;
    }
    return null;
  }

  Future<void> saveSocietyDetails(String societyId, String? societyName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_societyIdKey, societyId);
    if (societyName != null) {
      await prefs.setString(_societyNameKey, societyName);
    }
  }

  Future<void> saveSocietyId(String societyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_societyIdKey, societyId);
  }

  Future<String?> getSocietyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_societyIdKey);
  }

  // Future<void> saveAccessToken(String token) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString(_accessTokenKey, token);
  // }

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

  Future<void> saveImage(String image) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uploaded_image_url', image);
    // print("Image URL saved to SharedPreferences: $response");
  }
  Future<void> setComingFrom(String comingFrom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coming_from', comingFrom);
    log("coming_from  saved to SharedPreferences: $comingFrom");
  }

  Future<String?> getComingFrom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("coming_from");
  }

  //remove coming_from
  Future<void> removeComingFrom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('coming_from');
    log("coming_from removed from SharedPreferences");
  }

  Future<String?> getImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("uploaded_image_url");
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  // Future<void> saveSocietyDetails(int societyId, String societyName) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   await prefs.setInt(_societyIdKey, societyId);
  //   await prefs.setString('societyName', societyName);
  // }

  Future<Map> getSocietyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final societyId = prefs.getInt('societyId');
    final societyName = prefs.getString(_societyNameKey);
    return {_societyIdKey: societyId, 'societyName': societyName};
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // Future<void> saveSocietyId(int societyId) async {
  //   await _prefs?.setInt(_societyIdKey, societyId);
  //   log("Society ID saved successfully: $societyId");
  // }

  // Future<int?> getSocietyId() async {
  //   final id = _prefs?.getInt(_societyIdKey);
  //   log("Retrieved Society ID: $id");
  //   return id;
  // }

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

  Future<void> clearStorage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
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

  bool? getTooglevalue(String key) {
    return _prefs?.getBool(key);
  }

  Future<void> setToogleValue(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Save the entire member list as a JSON String
  Future<void> saveMemberList(List<dynamic> memberList) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert the list to a JSON string before storing
    final jsonString = jsonEncode(memberList);
    await prefs.setString('member_list', jsonString);
    log("Member list saved to SharedPreferences");
  }

  /// Retrieve the stored member list (if any)
  Future<List<dynamic>?> getMemberList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('member_list');
    if (jsonString != null) {
      try {
        final data = jsonDecode(jsonString);
        if (data is List) {
          return data;
        }
      } catch (e) {
        log("Error parsing stored member list: $e");
      }
    }
    return null;
  }

  Future<void> saveMemberApproval(bool approval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_memberApprovalKey, approval);
  }

// Retrieve member approval status
  Future<bool?> getMemberApproval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_memberApprovalKey);
  }

  Future<void> saveSelectedGate(
      String gateName, String gateId, String gateType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_gate', gateName);
    await prefs.setString('selected_gate_id', gateId);
    await prefs.setString('selected_gate_type', gateType);
    log("Gate saved: name=$gateName, id=$gateId, type=$gateType");
  }

  Future<Map<String, String?>> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('selected_gate');
    final id = prefs.getString('selected_gate_id');
    final type = prefs.getString('selected_gate_type');
    return {
      'name': name,
      'id': id,
      'type': type,
    };
  }

  Future<String?> getGateType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_gate_type');
  }
}
