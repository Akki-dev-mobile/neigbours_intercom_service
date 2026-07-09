import 'dart:developer';

import '../../../../core/utils/profile_data_helper.dart';
import '../models/room_info_model.dart';
import 'room_info_cache.dart';

/// Shared avatar extraction, normalization, and lookup for chat + Group Info.
class MemberAvatarResolver {
  MemberAvatarResolver._();

  static final Set<String> _loggedMissingAvatars = <String>{};

  static const List<String> _directAvatarFields = <String>[
    'avatar',
    'avatar_url',
    'profile_image',
    'profile_image_url',
    'user_avatar',
  ];

  static const List<String> _snapshotAvatarFields = <String>[
    'avatar',
    'avatar_url',
    'profile_image',
    'profile_image_url',
  ];

  /// Extract the first non-empty avatar URL from a member JSON payload.
  static ({String? url, String? source}) extractAvatarFromJson(
    Map<String, dynamic> json,
  ) {
    for (final field in _directAvatarFields) {
      final value = _nonEmptyString(json[field]);
      if (value != null) {
        return (url: value, source: field);
      }
    }

    final snapshot = json['user_snapshot'];
    if (snapshot is Map) {
      final snapshotMap = _toStringKeyMap(snapshot);
      for (final field in _snapshotAvatarFields) {
        final value = _nonEmptyString(snapshotMap[field]);
        if (value != null) {
          return (url: value, source: 'user_snapshot.$field');
        }
      }
    }

    return (url: null, source: null);
  }

  /// Normalize a raw avatar value to a loadable URL when possible.
  static String? normalizeAvatarUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return ProfileDataHelper.buildAvatarUrlFromUserId(trimmed);
    }

    final sanitized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return ProfileDataHelper.resolveAvatarUrl({'avatar': sanitized});
  }

  /// Build avatar + ID maps from members (used by RoomInfoCache and Group Info).
  static ({
    Map<String, String> avatarCache,
    Map<int, String> numericIdToUuidMap,
    Map<String, int> uuidToNumericIdMap,
    int avatarCount,
  }) buildMapsFromMembers(List<RoomInfoMember> members) {
    final avatarCache = <String, String>{};
    final numericIdToUuidMap = <int, String>{};
    final uuidToNumericIdMap = <String, int>{};

    for (final member in members) {
      final normalized = normalizeAvatarUrl(member.avatar);
      if (normalized != null && normalized.isNotEmpty) {
        avatarCache[member.userId] = normalized;
        if (member.numericUserId != null) {
          avatarCache[member.numericUserId!.toString()] = normalized;
        }
      }

      if (member.numericUserId != null) {
        numericIdToUuidMap[member.numericUserId!] = member.userId;
        uuidToNumericIdMap[member.userId] = member.numericUserId!;
      }
    }

    final uniqueUrls = <String>{};
    for (final url in avatarCache.values) {
      uniqueUrls.add(url);
    }

    return (
      avatarCache: avatarCache,
      numericIdToUuidMap: numericIdToUuidMap,
      uuidToNumericIdMap: uuidToNumericIdMap,
      avatarCount: uniqueUrls.length,
    );
  }

  /// Resolve avatar for a member using member field + RoomInfoCache.
  static String? resolveForMember({
    required String roomId,
    int? companyId,
    required RoomInfoMember member,
    bool logResolution = false,
  }) {
    final fromMember = normalizeAvatarUrl(member.avatar);
    if (fromMember != null) {
      if (logResolution) {
        log(
          '[GroupInfo] avatar resolved userId=${member.userId}, '
          'snapshotUserId=${member.numericUserId}, source=member.avatar',
        );
      }
      return fromMember;
    }

    final cache = RoomInfoCache();
    final avatars = cache.getCachedAvatars(roomId, companyId);
    if (avatars == null || avatars.isEmpty) {
      logMissingAvatarOnce(
        userId: member.userId,
        snapshotUserId: member.numericUserId,
      );
      return null;
    }

    String? resolved;
    String? source;

    if (member.userId.isNotEmpty && avatars[member.userId]?.isNotEmpty == true) {
      resolved = normalizeAvatarUrl(avatars[member.userId]);
      source = 'cache.uuid';
    }

    if ((resolved == null || resolved.isEmpty) && member.numericUserId != null) {
      final numericKey = member.numericUserId!.toString();
      if (avatars[numericKey]?.isNotEmpty == true) {
        resolved = normalizeAvatarUrl(avatars[numericKey]);
        source = 'cache.snapshot_user_id';
      }
    }

    if ((resolved == null || resolved.isEmpty) && member.numericUserId != null) {
      final uuidMap = cache.getCachedNumericIdToUuidMap(roomId, companyId);
      final mappedUuid = uuidMap?[member.numericUserId!];
      if (mappedUuid != null && avatars[mappedUuid]?.isNotEmpty == true) {
        resolved = normalizeAvatarUrl(avatars[mappedUuid]);
        source = 'cache.mapped_uuid';
      }
    }

    if (resolved != null && resolved.isNotEmpty) {
      if (logResolution) {
        log(
          '[GroupInfo] avatar resolved userId=${member.userId}, '
          'snapshotUserId=${member.numericUserId}, source=$source',
        );
      }
      return resolved;
    }

    logMissingAvatarOnce(
      userId: member.userId,
      snapshotUserId: member.numericUserId,
    );
    return null;
  }

  static void logMissingAvatarOnce({
    required String userId,
    int? snapshotUserId,
  }) {
    final key = '$userId:${snapshotUserId ?? ''}';
    if (_loggedMissingAvatars.contains(key)) return;
    _loggedMissingAvatars.add(key);
    log(
      '[GroupInfo] avatar missing userId=$userId '
      'snapshotUserId=${snapshotUserId ?? 'null'}',
    );
  }

  static String? _nonEmptyString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }

  static Map<String, dynamic> _toStringKeyMap(Map map) {
    if (map is Map<String, dynamic>) return map;
    return map.map((key, value) => MapEntry(key.toString(), value));
  }
}
