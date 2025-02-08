import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';

class LoginProvider extends ChangeNotifier {
  final AuthService authService;

  LoginProvider({required this.authService});

  bool isLoading = false;
  String? error;
  String? selectedSocietyId;

  Future<void> login() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final userInfo = await authService.login();
      if (userInfo == null) throw Exception('No user info received');

      final userId = userInfo["old_sso_user_id"];
      if (userId == null) throw Exception('No user ID found');

      final societies = await authService.fetchSocieties(userId);
      if (societies.isEmpty) throw Exception('No societies found for this user');

      if (societies.length == 1) {
        await _handleSingleSociety(societies.first);
      } else {
        selectedSocietyId = null;
        notifyListeners();
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleSingleSociety(Map<dynamic, dynamic> society) async {
    try {
      final societyId = society['company_id']?.toString();
      if (societyId == null || societyId.isEmpty) {
        throw Exception('Invalid society data');
      }

      await authService.gateStorage.saveSocietyId(societyId);
      selectedSocietyId = societyId;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}
