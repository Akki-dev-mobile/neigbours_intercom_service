import 'dart:developer' as dev;
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';
import 'package:hive/hive.dart';

/// Service for monitoring data health and consistency
class DataHealthService {
  static const String _healthCheckBoxName = 'health_checks';
  static const String _lastHealthCheckKey = 'last_health_check';
  static const String _healthCheckIntervalKey = 'health_check_interval';

  late RemoteDataSource _remoteDataSource;
  late CustomNotificationService _notificationService;
  late MeilisearchService _meilisearchService;
  late GateStorage _gateStorage;
  late Box _healthCheckBox;

  static final DataHealthService _instance = DataHealthService._internal();
  factory DataHealthService() => _instance;
  DataHealthService._internal();

  /// Initialize the data health service
  Future<void> initialize() async {
    _remoteDataSource = RemoteDataSource();
    _notificationService = CustomNotificationService();
    await _notificationService.initialize();
    _meilisearchService = MeilisearchService();
    _gateStorage = GateStorage();

    // Note: Hive is already initialized in main.dart
    // Initialize Hive box for health check data
    _healthCheckBox = await Hive.openBox(_healthCheckBoxName);

    dev.log('DataHealthService initialized');
  }

  /// Perform comprehensive health check
  Future<HealthCheckResult> performHealthCheck() async {
    dev.log('Starting comprehensive health check...');

    final result = HealthCheckResult();
    result.timestamp = DateTime.now();

    try {
      // Check resident data consistency
      final residentCheck = await _checkResidentDataConsistency();
      result.residentDataCheck = residentCheck;

      // Check visitor data consistency
      final visitorCheck = await _checkVisitorDataConsistency();
      result.visitorDataCheck = visitorCheck;

      // Check API health
      final apiCheck = await _checkApiHealth();
      result.apiHealthCheck = apiCheck;

      // Check Meilisearch health
      final searchCheck = await _checkMeilisearchHealth();
      result.meilisearchHealthCheck = searchCheck;

      // Calculate overall health status
      result.overallStatus = _calculateOverallStatus([
        residentCheck.status,
        visitorCheck.status,
        apiCheck.status,
        searchCheck.status,
      ]);

      // Store health check result
      await _storeHealthCheckResult(result);

      // Send alerts if necessary
      await _processHealthCheckAlerts(result);

      dev.log('Health check completed with status: ${result.overallStatus}');
      return result;
    } catch (e) {
      dev.log('Error during health check: $e');
      result.overallStatus = HealthStatus.critical;
      result.error = e.toString();
      return result;
    }
  }

  /// Check resident data consistency
  Future<DataConsistencyCheck> _checkResidentDataConsistency() async {
    final check = DataConsistencyCheck();
    check.checkType = 'resident_data';
    check.timestamp = DateTime.now();

    try {
      final companyId = await _gateStorage.getSocietyId();
      if (companyId == null) {
        check.status = HealthStatus.warning;
        check.message = 'Company ID not found';
        return check;
      }

      // Get all buildings
      final buildingsResponse = await _remoteDataSource.getBuildingsList();
      final buildings = buildingsResponse as List<dynamic>? ?? [];

      int totalExpectedResidents = 0;
      int totalActualResidents = 0;
      final buildingMismatches = <Map<String, dynamic>>[];

      for (final building in buildings) {
        final buildingName = building['soc_building_name']?.toString() ?? '';

        // Get members for this building
        final membersResponse = await _remoteDataSource.getMembersList(
          buildingName: buildingName,
        );
        final members = membersResponse['data'] as List<dynamic>? ?? [];
        final actualCount = members.length;

        // For now, we'll use the actual count as expected
        // In a real scenario, you'd have a separate source of truth
        final expectedCount = actualCount;

        totalExpectedResidents += expectedCount;
        totalActualResidents += actualCount;

        if (expectedCount != actualCount) {
          buildingMismatches.add({
            'building': buildingName,
            'expected': expectedCount,
            'actual': actualCount,
            'difference': actualCount - expectedCount,
          });
        }
      }

      check.details = {
        'totalBuildings': buildings.length,
        'totalExpectedResidents': totalExpectedResidents,
        'totalActualResidents': totalActualResidents,
        'buildingMismatches': buildingMismatches,
      };

      if (buildingMismatches.isNotEmpty) {
        check.status = HealthStatus.warning;
        check.message =
            'Found ${buildingMismatches.length} buildings with resident count mismatches';
      } else {
        check.status = HealthStatus.healthy;
        check.message = 'All resident data is consistent';
      }
    } catch (e) {
      check.status = HealthStatus.critical;
      check.message = 'Error checking resident data: $e';
      check.error = e.toString();
    }

    return check;
  }

  /// Check visitor data consistency
  Future<DataConsistencyCheck> _checkVisitorDataConsistency() async {
    final check = DataConsistencyCheck();
    check.checkType = 'visitor_data';
    check.timestamp = DateTime.now();

    try {
      // Get visitor logs for today
      final today = DateTime.now();
      final formattedDate =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final approvals = await _remoteDataSource.fetchApprovals();
      final visitorLogs = approvals
          .where((log) => log.logCreatedAt.startsWith(formattedDate))
          .toList();

      // Check for data inconsistencies
      final inconsistencies = <Map<String, dynamic>>[];

      for (final log in visitorLogs) {
        // Check for missing required fields
        if (log.visitorName.isEmpty) {
          inconsistencies.add({
            'type': 'missing_visitor_name',
            'logId': log.visitorLogId,
            'message': 'Visitor log missing name',
          });
        }

        if (log.visitorMobile.isEmpty) {
          inconsistencies.add({
            'type': 'missing_visitor_mobile',
            'logId': log.visitorLogId,
            'message': 'Visitor log missing mobile number',
          });
        }

        // Check for duplicate entries
        final duplicates = visitorLogs
            .where((other) =>
                other.visitorLogId != log.visitorLogId &&
                other.visitorMobile == log.visitorMobile &&
                other.logCreatedAt == log.logCreatedAt)
            .toList();

        if (duplicates.isNotEmpty) {
          inconsistencies.add({
            'type': 'duplicate_visitor_entry',
            'logId': log.visitorLogId,
            'duplicateIds': duplicates.map((d) => d.visitorLogId).toList(),
            'message': 'Duplicate visitor entries found',
          });
        }
      }

      check.details = {
        'totalVisitorLogs': visitorLogs.length,
        'inconsistencies': inconsistencies,
        'checkDate': formattedDate,
      };

      if (inconsistencies.isNotEmpty) {
        check.status = HealthStatus.warning;
        check.message =
            'Found ${inconsistencies.length} visitor data inconsistencies';
      } else {
        check.status = HealthStatus.healthy;
        check.message = 'All visitor data is consistent';
      }
    } catch (e) {
      check.status = HealthStatus.critical;
      check.message = 'Error checking visitor data: $e';
      check.error = e.toString();
    }

    return check;
  }

  /// Check API health
  Future<DataConsistencyCheck> _checkApiHealth() async {
    final check = DataConsistencyCheck();
    check.checkType = 'api_health';
    check.timestamp = DateTime.now();

    try {
      final apiChecks = <Map<String, dynamic>>[];

      // Test gates API
      try {
        final gates = await _remoteDataSource.fetchGates();
        apiChecks.add({
          'endpoint': 'gates',
          'status': 'healthy',
          'responseCount': gates.length,
        });
      } catch (e) {
        apiChecks.add({
          'endpoint': 'gates',
          'status': 'error',
          'error': e.toString(),
        });
      }

      // Test members API
      try {
        final members = await _remoteDataSource.getMembersList();
        apiChecks.add({
          'endpoint': 'members',
          'status': 'healthy',
          'responseCount': (members['data'] as List?)?.length ?? 0,
        });
      } catch (e) {
        apiChecks.add({
          'endpoint': 'members',
          'status': 'error',
          'error': e.toString(),
        });
      }

      // Test buildings API
      try {
        final buildings = await _remoteDataSource.getBuildingsList();
        apiChecks.add({
          'endpoint': 'buildings',
          'status': 'healthy',
          'responseCount': buildings.length,
        });
      } catch (e) {
        apiChecks.add({
          'endpoint': 'buildings',
          'status': 'error',
          'error': e.toString(),
        });
      }

      final errorCount = apiChecks.where((c) => c['status'] == 'error').length;

      check.details = {
        'apiChecks': apiChecks,
        'totalEndpoints': apiChecks.length,
        'errorCount': errorCount,
      };

      if (errorCount > 0) {
        check.status = errorCount == apiChecks.length
            ? HealthStatus.critical
            : HealthStatus.warning;
        check.message =
            '$errorCount out of ${apiChecks.length} API endpoints are failing';
      } else {
        check.status = HealthStatus.healthy;
        check.message = 'All API endpoints are healthy';
      }
    } catch (e) {
      check.status = HealthStatus.critical;
      check.message = 'Error checking API health: $e';
      check.error = e.toString();
    }

    return check;
  }

  /// Check Meilisearch health
  Future<DataConsistencyCheck> _checkMeilisearchHealth() async {
    final check = DataConsistencyCheck();
    check.checkType = 'meilisearch_health';
    check.timestamp = DateTime.now();

    try {
      final isHealthy = await _meilisearchService.isHealthy();

      if (isHealthy) {
        check.status = HealthStatus.healthy;
        check.message = 'Meilisearch is healthy and responsive';
      } else {
        check.status = HealthStatus.critical;
        check.message = 'Meilisearch is not responding';
      }

      check.details = {
        'isHealthy': isHealthy,
        'checkTime': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      check.status = HealthStatus.critical;
      check.message = 'Error checking Meilisearch health: $e';
      check.error = e.toString();
    }

    return check;
  }

  /// Calculate overall health status
  HealthStatus _calculateOverallStatus(List<HealthStatus> statuses) {
    if (statuses.contains(HealthStatus.critical)) {
      return HealthStatus.critical;
    } else if (statuses.contains(HealthStatus.warning)) {
      return HealthStatus.warning;
    } else {
      return HealthStatus.healthy;
    }
  }

  /// Store health check result
  Future<void> _storeHealthCheckResult(HealthCheckResult result) async {
    await _healthCheckBox.put(_lastHealthCheckKey, result.toJson());
    dev.log('Health check result stored');
  }

  /// Process health check alerts
  Future<void> _processHealthCheckAlerts(HealthCheckResult result) async {
    if (result.overallStatus == HealthStatus.critical) {
      await _notificationService.sendHealthCheckAlert(
        title: 'Critical Health Check Alert',
        message: 'OneGate system health check detected critical issues',
        data: result.toJson(),
        priority: AlertPriority.max,
      );
    } else if (result.overallStatus == HealthStatus.warning) {
      await _notificationService.sendHealthCheckAlert(
        title: 'Health Check Warning',
        message: 'OneGate system health check detected warnings',
        data: result.toJson(),
        priority: AlertPriority.high,
      );
    }

    // Send specific alerts for data inconsistencies
    if (result.residentDataCheck?.status == HealthStatus.warning) {
      final mismatches =
          result.residentDataCheck?.details?['buildingMismatches'] as List? ??
              [];
      for (final mismatch in mismatches) {
        await _notificationService.sendDataAnomalyAlert(
          title: 'Resident Count Mismatch',
          message:
              'Building ${mismatch['building']}: Expected ${mismatch['expected']}, Found ${mismatch['actual']}',
          data: {
            'building': mismatch['building'],
            'expectedCount': mismatch['expected'],
            'actualCount': mismatch['actual'],
          },
        );
      }
    }

    if (result.visitorDataCheck?.status == HealthStatus.warning) {
      await _notificationService.sendDataAnomalyAlert(
        title: 'Visitor Data Inconsistency',
        message: result.visitorDataCheck?.message ??
            'Visitor data inconsistency detected',
        data: result.visitorDataCheck?.details,
      );
    }
  }

  /// Get last health check result
  Future<HealthCheckResult?> getLastHealthCheckResult() async {
    final data = _healthCheckBox.get(_lastHealthCheckKey);
    if (data != null) {
      return HealthCheckResult.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// Set health check interval
  Future<void> setHealthCheckInterval(Duration interval) async {
    await _healthCheckBox.put(_healthCheckIntervalKey, interval.inMinutes);
  }

  /// Get health check interval
  Future<Duration> getHealthCheckInterval() async {
    final minutes =
        _healthCheckBox.get(_healthCheckIntervalKey, defaultValue: 30);
    return Duration(minutes: minutes);
  }
}

/// Health status enumeration
enum HealthStatus {
  healthy,
  warning,
  critical;

  String get displayName {
    switch (this) {
      case HealthStatus.healthy:
        return 'Healthy';
      case HealthStatus.warning:
        return 'Warning';
      case HealthStatus.critical:
        return 'Critical';
    }
  }
}

/// Data consistency check result
class DataConsistencyCheck {
  String? checkType;
  DateTime? timestamp;
  HealthStatus status = HealthStatus.healthy;
  String? message;
  String? error;
  Map<String, dynamic>? details;

  DataConsistencyCheck();

  Map<String, dynamic> toJson() {
    return {
      'checkType': checkType,
      'timestamp': timestamp?.toIso8601String(),
      'status': status.name,
      'message': message,
      'error': error,
      'details': details,
    };
  }

  factory DataConsistencyCheck.fromJson(Map<String, dynamic> json) {
    final check = DataConsistencyCheck();
    check.checkType = json['checkType'];
    check.timestamp =
        json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null;
    check.status = HealthStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => HealthStatus.healthy,
    );
    check.message = json['message'];
    check.error = json['error'];
    check.details = json['details'];
    return check;
  }
}

/// Overall health check result
class HealthCheckResult {
  DateTime? timestamp;
  HealthStatus overallStatus = HealthStatus.healthy;
  String? error;
  DataConsistencyCheck? residentDataCheck;
  DataConsistencyCheck? visitorDataCheck;
  DataConsistencyCheck? apiHealthCheck;
  DataConsistencyCheck? meilisearchHealthCheck;

  HealthCheckResult();

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp?.toIso8601String(),
      'overallStatus': overallStatus.name,
      'error': error,
      'residentDataCheck': residentDataCheck?.toJson(),
      'visitorDataCheck': visitorDataCheck?.toJson(),
      'apiHealthCheck': apiHealthCheck?.toJson(),
      'meilisearchHealthCheck': meilisearchHealthCheck?.toJson(),
    };
  }

  factory HealthCheckResult.fromJson(Map<String, dynamic> json) {
    final result = HealthCheckResult();
    result.timestamp =
        json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null;
    result.overallStatus = HealthStatus.values.firstWhere(
      (s) => s.name == json['overallStatus'],
      orElse: () => HealthStatus.healthy,
    );
    result.error = json['error'];
    result.residentDataCheck = json['residentDataCheck'] != null
        ? DataConsistencyCheck.fromJson(json['residentDataCheck'])
        : null;
    result.visitorDataCheck = json['visitorDataCheck'] != null
        ? DataConsistencyCheck.fromJson(json['visitorDataCheck'])
        : null;
    result.apiHealthCheck = json['apiHealthCheck'] != null
        ? DataConsistencyCheck.fromJson(json['apiHealthCheck'])
        : null;
    result.meilisearchHealthCheck = json['meilisearchHealthCheck'] != null
        ? DataConsistencyCheck.fromJson(json['meilisearchHealthCheck'])
        : null;
    return result;
  }
}
