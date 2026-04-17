import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/services/data_health/data_health_service.dart';
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/society/member.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';

String _tr(String key, {Map<String, String>? params}) {
  final context = navigatorKey.currentContext;
  if (context == null) return key;
  return FlutterI18n.translate(context, key, translationParams: params);
}

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
      dev.log('🔄 Starting immediate Meilisearch index sync...');

      final meilisearchService = MeilisearchService();

      // Initialize Meilisearch service
      final initialized = await meilisearchService.initialize();
      if (!initialized) {
        dev.log('❌ Failed to initialize Meilisearch service');
        return false;
      }

      // Check if Meilisearch is healthy
      final isHealthy = await meilisearchService.isHealthy();
      if (!isHealthy) {
        dev.log('❌ Meilisearch is not healthy, skipping index sync');
        return false;
      }

      dev.log('✅ Meilisearch is healthy, proceeding with data sync...');

      // Perform actual data indexing
      final syncResult = await _performDataIndexing(meilisearchService);

      if (syncResult) {
        dev.log('✅ Index sync completed successfully');
      } else {
        dev.log('❌ Index sync failed during data indexing');
      }

      return syncResult;
    } catch (e) {
      dev.log('❌ Error during index sync: $e');
      return false;
    }
  }

  /// Perform the actual data indexing from APIs to Meilisearch
  Future<bool> _performDataIndexing(
      MeilisearchService meilisearchService) async {
    try {
      // Import required services
      final remoteDataSource = RemoteDataSource();
      bool overallSuccess = true;

      dev.log('📊 Fetching and indexing residents data...');

      // Fetch and index residents data
      try {
        final membersResponse = await remoteDataSource.getMembersList();
        final membersList = membersResponse['data'] as List<dynamic>? ?? [];

        if (membersList.isNotEmpty) {
          // Convert to Member objects and index
          final members = membersList.map((memberData) {
            return Member.fromJson(memberData as Map<String, dynamic>);
          }).toList();

          final residentsIndexed =
              await meilisearchService.indexResidents(members);
          if (residentsIndexed) {
            dev.log('✅ Successfully indexed ${members.length} residents');
          } else {
            dev.log('❌ Failed to index residents data');
            overallSuccess = false;
          }
        } else {
          dev.log('⚠️ No residents data found to index');
        }
      } catch (e) {
        dev.log('❌ Error fetching/indexing residents: $e');
        overallSuccess = false;
      }

      dev.log('👥 Fetching and indexing visitors data...');

      // Fetch and index visitors data
      try {
        final visitorLogs = await remoteDataSource.fetchCheckInLogs();

        if (visitorLogs.isNotEmpty) {
          // Convert VisitorLog to Visitor objects for indexing
          final visitors =
              visitorLogs.where((log) => log.visitor != null).map((log) {
            final visitor = log.visitor!;
            return Visitor(
              id: visitor.id,
              name: visitor.name ?? '',
              mobile: visitor.mobile ?? '',
              visitor_image: visitor.visitor_image ?? '',
              isStaff: visitor.isStaff ?? false,
            );
          }).toList();

          final visitorsIndexed =
              await meilisearchService.indexVisitors(visitors);
          if (visitorsIndexed) {
            dev.log('✅ Successfully indexed ${visitors.length} visitors');
          } else {
            dev.log('❌ Failed to index visitors data');
            overallSuccess = false;
          }
        } else {
          dev.log('⚠️ No visitors data found to index');
        }
      } catch (e) {
        dev.log('❌ Error fetching/indexing visitors: $e');
        overallSuccess = false;
      }

      return overallSuccess;
    } catch (e) {
      dev.log('❌ Critical error during data indexing: $e');
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
          title: _tr('Scheduled Health Check Alert'),
          message: _tr('Background health check detected issues: {status}',
              params: {'status': result.overallStatus.displayName}),
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
          title: _tr('Background Health Check Failed'),
          message: _tr('Background health check task failed: {error}',
              params: {'error': '$e'}),
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
          title: _tr('Meilisearch Service Unhealthy'),
          message:
              _tr('Meilisearch service is not healthy during background sync'),
          data: {
            'indexName': 'all',
            'error': 'Meilisearch service is not healthy',
          },
        );
        return;
      }

      // Perform index sync with actual data
      final syncResult = await _performDataIndexing(meilisearchService);

      if (syncResult) {
        dev.log('✅ Background index sync completed successfully');
      } else {
        dev.log('❌ Background index sync failed');
        // Send error notification
        await notificationService.sendSearchErrorAlert(
          title: _tr('Background Index Sync Failed'),
          message:
              _tr('Failed to sync data to Meilisearch during background task'),
          data: {
            'indexName': 'background_sync',
            'error': 'Data indexing failed',
          },
        );
      }
    } catch (e) {
      dev.log('Error in background index sync: $e');

      // Try to send error notification
      try {
        final notificationService = CustomNotificationService();
        await notificationService.initialize();
        await notificationService.sendSearchErrorAlert(
          title: _tr('Background Index Sync Failed'),
          message: _tr('Background Meilisearch index sync failed: {error}',
              params: {'error': '$e'}),
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
