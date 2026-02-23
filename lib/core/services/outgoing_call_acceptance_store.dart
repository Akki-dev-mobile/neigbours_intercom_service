import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists outgoing call acceptance intent across isolates / app resume.
///
/// This is used to bridge `FirebaseMessaging.onBackgroundMessage` (background
/// isolate) to the UI isolate so the caller can close the outgoing UI and join
/// Jitsi after the app returns to foreground.
class OutgoingCallAcceptanceStore {
  static const String _logName = 'OutgoingCallAcceptStore';
  static const String _key = 'pending_outgoing_call_accepted_v1';
  static const String _perCallKeyPrefix = 'pending_call_accepted_';
  static const String _keyCallEnded = 'pending_call_ended_v1';
  static const Duration _maxAge = Duration(minutes: 2);

  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    const allowed = <String>{
      'action',
      'call_id',
      'callId',
      'callID',
      'callid',
      'call-id',
      'id',
      'call_type',
      'callType',
      'meeting_id',
      'meetingId',
      'meetingid',
      'meeting-id',
      'jitsi_url',
      'jitsiUrl',
      'call_status',
      'status',
    };

    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      if (!allowed.contains(entry.key)) continue;
      if (entry.value == null) continue;
      sanitized[entry.key] = entry.value;
    }
    return sanitized;
  }

  static Future<void> save(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = <String, dynamic>{
        'ts_ms': DateTime.now().millisecondsSinceEpoch,
        'data': _sanitize(data),
      };
      await prefs.setString(_key, jsonEncode(envelope));
      log('✅ [$_logName] Saved pending call_accepted');
    } catch (e) {
      log('⚠️ [$_logName] Failed to save pending call_accepted: $e');
    }
  }

  /// Background isolate cannot update UI-isolate state. Persist acceptance per
  /// call id so UI isolate can pick it up on next resume.
  static Future<void> saveForCallId(String callId, Map<String, dynamic> data) async {
    final normalized = callId.trim();
    if (normalized.isEmpty) {
      await save(data);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = <String, dynamic>{
        'ts_ms': DateTime.now().millisecondsSinceEpoch,
        'data': _sanitize(data),
      };
      await prefs.setString(
        '$_perCallKeyPrefix$normalized',
        jsonEncode(envelope),
      );
      log('✅ [$_logName] Saved pending call_accepted key=$_perCallKeyPrefix$normalized');
    } catch (e) {
      log('⚠️ [$_logName] Failed to save pending call_accepted(per-call): $e');
    }
  }

  static Future<void> clearForCallId(String callId) async {
    final normalized = callId.trim();
    if (normalized.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_perCallKeyPrefix$normalized');
    } catch (_) {
      // ignore
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // ignore
    }
  }

  static Future<Map<String, dynamic>?> readIfFresh() async {
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
      final ts = (tsMs is int)
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : null;
      if (ts == null ||
          DateTime.now().difference(ts) > _maxAge) {
        await prefs.remove(_key);
        return null;
      }

      final dataRaw = decoded?['data'];
      if (dataRaw is! Map) {
        await prefs.remove(_key);
        return null;
      }

      return Map<String, dynamic>.from(dataRaw);
    } catch (e) {
      log('⚠️ [$_logName] Failed to load pending call_accepted: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> readIfFreshForCallId(String callId) async {
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
      final ts = (tsMs is int)
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : null;
      if (ts == null || DateTime.now().difference(ts) > _maxAge) {
        await prefs.remove('$_perCallKeyPrefix$normalized');
        return null;
      }

      final dataRaw = decoded?['data'];
      if (dataRaw is! Map) {
        await prefs.remove('$_perCallKeyPrefix$normalized');
        return null;
      }

      return Map<String, dynamic>.from(dataRaw);
    } catch (e) {
      log('⚠️ [$_logName] Failed to load pending call_accepted(per-call): $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> takeIfFresh() async {
    final data = await readIfFresh();
    if (data == null) return null;
    await clear();
    return data;
  }

  static Future<Map<String, dynamic>?> takeIfFreshForCallId(String callId) async {
    final data = await readIfFreshForCallId(callId);
    if (data == null) return null;
    await clearForCallId(callId);
    return data;
  }

  // --- Pending "call ended" (receiver rejected / call ended) for UI-isolate replay ---

  /// Persist call_ended/call_declined from background FCM so UI isolate can close outgoing screen on resume.
  static Future<void> saveCallEnded(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = <String, dynamic>{
        'ts_ms': DateTime.now().millisecondsSinceEpoch,
        'data': _sanitize(data),
      };
      await prefs.setString(_keyCallEnded, jsonEncode(envelope));
      log('✅ [$_logName] Saved pending call_ended');
    } catch (e) {
      log('⚠️ [$_logName] Failed to save pending call_ended: $e');
    }
  }

  /// Load and clear pending call_ended if still fresh (used on app resume).
  static Future<Map<String, dynamic>?> takeCallEndedIfFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCallEnded);
      if (raw == null || raw.isEmpty) return null;

      Map<String, dynamic>? decoded;
      try {
        final obj = jsonDecode(raw);
        if (obj is Map) decoded = Map<String, dynamic>.from(obj);
      } catch (_) {
        decoded = null;
      }

      final tsMs = decoded?['ts_ms'];
      final ts =
          (tsMs is int) ? DateTime.fromMillisecondsSinceEpoch(tsMs) : null;
      if (ts == null || DateTime.now().difference(ts) > _maxAge) {
        await prefs.remove(_keyCallEnded);
        return null;
      }

      final dataRaw = decoded?['data'];
      if (dataRaw is! Map) {
        await prefs.remove(_keyCallEnded);
        return null;
      }

      await prefs.remove(_keyCallEnded);
      return Map<String, dynamic>.from(dataRaw);
    } catch (e) {
      log('⚠️ [$_logName] Failed to load pending call_ended: $e');
      return null;
    }
  }

  /// Load and clear any fresh per-call accept payloads (used on app resume).
  static Future<List<Map<String, dynamic>>> takeAllIfFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final acceptKeys =
          keys.where((k) => k.startsWith(_perCallKeyPrefix)).toList();
      if (acceptKeys.isEmpty) return const [];

      final results = <Map<String, dynamic>>[];
      for (final key in acceptKeys) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) {
          await prefs.remove(key);
          continue;
        }

        Map<String, dynamic>? decoded;
        try {
          final obj = jsonDecode(raw);
          if (obj is Map) decoded = Map<String, dynamic>.from(obj);
        } catch (_) {
          decoded = null;
        }

        final tsMs = decoded?['ts_ms'];
        final ts = (tsMs is int)
            ? DateTime.fromMillisecondsSinceEpoch(tsMs)
            : null;
        if (ts == null || DateTime.now().difference(ts) > _maxAge) {
          await prefs.remove(key);
          continue;
        }

        final dataRaw = decoded?['data'];
        if (dataRaw is! Map) {
          await prefs.remove(key);
          continue;
        }

        results.add(Map<String, dynamic>.from(dataRaw));
        await prefs.remove(key);
      }
      return results;
    } catch (e) {
      log('⚠️ [$_logName] Failed to load pending per-call accept payloads: $e');
      return const [];
    }
  }
}
