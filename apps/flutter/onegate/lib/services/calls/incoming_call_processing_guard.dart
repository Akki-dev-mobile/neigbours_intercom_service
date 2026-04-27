import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class IncomingCallProcessingGuard {
  IncomingCallProcessingGuard._();

  static const String _callIdKey = 'incoming_call_guard.call_id';
  static const String _timestampKey = 'incoming_call_guard.timestamp_ms';

  static Future<bool> tryStart(
    String callId, {
    Duration ttl = const Duration(seconds: 60),
  }) async {
    if (callId.trim().isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existingCallId = prefs.getString(_callIdKey);
    final existingTimestamp = prefs.getInt(_timestampKey) ?? 0;
    final ageMs = now - existingTimestamp;

    if (existingCallId == callId && ageMs >= 0 && ageMs < ttl.inMilliseconds) {
      log(
        '⏭️ [IncomingCallGuard] Duplicate blocked call_id=$callId ageMs=$ageMs ttlMs=${ttl.inMilliseconds}',
      );
      return false;
    }

    await prefs.setString(_callIdKey, callId);
    await prefs.setInt(_timestampKey, now);
    log('🔒 [IncomingCallGuard] Started call_id=$callId ttlMs=${ttl.inMilliseconds}');
    return true;
  }

  static Future<void> clear([String? callId]) async {
    final prefs = await SharedPreferences.getInstance();
    final existingCallId = prefs.getString(_callIdKey);
    if (callId != null && callId.isNotEmpty && existingCallId != callId) {
      log(
        'ℹ️ [IncomingCallGuard] Skip clear for call_id=$callId active=$existingCallId',
      );
      return;
    }

    await prefs.remove(_callIdKey);
    await prefs.remove(_timestampKey);
    log('🧹 [IncomingCallGuard] Cleared call_id=${callId ?? existingCallId ?? "-"}');
  }

  /// Returns true when a fresh incoming guard lock exists for this call id.
  /// Useful for background/killed terminal events where in-memory call state
  /// may not still be `ringing`.
  static Future<bool> isActive(
    String callId, {
    Duration ttl = const Duration(seconds: 60),
  }) async {
    if (callId.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final existingCallId = prefs.getString(_callIdKey);
    final existingTimestamp = prefs.getInt(_timestampKey) ?? 0;
    if (existingCallId != callId) return false;

    final ageMs = DateTime.now().millisecondsSinceEpoch - existingTimestamp;
    if (ageMs < 0 || ageMs > ttl.inMilliseconds) return false;
    return true;
  }
}
