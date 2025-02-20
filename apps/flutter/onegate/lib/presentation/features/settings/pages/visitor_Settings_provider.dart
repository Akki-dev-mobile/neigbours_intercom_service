import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorSettingsProvider with ChangeNotifier {
  bool visitorsAddress = false;
  bool membersApproval = false;
  bool gateIdToggleValue = false;
  bool visitorCardNumber = false;

  // Store original values for change detection
  bool _originalVisitorsAddress = false;
  bool _originalMembersApproval = false;
  bool _originalGateIdToggleValue = false;
  bool _originalVisitorCardNumber = false;

  VisitorSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    visitorsAddress =
        _originalVisitorsAddress = prefs.getBool('visitorsAddress') ?? false;
    membersApproval =
        _originalMembersApproval = prefs.getBool('membersApproval') ?? false;
    gateIdToggleValue = _originalGateIdToggleValue =
        prefs.getBool('gateIdToggleValue') ?? false;
    visitorCardNumber = _originalVisitorCardNumber =
        prefs.getBool('visitorCardNumber') ?? false;

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

  /// Check if any setting has changed from the original values
  bool hasChanges() {
    return visitorsAddress != _originalVisitorsAddress ||
        membersApproval != _originalMembersApproval ||
        gateIdToggleValue != _originalGateIdToggleValue ||
        visitorCardNumber != _originalVisitorCardNumber;
  }

  Future<void> saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('visitorsAddress', visitorsAddress);
    await prefs.setBool('membersApproval', membersApproval);
    await prefs.setBool('gateIdToggleValue', gateIdToggleValue);
    await prefs.setBool('visitorCardNumber', visitorCardNumber);

    // Update original values after saving
    _originalVisitorsAddress = visitorsAddress;
    _originalMembersApproval = membersApproval;
    _originalGateIdToggleValue = gateIdToggleValue;
    _originalVisitorCardNumber = visitorCardNumber;

    notifyListeners();
  }
}
