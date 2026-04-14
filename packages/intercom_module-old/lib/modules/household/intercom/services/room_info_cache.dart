import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import '../models/room_info_model.dart';

/// Room Refresh Coordinator - Prevents multiple redundant refreshes per room
/// Solves over-refresh, over-notify, over-invalidate problems
class RoomRefreshCoordinator {
  static final RoomRefreshCoordinator _instance = RoomRefreshCoordinator._internal();
  factory RoomRefreshCoordinator() => _instance;
  RoomRefreshCoordinator._internal();

  // Track refresh state per room
  final Map<String, _RefreshState> _refreshStates = {};

  // Track recent optimistic updates to coordinate with refresh coordinator
  final Map<String, DateTime> _recentOptimisticUpdates = {};


  // Minimum interval between any refreshes for same room
  static const Duration _minRefreshInterval = Duration(milliseconds: 500);

  /// Request a room refresh with coordination
  /// Returns true if refresh was scheduled/started, false if debounced
  Future<bool> requestRefresh({
    required String roomId,
    required String source,
    required Future<void> Function() refreshAction,
    bool skipIfOptimisticUpdate = false,
    String? successToastTitle,
    String? successToastMessage,
  }) async {
    final state = _getOrCreateState(roomId);

    // Check if we can refresh
    if (!state.canRefresh(source)) {
      log('⏸️ [RefreshCoordinator] Debounced refresh for room $roomId from $source (last: ${state.lastRefreshSource})');
      return false;
    }

    // Check optimistic update skip
    if (skipIfOptimisticUpdate && _wasRecentlyOptimisticallyUpdated(roomId)) {
      log('⚡ [RefreshCoordinator] Skipping refresh for room $roomId - optimistic update recent');
      return false;
    }

    try {
      state.startRefresh(source);
      log('🔄 [RefreshCoordinator] Starting refresh for room $roomId from $source');

      await refreshAction();

      // Show success toast only for direct user actions, not background/WebSocket
      if (source == 'user_action' && successToastTitle != null && successToastMessage != null) {
        // Import would be circular, so we'll handle toast in calling code
        log('✅ [RefreshCoordinator] Completed user-action refresh for room $roomId - toast should be shown by caller');
      } else {
        log('✅ [RefreshCoordinator] Completed refresh for room $roomId from $source');
      }
      return true;
    } catch (e) {
      log('❌ [RefreshCoordinator] Failed refresh for room $roomId from $source: $e');
      return false;
    } finally {
      state.endRefresh();
    }
  }

  /// Check if room was recently updated optimistically
  bool _wasRecentlyOptimisticallyUpdated(String roomId) {
    final updateTime = _recentOptimisticUpdates[roomId];
    if (updateTime == null) return false;

    final now = DateTime.now();
    // Consider "recent" as within the last 10 seconds (longer than refresh debounce)
    return now.difference(updateTime) < const Duration(seconds: 10);
  }

  /// Cancel any pending refresh for a room
  void cancelPendingRefresh(String roomId) {
    final state = _refreshStates[roomId];
    state?.pendingTimer?.cancel();
    state?.pendingTimer = null;
  }

  /// Check if refresh is currently in progress for a room
  bool isRefreshInProgress(String roomId) {
    return _refreshStates[roomId]?.isRefreshing ?? false;
  }

  _RefreshState _getOrCreateState(String roomId) {
    return _refreshStates.putIfAbsent(roomId, () => _RefreshState(roomId));
  }

  /// Track optimistic update (called by RoomInfoCache)
  void _trackOptimisticUpdate(String roomId) {
    _recentOptimisticUpdates[roomId] = DateTime.now();
  }

  /// Clean up old states (optional maintenance)
  void cleanup() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    _refreshStates.removeWhere((key, state) =>
      state.lastRefreshTime != null && state.lastRefreshTime!.isBefore(cutoff));
    _recentOptimisticUpdates.removeWhere((key, time) => time.isBefore(cutoff));
  }
}

class _RefreshState {
  final String roomId;
  bool isRefreshing = false;
  DateTime? lastRefreshTime;
  Timer? pendingTimer;
  String? lastRefreshSource;

  _RefreshState(this.roomId);

  bool canRefresh(String source) {
    final now = DateTime.now();

    // If currently refreshing, deny unless it's a higher priority source
    if (isRefreshing) {
      // User actions can interrupt background refreshes
      if (source == 'user_action' && (lastRefreshSource == 'background' || lastRefreshSource == 'websocket')) {
        return true;
      }
      return false;
    }

    // Check minimum interval
    if (lastRefreshTime != null) {
      final timeSinceLastRefresh = now.difference(lastRefreshTime!);
      if (timeSinceLastRefresh < RoomRefreshCoordinator._minRefreshInterval) {
        return false;
      }
    }

    return true;
  }

  void startRefresh(String source) {
    isRefreshing = true;
    lastRefreshTime = DateTime.now();
    lastRefreshSource = source;
  }

  void endRefresh() {
    isRefreshing = false;
    pendingTimer?.cancel();
    pendingTimer = null;
  }

  void scheduleDelayedRefresh(Duration delay, VoidCallback callback) {
    pendingTimer?.cancel();
    pendingTimer = Timer(delay, () {
      if (!isRefreshing) { // Only execute if not currently refreshing
        callback();
      }
    });
  }
}

/// Cache entry for RoomInfo
class _CachedRoomInfo {
  final RoomInfo roomInfo;
  final DateTime timestamp;
  final int companyId;
  final Map<String, String> avatarCache; // userId -> avatar URL
  final Map<int, String> numericIdToUuidMap; // numericId -> UUID
  final Map<String, int> uuidToNumericIdMap; // UUID -> numericId

  _CachedRoomInfo({
    required this.roomInfo,
    required this.timestamp,
    required this.companyId,
    required this.avatarCache,
    required this.numericIdToUuidMap,
    required this.uuidToNumericIdMap,
  });

  bool isValid(int? currentCompanyId, {Duration? expiry}) {
    if (companyId != currentCompanyId) return false;
    final now = DateTime.now();
    final cacheExpiry =
        expiry ?? const Duration(minutes: 3); // Default 3 minutes
    return now.difference(timestamp) < cacheExpiry;
  }
}

/// Global RoomInfo cache
///
/// Caches RoomInfo per room with:
/// - Parsed RoomInfo object
/// - Resolved avatars (userId -> avatar URL)
/// - Numeric ID to UUID mappings
/// - TTL: 3 minutes (configurable)
class RoomInfoCache {
  static final RoomInfoCache _instance = RoomInfoCache._internal();
  factory RoomInfoCache() => _instance;
  RoomInfoCache._internal();

  // Cache: roomId -> cached RoomInfo
  final Map<String, _CachedRoomInfo> _cache = {};
  // Track in-flight requests to prevent duplicates
  final Map<String, Future<RoomInfo?>> _inFlightRequests = {};
  // Track when members leave rooms - force fresh fetch for a period after member leaves
  final Map<String, DateTime> _memberLeaveTimestamps = {};

  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _inFlightDeduplications = 0;

  /// Get cached RoomInfo for a room
  /// Returns null if cache is invalid, expired, or if a member recently left (forcing fresh fetch)
  RoomInfo? getCachedRoomInfo(String roomId, int? companyId,
      {Duration? expiry}) {
    // CRITICAL FIX: If a member recently left this room, skip cache to force fresh API fetch
    // This ensures admins see updated member list immediately after someone leaves
    final leaveTimestamp = _memberLeaveTimestamps[roomId];
    if (leaveTimestamp != null) {
      final timeSinceLeave = DateTime.now().difference(leaveTimestamp);
      // Force fresh fetch for 30 seconds after a member leaves
      if (timeSinceLeave < const Duration(seconds: 30)) {
        log('🔄 [RoomInfoCache] Skipping cache for room $roomId - member left ${timeSinceLeave.inSeconds}s ago (forcing fresh fetch)');
        _cacheMisses++;
        return null;
      } else {
        // Clean up old leave timestamp after 30 seconds
        _memberLeaveTimestamps.remove(roomId);
      }
    }

    final cached = _cache[roomId];
    if (cached != null && cached.isValid(companyId, expiry: expiry)) {
      final age = DateTime.now().difference(cached.timestamp).inSeconds;
      log('✅ [RoomInfoCache] Cache hit for room $roomId (age: ${age}s)');
      _cacheHits++;
      return cached.roomInfo;
    }
    log('ℹ️ [RoomInfoCache] Cache miss for room $roomId');
    _cacheMisses++;
    return null;
  }

  /// Get cached avatars for a room
  Map<String, String>? getCachedAvatars(String roomId, int? companyId) {
    final cached = _cache[roomId];
    if (cached != null && cached.isValid(companyId)) {
      return Map.from(cached.avatarCache);
    }
    return null;
  }

  /// Get cached numeric ID to UUID mapping for a room
  Map<int, String>? getCachedNumericIdToUuidMap(String roomId, int? companyId) {
    final cached = _cache[roomId];
    if (cached != null && cached.isValid(companyId)) {
      return Map.from(cached.numericIdToUuidMap);
    }
    return null;
  }

  /// Get cached UUID to numeric ID mapping for a room
  Map<String, int>? getCachedUuidToNumericIdMap(String roomId, int? companyId) {
    final cached = _cache[roomId];
    if (cached != null && cached.isValid(companyId)) {
      return Map.from(cached.uuidToNumericIdMap);
    }
    return null;
  }

  /// Convenience: map a member UUID to numeric user ID using cached RoomInfo
  int? mapUuidToNumericId(String roomId, String uuid, int? companyId) {
    final cached = _cache[roomId];
    if (cached != null && cached.isValid(companyId)) {
      return cached.uuidToNumericIdMap[uuid];
    }
    return null;
  }

  /// Cache RoomInfo with processed data
  void cacheRoomInfo({
    required String roomId,
    required int companyId,
    required RoomInfo roomInfo,
    Map<String, String>? avatarCache,
    Map<int, String>? numericIdToUuidMap,
    Map<String, int>? uuidToNumericIdMap,
  }) {
    // Process avatars and mappings if not provided
    final processedAvatars = avatarCache ?? <String, String>{};
    final processedMappings = numericIdToUuidMap ?? <int, String>{};
    final processedUuidToNumericMap = uuidToNumericIdMap ?? <String, int>{};

    // If not provided, extract from roomInfo
    if (avatarCache == null || numericIdToUuidMap == null || uuidToNumericIdMap == null) {
      for (final member in roomInfo.members) {
        if (member.avatar != null && member.avatar!.isNotEmpty) {
          processedAvatars[member.userId] = member.avatar!;
          if (member.numericUserId != null) {
            processedAvatars[member.numericUserId!.toString()] = member.avatar!;
            processedMappings[member.numericUserId!] = member.userId;
            processedUuidToNumericMap[member.userId] = member.numericUserId!;
          }
        }
        if (member.numericUserId != null) {
          processedMappings[member.numericUserId!] = member.userId;
          processedUuidToNumericMap[member.userId] = member.numericUserId!;
        }
      }
    }

    _cache[roomId] = _CachedRoomInfo(
      roomInfo: roomInfo,
      timestamp: DateTime.now(),
      companyId: companyId,
      avatarCache: processedAvatars,
      numericIdToUuidMap: processedMappings,
      uuidToNumericIdMap: processedUuidToNumericMap,
    );
    log('💾 [RoomInfoCache] Cached RoomInfo for room $roomId (${roomInfo.memberCount} members, ${processedAvatars.length} avatars)');
  }

  /// Track an in-flight request for RoomInfo
  Future<RoomInfo?> trackInFlightRequest(
      String roomId, Future<RoomInfo?> future) {
    _inFlightRequests[roomId] = future;
    future.whenComplete(() {
      _inFlightRequests.remove(roomId);
    });
    return future;
  }

  /// Get an in-flight request for RoomInfo
  Future<RoomInfo?>? getInFlightRequest(String roomId) {
    final request = _inFlightRequests[roomId];
    if (request != null) {
      log('⏸️ [RoomInfoCache] Deduplicating in-flight request for room $roomId');
      _inFlightDeduplications++;
    }
    return request;
  }

  /// Clear cache for a specific room
  void clearRoomCache(String roomId) {
    _cache.remove(roomId);
    _inFlightRequests.remove(roomId);
    log('🗑️ [RoomInfoCache] Cleared cache for room: $roomId');
  }

  /// Mark that a member left a room - forces fresh API fetch for next 30 seconds
  /// This ensures admins see updated member list immediately after someone leaves
  void markMemberLeft(String roomId) {
    _memberLeaveTimestamps[roomId] = DateTime.now();
    log('🚪 [RoomInfoCache] Marked member left for room $roomId - will force fresh fetch for 30s');
  }

  /// Clear cache for a specific company
  void clearCompanyCache(int companyId) {
    _cache.removeWhere((key, value) => value.companyId == companyId);
    _inFlightRequests.removeWhere((key, value) {
      // Note: Can't check companyId from Future, so clear all in-flight for safety
      return true;
    });
    log('🗑️ [RoomInfoCache] Cleared cache for company ID: $companyId');
  }

  /// Optimistically add members to cached RoomInfo
  /// This updates the UI immediately without waiting for API refresh
  void addMembersOptimistically({
    required String roomId,
    required List<RoomInfoMember> newMembers,
  }) {
    // Track optimistic update for refresh coordination
    _trackOptimisticUpdate(roomId);
    final cached = _cache[roomId];
    if (cached == null) {
      log('⚠️ [RoomInfoCache] Cannot add members optimistically - no cached RoomInfo for room $roomId');
      return;
    }

    // Create updated RoomInfo with new members
    final updatedMembers = List<RoomInfoMember>.from(cached.roomInfo.members);
    updatedMembers.addAll(newMembers);

    final updatedRoomInfo = RoomInfo(
      id: cached.roomInfo.id,
      name: cached.roomInfo.name,
      description: cached.roomInfo.description,
      createdBy: cached.roomInfo.createdBy,
      createdAt: cached.roomInfo.createdAt,
      lastActive: cached.roomInfo.lastActive,
      memberCount: cached.roomInfo.memberCount + newMembers.length,
      admin: cached.roomInfo.admin,
      members: updatedMembers,
    );

    // Update avatar cache and mappings for new members
    final updatedAvatarCache = Map<String, String>.from(cached.avatarCache);
    final updatedNumericIdToUuidMap =
        Map<int, String>.from(cached.numericIdToUuidMap);
    final updatedUuidToNumericIdMap =
        Map<String, int>.from(cached.uuidToNumericIdMap);

    for (final member in newMembers) {
      if (member.avatar != null && member.avatar!.isNotEmpty) {
        updatedAvatarCache[member.userId] = member.avatar!;
        if (member.numericUserId != null) {
          updatedAvatarCache[member.numericUserId!.toString()] = member.avatar!;
          updatedNumericIdToUuidMap[member.numericUserId!] = member.userId;
          updatedUuidToNumericIdMap[member.userId] = member.numericUserId!;
        }
      }
      if (member.numericUserId != null) {
        updatedNumericIdToUuidMap[member.numericUserId!] = member.userId;
        updatedUuidToNumericIdMap[member.userId] = member.numericUserId!;
      }
    }

    // Update cache with optimistic data
    _cache[roomId] = _CachedRoomInfo(
      roomInfo: updatedRoomInfo,
      timestamp: DateTime.now(), // Fresh timestamp to reflect optimistic update
      companyId: cached.companyId,
      avatarCache: updatedAvatarCache,
      numericIdToUuidMap: updatedNumericIdToUuidMap,
      uuidToNumericIdMap: updatedUuidToNumericIdMap,
    );

    // Track optimistic update for refresh coordination
    _trackOptimisticUpdate(roomId);

    log('⚡ [RoomInfoCache] Optimistically added ${newMembers.length} members to room $roomId (new count: ${updatedRoomInfo.memberCount})');
  }

  /// Remove a specific member from cached RoomInfo (selective invalidation)
  /// This updates the cached data immediately without full cache clearing
  void removeMemberOptimistically({
    required String roomId,
    required String memberUserId,
  }) {
    final cached = _cache[roomId];
    if (cached == null) {
      log('⚠️ [RoomInfoCache] Cannot remove member optimistically - no cached RoomInfo for room $roomId');
      return;
    }

    // Filter out the removed member
    final updatedMembers = cached.roomInfo.members
        .where((member) => member.userId != memberUserId)
        .toList();

    // Only update if member was actually found and removed
    if (updatedMembers.length < cached.roomInfo.members.length) {
      final updatedRoomInfo = RoomInfo(
        id: cached.roomInfo.id,
        name: cached.roomInfo.name,
        description: cached.roomInfo.description,
        createdBy: cached.roomInfo.createdBy,
        createdAt: cached.roomInfo.createdAt,
        lastActive: cached.roomInfo.lastActive,
        memberCount: cached.roomInfo.memberCount - 1, // Decrement count
        admin: cached.roomInfo.admin,
        members: updatedMembers,
      );

      // Remove from avatar cache
      cached.avatarCache.remove(memberUserId);
      // Remove numeric ID mapping if it exists
      final numericIdToRemove = cached.numericIdToUuidMap.entries
          .where((entry) => entry.value == memberUserId)
          .map((entry) => entry.key)
          .toList();
      for (final numericId in numericIdToRemove) {
        cached.avatarCache.remove(numericId.toString());
        cached.numericIdToUuidMap.remove(numericId);
        cached.uuidToNumericIdMap.remove(memberUserId);
      }

      // Update cache with optimistic data
      _cache[roomId] = _CachedRoomInfo(
        roomInfo: updatedRoomInfo,
        timestamp: DateTime.now(), // Fresh timestamp to reflect optimistic update
        companyId: cached.companyId,
        avatarCache: cached.avatarCache,
        numericIdToUuidMap: cached.numericIdToUuidMap,
        uuidToNumericIdMap: cached.uuidToNumericIdMap,
      );

      // Track optimistic update for refresh coordination
      _trackOptimisticUpdate(roomId);

      log('⚡ [RoomInfoCache] Optimistically removed member $memberUserId from room $roomId (new count: ${updatedRoomInfo.memberCount})');
    } else {
      log('⚠️ [RoomInfoCache] Member $memberUserId not found in cached RoomInfo for room $roomId');
    }
  }

  /// Mark a room's cache as stale (lazy invalidation)
  /// This doesn't clear the cache immediately but marks it for refresh on next access
  void markStale(String roomId) {
    final cached = _cache[roomId];
    if (cached != null) {
      // Set timestamp to a very old date to force refresh on next access
      final staleTimestamp = DateTime.now().subtract(const Duration(hours: 1));
      _cache[roomId] = _CachedRoomInfo(
        roomInfo: cached.roomInfo,
        timestamp: staleTimestamp,
        companyId: cached.companyId,
        avatarCache: cached.avatarCache,
        numericIdToUuidMap: cached.numericIdToUuidMap,
        uuidToNumericIdMap: cached.uuidToNumericIdMap,
      );
      log('📅 [RoomInfoCache] Marked room $roomId as stale (will refresh on next access)');
    }
  }

  /// Track optimistic update for refresh coordination
  void _trackOptimisticUpdate(String roomId) {
    RoomRefreshCoordinator()._trackOptimisticUpdate(roomId);
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    _inFlightRequests.clear();
    log('🗑️ [RoomInfoCache] Cleared all cache');
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'in_flight_deduplications': _inFlightDeduplications,
      'cached_rooms': _cache.length,
      'in_flight_requests': _inFlightRequests.length,
    };
  }
}
