class ProfileDataHelper {
  static Map<String, dynamic> normalizeProfile(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw);
  }

  static String? resolveAvatarUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final candidates = <dynamic>[
      profile['avatar_url'],
      profile['avatarUrl'],
      profile['avatar'],
      profile['profile_image'],
      profile['profileImage'],
      profile['image'],
      profile['photo'],
    ];
    for (final c in candidates) {
      final s = c?.toString().trim();
      if (s != null && s.isNotEmpty && s.toLowerCase() != 'null') {
        return s;
      }
    }
    return null;
  }

  static String? buildAvatarUrlFromUserId(
    dynamic userId, {
    String size = 'large',
  }) {
    if (userId == null) return null;
    final id = userId.toString().trim();
    if (id.isEmpty) return null;
    // Host apps can override by providing a proper URL in their profile payload.
    return null;
  }
}

