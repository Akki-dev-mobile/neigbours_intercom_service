import 'package:shared_preferences/shared_preferences.dart';

class Environment {
  static const String baseUrl = 'https://gateapi.cubeone.in';
  static const String societyBackendUrl = 'http://socbackend.cubeone.in/api';

  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken == null) {
      throw Exception('Access token not found. Please log in again.');
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }
}