import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

String _tr(String key, {Map<String, String>? params}) {
  final context = navigatorKey.currentContext;
  if (context == null) return key;
  return FlutterI18n.translate(context, key, translationParams: params);
}

/// Custom notification service that replaces ntfy.sh with internal implementation
class CustomNotificationService {
  static const String _dataAnomalyTopic = 'onegate/data-anomaly';
  static const String _searchErrorTopic = 'onegate/search-error';
  static const String _apiErrorTopic = 'onegate/api-error';
  static const String _healthCheckTopic = 'onegate/health-check';

  static const String _notificationsBoxName = 'notifications';
  static const String _subscribersBoxName = 'notification_subscribers';

  late Box<NotificationMessage> _notificationsBox;
  late Box<NotificationSubscriber> _subscribersBox;
  late GateStorage _gateStorage;
  late Dio _dio;

  final List<Function(NotificationMessage)> _listeners = [];
  final Uuid _uuid = const Uuid();

  static final CustomNotificationService _instance =
      CustomNotificationService._internal();
  factory CustomNotificationService() => _instance;
  CustomNotificationService._internal();

  /// Initialize the custom notification service
  Future<void> initialize() async {
    try {
      _gateStorage = GateStorage();

      // Note: Hive and adapters are already initialized in main.dart
      // Open Hive boxes for storing notifications and subscribers
      _notificationsBox =
          await Hive.openBox<NotificationMessage>(_notificationsBoxName);
      _subscribersBox =
          await Hive.openBox<NotificationSubscriber>(_subscribersBoxName);

      // Initialize HTTP client for webhook delivery
      _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      dev.log('CustomNotificationService initialized successfully');
    } catch (e) {
      dev.log('Error initializing CustomNotificationService: $e');
      rethrow;
    }
  }

  /// Send a data anomaly alert
  Future<bool> sendDataAnomalyAlert({
    required String title,
    required String message,
    Map<String, dynamic>? data,
    AlertPriority priority = AlertPriority.high,
  }) async {
    return await _sendNotification(
      topic: _dataAnomalyTopic,
      title: title,
      message: message,
      data: data,
      priority: priority,
      tags: ['warning', 'data'],
    );
  }

  /// Send a search error alert
  Future<bool> sendSearchErrorAlert({
    required String title,
    required String message,
    Map<String, dynamic>? data,
    AlertPriority priority = AlertPriority.default_,
  }) async {
    return await _sendNotification(
      topic: _searchErrorTopic,
      title: title,
      message: message,
      data: data,
      priority: priority,
      tags: ['error', 'search'],
    );
  }

  /// Send an API error alert
  Future<bool> sendApiErrorAlert({
    required String title,
    required String message,
    Map<String, dynamic>? data,
    AlertPriority priority = AlertPriority.high,
  }) async {
    return await _sendNotification(
      topic: _apiErrorTopic,
      title: title,
      message: message,
      data: data,
      priority: priority,
      tags: ['error', 'api'],
    );
  }

  /// Send a health check alert
  Future<bool> sendHealthCheckAlert({
    required String title,
    required String message,
    Map<String, dynamic>? data,
    AlertPriority priority = AlertPriority.default_,
  }) async {
    return await _sendNotification(
      topic: _healthCheckTopic,
      title: title,
      message: message,
      data: data,
      priority: priority,
      tags: ['info', 'health'],
    );
  }

  /// Test notification functionality
  Future<bool> testNotification() async {
    return await _sendNotification(
      topic: _healthCheckTopic,
      title: _tr('Test Notification'),
      message: _tr(
          'This is a test notification from OneGate custom notification service.'),
      data: {'test': true},
      priority: AlertPriority.default_,
      tags: ['test'],
    );
  }

  /// Subscribe to notifications for a specific topic
  Future<String> subscribe({
    required String topic,
    String? webhookUrl,
    String? deviceId,
    Map<String, String>? metadata,
  }) async {
    final subscriber = NotificationSubscriber(
      id: _uuid.v4(),
      topic: topic,
      webhookUrl: webhookUrl,
      deviceId: deviceId,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
      isActive: true,
    );

    await _subscribersBox.put(subscriber.id, subscriber);
    dev.log('New subscriber added for topic: $topic');
    return subscriber.id;
  }

  /// Unsubscribe from notifications
  Future<bool> unsubscribe(String subscriberId) async {
    try {
      await _subscribersBox.delete(subscriberId);
      dev.log('Subscriber removed: $subscriberId');
      return true;
    } catch (e) {
      dev.log('Error unsubscribing: $e');
      return false;
    }
  }

  /// Add a listener for real-time notifications
  void addListener(Function(NotificationMessage) listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(Function(NotificationMessage) listener) {
    _listeners.remove(listener);
  }

  /// Get all notifications for a topic
  List<NotificationMessage> getNotifications({String? topic, int? limit}) {
    var notifications = _notificationsBox.values.toList();

    if (topic != null) {
      notifications = notifications.where((n) => n.topic == topic).toList();
    }

    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && limit > 0) {
      notifications = notifications.take(limit).toList();
    }

    return notifications;
  }

  /// Clear old notifications (keep last 1000)
  Future<void> cleanupOldNotifications() async {
    try {
      final notifications = _notificationsBox.values.toList();
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (notifications.length > 1000) {
        final toDelete = notifications.skip(1000);
        for (final notification in toDelete) {
          await _notificationsBox.delete(notification.id);
        }
        dev.log('Cleaned up ${toDelete.length} old notifications');
      }
    } catch (e) {
      dev.log('Error cleaning up notifications: $e');
    }
  }

  /// Send crash alert notification
  Future<void> sendCrashAlert({
    required String title,
    required String message,
    required Map<String, dynamic> data,
    AlertPriority priority = AlertPriority.high,
  }) async {
    await _sendNotification(
      topic: 'onegate/crash-alert',
      title: title,
      message: message,
      data: data,
      priority: priority,
    );
  }

  /// Internal method to send notifications
  Future<bool> _sendNotification({
    required String topic,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    AlertPriority priority = AlertPriority.default_,
    List<String>? tags,
  }) async {
    try {
      final gateInfo = await _gateStorage.getSelectedGate();
      final companyId = await _gateStorage.getSocietyId();

      final notification = NotificationMessage(
        id: _uuid.v4(),
        topic: topic,
        title: title,
        message: message,
        priority: priority.value,
        tags: tags ?? [],
        data: {
          'gateId': gateInfo['id'],
          'gateName': gateInfo['name'],
          'companyId': companyId,
          'timestamp': DateTime.now().toIso8601String(),
          ...?data,
        },
        timestamp: DateTime.now(),
      );

      // Store notification locally
      await _notificationsBox.put(notification.id, notification);

      // Notify local listeners
      for (final listener in _listeners) {
        try {
          listener(notification);
        } catch (e) {
          dev.log('Error calling listener: $e');
        }
      }

      // Send to subscribers
      await _deliverToSubscribers(notification);

      dev.log('Notification sent successfully: ${notification.title}');
      return true;
    } catch (e) {
      dev.log('Error sending notification: $e');
      return false;
    }
  }

  /// Deliver notification to all subscribers of the topic
  Future<void> _deliverToSubscribers(NotificationMessage notification) async {
    final subscribers = _subscribersBox.values
        .where((s) =>
            s.isActive &&
            (s.topic == notification.topic || s.topic == 'onegate/+'))
        .toList();

    for (final subscriber in subscribers) {
      if (subscriber.webhookUrl != null) {
        _deliverWebhook(subscriber, notification);
      }
    }
  }

  /// Deliver notification via webhook (fire and forget)
  void _deliverWebhook(
      NotificationSubscriber subscriber, NotificationMessage notification) {
    _dio
        .post(
      subscriber.webhookUrl!,
      data: notification.toJson(),
    )
        .catchError((e) {
      dev.log('Webhook delivery failed for ${subscriber.id}: $e');
      return Response(requestOptions: RequestOptions(path: ''));
    });
  }
}
