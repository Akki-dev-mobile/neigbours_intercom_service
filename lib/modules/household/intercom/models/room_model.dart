import 'package:flutter/foundation.dart';

/// Peer user snapshot for 1-to-1 chats (other participant; backend is source of truth).
/// Returned by GetRooms, GetAllRooms, GetGroupInfo as peer_user when member_count = 2.
class PeerUser {
  final int? userId;
  final String? userName;
  final String? userPhone;
  final String? avatar;
  final String? email;

  PeerUser({
    this.userId,
    this.userName,
    this.userPhone,
    this.avatar,
    this.email,
  });

  factory PeerUser.fromJson(Map<String, dynamic> json) {
    int? _int(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    String? _str(dynamic v) => v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
    return PeerUser(
      userId: _int(json['user_id']),
      userName: _str(json['user_name']),
      userPhone: _str(json['user_phone']),
      avatar: _str(json['avatar']),
      email: _str(json['email']),
    );
  }
}

/// Room model matching the API response structure
class Room {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final String createdBy;
  final int? createdByUserId; // Numeric user ID from API
  final int? membersCount; // Member count from API (members_count field)
  final int?
      unreadCount; // Unread message count for current user (unread_count field)
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActive;
  /// For 1-to-1 chats only: the other participant (peer); from backend peer_user.
  final PeerUser? peerUser;

  Room({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.createdBy,
    this.createdByUserId,
    this.membersCount,
    this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastActive,
    this.peerUser,
  });

  /// Create Room from JSON with resilient parsing for backend inconsistencies
  factory Room.fromJson(Map<String, dynamic> json) {
    return Room._fromJsonWithFallbacks(json, null);
  }

  /// Create Room from JSON with fallback values from original request
  factory Room.fromJsonWithFallbacks(
    Map<String, dynamic> json,
    CreateRoomRequest? originalRequest,
  ) {
    return Room._fromJsonWithFallbacks(json, originalRequest);
  }

  /// Internal method for parsing JSON with optional fallbacks
  factory Room._fromJsonWithFallbacks(
    Map<String, dynamic> json,
    CreateRoomRequest? originalRequest,
  ) {
    // Import developer for proper logging
    // Log the raw JSON for debugging backend issues
    if (json.isEmpty || json.values.any((v) => v == null)) {
      // Only log when there might be issues
      debugPrint('🔍 [Room.fromJson] Potentially problematic JSON: $json');
    }

    // Helper to safely parse integer
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Helper to safely parse string with fallback for backend inconsistencies
    String _parseStringResilient(dynamic value, String fieldName,
        {String? fallback}) {
      if (value == null) {
        if (fallback != null) {
          debugPrint(
              '⚠️ [Room.fromJson] Field "$fieldName" is null, using fallback: "$fallback"');
          return fallback;
        }
        // For debugging: log the entire JSON when a required field is missing
        debugPrint(
            '❌ [Room.fromJson] Required field "$fieldName" is null. Full JSON: $json');
        throw FormatException(
            'Required field "$fieldName" is null in Room JSON response. This indicates a backend API issue.');
      }
      if (value is String && value.isNotEmpty) return value;
      if (value is String && value.isEmpty && fallback != null) {
        debugPrint(
            '⚠️ [Room.fromJson] Field "$fieldName" is empty, using fallback: "$fallback"');
        return fallback;
      }
      return value.toString(); // Convert other types to string
    }

    // Helper to safely parse DateTime with fallback
    DateTime _parseDateTimeResilient(dynamic value, String fieldName,
        {DateTime? fallback}) {
      if (value == null) {
        if (fallback != null) {
          debugPrint(
              '⚠️ [Room.fromJson] DateTime field "$fieldName" is null, using fallback: $fallback');
          return fallback;
        }
        debugPrint(
            '❌ [Room.fromJson] Required DateTime field "$fieldName" is null. Full JSON: $json');
        throw FormatException(
            'Required DateTime field "$fieldName" is null in Room JSON response. This indicates a backend API issue.');
      }
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          if (fallback != null) {
            debugPrint(
                '⚠️ [Room.fromJson] Invalid DateTime "$value" for field "$fieldName", using fallback: $fallback');
            return fallback;
          }
          throw FormatException(
              'Invalid DateTime format for "$fieldName": $value');
        }
      }
      if (fallback != null) {
        debugPrint(
            '⚠️ [Room.fromJson] Unexpected type for DateTime field "$fieldName": ${value.runtimeType}, using fallback: $fallback');
        return fallback;
      }
      throw FormatException(
          'Expected String for DateTime field "$fieldName", got ${value.runtimeType}');
    }

    // Helper to safely parse optional DateTime
    DateTime? _parseOptionalDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('⚠️ [Room.fromJson] Invalid optional DateTime: $value');
          return null; // Return null for invalid optional DateTime
        }
      }
      return null;
    }

    // Current time as fallback for missing timestamps
    final now = DateTime.now();

    // Get fallbacks from original request if available
    final nameFallback = originalRequest?.name ?? 'Unnamed Group';
    final descriptionFallback = originalRequest?.description;

    // Optional peer_user for 1-to-1 chats (backend is source of truth)
    PeerUser? peerUser;
    final peerUserJson = json['peer_user'];
    if (peerUserJson != null && peerUserJson is Map) {
      try {
        final map = Map<String, dynamic>.from(
          peerUserJson.map((k, v) => MapEntry(k.toString(), v)),
        );
        peerUser = PeerUser.fromJson(map);
      } catch (_) {
        peerUser = null;
      }
    }

    return Room(
      // Use fallback values for critical fields that might be missing due to backend issues
      id: _parseStringResilient(json['id'], 'id',
          fallback: 'unknown-${now.millisecondsSinceEpoch}'),
      name: _parseStringResilient(json['name'], 'name', fallback: nameFallback),
      description: json['description'] as String? ?? descriptionFallback,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      createdBy: _parseStringResilient(json['created_by'], 'created_by',
          fallback: 'unknown-user'),
      createdByUserId: _parseInt(json['created_by_user_id']),
      membersCount:
          _parseInt(json['members_count']), // Parse members_count from API
      unreadCount:
          _parseInt(json['unread_count']), // Parse unread_count from API
      createdAt: _parseDateTimeResilient(json['created_at'], 'created_at',
          fallback: now),
      updatedAt: _parseDateTimeResilient(json['updated_at'], 'updated_at',
          fallback: now),
      lastActive: _parseOptionalDateTime(json['last_active']),
      peerUser: peerUser,
    );
  }

  /// Convert Room to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (lastActive != null) 'last_active': lastActive!.toIso8601String(),
    };
  }

  /// Create a copy with updated properties
  Room copyWith({
    String? id,
    String? name,
    String? description,
    String? photoUrl,
    String? createdBy,
    int? membersCount,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActive,
    PeerUser? peerUser,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      createdBy: createdBy ?? this.createdBy,
      membersCount: membersCount ?? this.membersCount,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActive: lastActive ?? this.lastActive,
      peerUser: peerUser ?? this.peerUser,
    );
  }

  @override
  String toString() {
    return 'Room{id: $id, name: $name, description: $description, createdBy: $createdBy}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Request model for creating a room
class CreateRoomRequest {
  final String name;
  final String? description;
  final int companyId;

  CreateRoomRequest({
    required this.name,
    this.description,
    required this.companyId,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name.trim(),
      'company_id': companyId,
    };
    if (description != null && description!.trim().isNotEmpty) {
      json['description'] = description!.trim();
    }
    return json;
  }

  /// Validate the request
  bool validate() {
    return name.trim().isNotEmpty && name.trim().length <= 255;
  }

  /// Get validation errors
  List<String> getValidationErrors() {
    final errors = <String>[];
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      errors.add('Group name is required');
    } else if (trimmedName.length > 255) {
      errors.add('Group name must be 255 characters or less');
    }
    if (description != null && description!.trim().length > 500) {
      errors.add('Description must be 500 characters or less');
    }
    return errors;
  }
}
