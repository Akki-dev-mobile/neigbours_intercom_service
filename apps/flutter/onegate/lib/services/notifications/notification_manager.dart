import 'dart:developer' as dev;
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:hive/hive.dart';

/// Notification manager for handling notification operations and statistics
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  late CustomNotificationService _notificationService;
  late Box<NotificationMessage> _notificationsBox;
  late Box<NotificationSubscriber> _subscribersBox;

  /// Initialize the notification manager
  Future<void> initialize() async {
    try {
      _notificationService = CustomNotificationService();
      await _notificationService.initialize();
      
      _notificationsBox = Hive.box<NotificationMessage>('notifications');
      _subscribersBox = Hive.box<NotificationSubscriber>('notification_subscribers');
      
      dev.log('NotificationManager initialized successfully');
    } catch (e) {
      dev.log('Error initializing NotificationManager: $e');
      rethrow;
    }
  }

  /// Get notification service instance
  CustomNotificationService get service => _notificationService;

  /// Get notification statistics
  NotificationStats getStatistics() {
    final notifications = _notificationsBox.values.toList();
    final subscribers = _subscribersBox.values.toList();

    final notificationsByTopic = <String, int>{};
    final notificationsByPriority = <String, int>{};
    int unreadCount = 0;

    for (final notification in notifications) {
      // Count by topic
      notificationsByTopic[notification.topic] = 
          (notificationsByTopic[notification.topic] ?? 0) + 1;

      // Count by priority
      final priorityName = notification.priorityEnum.displayName;
      notificationsByPriority[priorityName] = 
          (notificationsByPriority[priorityName] ?? 0) + 1;

      // Count unread
      if (!notification.isRead) {
        unreadCount++;
      }
    }

    final lastNotification = notifications.isNotEmpty
        ? notifications.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b).timestamp
        : DateTime.now();

    return NotificationStats(
      totalNotifications: notifications.length,
      unreadNotifications: unreadCount,
      activeSubscribers: subscribers.where((s) => s.isActive).length,
      notificationsByTopic: notificationsByTopic,
      notificationsByPriority: notificationsByPriority,
      lastNotification: lastNotification,
    );
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final notification = _notificationsBox.get(notificationId);
      if (notification != null) {
        final updatedNotification = notification.copyWith(isRead: true);
        await _notificationsBox.put(notificationId, updatedNotification);
        return true;
      }
      return false;
    } catch (e) {
      dev.log('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final notifications = _notificationsBox.values.toList();
      for (final notification in notifications) {
        if (!notification.isRead) {
          final updatedNotification = notification.copyWith(isRead: true);
          await _notificationsBox.put(notification.id, updatedNotification);
        }
      }
      return true;
    } catch (e) {
      dev.log('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _notificationsBox.delete(notificationId);
      return true;
    } catch (e) {
      dev.log('Error deleting notification: $e');
      return false;
    }
  }

  /// Clear all notifications
  Future<bool> clearAllNotifications() async {
    try {
      await _notificationsBox.clear();
      return true;
    } catch (e) {
      dev.log('Error clearing all notifications: $e');
      return false;
    }
  }

  /// Get notifications with filtering and pagination
  List<NotificationMessage> getFilteredNotifications({
    String? topic,
    AlertPriority? priority,
    bool? isRead,
    int? limit,
    int? offset,
  }) {
    var notifications = _notificationsBox.values.toList();

    // Apply filters
    if (topic != null) {
      notifications = notifications.where((n) => n.topic == topic).toList();
    }

    if (priority != null) {
      notifications = notifications.where((n) => n.priority == priority.value).toList();
    }

    if (isRead != null) {
      notifications = notifications.where((n) => n.isRead == isRead).toList();
    }

    // Sort by timestamp (newest first)
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Apply pagination
    if (offset != null && offset > 0) {
      notifications = notifications.skip(offset).toList();
    }

    if (limit != null && limit > 0) {
      notifications = notifications.take(limit).toList();
    }

    return notifications;
  }

  /// Get subscribers for a topic
  List<NotificationSubscriber> getSubscribers({String? topic}) {
    var subscribers = _subscribersBox.values.toList();

    if (topic != null) {
      subscribers = subscribers.where((s) => s.topic == topic || s.topic == 'onegate/+').toList();
    }

    return subscribers.where((s) => s.isActive).toList();
  }

  /// Update subscriber status
  Future<bool> updateSubscriberStatus(String subscriberId, bool isActive) async {
    try {
      final subscriber = _subscribersBox.get(subscriberId);
      if (subscriber != null) {
        final updatedSubscriber = subscriber.copyWith(isActive: isActive);
        await _subscribersBox.put(subscriberId, updatedSubscriber);
        return true;
      }
      return false;
    } catch (e) {
      dev.log('Error updating subscriber status: $e');
      return false;
    }
  }

  /// Get notification topics
  List<String> getAvailableTopics() {
    return [
      'onegate/data-anomaly',
      'onegate/search-error',
      'onegate/api-error',
      'onegate/health-check',
    ];
  }

  /// Export notifications as JSON
  Map<String, dynamic> exportNotifications({
    String? topic,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var notifications = _notificationsBox.values.toList();

    // Apply filters
    if (topic != null) {
      notifications = notifications.where((n) => n.topic == topic).toList();
    }

    if (fromDate != null) {
      notifications = notifications.where((n) => n.timestamp.isAfter(fromDate)).toList();
    }

    if (toDate != null) {
      notifications = notifications.where((n) => n.timestamp.isBefore(toDate)).toList();
    }

    return {
      'exportDate': DateTime.now().toIso8601String(),
      'totalCount': notifications.length,
      'filters': {
        'topic': topic,
        'fromDate': fromDate?.toIso8601String(),
        'toDate': toDate?.toIso8601String(),
      },
      'notifications': notifications.map((n) => n.toJson()).toList(),
    };
  }

  /// Import notifications from JSON
  Future<bool> importNotifications(Map<String, dynamic> data) async {
    try {
      final notificationsList = data['notifications'] as List;
      
      for (final notificationData in notificationsList) {
        final notification = NotificationMessage.fromJson(notificationData);
        await _notificationsBox.put(notification.id, notification);
      }
      
      dev.log('Imported ${notificationsList.length} notifications');
      return true;
    } catch (e) {
      dev.log('Error importing notifications: $e');
      return false;
    }
  }

  /// Get health status of notification system
  Map<String, dynamic> getSystemHealth() {
    final stats = getStatistics();
    final subscribers = _subscribersBox.values.toList();
    
    return {
      'status': 'healthy',
      'totalNotifications': stats.totalNotifications,
      'activeSubscribers': stats.activeSubscribers,
      'lastNotification': stats.lastNotification.toIso8601String(),
      'storageUsed': _notificationsBox.length,
      'subscribersCount': subscribers.length,
      'systemUptime': DateTime.now().toIso8601String(),
    };
  }

  /// Cleanup old data
  Future<void> performMaintenance() async {
    try {
      // Clean up old notifications (keep last 1000)
      await _notificationService.cleanupOldNotifications();
      
      // Remove inactive subscribers older than 30 days
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final subscribers = _subscribersBox.values.toList();
      
      for (final subscriber in subscribers) {
        if (!subscriber.isActive && subscriber.createdAt.isBefore(cutoffDate)) {
          await _subscribersBox.delete(subscriber.id);
        }
      }
      
      dev.log('Notification system maintenance completed');
    } catch (e) {
      dev.log('Error during notification maintenance: $e');
    }
  }
}
