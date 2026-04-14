import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/call_history_entry.dart';
import '../models/call_model.dart';
import '../models/call_status.dart';

/// Service responsible for persisting and exposing call history data.
class CallHistoryService {
  CallHistoryService._();

  static final CallHistoryService instance = CallHistoryService._();

  static const String _storageKey = 'intercom_call_history_entries';
  static const int _maxEntries = 120;

  final ValueNotifier<List<CallHistoryEntry>> _historyNotifier =
      ValueNotifier<List<CallHistoryEntry>>([]);

  bool _isLoaded = false;

  /// Listen to history updates.
  ValueListenable<List<CallHistoryEntry>> get historyListenable =>
      _historyNotifier;

  /// Ensure history is loaded from storage.
  Future<void> ensureInitialized() async {
    if (_isLoaded) return;
    await _loadFromStorage();
  }

  /// Force reload from storage.
  Future<void> reload() async {
    _isLoaded = false;
    await ensureInitialized();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson == null || rawJson.isEmpty) {
        _historyNotifier.value = const [];
        _isLoaded = true;
        return;
      }

      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final entries = decoded
            .whereType<Map<String, dynamic>>()
            .map(CallHistoryEntry.fromJson)
            .toList();
        final sorted = _sortDescending(entries);
        _historyNotifier.value = List.unmodifiable(sorted);
      } else {
        _historyNotifier.value = const [];
      }
    } catch (e) {
      debugPrint('CallHistoryService: failed to load history → $e');
      _historyNotifier.value = const [];
    } finally {
      _isLoaded = true;
    }
  }

  Future<void> recordCall({
    required Call call,
    required String contactName,
    required String contactPhone,
    String? contactAvatar,
  }) async {
    await ensureInitialized();
    final initiatedAt = call.createdAt ?? DateTime.now();
    final endedAt = call.updatedAt;
    final duration = _calculateDuration(initiatedAt, endedAt);

    final entry = CallHistoryEntry(
      callId: call.id,
      contactName: contactName,
      contactPhone: contactPhone,
      contactAvatar: contactAvatar,
      callType: call.callType,
      status: call.status,
      initiatedAt: initiatedAt,
      endedAt: endedAt,
      duration: duration,
    );

    await _addOrUpdate(entry);
  }

  Future<void> updateCallStatus({
    required int callId,
    required CallStatus status,
    DateTime? endedAt,
  }) async {
    await ensureInitialized();
    final entries = List<CallHistoryEntry>.from(_historyNotifier.value);
    final index = entries.indexWhere((entry) => entry.callId == callId);
    if (index == -1) return;

    final existing = entries[index];
    final resolvedEndedAt = endedAt ?? existing.endedAt;
    final duration = _calculateDuration(existing.initiatedAt, resolvedEndedAt);

    entries[index] = existing.copyWith(
      status: status,
      endedAt: resolvedEndedAt ?? existing.endedAt,
      duration: duration ?? existing.duration,
    );

    await _setEntries(entries);
  }

  Future<void> _addOrUpdate(CallHistoryEntry entry) async {
    final entries = List<CallHistoryEntry>.from(_historyNotifier.value);
    final existingIndex =
        entries.indexWhere((element) => element.callId == entry.callId);

    if (existingIndex != -1) {
      entries[existingIndex] = entry;
    } else {
      entries.insert(0, entry);
    }

    await _setEntries(entries);
  }

  Future<void> _setEntries(List<CallHistoryEntry> entries) async {
    final sorted = _sortDescending(entries);
    final trimmed = sorted.take(_maxEntries).toList();
    _historyNotifier.value = List.unmodifiable(trimmed);
    await _persist(trimmed);
  }

  Future<void> _persist(List<CallHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<CallHistoryEntry> _sortDescending(List<CallHistoryEntry> entries) {
    final copy = List<CallHistoryEntry>.from(entries);
    copy.sort((a, b) => b.initiatedAt.compareTo(a.initiatedAt));
    return copy;
  }

  Duration? _calculateDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final duration = end.difference(start);
    return duration.isNegative ? null : duration;
  }
}
