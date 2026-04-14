class Post {
  final String id;
  final String userName;
  final String userAvatar;
  final String flatNumber;
  final DateTime timestamp;
  final String content;
  final List<String> images;
  int likeCount;
  int commentCount;
  bool isLiked;

  Post({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.flatNumber,
    required this.timestamp,
    required this.content,
    this.images = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
  });

  // Helper method to get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  // Toggle like status
  void toggleLike() {
    if (isLiked) {
      likeCount--;
      isLiked = false;
    } else {
      likeCount++;
      isLiked = true;
    }
  }

  // Create a copy of the post with updated properties
  Post copyWith({
    String? id,
    String? userName,
    String? userAvatar,
    String? flatNumber,
    DateTime? timestamp,
    String? content,
    List<String>? images,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
  }) {
    return Post(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      flatNumber: flatNumber ?? this.flatNumber,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      images: images ?? this.images,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
