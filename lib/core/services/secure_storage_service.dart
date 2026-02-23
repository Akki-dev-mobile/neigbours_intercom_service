import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<int?> getKeycloakTokenLifetime() async {
    // Host apps can store this if they need it.
    return null;
  }
}

