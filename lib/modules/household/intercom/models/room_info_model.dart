import 'dart:developer' as developer;

/// Normalized room member key with all identifier types
/// This eliminates confusion between different ID formats used across the app
class RoomMemberKey {
  /// UUID user ID - primary identifier for chat messages, WebSocket, and UI selection
  final String userUuid;

  /// Legacy numeric room member ID (backend delete now expects member UUID)
  final int? roomMemberId;

  /// Numeric user ID - used for society APIs, avatar filenames, etc.
  final int? userNumericId;

  /// Display name for the member
  final String? username;

  /// Avatar URL
  final String? avatar;

  /// Whether this member is an admin
  final bool isAdmin;

  RoomMemberKey({
    required this.userUuid,
    this.roomMemberId,
    this.userNumericId,
    this.username,
    this.avatar,
    this.isAdmin = false,
  });

  /// Create from RoomInfoMember JSON
  /// Handles the different field mappings from backend
  factory RoomMemberKey.fromRoomInfoMemberJson(Map<String, dynamic> json) {
    // Helper function to safely convert to String
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    // Helper function to safely convert to nullable String
    String? _toStringNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    // Extract user UUID (primary identifier)
    final userUuid = _toString(json['user_id']);

    // Extract room member ID (used for DELETE /members/{id})
    int? roomMemberId;
    final idValue = json['id'];
    if (idValue != null) {
      if (idValue is int) {
        roomMemberId = idValue;
      } else if (idValue is String) {
        roomMemberId = int.tryParse(idValue);
      }
    }

    // Extract numeric user ID from various possible fields
    int? userNumericId;

    // Try snapshot_user_id first (most common)
    final snapshotUserId = json['snapshot_user_id'];
    if (snapshotUserId != null) {
      if (snapshotUserId is int) {
        userNumericId = snapshotUserId;
      } else if (snapshotUserId is String) {
        userNumericId = int.tryParse(snapshotUserId);
      }
    }

    // Fallback to user_snapshot.user_id
    if (userNumericId == null && json['user_snapshot'] != null) {
      final userSnapshot = json['user_snapshot'];
      if (userSnapshot is Map) {
        final snapshotMap = userSnapshot is Map<String, dynamic>
            ? userSnapshot
            : <String, dynamic>{
                ...userSnapshot.map((key, value) => MapEntry(key.toString(), value))
              };

        final userIdValue = snapshotMap['user_id'];
        if (userIdValue != null) {
          if (userIdValue is int) {
            userNumericId = userIdValue;
          } else if (userIdValue is String) {
            userNumericId = int.tryParse(userIdValue);
          }
        }
      }
    }

    // Extract username - prefer user_snapshot.user_name, fallback to direct field
    String? username;
    if (json['user_snapshot'] != null) {
      final userSnapshot = json['user_snapshot'];
      if (userSnapshot is Map) {
        final snapshotMap = userSnapshot is Map<String, dynamic>
            ? userSnapshot
            : <String, dynamic>{
                ...userSnapshot.map((key, value) => MapEntry(key.toString(), value))
              };
        username = _toStringNullable(snapshotMap['user_name']);
      }
    }
    if (username == null || username.isEmpty) {
      username = _toStringNullable(json['user_name']);
    }

    // Extract avatar - prefer user_snapshot.avatar, fallback to direct field
    String? avatar;
    if (json['user_snapshot'] != null) {
      final userSnapshot = json['user_snapshot'];
      if (userSnapshot is Map) {
        final snapshotMap = userSnapshot is Map<String, dynamic>
            ? userSnapshot
            : <String, dynamic>{
                ...userSnapshot.map((key, value) => MapEntry(key.toString(), value))
              };
        avatar = _toStringNullable(snapshotMap['avatar']);
      }
    }
    if (avatar == null || avatar.isEmpty) {
      avatar = _toStringNullable(json['avatar']);
    }

    // Extract admin status
    final isAdmin = json['is_admin'] is bool
        ? json['is_admin'] as bool
        : (json['is_admin'] is int
            ? (json['is_admin'] as int) != 0
            : (json['is_admin'] is String
                ? (json['is_admin'] as String).toLowerCase() == 'true'
                : false));

    return RoomMemberKey(
      userUuid: userUuid,
      roomMemberId: roomMemberId,
      userNumericId: userNumericId,
      username: username,
      avatar: avatar,
      isAdmin: isAdmin,
    );
  }

  /// Create from existing RoomInfoMember (for backward compatibility)
  factory RoomMemberKey.fromRoomInfoMember(RoomInfoMember member) {
    return RoomMemberKey(
      userUuid: member.userId,
      userNumericId: member.numericUserId,
      username: member.username,
      avatar: member.avatar,
      isAdmin: member.isAdmin,
      // Note: roomMemberId not available from RoomInfoMember, will be null
    );
  }

  /// Check if this member matches a given identifier
  bool matches(String identifier) {
    return userUuid == identifier ||
           roomMemberId?.toString() == identifier ||
           userNumericId?.toString() == identifier;
  }

  /// Get the appropriate ID for different use cases
  String get uiSelectionKey => userUuid; // UI selection uses UUID
  int? get removeApiKey => roomMemberId; // Legacy: remove API now uses userUuid
  int? get societyApiKey => userNumericId; // Society APIs use numeric user ID

  @override
  String toString() {
    return 'RoomMemberKey(uuid: $userUuid, roomMemberId: $roomMemberId, numericId: $userNumericId, name: $username)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoomMemberKey && other.userUuid == userUuid;
  }

  @override
  int get hashCode => userUuid.hashCode;
}

/// Room photo information
class RoomPhoto {
  final String id;
  final String roomId;
  final String photoUrl;
  final String uploadedBy;
  final bool isPrimary;
  final DateTime uploadedAt;

  RoomPhoto({
    required this.id,
    required this.roomId,
    required this.photoUrl,
    required this.uploadedBy,
    required this.isPrimary,
    required this.uploadedAt,
  });

  factory RoomPhoto.fromJson(dynamic json) {
    Map<String, dynamic> jsonMap;
    if (json is Map<String, dynamic>) {
      jsonMap = json;
    } else if (json is Map) {
      jsonMap = <String, dynamic>{};
      json.forEach((key, value) {
        jsonMap[key.toString()] = value;
      });
    } else {
      throw Exception('RoomPhoto.fromJson: Expected Map, got ${json.runtimeType}');
    }

    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    DateTime? _parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) {
          return DateTime.parse(value);
        }
        if (value is int) {
          if (value > 9999999999) {
            return DateTime.fromMillisecondsSinceEpoch(value);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(value * 1000);
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    }

    return RoomPhoto(
      id: _toString(jsonMap['id']),
      roomId: _toString(jsonMap['room_id']),
      photoUrl: _toString(jsonMap['photo_url']),
      uploadedBy: _toString(jsonMap['uploaded_by']),
      isPrimary: jsonMap['is_primary'] is bool ? jsonMap['is_primary'] as bool : false,
      uploadedAt: _parseDateTime(jsonMap['uploaded_at']) ?? DateTime.now(),
    );
  }
}

/// Room Info model for GET /api/v1/rooms/{roomId}/info response
class RoomInfo {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final int? createdByUserId;
  final RoomInfoUser? createdByUser;
  final int? companyId;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastActive;
  final int memberCount;
  final RoomInfoAdmin? admin;
  final List<RoomInfoMember> members;
  final List<RoomPhoto> photos;
  /// For 1-to-1 chats only: the other participant (peer); from backend peer_user.
  final RoomInfoUser? peerUser;

  RoomInfo({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.createdByUserId,
    this.createdByUser,
    this.companyId,
    this.photoUrl,
    required this.createdAt,
    this.lastActive,
    required this.memberCount,
    this.admin,
    required this.members,
    this.photos = const [],
    this.peerUser,
  });

  factory RoomInfo.fromJson(dynamic json) {
    // Convert to Map<String, dynamic> if needed
    Map<String, dynamic> jsonMap;
    if (json is Map<String, dynamic>) {
      jsonMap = json;
    } else if (json is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      jsonMap = <String, dynamic>{};
      json.forEach((key, value) {
        jsonMap[key.toString()] = value;
      });
    } else {
      throw Exception('RoomInfo.fromJson: Expected Map, got ${json.runtimeType}');
    }

    // Helper function to safely convert to String
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    // Helper function to safely parse DateTime
    DateTime? _parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) {
          return DateTime.parse(value);
        }
        if (value is int) {
          // Handle Unix timestamp (seconds or milliseconds)
          if (value > 9999999999) {
            return DateTime.fromMillisecondsSinceEpoch(value);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(value * 1000);
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    }

    // Helper to safely convert Map to Map<String, dynamic>
    Map<String, dynamic>? _toMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        final result = <String, dynamic>{};
        value.forEach((key, val) {
          result[key.toString()] = val;
        });
        return result;
      }
      return null;
    }

    return RoomInfo(
      id: _toString(jsonMap['id']),
      name: _toString(jsonMap['name']),
      description: jsonMap['description'] != null ? _toString(jsonMap['description']) : null,
      createdBy: _toString(jsonMap['created_by']),
      createdByUserId: jsonMap['created_by_user_id'] is int ? jsonMap['created_by_user_id'] as int : null,
      createdByUser: _toMap(jsonMap['created_by_user']) != null
          ? RoomInfoUser.fromJson(_toMap(jsonMap['created_by_user'])!)
          : null,
      companyId: jsonMap['company_id'] is int ? jsonMap['company_id'] as int : null,
      photoUrl: jsonMap['photo_url'] != null ? _toString(jsonMap['photo_url']) : null,
      createdAt: _parseDateTime(jsonMap['created_at']) ?? DateTime.now(),
      lastActive: _parseDateTime(jsonMap['last_active']),
      memberCount: jsonMap['member_count'] is int
          ? jsonMap['member_count'] as int
          : (jsonMap['member_count'] is String
              ? int.tryParse(jsonMap['member_count'] as String) ?? 0
              : 0),
      admin: _toMap(jsonMap['admin']) != null
          ? RoomInfoAdmin.fromJson(_toMap(jsonMap['admin'])!)
          : null,
      members: jsonMap['members'] != null && jsonMap['members'] is List
          ? (jsonMap['members'] as List)
              .map((item) => _toMap(item))
              .whereType<Map<String, dynamic>>()
              .map((item) => RoomInfoMember.fromJson(item))
              .where((member) => member.status == null || member.status == 'active') // Only show active members
              .toList()
          : <RoomInfoMember>[],
      photos: jsonMap['photos'] != null && jsonMap['photos'] is List
          ? (jsonMap['photos'] as List)
              .map((item) => _toMap(item))
              .whereType<Map<String, dynamic>>()
              .map((item) => RoomPhoto.fromJson(item))
              .toList()
          : <RoomPhoto>[],
      peerUser: _toMap(jsonMap['peer_user']) != null
          ? RoomInfoUser.fromJson(_toMap(jsonMap['peer_user'])!)
          : null,
    );
  }
}

/// User information for created_by_user field
class RoomInfoUser {
  final int? userId;
  final String? userName;
  final String? userPhone;
  final String? email;
  final String? avatar;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RoomInfoUser({
    this.userId,
    this.userName,
    this.userPhone,
    this.email,
    this.avatar,
    this.createdAt,
    this.updatedAt,
  });

  factory RoomInfoUser.fromJson(dynamic json) {
    Map<String, dynamic> jsonMap;
    if (json is Map<String, dynamic>) {
      jsonMap = json;
    } else if (json is Map) {
      jsonMap = <String, dynamic>{};
      json.forEach((key, value) {
        jsonMap[key.toString()] = value;
      });
    } else {
      throw Exception('RoomInfoUser.fromJson: Expected Map, got ${json.runtimeType}');
    }

    String? _toStringNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    DateTime? _parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) {
          return DateTime.parse(value);
        }
        if (value is int) {
          if (value > 9999999999) {
            return DateTime.fromMillisecondsSinceEpoch(value);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(value * 1000);
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    }

    return RoomInfoUser(
      userId: jsonMap['user_id'] is int ? jsonMap['user_id'] as int : null,
      userName: _toStringNullable(jsonMap['user_name']),
      userPhone: _toStringNullable(jsonMap['user_phone']),
      email: _toStringNullable(jsonMap['email']),
      avatar: _toStringNullable(jsonMap['avatar']),
      createdAt: _parseDateTime(jsonMap['created_at']),
      updatedAt: _parseDateTime(jsonMap['updated_at']),
    );
  }
}

/// Admin information in room info
class RoomInfoAdmin {
  final String? username;
  final String? email;
  final String? userId;

  RoomInfoAdmin({
    this.username,
    this.email,
    this.userId,
  });

  factory RoomInfoAdmin.fromJson(dynamic json) {
    // Convert to Map<String, dynamic> if needed
    Map<String, dynamic> jsonMap;
    if (json is Map<String, dynamic>) {
      jsonMap = json;
    } else if (json is Map) {
      jsonMap = <String, dynamic>{};
      json.forEach((key, value) {
        jsonMap[key.toString()] = value;
      });
    } else {
      throw Exception('RoomInfoAdmin.fromJson: Expected Map, got ${json.runtimeType}');
    }

    // Helper function to safely convert to String
    String? _toString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    return RoomInfoAdmin(
      username: _toString(jsonMap['username']),
      email: _toString(jsonMap['email']),
      userId: _toString(jsonMap['user_id']),
    );
  }
}

/// Member information in room info
class RoomInfoMember {
  final String userId; // UUID
  final int? roomMemberId; // Legacy numeric room member ID (DELETE now uses UUID)
  final String? username;
  final String? avatar;
  final bool isAdmin;
  final DateTime? joinedAt;
  final int? numericUserId; // Numeric user ID extracted from user_snapshot
  final String? status; // Member status: "active" or "inactive"

  RoomInfoMember({
    required this.userId,
    this.roomMemberId,
    this.username,
    this.avatar,
    required this.isAdmin,
    this.joinedAt,
    this.numericUserId,
    this.status,
  });

  /// Returns true if this member is the current signed-in user.
  /// Compares both UUID (userId) and numeric ID so "other member" (receiver) is correct
  /// regardless of how current user ID is stored (UUID from token vs numeric fallback).
  bool isCurrentUser(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    final c = currentUserId.trim();
    if (userId.trim() == c) return true;
    if (numericUserId != null && numericUserId.toString() == c) return true;
    return false;
  }

  factory RoomInfoMember.fromJson(dynamic json) {
    // Convert to Map<String, dynamic> if needed
    Map<String, dynamic> jsonMap;
    if (json is Map<String, dynamic>) {
      jsonMap = json;
    } else if (json is Map) {
      jsonMap = <String, dynamic>{};
      json.forEach((key, value) {
        jsonMap[key.toString()] = value;
      });
    } else {
      throw Exception('RoomInfoMember.fromJson: Expected Map, got ${json.runtimeType}');
    }

    // Helper function to safely convert to String
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    // Helper function to safely parse DateTime
    DateTime? _parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) {
          return DateTime.parse(value);
        }
        if (value is int) {
          // Handle Unix timestamp (seconds or milliseconds)
          if (value > 9999999999) {
            return DateTime.fromMillisecondsSinceEpoch(value);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(value * 1000);
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    }

    // Helper function to safely convert to nullable String
    String? _toStringNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    // Extract username - PREFER user_snapshot.user_name, fallback to direct user_name field
    // This ensures we use the most up-to-date name from user_snapshot
    String? extractedUsername;
    
    // Extract avatar - PREFER user_snapshot.avatar, fallback to direct avatar field
    String? extractedAvatar;
    
    // Extract room member ID (used for DELETE endpoint)
    int? extractedRoomMemberId;
    final idValue = jsonMap['id'];
    if (idValue != null) {
      if (idValue is int) {
        extractedRoomMemberId = idValue;
      } else if (idValue is String) {
        extractedRoomMemberId = int.tryParse(idValue);
      }
    }

    // Extract numeric user ID from user_snapshot for mapping
    int? extractedNumericUserId;
    
    // FIRST: Try user_snapshot (preferred source)
    if (jsonMap['user_snapshot'] != null) {
      final userSnapshot = jsonMap['user_snapshot'];
      if (userSnapshot is Map) {
        // Handle both Map<String, dynamic> and Map<dynamic, dynamic>
        final snapshotMap = userSnapshot is Map<String, dynamic>
            ? userSnapshot
            : <String, dynamic>{
                ...userSnapshot.map((key, value) => MapEntry(key.toString(), value))
              };
        
        // Prefer user_snapshot.user_name
        extractedUsername = _toStringNullable(snapshotMap['user_name']);
        if (extractedUsername != null && extractedUsername.isNotEmpty) {
          developer.log('✅ [RoomInfoMember] Found username in user_snapshot.user_name: $extractedUsername');
        }
        
        // Prefer user_snapshot.avatar
        extractedAvatar = _toStringNullable(snapshotMap['avatar']);
        if (extractedAvatar != null && extractedAvatar.isNotEmpty) {
          developer.log('✅ [RoomInfoMember] Found avatar in user_snapshot: $extractedAvatar');
        }
        
        // Extract numeric user_id from user_snapshot
        final userIdValue = snapshotMap['user_id'];
        if (userIdValue != null) {
          if (userIdValue is int) {
            extractedNumericUserId = userIdValue;
          } else if (userIdValue is String) {
            extractedNumericUserId = int.tryParse(userIdValue);
          }
        }
      }
    }
    
    // FALLBACK: If not found in user_snapshot, try direct fields
    if (extractedUsername == null || extractedUsername.isEmpty) {
      extractedUsername = _toStringNullable(jsonMap['user_name']);
      if (extractedUsername != null && extractedUsername.isNotEmpty) {
        developer.log('✅ [RoomInfoMember] Found username in direct user_name field: $extractedUsername');
      }
    }
    
    if (extractedAvatar == null || extractedAvatar.isEmpty) {
      extractedAvatar = _toStringNullable(jsonMap['avatar']);
      if (extractedAvatar != null && extractedAvatar.isNotEmpty) {
        developer.log('✅ [RoomInfoMember] Found avatar in direct field: $extractedAvatar');
      }
    }
    
    if (extractedAvatar == null || extractedAvatar.isEmpty) {
      developer.log('⚠️ [RoomInfoMember] No avatar found for user_id: ${_toString(jsonMap['user_id'])}');
      developer.log('   Available keys in jsonMap: ${jsonMap.keys.toList()}');
    }

    return RoomInfoMember(
      userId: _toString(jsonMap['user_id']),
      roomMemberId: extractedRoomMemberId,
      username: extractedUsername,
      avatar: extractedAvatar,
      numericUserId: extractedNumericUserId,
      isAdmin: jsonMap['is_admin'] is bool
          ? jsonMap['is_admin'] as bool
          : (jsonMap['is_admin'] is int
              ? (jsonMap['is_admin'] as int) != 0
              : (jsonMap['is_admin'] is String
                  ? (jsonMap['is_admin'] as String).toLowerCase() == 'true'
                  : false)),
      joinedAt: _parseDateTime(jsonMap['joined_at']),
      status: _toStringNullable(jsonMap['status']),
    );
  }
}
