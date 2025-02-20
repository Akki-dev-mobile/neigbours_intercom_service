import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraSettingsProvider extends ChangeNotifier {
  String _selectedCameraValue = 'back'; // Default to back camera

  String get selectedCameraValue => _selectedCameraValue;

  CameraSettingsProvider() {
    _loadCameraSetting();
  }

  Future<void> _loadCameraSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedCameraValue =
        prefs.getString('selected_camera') ?? 'back'; // Default to back
    notifyListeners();
  }

  Future<void> updateCameraValue(String value) async {
    _selectedCameraValue = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_camera', value);
    notifyListeners();
  }
}
