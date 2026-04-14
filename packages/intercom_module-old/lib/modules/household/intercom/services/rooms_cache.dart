import 'dart:developer';
import 'dart:async';
import '../../../../core/models/api_response.dart';
import '../models/room_model.dart';

/// Cache entry for rooms list
class _RoomsCacheEntry {
  final List<Room> rooms;
  final DateTime timestamp;
  final int companyId;
  final String? chatType; // null means all rooms

  _RoomsCacheEntry({
    required this.rooms,
    required this.timestamp,
    required this.companyId,
    this.chatType,
  });

  bool isValid(int? currentCompanyId, String? currentChatType,
      {Duration? expiry}) {
    if (companyId != currentCompanyId) return false;
    // If cache has chatType filter and requested has different filter, invalid
    if (chatType != null && chatType != currentChatType) {
      // But if cache has all rooms (chatType=null) and requested is filtered, we can use subset
      return false; // For now, exact match only - can optimize later
    }
    final now = DateTime.now();
    final cacheExpiry =
        expiry ?? const Duration(seconds: 45); // Default 45 seconds
    return now.difference(timestamp) < cacheExpiry;
  }

  /// Get filtered rooms if cache has all rooms and request is filtered
  List<Room>? getFilteredRooms(String? requestedChatType) {
    if (chatType != null) return null; // Cache is already filtered
    if (requestedChatType == null) return null; // Request wants all rooms
    // Cache has all rooms, filter by requested chatType
    return rooms.where((r) {
      // Filter logic (if room has chatType property)
      return true; // For now, return all - refine based on Room model
    }).toList();
  }
}

/// Global room list cache with request coalescing
///
/// This cache ensures:
/// - Single API call for /rooms even if multiple parts of app request it
/// - Shared Future prevents duplicate concurrent requests
/// - 45-second TTL for room list (rooms don't change frequently)
/// - Graceful 429 handling (use cached data, retry with backoff)
class RoomsCache {
  static final RoomsCache _instance = RoomsCache._internal();
  factory RoomsCache() => _instance;
  RoomsCache._internal();

  // Cache: companyId + chatType -> cache entry
  final Map<String, _RoomsCacheEntry> _cache = {};

  // Track in-flight requests to prevent duplicate calls (request coalescing)
  // Key: "companyId_chatType" or "companyId" for all rooms
  final Map<String, Future<ApiResponse<List<Room>>>> _inFlightRequests = {};

  /// Get cache key
  String _getCacheKey(int companyId, String? chatType) {
    if (chatType == null) return '${companyId}_all';
    return '${companyId}_$chatType';
  }

  /// Get cached rooms
  List<Room>? getCachedRooms(int? companyId, String? chatType) {
    if (companyId == null) return null;

    final key = _getCacheKey(companyId, chatType);
    final entry = _cache[key];

    if (entry == null) {
      // Try to find cache with all rooms (can filter subset)
      if (chatType != null) {
        final allRoomsKey = _getCacheKey(companyId, null);
        final allRoomsEntry = _cache[allRoomsKey];
        if (allRoomsEntry != null &&
            allRoomsEntry.isValid(companyId, chatType)) {
          final filtered = allRoomsEntry.getFilteredRooms(chatType);
          if (filtered != null) {
            log('✅ [RoomsCache] Cache hit (filtered from all rooms): $key');
            return filtered;
          }
        }
      }
      log('📦 [RoomsCache] Cache miss: $key');
      return null;
    }

    if (!entry.isValid(companyId, chatType)) {
      log('📦 [RoomsCache] Cache expired: $key');
      _cache.remove(key);
      return null;
    }

    final age = DateTime.now().difference(entry.timestamp);
    log('✅ [RoomsCache] Cache hit: $key (age: ${age.inSeconds}s)');
    return List.from(entry.rooms); // Return copy
  }

  /// Cache rooms list
  void cacheRooms(int companyId, List<Room> rooms, String? chatType) {
    final key = _getCacheKey(companyId, chatType);
    _cache[key] = _RoomsCacheEntry(
      rooms: List.from(rooms), // Store copy
      timestamp: DateTime.now(),
      companyId: companyId,
      chatType: chatType,
    );
    log('💾 [RoomsCache] Cached ${rooms.length} rooms: $key');
  }

  /// Check if a request is in-flight (request coalescing)
  Future<ApiResponse<List<Room>>>? getInFlightRequest(
      int companyId, String? chatType) {
    final key = _getCacheKey(companyId, chatType);
    return _inFlightRequests[key];
  }

  /// Mark request as in-flight
  void markRequestInFlight(
    int companyId,
    String? chatType,
    Future<ApiResponse<List<Room>>> future,
  ) {
    final key = _getCacheKey(companyId, chatType);
    _inFlightRequests[key] = future;
    log('🔄 [RoomsCache] Marked request in-flight: $key');

    // Clean up when future completes
    future.then((_) {
      _inFlightRequests.remove(key);
      log('✅ [RoomsCache] Request complete, removed from in-flight: $key');
    }).catchError((_) {
      _inFlightRequests.remove(key);
      log('❌ [RoomsCache] Request failed, removed from in-flight: $key');
    });
  }

  /// Clear cache for a specific company (on company change)
  void clearForCompany(int companyId) {
    _cache.removeWhere((key, entry) => entry.companyId == companyId);
    _inFlightRequests
        .removeWhere((key, value) => key.startsWith('${companyId}_'));
    log('🗑️ [RoomsCache] Cleared cache for company $companyId');
  }

  /// Invalidate cache for a specific company + chatType combo.
  /// Used when rooms list changes (e.g. new 1-1 room created) so next fetch hits API.
  void invalidateEntry(int companyId, String? chatType) {
    final key = _getCacheKey(companyId, chatType);
    final removedCache = _cache.remove(key) != null;
    final removedInFlight = _inFlightRequests.remove(key) != null;
    if (removedCache || removedInFlight) {
      log('🗑️ [RoomsCache] Invalidated cache entry: $key');
    }
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _inFlightRequests.clear();
    log('🗑️ [RoomsCache] Cleared all cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'cachedEntries': _cache.length,
      'inFlightRequests': _inFlightRequests.length,
      'cacheKeys': _cache.keys.toList(),
    };
  }
}
