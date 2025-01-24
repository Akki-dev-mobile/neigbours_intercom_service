import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorSettingsProvider with ChangeNotifier {
  bool visitorsAddress = false;
  bool membersApproval = false;
  bool gateIdToggleValue = false;
  bool visitorCardNumber = false;

  VisitorSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    visitorsAddress = prefs.getBool('visitorsAddress') ?? false;
    membersApproval = prefs.getBool('membersApproval') ?? false;
    gateIdToggleValue = prefs.getBool('gateIdToggleValue') ?? false;
    visitorCardNumber =
        prefs.getBool('visitorCardNumber') ?? false; // Load visitorCardNumber
    notifyListeners();
  }

  void updateVisitorsAddress(bool value) {
    visitorsAddress = value;
    notifyListeners();
  }

  void updateMembersApproval(bool value) {
    membersApproval = value;
    notifyListeners();
  }

  void updateGateIdToggleValue(bool value) {
    gateIdToggleValue = value;
    notifyListeners();
  }

  void updateVisitorCardNumber(bool value) {
    visitorCardNumber = value;
    notifyListeners();
  }

  bool hasChanges() {
    // Logic to determine if there are unsaved changes
    return true; // Placeholder for actual comparison logic
  }

  Future<void> saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('visitorsAddress', visitorsAddress);
    await prefs.setBool('membersApproval', membersApproval);
    await prefs.setBool('gateIdToggleValue', gateIdToggleValue);
    await prefs.setBool(
        'visitorCardNumber', visitorCardNumber); // Save visitorCardNumber
  }
}
