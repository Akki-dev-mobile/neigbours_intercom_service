import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class PendingCallCallbackStore {
  PendingCallCallbackStore._();

  static const String _key = 'pending_call_callback_v1';
  static const Duration _ttl = Duration(minutes: 5);

  static Future<void> save(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = <String, dynamic>{
        'ts_ms': DateTime.now().millisecondsSinceEpoch,
        'data': payload,
      };
      await prefs.setString(_key, jsonEncode(envelope));
      log(
        '💾 [PendingCallCallbackStore] saved call_id=${payload['call_id'] ?? payload['id'] ?? "-"}',
      );
    } catch (e) {
      log('⚠️ [PendingCallCallbackStore] save failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> consumeIfFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final tsMs = map['ts_ms'];
      final dataRaw = map['data'];
      if (tsMs is! int || dataRaw is! Map) {
        await clear();
        return null;
      }
      final age = DateTime.now().millisecondsSinceEpoch - tsMs;
      if (age < 0 || age > _ttl.inMilliseconds) {
        await clear();
        return null;
      }
      await clear();
      return Map<String, dynamic>.from(dataRaw);
    } catch (e) {
      log('⚠️ [PendingCallCallbackStore] consume failed: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
