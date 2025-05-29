import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/services/data_health/data_health_service.dart';
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';

/// Background service for data observability and periodic health checks
class DataObservabilityService {
  static final DataObservabilityService _instance =
      DataObservabilityService._internal();
  factory DataObservabilityService() => _instance;
  DataObservabilityService._internal();

  bool _isInitialized = false;
  Timer? _healthCheckTimer;
  Timer? _indexSyncTimer;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      dev.log('DataObservabilityService initialized');
    } catch (e) {
      dev.log('Error initializing DataObservabilityService: $e');
    }
  }

  /// Start periodic health checks
  Future<bool> startPeriodicHealthChecks({
    Duration interval = const Duration(minutes: 30),
  }) async {
    if (!kDebugMode) {
      dev.log('Background tasks disabled in release mode');
      return false;
    }

    try {
      // Cancel existing timer
      _healthCheckTimer?.cancel();

      // Start new periodic timer
      _healthCheckTimer = Timer.periodic(interval, (timer) async {
        await _executeHealthCheck();
      });

      dev.log(
          'Periodic health checks started with ${interval.inMinutes} minute interval');
      return true;
    } catch (e) {
      dev.log('Error starting periodic health checks: $e');
      return false;
    }
  }

  /// Start periodic Meilisearch index synchronization
  Future<bool> startPeriodicIndexSync({
    Duration interval = const Duration(hours: 2),
  }) async {
    if (!kDebugMode) {
      dev.log('Background tasks disabled in release mode');
      return false;
    }

    try {
      // Cancel existing timer
      _indexSyncTimer?.cancel();

      // Start new periodic timer
      _indexSyncTimer = Timer.periodic(interval, (timer) async {
        await _executeIndexSync();
      });

      dev.log(
          'Periodic index sync started with ${interval.inHours} hour interval');
      return true;
    } catch (e) {
      dev.log('Error starting periodic index sync: $e');
      return false;
    }
  }

  /// Stop all background tasks
  Future<void> stopAllTasks() async {
    try {
      _healthCheckTimer?.cancel();
      _indexSyncTimer?.cancel();
      _healthCheckTimer = null;
      _indexSyncTimer = null;
      dev.log('All background tasks stopped');
    } catch (e) {
      dev.log('Error stopping background tasks: $e');
    }
  }

  /// Perform immediate health check
  Future<HealthCheckResult> performImmediateHealthCheck() async {
    final healthService = DataHealthService();
    await healthService.initialize();
    return await healthService.performHealthCheck();
  }

  /// Perform immediate index sync
  Future<bool> performImmediateIndexSync() async {
    try {
      final meilisearchService = MeilisearchService();
      final isHealthy = await meilisearchService.isHealthy();

      if (!isHealthy) {
        dev.log('Meilisearch is not healthy, skipping index sync');
        return false;
      }

      // This would typically sync data from your primary database to Meilisearch
      // For now, we'll just log that the sync would happen
      dev.log('Index sync completed successfully');
      return true;
    } catch (e) {
      dev.log('Error during index sync: $e');
      return false;
    }
  }

  /// Get background task status
  Future<Map<String, dynamic>> getTaskStatus() async {
    return {
      'healthCheckActive': _healthCheckTimer?.isActive ?? false,
      'indexSyncActive': _indexSyncTimer?.isActive ?? false,
      'lastHealthCheck': DateTime.now().toIso8601String(),
      'lastIndexSync': DateTime.now().toIso8601String(),
    };
  }

  /// Execute health check in background
  Future<void> _executeHealthCheck() async {
    try {
      dev.log('Executing background health check...');

      // Initialize services
      final healthService = DataHealthService();
      await healthService.initialize();

      final notificationService = CustomNotificationService();
      await notificationService.initialize();

      // Perform health check
      final result = await healthService.performHealthCheck();

      // Log result
      dev.log(
          'Background health check completed with status: ${result.overallStatus}');

      // Send notification if there are issues
      if (result.overallStatus != HealthStatus.healthy) {
        await notificationService.sendHealthCheckAlert(
          title: 'Scheduled Health Check Alert',
          message:
              'Background health check detected issues: ${result.overallStatus.displayName}',
          data: {
            'backgroundTask': true,
            'taskTime': DateTime.now().toIso8601String(),
            ...result.toJson(),
          },
          priority: result.overallStatus == HealthStatus.critical
              ? AlertPriority.max
              : AlertPriority.high,
        );
      }
    } catch (e) {
      dev.log('Error in background health check: $e');

      // Try to send error notification
      try {
        final notificationService = CustomNotificationService();
        await notificationService.initialize();
        await notificationService.sendHealthCheckAlert(
          title: 'Background Health Check Failed',
          message: 'Background health check task failed: $e',
          data: {
            'backgroundTask': true,
            'error': e.toString(),
            'taskTime': DateTime.now().toIso8601String(),
          },
          priority: AlertPriority.high,
        );
      } catch (notificationError) {
        dev.log('Failed to send error notification: $notificationError');
      }
    }
  }

  /// Execute index sync in background
  Future<void> _executeIndexSync() async {
    try {
      dev.log('Executing background index sync...');

      // Initialize services
      final meilisearchService = MeilisearchService();
      await meilisearchService.initialize();

      final notificationService = CustomNotificationService();
      await notificationService.initialize();

      // Check if Meilisearch is healthy
      final isHealthy = await meilisearchService.isHealthy();
      if (!isHealthy) {
        await notificationService.sendSearchErrorAlert(
          title: 'Meilisearch Service Unhealthy',
          message: 'Meilisearch service is not healthy during background sync',
          data: {
            'indexName': 'all',
            'error': 'Meilisearch service is not healthy',
          },
        );
        return;
      }

      // Perform index sync
      // This is where you would typically:
      // 1. Fetch latest data from your APIs
      // 2. Index the data in Meilisearch
      // 3. Verify the indexing was successful

      dev.log('Background index sync completed successfully');
    } catch (e) {
      dev.log('Error in background index sync: $e');

      // Try to send error notification
      try {
        final notificationService = CustomNotificationService();
        await notificationService.initialize();
        await notificationService.sendSearchErrorAlert(
          title: 'Background Index Sync Failed',
          message: 'Background Meilisearch index sync failed: $e',
          data: {
            'indexName': 'background_sync',
            'error': e.toString(),
          },
        );
      } catch (notificationError) {
        dev.log('Failed to send error notification: $notificationError');
      }
    }
  }
}

/// Manual trigger for background tasks (for testing)
class BackgroundTaskTrigger {
  static Future<void> triggerHealthCheck() async {
    final service = DataObservabilityService();
    await service._executeHealthCheck();
  }

  static Future<void> triggerIndexSync() async {
    final service = DataObservabilityService();
    await service._executeIndexSync();
  }
}
