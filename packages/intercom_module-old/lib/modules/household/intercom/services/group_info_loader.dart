import 'dart:developer';

import '../models/room_info_model.dart';
import 'member_avatar_resolver.dart';
import 'room_info_cache.dart';
import 'room_service.dart';

/// Result of a Group Info network load (cache-first display is separate).
class GroupInfoLoadResult {
  final RoomInfo? roomInfo;
  final bool fromCache;
  final bool duplicateSkipped;
  final Duration? infoDuration;
  final Duration? membersDuration;
  final bool membersIncludedInInfo;
  final bool membersFetchAttempted;
  final int avatarCount;
  final String? error;

  const GroupInfoLoadResult({
    this.roomInfo,
    this.fromCache = false,
    this.duplicateSkipped = false,
    this.infoDuration,
    this.membersDuration,
    this.membersIncludedInInfo = false,
    this.membersFetchAttempted = false,
    this.avatarCount = 0,
    this.error,
  });
}

/// Coordinates Group Info fetches: single /info, conditional /members,
/// in-flight deduplication keyed by roomId + companyId.
class GroupInfoLoader {
  static final GroupInfoLoader _instance = GroupInfoLoader._internal();
  factory GroupInfoLoader() => _instance;
  GroupInfoLoader._internal();

  static const Duration displayCacheTtl = RoomInfoCache.defaultFreshTtl;

  final Map<String, Future<GroupInfoLoadResult>> _inFlightLoads = {};

  static String cacheKey(String roomId, int companyId) => '$roomId:$companyId';

  /// Cached RoomInfo for instant Group Info display (respects fresh TTL + company).
  RoomInfo? cachedForDisplay(String roomId, int companyId) {
    return RoomInfoCache().getCachedRoomInfo(
      roomId,
      companyId,
      expiry: displayCacheTtl,
    );
  }

  /// Slightly stale cache for immediate display while background refresh runs.
  RoomInfo? staleCachedForDisplay(String roomId, int companyId) {
    return RoomInfoCache().getStaleCachedRoomInfoForDisplay(
      roomId,
      companyId,
    );
  }

  int cachedAvatarCount(String roomId, int companyId) {
    return RoomInfoCache().getAvatarCount(roomId, companyId);
  }

  /// Fresh network load for Group Info. Dedupes concurrent loads per room/company.
  Future<GroupInfoLoadResult> loadFresh({
    required String roomId,
    required int companyId,
    required RoomService roomService,
    bool forceRefresh = true,
  }) async {
    final key = cacheKey(roomId, companyId);
    log('[GroupInfo] open room=$roomId company=$companyId');

    final inFlight = _inFlightLoads[key];
    if (inFlight != null) {
      log('[GroupInfo] skipped duplicate load for $key');
      final result = await inFlight;
      return GroupInfoLoadResult(
        roomInfo: result.roomInfo,
        fromCache: result.fromCache,
        duplicateSkipped: true,
        infoDuration: result.infoDuration,
        membersDuration: result.membersDuration,
        membersIncludedInInfo: result.membersIncludedInInfo,
        membersFetchAttempted: result.membersFetchAttempted,
        avatarCount: result.avatarCount,
        error: result.error,
      );
    }

    final future = _loadFreshInternal(
      roomId: roomId,
      companyId: companyId,
      roomService: roomService,
      forceRefresh: forceRefresh,
    );
    _inFlightLoads[key] = future;
    try {
      return await future;
    } finally {
      _inFlightLoads.remove(key);
    }
  }

  Future<GroupInfoLoadResult> _loadFreshInternal({
    required String roomId,
    required int companyId,
    required RoomService roomService,
    required bool forceRefresh,
  }) async {
    final cache = RoomInfoCache();
    if (!forceRefresh) {
      final cached = cache.getCachedRoomInfo(
        roomId,
        companyId,
        expiry: displayCacheTtl,
      );
      if (cached != null && cached.members.isNotEmpty) {
        final avatarCount = cache.getAvatarCount(roomId, companyId);
        log(
          '[GroupInfo] cache hit, cachedMembers=${cached.members.length}, '
          'avatarCount=$avatarCount',
        );
        return GroupInfoLoadResult(
          roomInfo: cached,
          fromCache: true,
          membersIncludedInInfo: true,
          avatarCount: avatarCount,
        );
      }
    }

    final infoStart = DateTime.now();
    final infoResponse = await roomService.getRoomInfo(
      roomId: roomId,
      companyId: companyId,
      fetchMembersIfMissing: false,
    );
    final infoDuration = DateTime.now().difference(infoStart);

    if (!infoResponse.success || infoResponse.data == null) {
      log(
        '⚠️ [GroupInfo] /info failed duration=${infoDuration.inMilliseconds}ms: '
        '${infoResponse.error}',
      );
      return GroupInfoLoadResult(
        infoDuration: infoDuration,
        error: infoResponse.error ?? infoResponse.displayError,
      );
    }

    var roomInfo = infoResponse.data!;
    final membersInInfo = roomInfo.members.isNotEmpty;
    log(
      '[GroupInfo] /info duration=${infoDuration.inMilliseconds}ms, '
      'membersIncluded=$membersInInfo, memberCount=${roomInfo.memberCount}',
    );

    Duration? membersDuration;
    var membersFetchAttempted = false;

    if (!membersInInfo && roomInfo.memberCount > 0) {
      membersFetchAttempted = true;
      final membersStart = DateTime.now();
      final membersResponse = await roomService.getRoomMembers(
        roomId: roomId,
        companyId: companyId,
      );
      membersDuration = DateTime.now().difference(membersStart);

      if (membersResponse.success &&
          membersResponse.data != null &&
          membersResponse.data!.isNotEmpty) {
        final members = membersResponse.data!;
        roomInfo = RoomInfo(
          id: roomInfo.id.isNotEmpty ? roomInfo.id : roomId,
          name: roomInfo.name,
          description: roomInfo.description,
          createdBy: roomInfo.createdBy,
          createdByUserId: roomInfo.createdByUserId,
          createdByUser: roomInfo.createdByUser,
          companyId: roomInfo.companyId,
          photoUrl: roomInfo.photoUrl,
          createdAt: roomInfo.createdAt,
          lastActive: roomInfo.lastActive,
          memberCount: roomInfo.memberCount,
          admin: roomInfo.admin,
          members: members,
          photos: roomInfo.photos,
          peerUser: roomInfo.peerUser,
        );
      }

      final maps = MemberAvatarResolver.buildMapsFromMembers(
        roomInfo.members,
      );
      log(
        '[GroupInfo] /members duration=${membersDuration.inMilliseconds}ms, '
        'memberCount=${roomInfo.members.length}, avatarCount=${maps.avatarCount}',
      );
    } else {
      final maps = MemberAvatarResolver.buildMapsFromMembers(roomInfo.members);
      log(
        '[GroupInfo] /members skipped, memberCount=${roomInfo.members.length}, '
        'avatarCount=${maps.avatarCount}',
      );
    }

    cache.applyRoomInfoUpdate(
      roomId: roomId,
      companyId: companyId,
      roomInfo: roomInfo,
    );

    final avatarCount = cache.getAvatarCount(roomId, companyId);
    return GroupInfoLoadResult(
      roomInfo: roomInfo,
      infoDuration: infoDuration,
      membersDuration: membersDuration,
      membersIncludedInInfo: membersInInfo,
      membersFetchAttempted: membersFetchAttempted,
      avatarCount: avatarCount,
    );
  }
}
