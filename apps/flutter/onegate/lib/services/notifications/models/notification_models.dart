import 'package:hive/hive.dart';

part 'notification_models.g.dart';

/// Notification message model
@HiveType(typeId: 100)
class NotificationMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String topic;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String message;

  @HiveField(4)
  final int priority;

  @HiveField(5)
  final List<String> tags;

  @HiveField(6)
  final Map<String, dynamic> data;

  @HiveField(7)
  final DateTime timestamp;

  @HiveField(8)
  final bool isRead;

  NotificationMessage({
    required this.id,
    required this.topic,
    required this.title,
    required this.message,
    required this.priority,
    required this.tags,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  /// Convert to JSON for API compatibility
  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'title': title,
        'message': message,
        'priority': priority,
        'tags': tags,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  /// Create from JSON
  factory NotificationMessage.fromJson(Map<String, dynamic> json) => NotificationMessage(
        id: json['id'],
        topic: json['topic'],
        title: json['title'],
        message: json['message'],
        priority: json['priority'],
        tags: List<String>.from(json['tags']),
        data: Map<String, dynamic>.from(json['data']),
        timestamp: DateTime.parse(json['timestamp']),
        isRead: json['isRead'] ?? false,
      );

  /// Create a copy with updated fields
  NotificationMessage copyWith({
    String? id,
    String? topic,
    String? title,
    String? message,
    int? priority,
    List<String>? tags,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
  }) => NotificationMessage(
        id: id ?? this.id,
        topic: topic ?? this.topic,
        title: title ?? this.title,
        message: message ?? this.message,
        priority: priority ?? this.priority,
        tags: tags ?? this.tags,
        data: data ?? this.data,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
      );

  /// Get priority as enum
  AlertPriority get priorityEnum => AlertPriority.values.firstWhere(
        (p) => p.value == priority,
        orElse: () => AlertPriority.default_,
      );

  /// Get formatted timestamp
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  String toString() => 'NotificationMessage(id: $id, topic: $topic, title: $title)';
}

/// Notification subscriber model
@HiveType(typeId: 101)
class NotificationSubscriber extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String topic;

  @HiveField(2)
  final String? webhookUrl;

  @HiveField(3)
  final String? deviceId;

  @HiveField(4)
  final Map<String, String> metadata;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final bool isActive;

  @HiveField(7)
  final DateTime? lastDelivery;

  @HiveField(8)
  final int deliveryCount;

  NotificationSubscriber({
    required this.id,
    required this.topic,
    this.webhookUrl,
    this.deviceId,
    required this.metadata,
    required this.createdAt,
    required this.isActive,
    this.lastDelivery,
    this.deliveryCount = 0,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'webhookUrl': webhookUrl,
        'deviceId': deviceId,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
        'lastDelivery': lastDelivery?.toIso8601String(),
        'deliveryCount': deliveryCount,
      };

  /// Create from JSON
  factory NotificationSubscriber.fromJson(Map<String, dynamic> json) => NotificationSubscriber(
        id: json['id'],
        topic: json['topic'],
        webhookUrl: json['webhookUrl'],
        deviceId: json['deviceId'],
        metadata: Map<String, String>.from(json['metadata']),
        createdAt: DateTime.parse(json['createdAt']),
        isActive: json['isActive'],
        lastDelivery: json['lastDelivery'] != null ? DateTime.parse(json['lastDelivery']) : null,
        deliveryCount: json['deliveryCount'] ?? 0,
      );

  /// Create a copy with updated fields
  NotificationSubscriber copyWith({
    String? id,
    String? topic,
    String? webhookUrl,
    String? deviceId,
    Map<String, String>? metadata,
    DateTime? createdAt,
    bool? isActive,
    DateTime? lastDelivery,
    int? deliveryCount,
  }) => NotificationSubscriber(
        id: id ?? this.id,
        topic: topic ?? this.topic,
        webhookUrl: webhookUrl ?? this.webhookUrl,
        deviceId: deviceId ?? this.deviceId,
        metadata: metadata ?? this.metadata,
        createdAt: createdAt ?? this.createdAt,
        isActive: isActive ?? this.isActive,
        lastDelivery: lastDelivery ?? this.lastDelivery,
        deliveryCount: deliveryCount ?? this.deliveryCount,
      );

  @override
  String toString() => 'NotificationSubscriber(id: $id, topic: $topic, isActive: $isActive)';
}

/// Alert priority levels (compatible with ntfy.sh)
enum AlertPriority {
  min(1),
  low(2),
  default_(3),
  high(4),
  max(5);

  const AlertPriority(this.value);
  final int value;

  String get displayName {
    switch (this) {
      case AlertPriority.min:
        return 'Minimal';
      case AlertPriority.low:
        return 'Low';
      case AlertPriority.default_:
        return 'Default';
      case AlertPriority.high:
        return 'High';
      case AlertPriority.max:
        return 'Maximum';
    }
  }

  /// Get color for priority
  String get colorHex {
    switch (this) {
      case AlertPriority.min:
        return '#9E9E9E'; // Grey
      case AlertPriority.low:
        return '#2196F3'; // Blue
      case AlertPriority.default_:
        return '#4CAF50'; // Green
      case AlertPriority.high:
        return '#FF9800'; // Orange
      case AlertPriority.max:
        return '#F44336'; // Red
    }
  }
}

/// Notification delivery status
enum DeliveryStatus {
  pending,
  delivered,
  failed,
  retrying,
}

/// Notification statistics model
class NotificationStats {
  final int totalNotifications;
  final int unreadNotifications;
  final int activeSubscribers;
  final Map<String, int> notificationsByTopic;
  final Map<String, int> notificationsByPriority;
  final DateTime lastNotification;

  NotificationStats({
    required this.totalNotifications,
    required this.unreadNotifications,
    required this.activeSubscribers,
    required this.notificationsByTopic,
    required this.notificationsByPriority,
    required this.lastNotification,
  });

  Map<String, dynamic> toJson() => {
        'totalNotifications': totalNotifications,
        'unreadNotifications': unreadNotifications,
        'activeSubscribers': activeSubscribers,
        'notificationsByTopic': notificationsByTopic,
        'notificationsByPriority': notificationsByPriority,
        'lastNotification': lastNotification.toIso8601String(),
      };
}
