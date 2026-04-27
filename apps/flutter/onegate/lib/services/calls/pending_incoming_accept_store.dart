import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class PendingIncomingAcceptStore {
  PendingIncomingAcceptStore._();

  static const String _key = 'pending_incoming_call_accept_v1';
  static const Duration _ttl = Duration(minutes: 2);

  static Future<void> save(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'saved_at_ms': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    };
    await prefs.setString(_key, jsonEncode(data));
    log(
      '💾 [PendingIncomingAcceptStore] Saved pending accept '
      'call_id=${payload['call_id'] ?? payload['callId'] ?? "-"}',
    );
  }

  static Future<Map<String, dynamic>?> takeIfFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }
      final ts = decoded['saved_at_ms'];
      final payload = decoded['payload'];
      if (ts is! int || payload is! Map) {
        await clear();
        return null;
      }
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age < 0 || age > _ttl.inMilliseconds) {
        log(
          '⏭️ [PendingIncomingAcceptStore] Pending accept stale ageMs=$age; clearing',
        );
        await clear();
        return null;
      }
      await clear();
      return Map<String, dynamic>.from(payload);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
