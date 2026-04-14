import 'package:flutter/material.dart';

enum IntercomContactType {
  resident,
  committee,
  gatekeeper,
  office,
  lobby,
}

enum IntercomContactStatus {
  online,
  offline,
  busy,
  away,
}

class IntercomContact {
  final String id;
  final String name;
  final String? unit;
  final String? role;
  final String? building;
  final String? floor;
  final IntercomContactType type;
  final IntercomContactStatus? status;
  final bool hasUnreadMessages;
  final String? photoUrl;
  final DateTime? lastContact;

  // Kept for backward compatibility but no longer used
  @Deprecated('Favorites functionality has been removed')
  final bool isFavorite;

  final String? phoneNumber;
  final List<FamilyMember>? familyMembers;
  final bool isPrimary;
  bool? isExpanded;

  /// Numeric user ID for API calls that require numeric identifiers
  /// For residents, this is typically the numeric user ID from the society API
  /// For group members, this might be null if only UUID is available
  final int? numericUserId;

  /// Indicates if the member has a valid user_id (not null) from the API
  /// Members without user_id are not OneApp users and should be disabled from selection
  final bool hasUserId;
  final bool isOnline; // New field for accurate online status
  final DateTime? lastSeenAt; // New field for last seen time

  IntercomContact({
    required this.id,
    required this.name,
    this.unit,
    this.role,
    this.building,
    this.floor,
    required this.type,
    this.status = IntercomContactStatus.offline,
    this.hasUnreadMessages = false,
    this.photoUrl,
    this.lastContact,

    // New fields
    this.isOnline = false,
    this.lastSeenAt,

    // Default to false and mark as deprecated
    @Deprecated('Favorites functionality has been removed')
    this.isFavorite = false,
    this.phoneNumber,
    this.familyMembers,
    this.isPrimary = true,
    this.isExpanded = false,
    this.numericUserId,
    this.hasUserId = true, // Default to true for backward compatibility
  });

  // Get initials from name
  String get initials {
    if (name.trim().isEmpty) return '?';

    final nameParts =
        name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.isEmpty) return '?';

    String result = '';
    if (nameParts.isNotEmpty && nameParts.first.isNotEmpty) {
      result += nameParts.first[0];
      if (nameParts.length > 1 && nameParts.last.isNotEmpty) {
        result += nameParts.last[0];
      }
    }

    return result.isEmpty ? '?' : result.toUpperCase();
  }

  // Get label based on type
  String get typeLabel {
    switch (type) {
      case IntercomContactType.resident:
        return unit != null ? 'Unit $unit' : 'Resident';
      case IntercomContactType.committee:
        return role ?? 'Committee Member';
      case IntercomContactType.gatekeeper:
        return 'Gate Staff';
      case IntercomContactType.office:
        return 'Society Office';
      case IntercomContactType.lobby:
        return 'Lobby';
    }
  }

  // Get status text
  String get statusText {
    if (status == IntercomContactStatus.offline && lastSeenAt != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeenAt!);

      if (difference.inMinutes < 1) {
        return 'Last seen just now';
      } else if (difference.inMinutes < 60) {
        return 'Last seen ${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return 'Last seen ${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return 'Last seen ${difference.inDays}d ago';
      } else {
        return 'Offline';
      }
    }

    switch (status) {
      case IntercomContactStatus.online:
        return 'Online';
      case IntercomContactStatus.offline:
        return 'Offline';
      case IntercomContactStatus.busy:
        return 'Busy';
      case IntercomContactStatus.away:
        return 'Away';
      default:
        return 'Offline';
    }
  }

  // Get status color
  Color get statusColor {
    switch (status) {
      case IntercomContactStatus.online:
        return Colors.green;
      case IntercomContactStatus.offline:
        return Colors.grey;
      case IntercomContactStatus.busy:
        return Colors.red;
      case IntercomContactStatus.away:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // Check if contact is contactable
  bool get isContactable {
    return status != IntercomContactStatus.offline;
  }

  // Check if contact has family members
  bool get hasFamilyMembers {
    return familyMembers != null && familyMembers!.isNotEmpty;
  }

  IntercomContact copyWith({
    String? id,
    String? name,
    String? unit,
    String? role,
    String? building,
    String? floor,
    IntercomContactType? type,
    IntercomContactStatus? status,
    bool? hasUnreadMessages,
    String? photoUrl,
    DateTime? lastContact,
    bool? isFavorite,
    String? phoneNumber,
    List<FamilyMember>? familyMembers,
    bool? isPrimary,
    bool? isExpanded,
    int? numericUserId,
    bool? hasUserId,
    bool? isOnline,
    DateTime? lastSeenAt,
  }) {
    return IntercomContact(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      role: role ?? this.role,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      type: type ?? this.type,
      status: status ?? this.status,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      photoUrl: photoUrl ?? this.photoUrl,
      lastContact: lastContact ?? this.lastContact,
      // ignore: deprecated_member_use_from_same_package
      isFavorite: isFavorite ?? this.isFavorite,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      familyMembers: familyMembers ?? this.familyMembers,
      isPrimary: isPrimary ?? this.isPrimary,
      isExpanded: isExpanded ?? this.isExpanded,
      numericUserId: numericUserId ?? this.numericUserId,
      hasUserId: hasUserId ?? this.hasUserId,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class FamilyMember {
  final String id;
  final String name;
  final String relation;
  final String? photoUrl;
  final String? phoneNumber;
  final IntercomContactStatus status;

  FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    this.photoUrl,
    this.phoneNumber,
    this.status = IntercomContactStatus.offline,
  });

  // Get initials from name
  String get initials {
    if (name.trim().isEmpty) return '?';

    final nameParts =
        name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.isEmpty) return '?';

    String result = '';
    if (nameParts.isNotEmpty && nameParts.first.isNotEmpty) {
      result += nameParts.first[0];
      if (nameParts.length > 1 && nameParts.last.isNotEmpty) {
        result += nameParts.last[0];
      }
    }

    return result.isEmpty ? '?' : result.toUpperCase();
  }
}

class IntercomCall {
  final String id;
  final IntercomContact contact;
  final DateTime timeStamp;
  final bool isIncoming;
  final bool isMissed;
  final Duration? duration;

  IntercomCall({
    required this.id,
    required this.contact,
    required this.timeStamp,
    required this.isIncoming,
    this.isMissed = false,
    this.duration,
  });

  String get formattedDuration {
    if (duration == null) return '';
    if (duration!.inHours > 0) {
      return '${duration!.inHours}h ${duration!.inMinutes.remainder(60)}m';
    } else if (duration!.inMinutes > 0) {
      return '${duration!.inMinutes}m ${duration!.inSeconds.remainder(60)}s';
    } else {
      return '${duration!.inSeconds}s';
    }
  }
}

class IntercomChat {
  final String id;
  final IntercomContact contact;
  final DateTime lastMessageTime;
  final String lastMessage;
  final bool isUnread;
  final int unreadCount;

  IntercomChat({
    required this.id,
    required this.contact,
    required this.lastMessageTime,
    required this.lastMessage,
    this.isUnread = false,
    this.unreadCount = 0,
  });
}
