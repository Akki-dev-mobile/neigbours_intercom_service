import 'dart:convert';

import 'package:flutter/material.dart';

/// Represents a short, user-friendly preview for chat activity.
class ActivityPreview {
  final String text;
  final ActivityPreviewKind kind;

  const ActivityPreview({
    required this.text,
    required this.kind,
  });

  /// Optional icon to pair with the preview text.
  IconData? get icon {
    switch (kind) {
      case ActivityPreviewKind.image:
        return Icons.photo_camera_outlined;
      case ActivityPreviewKind.video:
        return Icons.videocam_outlined;
      case ActivityPreviewKind.audio:
        return Icons.mic_none_outlined;
      case ActivityPreviewKind.file:
        return Icons.insert_drive_file_outlined;
      case ActivityPreviewKind.location:
        return Icons.location_on_outlined;
      case ActivityPreviewKind.reply:
        return Icons.reply_outlined;
      case ActivityPreviewKind.reaction:
        return Icons.emoji_emotions_outlined;
      case ActivityPreviewKind.text:
      case ActivityPreviewKind.unknown:
        return null;
    }
  }

  bool get hasIcon => icon != null;
}

enum ActivityPreviewKind {
  text,
  image,
  video,
  audio,
  file,
  location,
  reply,
  reaction,
  unknown,
}

class ActivityPreviewHelper {
  /// Build preview from a WebSocket payload.
  static ActivityPreview fromWebSocket({
    String? content,
    String? messageType,
    Map<String, dynamic>? data,
  }) {
    return _resolve(
      content ?? data?['content']?.toString(),
      messageType ?? data?['message_type']?.toString(),
      data,
    );
  }

  /// Build preview from stored text (e.g., SharedPreferences or cached model).
  static ActivityPreview fromStored(String? content) {
    return _resolve(content, null, null);
  }

  /// Build preview from arbitrary content/type pairs (e.g., REST responses).
  static ActivityPreview fromContent(
    String? content, {
    String? messageType,
    Map<String, dynamic>? data,
  }) {
    return _resolve(content, messageType, data);
  }

  // ---- Internal helpers ---------------------------------------------------

  static ActivityPreview _resolve(
    String? rawContent,
    String? rawType,
    Map<String, dynamic>? data,
  ) {
    final content = _normalizeContent(
      rawContent ?? data?['content']?.toString(),
    );
    final type = _normalizeType(
      rawType ?? data?['message_type']?.toString(),
    );

    if ((content == null || content.isEmpty) &&
        (type == null || type.isEmpty)) {
      return const ActivityPreview(
        text: '',
        kind: ActivityPreviewKind.unknown,
      );
    }

    final previewFromContent = _previewFromContent(content, type);
    if (previewFromContent != null) return previewFromContent;

    if (content == null || content.isEmpty) {
      return _previewFromType(type);
    }

    return ActivityPreview(
      text: content,
      kind: _mapTypeToKind(type) ?? ActivityPreviewKind.text,
    );
  }

  static ActivityPreview? _previewFromContent(
    String? content,
    String? type,
  ) {
    if (content == null || content.isEmpty) return null;

    // 1) Structured JSON payloads that contain file_url or similar keys.
    if (content.trim().startsWith('{')) {
      final decoded = _tryDecodeJson(content);
      if (decoded != null) {
        final fileUrl = _extractFileUrl(decoded);
        final metaType = _normalizeType(
          decoded['message_type']?.toString() ??
              decoded['type']?.toString() ??
              decoded['file_type']?.toString(),
        );
        final inferredKind = _kindFromUrlOrType(fileUrl, metaType ?? type);
        if (inferredKind != ActivityPreviewKind.text &&
            inferredKind != ActivityPreviewKind.unknown) {
          return ActivityPreview(
            text: _labelForKind(inferredKind),
            kind: inferredKind,
          );
        }
      }
    }

    // 2) Raw strings that still contain file_url patterns.
    final fileUrlFromPattern = _extractFileUrlFromString(content);
    if (fileUrlFromPattern != null) {
      final inferredKind = _kindFromUrlOrType(fileUrlFromPattern, type);
      return ActivityPreview(
        text: _labelForKind(inferredKind),
        kind: inferredKind,
      );
    }

    // 3) Standalone URLs (no spaces) - often sent for media.
    if (_isStandaloneUrl(content)) {
      final inferredKind = _kindFromUrlOrType(content, type);
      if (inferredKind != ActivityPreviewKind.text &&
          inferredKind != ActivityPreviewKind.unknown) {
        return ActivityPreview(
          text: _labelForKind(inferredKind),
          kind: inferredKind,
        );
      }
    }

    // 4) Human-friendly phrases that imply media.
    final lower = content.toLowerCase();
    if (lower == 'image' ||
        lower == 'photo' ||
        lower.contains('sent a photo') ||
        lower.contains('shared an image') ||
        lower.contains('[image]')) {
      return const ActivityPreview(
        text: 'Image',
        kind: ActivityPreviewKind.image,
      );
    }
    if (lower.contains('sent a video') || lower == 'video') {
      return const ActivityPreview(
        text: 'Video',
        kind: ActivityPreviewKind.video,
      );
    }
    if (lower.contains('audio message') || lower == 'audio') {
      return const ActivityPreview(
        text: 'Audio message',
        kind: ActivityPreviewKind.audio,
      );
    }

    return null;
  }

  static ActivityPreview _previewFromType(String? type) {
    final kind = _mapTypeToKind(type);
    if (kind == null || kind == ActivityPreviewKind.text) {
      return ActivityPreview(
        text: 'New activity',
        kind: ActivityPreviewKind.unknown,
      );
    }
    return ActivityPreview(
      text: _labelForKind(kind),
      kind: kind,
    );
  }

  static ActivityPreviewKind _kindFromUrlOrType(
    String? url,
    String? type,
  ) {
    final mappedType = _mapTypeToKind(type);
    if (mappedType != null && mappedType != ActivityPreviewKind.text) {
      return mappedType;
    }

    if (url != null) {
      if (_isImageUrl(url)) return ActivityPreviewKind.image;
      if (_isVideoUrl(url)) return ActivityPreviewKind.video;
      if (_isAudioUrl(url)) return ActivityPreviewKind.audio;
      return ActivityPreviewKind.file;
    }

    return ActivityPreviewKind.text;
  }

  static ActivityPreviewKind? _mapTypeToKind(String? type) {
    final value = type?.toLowerCase().trim();
    switch (value) {
      case 'image':
      case 'photo':
      case 'picture':
        return ActivityPreviewKind.image;
      case 'video':
        return ActivityPreviewKind.video;
      case 'audio':
      case 'voice':
        return ActivityPreviewKind.audio;
      case 'file':
      case 'document':
        return ActivityPreviewKind.file;
      case 'location':
        return ActivityPreviewKind.location;
      case 'reply':
        return ActivityPreviewKind.reply;
      case 'reaction':
        return ActivityPreviewKind.reaction;
      case 'text':
      case null:
        return ActivityPreviewKind.text;
      default:
        return ActivityPreviewKind.text;
    }
  }

  static String _labelForKind(ActivityPreviewKind kind) {
    switch (kind) {
      case ActivityPreviewKind.image:
        return 'Image';
      case ActivityPreviewKind.video:
        return 'Video';
      case ActivityPreviewKind.audio:
        return 'Audio message';
      case ActivityPreviewKind.file:
        return 'File';
      case ActivityPreviewKind.location:
        return 'Location';
      case ActivityPreviewKind.reply:
        return 'Replied';
      case ActivityPreviewKind.reaction:
        return 'Reacted';
      case ActivityPreviewKind.text:
      case ActivityPreviewKind.unknown:
        return 'New activity';
    }
  }

  static String? _normalizeContent(String? content) {
    final value = content?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? _normalizeType(String? type) {
    final value = type?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Map<String, dynamic>? _tryDecodeJson(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) =>
            MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Ignore JSON errors – fallback handled by callers.
    }
    return null;
  }

  static String? _extractFileUrl(Map<String, dynamic> data) {
    final candidates = [
      data['file_url'],
      data['fileUrl'],
      data['url'],
      data['file'],
      data['fileKey'],
      data['file_key'],
      data['preview_url'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    // Sometimes file_url is nested under "data" -> {...}
    final nested = data['data'];
    if (nested is Map) {
      return _extractFileUrl(
        nested.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return null;
  }

  static String? _extractFileUrlFromString(String content) {
    final pattern = RegExp(r'"file_url"\s*:\s*"([^"]+)"');
    final match = pattern.firstMatch(content);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  static bool _isStandaloneUrl(String content) {
    final trimmed = content.trim();
    if (trimmed.contains(' ')) return false;
    final pattern = RegExp(
      r"^(https?:\/\/)[\w\-._~:/?#[\]@!$&'()*+,;=%]+$",
      caseSensitive: false,
    );
    return pattern.hasMatch(trimmed);
  }

  static bool _isImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.bmp');
  }

  static bool _isVideoUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.wmv') ||
        lower.endsWith('.webm');
  }

  static bool _isAudioUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.mp3') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.ogg');
  }
}
