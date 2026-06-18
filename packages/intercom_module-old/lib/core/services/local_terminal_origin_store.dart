import 'package:shared_preferences/shared_preferences.dart';

/// Tracks call ids whose terminal events were emitted locally so push/WS
/// handlers can ignore duplicate remote terminal notifications.
class LocalTerminalOriginStore {
  LocalTerminalOriginStore._();

  static const _prefix = 'local_terminal_origin_';
  static const _ttl = Duration(seconds: 20);

  static Future<void> markEmittedLocally(String callId) async {
    final normalized = callId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_prefix$normalized',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<bool> wasRecentlyEmittedLocally(String callId) async {
    final normalized = callId.trim();
    if (normalized.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final atMs = prefs.getInt('$_prefix$normalized');
    if (atMs == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - atMs;
    if (age > _ttl.inMilliseconds) {
      await prefs.remove('$_prefix$normalized');
      return false;
    }
    return true;
  }
}
