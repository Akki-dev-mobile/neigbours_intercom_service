import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';

/// Debug helper to diagnose login flow issues
class LoginDebugHelper {
  static Future<void> logCurrentState() async {
    try {
      dev.log('🔍 === LOGIN DEBUG STATE ===');
      
      final prefs = await SharedPreferences.getInstance();
      final gateStorage = GateStorage();
      await gateStorage.init();
      
      // Check authentication state
      final accessToken = await gateStorage.getAccessToken();
      final refreshToken = await gateStorage.getRefreshToken();
      final isTokenExpired = await gateStorage.isTokenExpired();
      
      dev.log('🔑 Access Token: ${accessToken != null ? "Present" : "Missing"}');
      dev.log('🔄 Refresh Token: ${refreshToken != null ? "Present" : "Missing"}');
      dev.log('⏰ Token Expired: $isTokenExpired');
      
      // Check user data
      final userId = await gateStorage.getUserId();
      final username = await gateStorage.getUsername();
      final role = await gateStorage.getRole();
      final societyId = await gateStorage.getSocietyId();
      
      dev.log('👤 User ID: $userId');
      dev.log('👤 Username: $username');
      dev.log('🎭 Role: $role');
      dev.log('🏢 Society ID: $societyId');
      
      // Check gate selection
      final selectedGate = prefs.getString('selected_gate');
      final selectedGateId = prefs.getString('selected_gate_id');
      final selectedGateType = prefs.getString('selected_gate_type');
      final hasNavigatedToGateSettings = prefs.getBool('hasNavigatedToGateSettings');
      
      dev.log('🚪 Selected Gate: $selectedGate');
      dev.log('🆔 Selected Gate ID: $selectedGateId');
      dev.log('🏷️ Selected Gate Type: $selectedGateType');
      dev.log('⚙️ Has Navigated to Gate Settings: $hasNavigatedToGateSettings');
      
      // Check all stored keys for debugging
      final allKeys = prefs.getKeys();
      dev.log('🗝️ All SharedPreferences keys: ${allKeys.toList()}');
      
      dev.log('🔍 === END LOGIN DEBUG STATE ===');
      
    } catch (e) {
      dev.log('💥 Error in login debug: $e');
    }
  }
  
  static Future<void> clearAllLoginData() async {
    try {
      dev.log('🧹 Clearing all login data...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Clear authentication data
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('token_expiry');
      await prefs.remove('user_id');
      await prefs.remove('username');
      await prefs.remove('role');
      await prefs.remove('society_id');
      
      // Clear gate selection data
      await prefs.remove('selected_gate');
      await prefs.remove('selected_gate_id');
      await prefs.remove('selected_gate_type');
      await prefs.remove('hasNavigatedToGateSettings');
      
      dev.log('✅ All login data cleared');
      
    } catch (e) {
      dev.log('💥 Error clearing login data: $e');
    }
  }
  
  static Future<bool> isUserLoggedIn() async {
    try {
      final gateStorage = GateStorage();
      await gateStorage.init();
      
      final accessToken = await gateStorage.getAccessToken();
      final isTokenExpired = await gateStorage.isTokenExpired();
      final role = await gateStorage.getRole();
      
      final isLoggedIn = accessToken != null && !isTokenExpired && role != null;
      
      dev.log('🔐 User logged in: $isLoggedIn');
      dev.log('   - Has token: ${accessToken != null}');
      dev.log('   - Token expired: $isTokenExpired');
      dev.log('   - Has role: ${role != null}');
      
      return isLoggedIn;
      
    } catch (e) {
      dev.log('💥 Error checking login state: $e');
      return false;
    }
  }
  
  static Future<String?> getExpectedDestination() async {
    try {
      final gateStorage = GateStorage();
      await gateStorage.init();
      final prefs = await SharedPreferences.getInstance();
      
      final role = await gateStorage.getRole();
      final selectedGate = prefs.getString('selected_gate') ?? '';
      final hasNavigatedToGateSettings = prefs.getBool('hasNavigatedToGateSettings') ?? false;
      
      if (role == 'admin') {
        return 'AdminDashboardView';
      } else if (role == 'gatekeeper') {
        if (selectedGate.toLowerCase().contains('tower')) {
          return 'MissedApprovalsScreen2 (Tower)';
        } else {
          if (!hasNavigatedToGateSettings) {
            return 'VisitorSettingsView (First time)';
          } else {
            return 'GateDashboardView';
          }
        }
      }
      
      return 'Unknown destination for role: $role';
      
    } catch (e) {
      dev.log('💥 Error getting expected destination: $e');
      return 'Error determining destination';
    }
  }
}
