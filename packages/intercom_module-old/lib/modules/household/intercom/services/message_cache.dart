import 'dart:developer';
import '../models/room_message_model.dart';

/// Cache entry for messages
class _CachedMessages {
  final List<RoomMessage> messages;
  final DateTime timestamp;
  final int companyId;
  final int offset;
  final int limit;

  _CachedMessages({
    required this.messages,
    required this.timestamp,
    required this.companyId,
    required this.offset,
    required this.limit,
  });

  bool isValid(int? currentCompanyId, {Duration? expiry}) {
    if (companyId != currentCompanyId) return false;
    final now = DateTime.now();
    final cacheExpiry =
        expiry ?? const Duration(minutes: 5); // Default 5 minutes
    return now.difference(timestamp) < cacheExpiry;
  }
}

/// Global message cache for chat rooms
///
/// Caches messages per room with offset/limit tracking
/// This prevents refetching messages that were already loaded
class MessageCache {
  static final MessageCache _instance = MessageCache._internal();
  factory MessageCache() => _instance;
  MessageCache._internal();

  // Cache: roomId -> List of cached message batches (by offset)
  final Map<String, Map<int, _CachedMessages>> _cache = {};

  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Get cached messages for a room at a specific offset
  List<RoomMessage>? getCachedMessages(
    String roomId,
    int companyId,
    int offset,
    int limit, {
    Duration? expiry,
  }) {
    final roomCache = _cache[roomId];
    if (roomCache == null) {
      _cacheMisses++;
      return null;
    }

    // Check if we have cached messages for this exact offset
    final cached = roomCache[offset];
    if (cached != null && cached.isValid(companyId, expiry: expiry)) {
      // Verify limit matches (or cached has more messages)
      if (cached.limit >= limit && cached.messages.length >= limit) {
        log('✅ [MessageCache] Cache hit for room $roomId at offset $offset (age: ${DateTime.now().difference(cached.timestamp).inSeconds}s)');
        _cacheHits++;
        // Return the requested number of messages
        return cached.messages.take(limit).toList();
      }
    }

    _cacheMisses++;
    return null;
  }

  /// Check if we have any cached messages for a room (any offset)
  bool hasCachedMessages(String roomId, int companyId) {
    final roomCache = _cache[roomId];
    if (roomCache == null) return false;

    // Check if any cached batch is valid
    for (final cached in roomCache.values) {
      if (cached.isValid(companyId)) {
        return true;
      }
    }
    return false;
  }

  /// Get all cached messages for a room (merged from all offsets)
  List<RoomMessage>? getAllCachedMessages(String roomId, int companyId) {
    final roomCache = _cache[roomId];
    if (roomCache == null) return null;

    final allMessages = <RoomMessage>[];
    for (final cached in roomCache.values) {
      if (cached.isValid(companyId)) {
        allMessages.addAll(cached.messages);
      }
    }

    if (allMessages.isEmpty) return null;

    // Sort by createdAt (oldest first)
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return allMessages;
  }

  /// Cache messages for a room
  void cacheMessages(
    String roomId,
    int companyId,
    int offset,
    int limit,
    List<RoomMessage> messages,
  ) {
    _cache.putIfAbsent(roomId, () => {})[offset] = _CachedMessages(
      messages: List.from(messages), // Store copy
      timestamp: DateTime.now(),
      companyId: companyId,
      offset: offset,
      limit: limit,
    );
    log('💾 [MessageCache] Cached ${messages.length} messages for room $roomId at offset $offset');
  }

  /// Clear cache for a specific room
  void clearRoomCache(String roomId) {
    _cache.remove(roomId);
    log('🗑️ [MessageCache] Cleared cache for room: $roomId');
  }

  /// Clear cache for a specific company
  void clearCompanyCache(int companyId) {
    _cache.removeWhere((key, value) {
      return value.values.any((cached) => cached.companyId == companyId);
    });
    log('🗑️ [MessageCache] Cleared cache for company ID: $companyId');
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    log('🗑️ [MessageCache] Cleared all cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'cached_rooms': _cache.length,
      'total_cached_batches':
          _cache.values.fold(0, (sum, batches) => sum + batches.length),
    };
  }
}
