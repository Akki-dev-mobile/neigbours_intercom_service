import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraSettingsProvider with ChangeNotifier {
  static String _selectedCameraValue = 'back';
  static const String _cameraPreferenceKey = 'selected_camera';

  CameraSettingsProvider() {
    _loadCameraSettings();
  }

  String get selectedCameraValue => _selectedCameraValue;

  Future<void> _loadCameraSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedCameraValue = prefs.getString(_cameraPreferenceKey) ?? '';
    notifyListeners();
  }

  Future<void> updateCameraValue(String value) async {
    _selectedCameraValue = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cameraPreferenceKey, value);
  }
}