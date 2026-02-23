import 'dart:convert';
import 'dart:developer';
import 'message_reaction_model.dart';

/// Room Message model matching the API response structure
class RoomMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar; // Avatar URL from API response
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final int? snapshotUserId; // Numeric user ID from snapshot_user_id field
  final String? replyTo; // ID of the message this is replying to
  final List<MessageReaction>
      reactions; // Reactions included in the API response
  final String? messageType; // Message type: "text", "system", "event", etc.
  final String? eventType; // Event type: "user_left", "message_deleted", etc.
  final bool isForwarded; // Indicates forwarded messages

  RoomMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.body,
    required this.createdAt,
    this.editedAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.snapshotUserId,
    this.replyTo,
    this.reactions = const [],
    this.messageType,
    this.eventType,
    this.isForwarded = false,
  });

  /// Create RoomMessage from JSON
  /// Handles null values gracefully to prevent type cast errors.
  /// Supports both flat message objects and nested payloads (e.g. { "message": { ... } } or { "data": { ... } })
  /// so that is_forwarded and other fields are preserved when the API wraps each message.
  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    try {
      // Normalize: if API returns each message wrapped (e.g. { "message": { id, content, is_forwarded } }),
      // use the inner map so is_forwarded and all fields are read correctly on re-fetch.
      Map<String, dynamic> raw = json;
      if (json.length == 1) {
        final inner = json['message'] ?? json['data'];
        if (inner is Map<String, dynamic>) {
          raw = inner;
        } else if (inner is Map) {
          raw = Map<String, dynamic>.from(
            inner.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      }

      bool parseBool(dynamic value) {
        if (value is bool) return value;
        if (value is num) return value == 1;
        if (value is String) {
          final v = value.toLowerCase();
          return v == 'true' || v == '1';
        }
        return false;
      }

      bool hasForwardMarker(Map<dynamic, dynamic>? map) {
        if (map == null || map.isEmpty) return false;
        final keys = map.keys.map((k) => k.toString().toLowerCase()).toSet();
        const forwardKeys = {
          'is_forwarded',
          'forwarded',
          'forward',
          'forwarded_from',
          'forwardedfrom',
          'forwarded_message_id',
          'forwardedmessageid',
          'forwarded_room_id',
          'original_room_id',
          'original_message_id',
          'forward_message_id',
          'forwardroomid',
        };
        if (keys.any(forwardKeys.contains)) return true;
        // Also check nested data map
        for (final entry in map.entries) {
          final value = entry.value;
          if (value is Map && hasForwardMarker(value)) return true;
        }
        return false;
      }

      // Parse id - required field, use empty string if null
      final id = raw['id']?.toString() ?? '';

      // Parse room_id - required field, use empty string if null
      final roomId = raw['room_id']?.toString() ?? '';

      // Parse sender_id/user_id - API returns 'user_id' but we use 'sender_id' internally
      // Handle both field names for compatibility
      final senderId =
          raw['user_id']?.toString() ?? raw['sender_id']?.toString() ?? '';

      // Parse sender_name - user_name is now guaranteed to be present in API response
      // Prioritize user_name since it's always populated, fallback to sender_name for compatibility
      // Also check user_snapshot if direct field is missing or empty
      String? senderName;

      // Try direct user_name field first (guaranteed to be present)
      final userName = raw['user_name']?.toString();
      if (userName != null && userName.isNotEmpty) {
        senderName = userName;
      } else {
        // Try sender_name as fallback
        final senderNameField = raw['sender_name']?.toString();
        if (senderNameField != null && senderNameField.isNotEmpty) {
          senderName = senderNameField;
        } else {
          // Try user_snapshot if direct fields are missing
          if (raw['user_snapshot'] != null) {
            final userSnapshot = raw['user_snapshot'];
            if (userSnapshot is Map) {
              final snapshotMap = userSnapshot is Map<String, dynamic>
                  ? userSnapshot
                  : <String, dynamic>{
                      ...userSnapshot
                          .map((key, value) => MapEntry(key.toString(), value))
                    };
              final snapshotUserName = snapshotMap['user_name']?.toString();
              if (snapshotUserName != null && snapshotUserName.isNotEmpty) {
                senderName = snapshotUserName;
              }
            }
          }
        }
      }

      // Final fallback - never use senderId (UUID) as name
      // Ensure senderName is never null and not a UUID
      if (senderName == null || senderName.isEmpty) {
        senderName = 'User';
      } else {
        // Reject UUID-like strings and "user_" prefixed UUIDs
        // Check if it starts with "user_" (common pattern for missing usernames)
        final isUserPrefixedUuid = senderName.startsWith('user_');
        // Check if it matches UUID pattern (8-4-4-4-12 format with hyphens)
        final uuidPattern = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false);
        final isUuidFormat = uuidPattern.hasMatch(senderName);
        // Also check if it's "user_" followed by UUID
        final isUserUuid = isUserPrefixedUuid &&
            senderName.length > 36 && // "user_" (5) + UUID (36) = 41
            uuidPattern.hasMatch(senderName.substring(5));

        if (isUuidFormat || isUserUuid || isUserPrefixedUuid) {
          log('⚠️ [RoomMessage] Rejected UUID-like senderName: $senderName, using "User" instead');
          senderName = 'User';
        }
      }

      // Parse sender_avatar - extract from multiple possible fields
      // API now includes 'avatar' field directly, also check user_snapshot
      String? senderAvatar;
      // Try direct 'avatar' field first (now guaranteed in API response)
      senderAvatar = raw['avatar']?.toString() ??
          raw['sender_avatar']?.toString() ??
          raw['photo_url']?.toString() ??
          raw['user_avatar']?.toString();

      // If not found, try user_snapshot field
      if (senderAvatar == null && raw['user_snapshot'] != null) {
        final userSnapshot = raw['user_snapshot'];
        if (userSnapshot is Map) {
          final snapshotMap = userSnapshot is Map<String, dynamic>
              ? userSnapshot
              : <String, dynamic>{
                  ...userSnapshot
                      .map((key, value) => MapEntry(key.toString(), value))
                };
          senderAvatar = snapshotMap['avatar']?.toString() ??
              snapshotMap['photo_url']?.toString() ??
              snapshotMap['sender_avatar']?.toString();
        }
      }

      // Only use non-empty strings
      if (senderAvatar != null && senderAvatar.isEmpty) {
        senderAvatar = null;
      }

      // Parse body/content - API returns 'content' but we use 'body' internally
      // Handle both field names for compatibility
      final body = raw['content']?.toString() ?? raw['body']?.toString() ?? '';

      // Parse created_at - required field, handle null gracefully
      DateTime createdAt;
      try {
        final createdAtStr = raw['created_at']?.toString();
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          createdAt = DateTime.parse(createdAtStr);
        } else {
          createdAt = DateTime.now();
        }
      } catch (e) {
        // If parsing fails, use current time
        createdAt = DateTime.now();
      }

      // Parse edited_at - optional field
      DateTime? editedAt;
      try {
        final editedAtStr = raw['edited_at']?.toString();
        if (editedAtStr != null && editedAtStr.isNotEmpty) {
          editedAt = DateTime.parse(editedAtStr);
        }
      } catch (e) {
        // Ignore parsing errors for optional field
        editedAt = null;
      }

      // Parse updated_at - optional field
      DateTime? updatedAt;
      try {
        final updatedAtStr = raw['updated_at']?.toString();
        if (updatedAtStr != null && updatedAtStr.isNotEmpty) {
          updatedAt = DateTime.parse(updatedAtStr);
        }
      } catch (e) {
        // Ignore parsing errors for optional field
        updatedAt = null;
      }

      // Parse is_deleted - optional field, defaults to false
      final isDeleted = raw['is_deleted'] as bool? ?? false;

      // Parse deleted_at - optional field
      DateTime? deletedAt;
      try {
        final deletedAtStr = raw['deleted_at']?.toString();
        if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
          deletedAt = DateTime.parse(deletedAtStr);
        }
      } catch (e) {
        // Ignore parsing errors for optional field
        deletedAt = null;
      }

      // Parse deleted_by - optional field
      final deletedBy = raw['deleted_by']?.toString();

      // Parse snapshot_user_id - optional numeric user ID
      int? snapshotUserId;
      try {
        final snapshotUserIdValue = raw['snapshot_user_id'];
        if (snapshotUserIdValue != null) {
          if (snapshotUserIdValue is int) {
            snapshotUserId = snapshotUserIdValue;
          } else if (snapshotUserIdValue is String) {
            snapshotUserId = int.tryParse(snapshotUserIdValue);
          }
        }
      } catch (e) {
        // Ignore parsing errors for optional field
        snapshotUserId = null;
      }

      // Parse reply_to - optional field for reply functionality
      // API may return 'reply_to' or 'parent_message_id' or nested in data
      String? replyTo;
      // Try direct field first
      replyTo = raw['reply_to']?.toString();
      // Try alternative field names
      if (replyTo == null || replyTo.isEmpty) {
        replyTo = raw['parent_message_id']?.toString();
      }
      if (replyTo == null || replyTo.isEmpty) {
        replyTo = raw['reply_to_id']?.toString();
      }
      // Try nested in data field if present
      if ((replyTo == null || replyTo.isEmpty) && raw['data'] != null) {
        final data = raw['data'];
        if (data is Map) {
          replyTo = data['reply_to']?.toString() ??
              data['parent_message_id']?.toString() ??
              data['reply_to_id']?.toString();
        }
      }
      // Only use non-empty strings
      if (replyTo != null && replyTo.isEmpty) {
        replyTo = null;
      }

      // Parse reactions - included in the messages API response
      List<MessageReaction> reactions = [];
      try {
        if (raw['reactions'] != null) {
          if (raw['reactions'] is List) {
            reactions = (raw['reactions'] as List)
                .map((item) {
                  try {
                    if (item is Map<String, dynamic>) {
                      return MessageReaction.fromJson(item);
                    }
                    return null;
                  } catch (e) {
                    log('⚠️ [RoomMessage] Error parsing reaction: $e');
                    return null;
                  }
                })
                .whereType<MessageReaction>()
                .toList();
          }
        }
      } catch (e) {
        log('⚠️ [RoomMessage] Error parsing reactions: $e');
        reactions = [];
      }

      // Parse message_type - used to identify system messages and event types
      String? messageType = raw['message_type']?.toString();
      if (messageType != null && messageType.isEmpty) {
        messageType = null;
      }

      // Parse event_type - used to identify specific events like "user_left", "message_deleted"
      String? eventType = raw['event_type']?.toString();
      if (eventType != null && eventType.isEmpty) {
        eventType = null;
      }

      // Also check in data field if present
      if ((messageType == null || eventType == null) && raw['data'] != null) {
        final data = raw['data'];
        if (data is Map) {
          if (messageType == null) {
            messageType = data['message_type']?.toString();
            if (messageType != null && messageType.isEmpty) {
              messageType = null;
            }
          }
          if (eventType == null) {
            eventType = data['event_type']?.toString();
            if (eventType != null && eventType.isEmpty) {
              eventType = null;
            }
          }
        }
      }

      bool isForwarded = false;
      dynamic forwardedRaw =
          raw['is_forwarded'] ?? raw['forwarded'] ?? raw['forward'];

      if (forwardedRaw != null) {
        isForwarded = parseBool(forwardedRaw);
      }

      // Check nested data map as well
      if (!isForwarded && raw['data'] != null) {
        dynamic dataField = raw['data'];

        // Handle if data is a JSON string
        if (dataField is String) {
          try {
            if (dataField.trim().startsWith('{') &&
                dataField.trim().endsWith('}')) {
              dataField = jsonDecode(dataField);
            }
          } catch (_) {}
        }

        if (dataField is Map) {
          final dataMap = dataField;
          if (dataMap.containsKey('is_forwarded')) {
            isForwarded = parseBool(dataMap['is_forwarded']);
          }
          // Look for common forward markers inside data
          if (!isForwarded && hasForwardMarker(dataMap)) {
            isForwarded = true;
          }
        }
      }

      // Check metadata field if present (some backends use this)
      if (!isForwarded && raw['metadata'] != null) {
        dynamic metadata = raw['metadata'];
        if (metadata is String) {
          try {
            if (metadata.trim().startsWith('{') &&
                metadata.trim().endsWith('}')) {
              metadata = jsonDecode(metadata);
            }
          } catch (_) {}
        }

        if (metadata is Map) {
          if (metadata.containsKey('is_forwarded')) {
            isForwarded = parseBool(metadata['is_forwarded']);
          }
          if (!isForwarded && hasForwardMarker(metadata)) {
            isForwarded = true;
          }
        }
      }

      // Fallback: infer from message type keywords
      if (!isForwarded && messageType != null) {
        final lowerType = messageType.toLowerCase();
        if (lowerType.contains('forward')) {
          isForwarded = true;
        }
      }

      // Persist forwarded flag even if body is empty or minimal; never lose it.
      if (!isForwarded &&
          (raw['forwarded_from'] != null ||
              raw['original_room_id'] != null ||
              raw['forwarded_room_id'] != null ||
              raw['forwarded_message_id'] != null)) {
        isForwarded = true;
      }

      // As a last resort, inspect body if it looks like JSON for forward markers
      if (!isForwarded) {
        final bodyStr = raw['body']?.toString() ?? raw['content']?.toString();
        if (bodyStr != null &&
            bodyStr.trim().startsWith('{') &&
            bodyStr.trim().endsWith('}')) {
          try {
            final bodyJson = jsonDecode(bodyStr);
            if (bodyJson is Map && hasForwardMarker(bodyJson)) {
              isForwarded = true;
            }
          } catch (_) {
            // ignore parse failure
          }
        }
      }

      return RoomMessage(
        id: id,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        body: body,
        createdAt: createdAt,
        editedAt: editedAt,
        updatedAt: updatedAt,
        isDeleted: isDeleted,
        deletedAt: deletedAt,
        deletedBy: deletedBy,
        snapshotUserId: snapshotUserId,
        replyTo: replyTo,
        reactions: reactions,
        messageType: messageType,
        eventType: eventType,
        isForwarded: isForwarded,
      );
    } catch (e, stackTrace) {
      // Log the error and the problematic JSON for debugging
      log('⚠️ [RoomMessage] Error parsing from JSON: $e',
          error: e, stackTrace: stackTrace);
      log('⚠️ [RoomMessage] Problematic JSON: $json');

      // Preserve isForwarded even on parse error so forwarded state is not lost on re-entry
      bool fallbackForwarded = false;
      final map = json;
      dynamic rawF = map['is_forwarded'] ?? map['forwarded'] ?? map['forward'];
      if (rawF == null) {
        final inner = map['message'] ?? map['data'];
        if (inner is Map) {
          final innerMap = inner is Map<String, dynamic>
              ? inner
              : <String, dynamic>{
                  ...inner.map((k, v) => MapEntry(k.toString(), v))
                };
          rawF = innerMap['is_forwarded'] ??
              innerMap['forwarded'] ??
              innerMap['forward'];
        }
      }
      if (rawF != null) {
        if (rawF is bool) {
          fallbackForwarded = rawF;
        } else if (rawF is num) {
          fallbackForwarded = rawF == 1;
        } else if (rawF is String) {
          final v = rawF.toLowerCase();
          fallbackForwarded = v == 'true' || v == '1';
        }
      }
      if (!fallbackForwarded &&
          (map['forwarded_from'] != null ||
              map['forwarded_room_id'] != null ||
              map['forwarded_message_id'] != null)) {
        fallbackForwarded = true;
      }

      // Return a valid RoomMessage with defaults instead of crashing
      // This prevents the app from breaking while still logging the issue
      return RoomMessage(
        id: json['id']?.toString() ?? '',
        roomId: json['room_id']?.toString() ?? '',
        senderId: json['sender_id']?.toString() ?? '',
        senderName: json['sender_name']?.toString() ?? 'Unknown',
        senderAvatar:
            json['sender_avatar']?.toString() ?? json['avatar']?.toString(),
        body: json['body']?.toString() ?? '',
        createdAt: DateTime.now(),
        isDeleted: json['is_deleted'] as bool? ?? false,
        isForwarded: fallbackForwarded,
      );
    }
  }

  /// Convert RoomMessage to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      if (editedAt != null) 'edited_at': editedAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (replyTo != null) 'reply_to': replyTo,
      'is_forwarded': isForwarded,
    };
  }

  @override
  String toString() {
    return 'RoomMessage{id: $id, roomId: $roomId, senderId: $senderId, senderName: $senderName, body: $body}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
