import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class PendingCallTerminalEventStore {
  PendingCallTerminalEventStore._();

  static const String _key = 'pending_call_terminal_event_v1';
  static const String _perCallKeyPrefix = 'pending_call_terminal_event_';
  static const Duration _ttl = Duration(minutes: 3);

  static Future<void> saveCallEnded(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final callId =
          payload['call_id']?.toString() ??
          payload['callId']?.toString() ??
          payload['id']?.toString() ??
          payload['uuid']?.toString();
      final envelope = <String, dynamic>{
        'ts_ms': DateTime.now().millisecondsSinceEpoch,
        'data': payload,
      };
      await prefs.setString(_key, jsonEncode(envelope));
      if (callId != null && callId.trim().isNotEmpty) {
        await prefs.setString(
          '$_perCallKeyPrefix${callId.trim()}',
          jsonEncode(envelope),
        );
      }
      log(
        '💾 [PendingCallTerminalEventStore] saved '
        'call_id=${payload['call_id'] ?? payload['callId'] ?? "-"}',
      );
    } catch (e) {
      log('⚠️ [PendingCallTerminalEventStore] save failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> consumePendingCallEnded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      Map<String, dynamic>? decoded;
      try {
        final obj = jsonDecode(raw);
        if (obj is Map) decoded = Map<String, dynamic>.from(obj);
      } catch (_) {
        decoded = null;
      }
      final tsMs = decoded?['ts_ms'];
      final dataRaw = decoded?['data'];
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
      final out = Map<String, dynamic>.from(dataRaw);
      log(
        '📦 [PendingCallTerminalEventStore] consumed '
        'call_id=${out['call_id'] ?? out['callId'] ?? "-"}',
      );
      return out;
    } catch (e) {
      log('⚠️ [PendingCallTerminalEventStore] consume failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> consumePendingCallEndedForCallId(
    String callId,
  ) async {
    final normalized = callId.trim();
    if (normalized.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_perCallKeyPrefix$normalized');
      if (raw == null || raw.isEmpty) return null;
      Map<String, dynamic>? decoded;
      try {
        final obj = jsonDecode(raw);
        if (obj is Map) decoded = Map<String, dynamic>.from(obj);
      } catch (_) {
        decoded = null;
      }
      final tsMs = decoded?['ts_ms'];
      final dataRaw = decoded?['data'];
      if (tsMs is! int || dataRaw is! Map) {
        await prefs.remove('$_perCallKeyPrefix$normalized');
        return null;
      }
      final age = DateTime.now().millisecondsSinceEpoch - tsMs;
      if (age < 0 || age > _ttl.inMilliseconds) {
        await prefs.remove('$_perCallKeyPrefix$normalized');
        return null;
      }
      await prefs.remove('$_perCallKeyPrefix$normalized');
      return Map<String, dynamic>.from(dataRaw);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasPendingForCallId(String callId) async {
    final pending = await _readIfFresh();
    if (pending == null) return false;
    final pendingId =
        pending['call_id']?.toString() ?? pending['callId']?.toString();
    return pendingId?.trim() == callId.trim();
  }

  static Future<Map<String, dynamic>?> _readIfFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    Map<String, dynamic>? decoded;
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) decoded = Map<String, dynamic>.from(obj);
    } catch (_) {
      decoded = null;
    }
    final tsMs = decoded?['ts_ms'];
    final dataRaw = decoded?['data'];
    if (tsMs is! int || dataRaw is! Map) {
      await clear();
      return null;
    }
    final age = DateTime.now().millisecondsSinceEpoch - tsMs;
    if (age < 0 || age > _ttl.inMilliseconds) {
      await clear();
      return null;
    }
    return Map<String, dynamic>.from(dataRaw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_perCallKeyPrefix)) {
        await prefs.remove(key);
      }
    }
    log('🧹 [PendingCallTerminalEventStore] cleared');
  }

  static Future<void> clearForCallId(String callId) async {
    final normalized = callId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_perCallKeyPrefix$normalized');
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return;
      final map = Map<String, dynamic>.from(obj);
      final dataRaw = map['data'];
      if (dataRaw is! Map) return;
      final data = Map<String, dynamic>.from(dataRaw);
      final globalId = data['call_id']?.toString() ??
          data['callId']?.toString() ??
          data['id']?.toString() ??
          data['uuid']?.toString();
      if (globalId?.trim() == normalized) {
        await prefs.remove(_key);
      }
    } catch (_) {
      // ignore malformed cache
    }
  }
}
