import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages unread message counts and room-to-contact mappings
/// Persists data in SharedPreferences for cross-session persistence
class UnreadCountManager {
  static UnreadCountManager? _instance;
  static const String _logName = 'UnreadCountManager';

  // In-memory cache for fast access
  final Map<String, int> _unreadCounts = {}; // roomId -> count
  final Map<String, String> _roomToContactMap = {}; // roomId -> contactId
  final Map<String, String> _contactToRoomMap = {}; // contactId -> roomId
  final Map<String, DateTime> _lastMessageTimes = {}; // roomId -> timestamp
  final Map<String, String> _lastMessages =
      {}; // roomId -> last message content

  UnreadCountManager._();

  static UnreadCountManager get instance {
    _instance ??= UnreadCountManager._();
    return _instance!;
  }

  /// Initialize - load data from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load unread counts
      final unreadKeys =
          prefs.getKeys().where((key) => key.startsWith('unread_count_'));
      for (final key in unreadKeys) {
        final roomId = key.replaceFirst('unread_count_', '');
        final count = prefs.getInt(key) ?? 0;
        _unreadCounts[roomId] = count;
      }

      // Load room-to-contact mappings
      final mappingKeys =
          prefs.getKeys().where((key) => key.startsWith('room_contact_'));
      for (final key in mappingKeys) {
        final roomId = key.replaceFirst('room_contact_', '');
        final contactId = prefs.getString(key);
        if (contactId != null) {
          _roomToContactMap[roomId] = contactId;
          _contactToRoomMap[contactId] = roomId;
        }
      }

      // Load last message times
      final timeKeys =
          prefs.getKeys().where((key) => key.startsWith('last_msg_time_'));
      for (final key in timeKeys) {
        final roomId = key.replaceFirst('last_msg_time_', '');
        final timestamp = prefs.getInt(key);
        if (timestamp != null) {
          _lastMessageTimes[roomId] =
              DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }

      // Load last messages
      final msgKeys =
          prefs.getKeys().where((key) => key.startsWith('last_msg_'));
      for (final key in msgKeys) {
        final roomId = key.replaceFirst('last_msg_', '');
        final message = prefs.getString(key);
        if (message != null) {
          _lastMessages[roomId] = message;
        }
      }

      log('✅ [UnreadCountManager] Initialized: ${_unreadCounts.length} unread counts, ${_roomToContactMap.length} mappings',
          name: _logName);
    } catch (e) {
      log('❌ [UnreadCountManager] Error initializing: $e', name: _logName);
    }
  }

  /// Map a room ID to a contact ID (called when chat is opened)
  Future<void> mapRoomToContact(String roomId, String contactId) async {
    try {
      _roomToContactMap[roomId] = contactId;
      _contactToRoomMap[contactId] = roomId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_contact_$roomId', contactId);

      log('✅ [UnreadCountManager] Mapped room $roomId to contact $contactId',
          name: _logName);
    } catch (e) {
      log('❌ [UnreadCountManager] Error mapping room to contact: $e',
          name: _logName);
    }
  }

  /// Get room ID for a contact
  String? getRoomIdForContact(String contactId) {
    return _contactToRoomMap[contactId];
  }

  /// Get contact ID for a room
  String? getContactIdForRoom(String roomId) {
    return _roomToContactMap[roomId];
  }

  /// Increment unread count for a room
  Future<void> incrementUnreadCount(String roomId) async {
    try {
      final currentCount = _unreadCounts[roomId] ?? 0;
      _unreadCounts[roomId] = currentCount + 1;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_count_$roomId', _unreadCounts[roomId]!);

      log('📈 [UnreadCountManager] Incremented unread count for room $roomId: ${_unreadCounts[roomId]}',
          name: _logName);
    } catch (e) {
      log('❌ [UnreadCountManager] Error incrementing unread count: $e',
          name: _logName);
    }
  }

  /// Clear unread count for a room (when chat is opened)
  Future<void> clearUnreadCount(String roomId) async {
    try {
      _unreadCounts[roomId] = 0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_count_$roomId', 0);

      log('✅ [UnreadCountManager] Cleared unread count for room $roomId',
          name: _logName);
    } catch (e) {
      log('❌ [UnreadCountManager] Error clearing unread count: $e',
          name: _logName);
    }
  }

  /// Set unread count for a room (used when backend sends unread_count_update)
  /// This ensures local cache stays in sync with backend state
  Future<void> setUnreadCount(String roomId, int count) async {
    try {
      _unreadCounts[roomId] = count < 0 ? 0 : count;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_count_$roomId', _unreadCounts[roomId]!);

      log('✅ [UnreadCountManager] Set unread count for room $roomId: ${_unreadCounts[roomId]}',
          name: _logName);
    } catch (e) {
      log('❌ [UnreadCountManager] Error setting unread count: $e',
          name: _logName);
    }
  }

  /// Get unread count for a room
  int getUnreadCount(String roomId) {
    return _unreadCounts[roomId] ?? 0;
  }

  /// Get unread count for a contact
  int getUnreadCountForContact(String contactId) {
    final roomId = getRoomIdForContact(contactId);
    if (roomId == null) return 0;
    return getUnreadCount(roomId);
  }

  /// Update last message timestamp and content
  Future<void> updateLastMessage(
      String roomId, String message, DateTime timestamp) async {
    try {
      _lastMessageTimes[roomId] = timestamp;
      _lastMessages[roomId] = message;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'last_msg_time_$roomId', timestamp.millisecondsSinceEpoch);
      await prefs.setString('last_msg_$roomId', message);

      log('✅ [UnreadCountManager] Updated last message for room $roomId',
          name: _logName);
    } catch (e) {
      log('❌ [UnreadCountManager] Error updating last message: $e',
          name: _logName);
    }
  }

  /// Get last message timestamp for a room
  DateTime? getLastMessageTime(String roomId) {
    return _lastMessageTimes[roomId];
  }

  /// Get last message content for a room
  String? getLastMessage(String roomId) {
    return _lastMessages[roomId];
  }

  /// Get last message timestamp for a contact
  DateTime? getLastMessageTimeForContact(String contactId) {
    final roomId = getRoomIdForContact(contactId);
    if (roomId == null) return null;
    return getLastMessageTime(roomId);
  }

  /// Get last message content for a contact
  String? getLastMessageForContact(String contactId) {
    final roomId = getRoomIdForContact(contactId);
    if (roomId == null) return null;
    return getLastMessage(roomId);
  }

  /// Clear all data (for testing or logout)
  Future<void> clearAll() async {
    try {
      _unreadCounts.clear();
      _roomToContactMap.clear();
      _contactToRoomMap.clear();
      _lastMessageTimes.clear();
      _lastMessages.clear();

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) =>
          key.startsWith('unread_count_') ||
          key.startsWith('room_contact_') ||
          key.startsWith('last_msg_time_') ||
          key.startsWith('last_msg_'));
      for (final key in keys) {
        await prefs.remove(key);
      }

      log('✅ [UnreadCountManager] Cleared all data', name: _logName);
    } catch (e) {
      log('❌ [UnreadCountManager] Error clearing all data: $e', name: _logName);
    }
  }
}
