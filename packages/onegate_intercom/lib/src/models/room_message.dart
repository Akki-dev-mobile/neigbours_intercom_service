import 'package:flutter/foundation.dart';

@immutable
class RoomMessage {
  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.avatar,
  });

  final String id;
  final String roomId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final String? avatar;

  static String _str(dynamic v, {String fallback = ''}) {
    final s = v?.toString();
    if (s == null) return fallback;
    final t = s.trim();
    return t.isEmpty ? fallback : t;
  }

  static DateTime _dt(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    return RoomMessage(
      id: _str(json['id']),
      roomId: _str(json['room_id']),
      userId: _str(json['user_id']),
      userName: _str(json['user_name'], fallback: 'User'),
      avatar: (json['avatar'] as String?)?.trim(),
      content: _str(json['content']),
      createdAt: _dt(json['created_at']),
    );
  }
}

