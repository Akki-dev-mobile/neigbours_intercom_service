import 'dart:io';
import 'intercom_contact.dart';
import 'message_reaction_model.dart';

class GroupChat {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String creatorId;
  final int? createdByUserId; // Numeric user ID for comparison
  final List<IntercomContact> members;
  final int? memberCount; // Actual member count from API (from RoomInfo)
  final DateTime createdAt;
  final DateTime lastMessageTime;
  final String? lastMessage;
  final bool isUnread;
  final int unreadCount;
  final bool hasLeft; // Whether current user has left this group

  GroupChat({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.creatorId,
    this.createdByUserId,
    required this.members,
    this.memberCount, // Optional - from RoomInfo API
    required this.createdAt,
    required this.lastMessageTime,
    this.lastMessage,
    this.isUnread = false,
    this.unreadCount = 0,
    this.hasLeft = false, // Default to false for backward compatibility
  });

  // Get initials from group name (for avatar)
  String get initials {
    final nameParts = name.split(' ');
    if (nameParts.isEmpty) return '';

    String result = '';
    if (nameParts.isNotEmpty) {
      result += nameParts.first[0];
      if (nameParts.length > 1) {
        result += nameParts.last[0];
      }
    }

    return result.toUpperCase();
  }

  // Get member count as string
  // Uses stored memberCount from API if available, otherwise falls back to members.length
  String get memberCountDisplay {
    final count = memberCount ?? members.length;
    return '$count ${count == 1 ? 'member' : 'members'}';
  }

  // Check if user is admin (creator)
  bool isAdmin(String userId) {
    return creatorId == userId;
  }

  // Check if user is member
  bool isMember(String userId) {
    return members.any((member) => member.id == userId);
  }

  // Create a copy with updated properties
  GroupChat copyWith({
    String? name,
    String? description,
    String? iconUrl,
    List<IntercomContact>? members,
    int? memberCount,
    DateTime? lastMessageTime,
    String? lastMessage,
    bool? isUnread,
    int? unreadCount,
    int? createdByUserId,
    bool? hasLeft,
  }) {
    return GroupChat(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      creatorId: creatorId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      members: members ?? this.members,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      isUnread: isUnread ?? this.isUnread,
      unreadCount: unreadCount ?? this.unreadCount,
      hasLeft: hasLeft ?? this.hasLeft,
    );
  }
}

enum GroupMessageStatus { sending, sent, delivered, seen }

class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime timestamp;
  final DateTime? editedAt;
  final bool isDeleted;
  final File? imageFile;
  final bool isLocation;
  final bool isDocument;
  final String? documentName;
  final String? documentType;
  final File? documentFile;
  final bool isContact;
  final bool isAudio;
  final File? audioFile;
  final Duration? audioDuration;
  final String? audioUrl; // S3 URL for audio / voice notes
  final bool isVideo;
  final File? videoFile;
  final String? videoThumbnail;
  final String? videoUrl; // S3 URL for videos
  final GroupMessageStatus status;
  final List<MessageReaction> reactions; // Message reactions
  final GroupMessage? replyTo; // Reply to another message
  final LinkPreview? linkPreview; // Link preview data
  final List<String>? imageUrls; // S3 URLs for images (can be multiple)
  final String? documentUrl; // S3 URL for documents
  final bool isRead; // Legacy support
  final bool isSystemMessage; // System messages like "John left the group"
  final int? snapshotUserId; // Numeric user ID from snapshot_user_id field
  final bool isForwarded; // Forwarded marker

  GroupMessage({
    String? id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
    this.editedAt,
    this.isDeleted = false,
    this.imageFile,
    this.isLocation = false,
    this.isDocument = false,
    this.documentName,
    this.documentType,
    this.documentFile,
    this.isContact = false,
    this.isAudio = false,
    this.audioFile,
    this.audioDuration,
    this.audioUrl,
    this.isVideo = false,
    this.videoFile,
    this.videoThumbnail,
    this.videoUrl,
    this.status = GroupMessageStatus.sent,
    this.reactions = const [],
    this.replyTo,
    this.linkPreview,
    this.imageUrls,
    this.documentUrl,
    this.isRead = false,
    this.isSystemMessage = false,
    this.snapshotUserId,
    this.isForwarded = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Check if message has images
  bool get hasImages => (imageFile != null) || (imageUrls != null && imageUrls!.isNotEmpty);
  
  // Get first image URL (for single image display)
  String? get firstImageUrl {
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      return imageUrls!.first;
    }
    return null;
  }

  // Get initials from sender name (for avatar)
  String get senderInitials {
    final nameParts = senderName.split(' ');
    if (nameParts.isEmpty) return '?';

    String result = '';
    if (nameParts.isNotEmpty) {
      result += nameParts.first[0];
      if (nameParts.length > 1) {
        result += nameParts.last[0];
      }
    }

    return result.toUpperCase();
  }

  // Check if message is from current user
  // Supports both UUID and numeric ID comparison
  // Priority: snapshot_user_id (most reliable) > UUID > numeric senderId
  bool isFromUser(String currentUserId, {int? currentUserNumericId}) {
    // Priority 1: Check snapshot_user_id against currentUserNumericId (most reliable)
    if (snapshotUserId != null && currentUserNumericId != null) {
      if (snapshotUserId == currentUserNumericId) {
        return true;
      }
    }
    
    // Priority 2: Try direct string comparison (UUID to UUID)
    if (senderId == currentUserId) {
      return true;
    }
    
    // Priority 3: If numeric ID is provided, also check numeric comparison of senderId
    if (currentUserNumericId != null) {
      final senderIdInt = int.tryParse(senderId);
      if (senderIdInt != null && senderIdInt == currentUserNumericId) {
        return true;
      }
    }
    
    return false;
  }

  GroupMessage copyWith({
    String? text,
    GroupMessageStatus? status,
    DateTime? editedAt,
    bool? isDeleted,
    List<MessageReaction>? reactions,
    GroupMessage? replyTo,
    LinkPreview? linkPreview,
    bool? isSystemMessage,
    int? snapshotUserId,
    List<String>? imageUrls,
    String? documentUrl,
    String? audioUrl,
    bool? isAudio,
    Duration? audioDuration,
    bool? isVideo,
    String? videoUrl,
    File? videoFile,
    bool? isForwarded,
  }) {
    return GroupMessage(
      id: id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: text ?? this.text,
      timestamp: timestamp,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      imageFile: imageFile,
      isLocation: isLocation,
      isDocument: isDocument,
      documentName: documentName,
      documentType: documentType,
      documentFile: documentFile,
      isContact: isContact,
      isAudio: isAudio ?? this.isAudio,
      audioFile: audioFile,
      audioDuration: audioDuration ?? this.audioDuration,
      audioUrl: audioUrl ?? this.audioUrl,
      isVideo: isVideo ?? this.isVideo,
      videoFile: videoFile ?? this.videoFile,
      videoThumbnail: videoThumbnail,
      videoUrl: videoUrl ?? this.videoUrl,
      status: status ?? this.status,
      reactions: reactions != null ? List<MessageReaction>.from(reactions) : this.reactions,
      replyTo: replyTo ?? this.replyTo,
      linkPreview: linkPreview ?? this.linkPreview,
      imageUrls: imageUrls ?? this.imageUrls,
      documentUrl: documentUrl ?? this.documentUrl,
      isRead: isRead,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
      snapshotUserId: snapshotUserId ?? this.snapshotUserId,
      isForwarded: isForwarded ?? this.isForwarded,
    );
  }
}

class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;

  LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
  });
}
