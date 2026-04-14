import 'intercom_contact.dart';

/// Simple Gatekeeper model matching the API response exactly
class Gatekeeper {
  final int userId;
  final String username;
  final String? email;
  final String status;

  Gatekeeper({
    required this.userId,
    required this.username,
    this.email,
    required this.status,
  });

  factory Gatekeeper.fromJson(Map<String, dynamic> json) {
    return Gatekeeper(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      email: json['email'] as String?,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'status': status,
    };
  }

  /// Check if gatekeeper is active
  bool get isActive => status == 'active';

  /// Get display name (username)
  String get displayName => username;

  /// Get initials for avatar
  String get initials {
    if (username.isEmpty) return '';
    return username.length >= 2
        ? username.substring(0, 2).toUpperCase()
        : username[0].toUpperCase();
  }

  /// Convert to IntercomContact for chat functionality
  IntercomContact toIntercomContact() {
    return IntercomContact(
      id: userId.toString(),
      name: username,
      type: IntercomContactType.gatekeeper,
      phoneNumber: username, // Use username as phone number for gatekeepers
      status: isActive
          ? IntercomContactStatus.online
          : IntercomContactStatus.offline,
      role: 'Gatekeeper',
    );
  }
}
