import 'dart:developer';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';

class AuthService {
  final KeycloakWrapper keycloakWrapper;
  final GateStorage gateStorage;
  final RemoteDataSource remoteDataSource;

  AuthService({
    required this.keycloakWrapper,
    required this.gateStorage,
    required this.remoteDataSource,
  }) {
    _initializeKeycloak();
  }

  Future<void> _initializeKeycloak() async {
    try {
      await keycloakWrapper.initialize();
      log("✅ Keycloak initialized successfully");
    } catch (e) {
      log('❌ Error initializing Keycloak: $e');
      throw Exception('Failed to initialize Keycloak: $e');
    }
  }

  Future<Map<String, dynamic>?> login() async {
    if (!keycloakWrapper.isInitialized) {
      log('❌ Keycloak is not initialized, retrying...');
      await _initializeKeycloak();
    }

    final isLoggedIn = await keycloakWrapper.login();
    if (!isLoggedIn || keycloakWrapper.accessToken == null) {
      throw Exception('Login failed');
    }

    final userInfo = await keycloakWrapper.getUserInfo();
    log("🔑 Access token: ${keycloakWrapper.accessToken}");
    await _saveUserData(userInfo);
    return userInfo;
  }

  /// ✅ **Implement fetchSocieties**
  Future<List<dynamic>> fetchSocieties(String userId) async {
    try {
      return await remoteDataSource.fetchSocieties(userId);
    } catch (e) {
      log('❌ Error fetching societies: $e');
      throw Exception('Failed to fetch societies: $e');
    }
  }

  Future<void> _saveUserData(Map<String, dynamic>? userInfo) async {
    if (userInfo == null) return;
    await gateStorage.saveAccessToken(keycloakWrapper.accessToken!);
    await gateStorage.saveUserId(userInfo["old_sso_user_id"] ?? "");
    await gateStorage.saveUsername(userInfo["preferred_username"] ?? "");
  }
}
