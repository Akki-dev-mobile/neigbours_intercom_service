/// Message Reaction model matching the API response structure
class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String reactionType;
  final String userName;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reactionType,
    required this.userName,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id']?.toString() ?? '',
      messageId: json['message_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      reactionType: json['reaction_type']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'reaction_type': reactionType,
      'user_name': userName,
    };
  }

  @override
  String toString() {
    return 'MessageReaction{id: $id, messageId: $messageId, userId: $userId, reactionType: $reactionType, userName: $userName}';
  }
}
