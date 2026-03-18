import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/services/auth_service/jwt_token_utility.dart';

class GateStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiryKey = 'token_expiry';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _userEmailKey = 'user_email';
  static const _userFullNameKey = 'user_full_name';
  static const _userRolesKey = 'user_roles';
  static const _sessionTimestampKey = 'session_timestamp';
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

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  Future<void> saveTokenExpiry(DateTime expiryTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tokenExpiryKey, expiryTime.millisecondsSinceEpoch);
  }

  /// Get stored token expiry (for opaque/non-JWT tokens)
  Future<DateTime?> getTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_tokenExpiryKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
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

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<bool> isTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if session timeout override is active (check multiple keys for compatibility)
      final tokenExpirationLogoutDisabled =
          prefs.getBool('token_expiration_logout_disabled') ?? false;
      final gateStorageTimeoutDisabled =
          prefs.getBool('gate_storage_token_expiration_disabled') ?? false;
      final autoLogoutDisabled = prefs.getBool('auto_logout_disabled') ?? false;
      final continuousSessionActive =
          prefs.getBool('continuous_session_active') ?? false;

      // If any timeout override is active, use JWT-based expiry only
      if (tokenExpirationLogoutDisabled ||
          gateStorageTimeoutDisabled ||
          autoLogoutDisabled ||
          continuousSessionActive) {
        log("🔒 Token expiration override active - using JWT-based expiry only");
        return await _isTokenExpiredFromJWT();
      }

      // For normal mode, use JWT-based expiry with buffer
      return await _isTokenExpiredWithBuffer();
    } catch (e) {
      log("❌ Error checking token expiry: $e");
      return true; // Consider expired on error
    }
  }

  /// Check if token is expired based on JWT exp claim only (no buffer)
  /// Falls back to stored token_expiry for opaque tokens (e.g. old_sso_tokens from hybrid-auth)
  Future<bool> _isTokenExpiredFromJWT() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        log("⚠️ No access token available");
        return true;
      }

      // Use JWT utility to get actual expiration time
      var expirationTime =
          JwtTokenUtility.getTokenExpirationTime(accessToken);

      // Fallback: opaque tokens (old_sso_tokens) are not JWTs - use stored expiry
      if (expirationTime == null) {
        expirationTime = await getTokenExpiry();
        if (expirationTime != null) {
          log("📋 Using stored expiry for opaque token (valid until $expirationTime)");
        } else {
          log("⚠️ Could not determine token expiration (JWT or stored)");
          return true;
        }
      }

      final now = DateTime.now();
      final isExpired = now.isAfter(expirationTime);

      if (isExpired) {
        log("⏰ Token expired at $expirationTime (${now.difference(expirationTime).inMinutes} minutes ago)");
      } else {
        final timeUntilExpiry = expirationTime.difference(now);
        log("✅ Token valid for ${timeUntilExpiry.inMinutes}min ${timeUntilExpiry.inSeconds % 60}s");
      }

      return isExpired;
    } catch (e) {
      log("❌ Error checking token expiry: $e");
      return true;
    }
  }

  /// Check if token is expired with dynamic buffer for refresh timing
  /// Falls back to stored expiry for opaque tokens (e.g. old_sso_tokens)
  Future<bool> _isTokenExpiredWithBuffer() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        log("⚠️ No access token available");
        return true;
      }

      // Try JWT-based check first
      final jwtExpiration = JwtTokenUtility.getTokenExpirationTime(accessToken);
      if (jwtExpiration != null) {
        final buffer = JwtTokenUtility.calculateOptimalRefreshBuffer(accessToken);
        return JwtTokenUtility.isTokenExpiredOrExpiring(accessToken, buffer: buffer);
      }

      // Fallback: opaque token - use stored expiry with 5 min buffer
      final storedExpiry = await getTokenExpiry();
      if (storedExpiry == null) {
        log("⚠️ Opaque token with no stored expiry - considering valid");
        return false; // Don't force logout for opaque tokens without expiry
      }
      const buffer = Duration(minutes: 5);
      final isExpiring = DateTime.now().isAfter(storedExpiry.subtract(buffer));
      if (isExpiring) {
        log("🔄 Opaque token expiring within ${buffer.inMinutes}min buffer (expires at $storedExpiry)");
      }
      return isExpiring;
    } catch (e) {
      log("❌ Error checking token expiry with buffer: $e");
      return true;
    }
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

  /// Enhanced user session management methods
  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  Future<void> saveUserFullName(String fullName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userFullNameKey, fullName);
  }

  Future<String?> getUserFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userFullNameKey);
  }

  Future<void> saveUserRoles(List<String> roles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRolesKey, jsonEncode(roles));
  }

  Future<List<String>> getUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final rolesJson = prefs.getString(_userRolesKey);
    if (rolesJson != null) {
      try {
        final rolesList = jsonDecode(rolesJson) as List;
        return rolesList.cast<String>();
      } catch (e) {
        log("❌ Error parsing user roles: $e");
      }
    }
    return [];
  }

  Future<void> saveSessionTimestamp(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionTimestampKey, timestamp.millisecondsSinceEpoch);
  }

  Future<DateTime?> getSessionTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_sessionTimestampKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
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

  /// Clear all authentication tokens
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiryKey);
    log("✅ All authentication tokens cleared from GateStorage");
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

  Future<void> clearVisitorImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("uploaded_image_url");
    print("uploaded_image_url  removed from SharedPreferences");
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

  // Meilisearch configuration
  Future<void> setMeilisearchHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meilisearch_host', host);
    log("Meilisearch host saved: $host");
  }

  Future<String?> getMeilisearchHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('meilisearch_host');
  }

  Future<void> setMeilisearchApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meilisearch_api_key', apiKey);
    log("Meilisearch API key saved");
  }

  Future<String?> getMeilisearchApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('meilisearch_api_key');
  }

  // Custom notification service configuration
  Future<void> setNotificationServiceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_service_enabled', enabled);
    log("Custom notification service enabled: $enabled");
  }

  Future<bool> getNotificationServiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_service_enabled') ?? true;
  }

  Future<void> setNotificationWebhookUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url != null) {
      await prefs.setString('notification_webhook_url', url);
      log("Notification webhook URL saved: $url");
    } else {
      await prefs.remove('notification_webhook_url');
      log("Notification webhook URL removed");
    }
  }

  Future<String?> getNotificationWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notification_webhook_url');
  }

  Future<void> setNotificationRetentionDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_retention_days', days);
    log("Notification retention days saved: $days");
  }

  Future<int> getNotificationRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('notification_retention_days') ?? 30;
  }

  // Data observability settings
  Future<void> setDataObservabilityEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('data_observability_enabled', enabled);
    log("Data observability enabled: $enabled");
  }

  Future<bool> getDataObservabilityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('data_observability_enabled') ?? true;
  }

  Future<void> setHealthCheckInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('health_check_interval', minutes);
    log("Health check interval saved: $minutes minutes");
  }

  Future<int> getHealthCheckInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('health_check_interval') ?? 30;
  }

  Future<void> setMeilisearchIndexSyncInterval(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('meilisearch_sync_interval', hours);
    log("Meilisearch sync interval saved: $hours hours");
  }

  Future<int> getMeilisearchIndexSyncInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('meilisearch_sync_interval') ?? 2;
  }

  /// Clears all visitor-related data from SharedPreferences
  Future<void> clearVisitorSessionData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Clear visitor identification data
      await prefs.remove('visitorId');
      await prefs.remove('search_visitor_id');
      await prefs.remove('visitor_log');

      // Clear visitor details
      await prefs.remove('visitor_name');
      await prefs.remove('visitor_mobile');
      await prefs.remove('visitor_coming_from');
      await prefs.remove('uploaded_image_url');
      await prefs.remove('dialoguePurpose');

      // Clear any cached search results
      await prefs.remove('last_search_result');
      await prefs.remove('last_search_mobile');

      // Clear any session-specific data
      await prefs.remove('current_visitor_session');

      log("✅ Visitor session data cleared from SharedPreferences");
    } catch (e) {
      log("❌ Error clearing visitor session data: $e");
    }
  }
}
