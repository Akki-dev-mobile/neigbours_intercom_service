import 'package:flutter/foundation.dart';

@immutable
class Room {
  const Room({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    this.membersCount,
    this.unreadCount,
    this.lastActive,
  });

  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final int? membersCount;
  final int? unreadCount;
  final DateTime? lastActive;

  static int? _int(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static String _str(dynamic v, {String fallback = ''}) {
    final s = v?.toString();
    if (s == null) return fallback;
    final t = s.trim();
    return t.isEmpty ? fallback : t;
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: _str(json['id']),
      name: _str(json['name'], fallback: 'Unnamed'),
      description: (json['description'] as String?)?.trim(),
      photoUrl: (json['photo_url'] as String?)?.trim(),
      membersCount: _int(json['members_count']),
      unreadCount: _int(json['unread_count']),
      lastActive: _dt(json['last_active']),
    );
  }
}

