import 'package:shared_preferences/shared_preferences.dart';

class RouteTracker {
  static const String _lastRouteKey = 'last_route_before_internet_loss';
  static const String _isExpressEntryKey = 'is_express_entry_route';

  /// Save the current route information before internet loss
  static Future<void> saveCurrentRoute(String routeName,
      {bool isExpressEntry = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRouteKey, routeName);
    await prefs.setBool(_isExpressEntryKey, isExpressEntry);
  }

  /// Get the last route before internet loss
  static Future<String?> getLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastRouteKey);
  }

  /// Check if the last route was express entry
  static Future<bool> wasExpressEntryRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isExpressEntryKey) ?? false;
  }

  /// Clear the saved route information
  static Future<void> clearSavedRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastRouteKey);
    await prefs.remove(_isExpressEntryKey);
  }
}
