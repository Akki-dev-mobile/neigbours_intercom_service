import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/data_health/data_health_service.dart';
import 'package:flutter_onegate/services/background/data_observability_service.dart';
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/services/notifications/notification_manager.dart';
import 'package:flutter_onegate/presentation/features/settings/custom_notifications_screen.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';
import 'package:flutter_onegate/services/search/meilisearch_config_helper.dart';
import 'package:flutter_onegate/presentation/features/settings/meilisearch_config_screen.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_screen.dart';
import 'package:flutter_onegate/presentation/features/settings/crash_reports_screen.dart';
import 'package:flutter_onegate/presentation/features/settings/analytics_dashboard_screen.dart';
import 'package:flutter_onegate/presentation/features/settings/observatory_dashboard_screen.dart';
import 'package:flutter_onegate/services/observatory/observatory_dashboard_service.dart';
import 'package:flutter_onegate/presentation/widgets/debug_token_widget.dart';
import 'package:ionicons/ionicons.dart';

/// Settings screen for data observability and network monitoring
class DataObservabilitySettingsScreen extends StatefulWidget {
  const DataObservabilitySettingsScreen({Key? key}) : super(key: key);

  @override
  State<DataObservabilitySettingsScreen> createState() =>
      _DataObservabilitySettingsScreenState();
}

class _DataObservabilitySettingsScreenState
    extends State<DataObservabilitySettingsScreen> {
  final DataHealthService _healthService = DataHealthService();
  final DataObservabilityService _observabilityService =
      DataObservabilityService();
  final CustomNotificationService _notificationService =
      CustomNotificationService();
  final NotificationManager _notificationManager = NotificationManager();
  final MeilisearchService _meilisearchService = MeilisearchService();
  final ObservatoryDashboardService _observatoryService =
      ObservatoryDashboardService();

  bool _isLoading = true;
  HealthCheckResult? _lastHealthCheck;
  bool _backgroundTasksEnabled = false;
  bool _notificationsEnabled = false;
  bool _meilisearchHealthy = false;
  Map<String, dynamic>? _meilisearchStatus;
  String? _lastSyncError;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    try {
      await _healthService.initialize();
      await _observabilityService.initialize();
      await _notificationService.initialize();
      await _notificationManager.initialize();
      await _meilisearchService.initialize();
      await _observatoryService.initialize();

      await _loadCurrentStatus();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentStatus() async {
    try {
      final lastCheck = await _healthService.getLastHealthCheckResult();
      final meilisearchHealthy = await _meilisearchService.isHealthy();

      setState(() {
        _lastHealthCheck = lastCheck;
        _meilisearchHealthy = meilisearchHealthy;
        _backgroundTasksEnabled = kDebugMode; // Only available in debug mode
        _notificationsEnabled = true; // Assume enabled for now
      });
    } catch (e) {
      debugPrint('Error loading status: $e');
    }
  }

  Future<void> _runHealthCheck() async {
    setState(() => _isLoading = true);

    try {
      final result = await _observabilityService.performImmediateHealthCheck();
      setState(() => _lastHealthCheck = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Health check completed: ${result.overallStatus.displayName}'),
            backgroundColor: _getStatusColor(result.overallStatus),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Health check failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotification() async {
    try {
      final success = await _notificationService.testNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Test notification sent successfully'
                : 'Failed to send test notification'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncMeilisearchIndex() async {
    setState(() {
      _isLoading = true;
      _lastSyncError = null;
    });

    try {
      // First, check Meilisearch configuration
      final configStatus =
          await MeilisearchConfigHelper.getConfigurationStatus();
      setState(() => _meilisearchStatus = configStatus);

      if (!configStatus['isConfigured']) {
        // Try to initialize with defaults
        final initialized =
            await MeilisearchConfigHelper.initializeWithDefaults();
        if (!initialized) {
          throw Exception(
              'Failed to initialize Meilisearch with default configuration');
        }
      }

      // Perform the sync
      final success = await _observabilityService.performImmediateIndexSync();

      setState(() {
        _meilisearchHealthy = success;
        if (!success) {
          _lastSyncError = 'Index sync failed - check logs for details';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Index sync completed successfully'
                : 'Index sync failed - check configuration'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
            action: !success
                ? SnackBarAction(
                    label: 'Details',
                    onPressed: () => _showSyncErrorDialog(),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      setState(() => _lastSyncError = e.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error syncing index: ${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () => _showSyncErrorDialog(),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToMeilisearchConfig() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const MeilisearchConfigScreen(),
      ),
    );

    // If configuration was successful, reload the status
    if (result == true) {
      await _loadCurrentStatus();
    }
  }

  void _showSyncErrorDialog() {
    if (_lastSyncError == null && _meilisearchStatus == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meilisearch Sync Error'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lastSyncError != null) ...[
                const Text('Error:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_lastSyncError!),
                const SizedBox(height: 16),
              ],
              if (_meilisearchStatus != null) ...[
                const Text('Configuration Status:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...(_meilisearchStatus!.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${entry.key}: ${entry.value}'),
                    ))),
                const SizedBox(height: 16),
              ],
              const Text('Troubleshooting:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  '1. Ensure Meilisearch server is running on localhost:7700'),
              const Text('2. Check network connectivity'),
              const Text('3. Verify API key configuration'),
              const Text('4. Check app logs for detailed error messages'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToMeilisearchConfig();
            },
            child: const Text('Configure'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _syncMeilisearchIndex(); // Retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return Colors.green;
      case HealthStatus.warning:
        return Colors.orange;
      case HealthStatus.critical:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return Ionicons.checkmark_circle;
      case HealthStatus.warning:
        return Ionicons.warning;
      case HealthStatus.critical:
        return Ionicons.close_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return MyScrollView(
      pageTitle: 'Data Observability',
      pageBody: _isLoading
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xffF44336).withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gate Animation
                    _DataObservabilityGateLoader(),

                    const SizedBox(height: 20),
                    Text(
                      'Loading Data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xff212427),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait while we fetch observability data',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildHealthStatusCard(isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildObservatoryCard(isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildMonitoringCardsRow(isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildMeilisearchCard(isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildNotificationsCard(isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildBackgroundTasksCard(isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                if (kDebugMode) ...[
                  _buildDebugTokenCard(isTablet),
                  SizedBox(height: isTablet ? 24 : 16),
                ],
                _buildActionsCard(isTablet),
              ],
            ),
    );
  }

  Widget _buildHealthStatusCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.08),
                    const Color(0xffff5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
              children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Ionicons.pulse_outline,
                      color: const Color(0xffF44336),
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                  'System Health',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 22 : 20,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Monitor system performance',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                      ),
                ),
              ],
            ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            if (_lastHealthCheck != null) ...[
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: _getStatusColor(_lastHealthCheck!.overallStatus)
                      .withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getStatusColor(_lastHealthCheck!.overallStatus)
                        .withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 10 : 8),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(_lastHealthCheck!.overallStatus)
                                    .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                    _getStatusIcon(_lastHealthCheck!.overallStatus),
                            color: _getStatusColor(
                                _lastHealthCheck!.overallStatus),
                            size: isTablet ? 24 : 20,
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                  Text(
                                'Overall Status',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xff57636C),
                                      fontSize: isTablet ? 15 : 14,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _lastHealthCheck!.overallStatus.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: _getStatusColor(
                                          _lastHealthCheck!.overallStatus),
                                      fontWeight: FontWeight.w700,
                                      fontSize: isTablet ? 18 : 16,
                    ),
                  ),
                ],
              ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16 : 12,
                        vertical: isTablet ? 10 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Ionicons.time_outline,
                            size: isTablet ? 18 : 16,
                            color: const Color(0xff57636C),
                          ),
                          SizedBox(width: isTablet ? 10 : 8),
              Text(
                'Last Check: ${_lastHealthCheck!.timestamp?.toString().split('.')[0] ?? 'Unknown'}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xff57636C),
                                      fontSize: isTablet ? 14 : 13,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildHealthCheckDetails(isTablet),
            ] else ...[
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Ionicons.information_circle_outline,
                      size: isTablet ? 48 : 40,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    Text(
                      'No Health Check Data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff212427),
                            fontSize: isTablet ? 18 : 16,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Run a health check to see system status',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xff57636C),
                            fontSize: isTablet ? 15 : 14,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCheckDetails(bool isTablet) {
    if (_lastHealthCheck == null) return const SizedBox.shrink();

    final checks = [
      ('Resident Data', _lastHealthCheck!.residentDataCheck),
      ('Visitor Data', _lastHealthCheck!.visitorDataCheck),
      ('API Health', _lastHealthCheck!.apiHealthCheck),
      ('Meilisearch', _lastHealthCheck!.meilisearchHealthCheck),
    ];

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Health Checks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff212427),
                  fontSize: isTablet ? 18 : 16,
                ),
          ),
          SizedBox(height: isTablet ? 16 : 12),
          ...checks.map((check) {
        final (name, result) = check;
        if (result == null) return const SizedBox.shrink();

            return Container(
              margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              decoration: BoxDecoration(
                color: _getStatusColor(result.status).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(result.status).withOpacity(0.2),
                  width: 1,
                ),
              ),
          child: Row(
            children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 8 : 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(result.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                _getStatusIcon(result.status),
                      size: isTablet ? 18 : 16,
                color: _getStatusColor(result.status),
              ),
                  ),
                  SizedBox(width: isTablet ? 14 : 12),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff212427),
                            fontSize: isTablet ? 16 : 15,
                          ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 10,
                      vertical: isTablet ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(result.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                result.status.displayName,
                style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 13 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
        ],
      ),
    );
  }

  Widget _buildObservatoryCard(bool isTablet) {
    final isActive = _observatoryService.isInitialized &&
        _observatoryService.isCollectingMetrics;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.08),
                    const Color(0xffff5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
              children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                  Ionicons.telescope_outline,
                      color: const Color(0xffF44336),
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                  'Observatory Dashboard',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 22 : 20,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Centralized monitoring & analytics',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                                  ),
                        ),
                      ],
                    ),
                  ),
                Container(
                    padding: EdgeInsets.all(isTablet ? 8 : 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isTablet ? 10 : 8,
                          height: isTablet ? 10 : 8,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                        SizedBox(width: isTablet ? 8 : 6),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: isActive ? Colors.green : Colors.grey,
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'Comprehensive monitoring with SigNoz, Grafana, PostHog, and advanced analytics tools for real-time insights.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xff57636C),
                    fontSize: isTablet ? 15 : 14,
                    height: 1.4,
                  ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: isTablet ? 52 : 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xffF44336),
                          const Color(0xffF44336).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ObservatoryDashboardScreen(),
                        ),
                      );
                    },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Ionicons.analytics_outline,
                        size: isTablet ? 22 : 20,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Open Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 16 : 15,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Container(
                  height: isTablet ? 52 : 48,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.1)
                        : const Color(0xffF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? Colors.green.withOpacity(0.3)
                          : const Color(0xffF44336).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ElevatedButton.icon(
                  onPressed: isActive ? null : _initializeObservatory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isActive
                      ? Ionicons.checkmark_outline
                          : Ionicons.play_outline,
                      size: isTablet ? 22 : 20,
                      color: isActive ? Colors.green : const Color(0xffF44336),
                    ),
                    label: Text(
                      isActive ? 'Active' : 'Start',
                      style: TextStyle(
                        color:
                            isActive ? Colors.green : const Color(0xffF44336),
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 16 : 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeObservatory() async {
    try {
      await _observatoryService.initialize();
      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Observatory Dashboard initialized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize Observatory: $e')),
        );
      }
    }
  }

  Widget _buildMonitoringCardsRow(bool isTablet) {
    return Row(
      children: [
        Expanded(child: _buildNetworkLogsCard(isTablet)),
        SizedBox(width: isTablet ? 12 : 8),
        Expanded(child: _buildCrashReportsCard(isTablet)),
      ],
    );
  }

  Widget _buildNetworkLogsCard(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NetworkLogScreen(),
            ),
          );
        },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Ionicons.analytics_outline,
                        color: const Color(0xffF44336),
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Ionicons.chevron_forward,
                      color: const Color(0xff57636C),
                      size: isTablet ? 20 : 16,
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  'Network Logs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff212427),
                        fontSize: isTablet ? 18 : 16,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'API monitoring & requests',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff57636C),
                        fontSize: isTablet ? 14 : 13,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrashReportsCard(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CrashReportsScreen(),
            ),
          );
        },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Ionicons.bug_outline,
                        color: const Color(0xffF44336),
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Ionicons.chevron_forward,
                      color: const Color(0xff57636C),
                      size: isTablet ? 20 : 16,
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  'Crash Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff212427),
                        fontSize: isTablet ? 18 : 16,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Error tracking & analysis',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff57636C),
                        fontSize: isTablet ? 14 : 13,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeilisearchCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.08),
                    const Color(0xffff5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
              children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Ionicons.search_outline,
                      color: const Color(0xffF44336),
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                  'Meilisearch',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 22 : 20,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search engine & indexing',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                      ),
                ),
              ],
            ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 10,
                      vertical: isTablet ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: _meilisearchHealthy
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _meilisearchHealthy
                      ? Ionicons.checkmark_circle
                      : Ionicons.close_circle,
                          color:
                              _meilisearchHealthy ? Colors.green : Colors.red,
                          size: isTablet ? 18 : 16,
                ),
                        SizedBox(width: isTablet ? 8 : 6),
                Text(
                  _meilisearchHealthy ? 'Healthy' : 'Unhealthy',
                  style: TextStyle(
                            color:
                                _meilisearchHealthy ? Colors.green : Colors.red,
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: isTablet ? 48 : 44,
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xffF44336).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextButton.icon(
                  onPressed: () => _navigateToMeilisearchConfig(),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.settings,
                        size: isTablet ? 20 : 18,
                        color: const Color(0xffF44336),
                      ),
                      label: Text(
                        'Configure',
                        style: TextStyle(
                          color: const Color(0xffF44336),
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 15 : 14,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Expanded(
                  child: Container(
                    height: isTablet ? 48 : 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xffF44336),
                          const Color(0xffF44336).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextButton(
                  onPressed: _syncMeilisearchIndex,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Sync Index',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 15 : 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.08),
                    const Color(0xffff5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
              children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Ionicons.notifications_outline,
                      color: const Color(0xffF44336),
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                  'Custom Notifications',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 22 : 20,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Push notifications & alerts',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                      ),
                ),
              ],
            ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 10,
                      vertical: isTablet ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: _notificationsEnabled
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _notificationsEnabled
                      ? Ionicons.checkmark_circle
                      : Ionicons.close_circle,
                          color:
                              _notificationsEnabled ? Colors.green : Colors.red,
                          size: isTablet ? 18 : 16,
                ),
                        SizedBox(width: isTablet ? 8 : 6),
                Text(
                  _notificationsEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                            color: _notificationsEnabled
                                ? Colors.green
                                : Colors.red,
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Row(
                  children: [
                Expanded(
                  child: Container(
                    height: isTablet ? 48 : 44,
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xffF44336).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextButton(
                      onPressed: _testNotification,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Test Notification',
                        style: TextStyle(
                          color: const Color(0xffF44336),
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 15 : 14,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Expanded(
                  child: Container(
                    height: isTablet ? 48 : 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xffF44336),
                          const Color(0xffF44336).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CustomNotificationsScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View All',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 15 : 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundTasksCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.08),
                    const Color(0xffff5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
              children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Ionicons.time_outline,
                      color: const Color(0xffF44336),
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                  'Background Tasks',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 22 : 20,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automated background processes',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                      ),
                ),
              ],
            ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 10,
                      vertical: isTablet ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: _backgroundTasksEnabled
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _backgroundTasksEnabled
                      ? Ionicons.checkmark_circle
                      : Ionicons.close_circle,
                          color: _backgroundTasksEnabled
                              ? Colors.green
                              : Colors.red,
                          size: isTablet ? 18 : 16,
                        ),
                        SizedBox(width: isTablet ? 8 : 6),
                Text(
                  _backgroundTasksEnabled ? 'Active' : 'Inactive',
                  style: TextStyle(
                            color: _backgroundTasksEnabled
                                ? Colors.green
                                : Colors.red,
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: FontWeight.w600,
                  ),
                ),
              ],
                    ),
                  ),
                ],
              ),
            ),
            if (!kDebugMode) ...[
              SizedBox(height: isTablet ? 20 : 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 16 : 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Ionicons.information_circle_outline,
                      color: Colors.orange,
                      size: isTablet ? 22 : 20,
                    ),
                    SizedBox(width: isTablet ? 12 : 10),
                    Expanded(
                      child: Text(
                        'Background tasks are only available in debug mode',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.orange.shade700,
                              fontSize: isTablet ? 15 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDebugTokenCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.08),
                    const Color(0xffff5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
              children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Ionicons.key_outline,
                      color: const Color(0xffF44336),
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                  'Debug Token Manager',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 22 : 20,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Authentication & token management',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                                  ),
                        ),
                      ],
                    ),
                  ),
                Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 8,
                      vertical: isTablet ? 6 : 4,
                    ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'DEBUG ONLY',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                        fontSize: isTablet ? 11 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'View token information, test refresh notifications, and manage authentication state for debugging purposes.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff57636C),
                      fontSize: isTablet ? 15 : 14,
                      height: 1.4,
                    ),
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Container(
              width: double.infinity,
              height: isTablet ? 52 : 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xffF44336),
                    const Color(0xffF44336).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffF44336).withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => showDebugTokenWidget(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  Ionicons.settings_outline,
                  size: isTablet ? 22 : 20,
                  color: Colors.white,
                ),
                label: Text(
                  'Open Token Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(bool isTablet) {
    return Column(
      children: [
        _buildAnalyticsCard(isTablet),
        SizedBox(height: isTablet ? 24 : 16),
        Container(
          margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced header with gradient background
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 16 : 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xffF44336).withOpacity(0.08),
                        const Color(0xffff5722).withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTablet ? 12 : 10),
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffF44336).withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Ionicons.flash_outline,
                          color: const Color(0xffF44336),
                          size: isTablet ? 28 : 24,
                        ),
                      ),
                      SizedBox(width: isTablet ? 16 : 12),
                      Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                              'Quick Actions',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 22 : 20,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'System maintenance & checks',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: isTablet ? 52 : 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xffF44336),
                              const Color(0xffF44336).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffF44336).withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      child: ElevatedButton.icon(
                        onPressed: _runHealthCheck,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            Ionicons.pulse_outline,
                            size: isTablet ? 22 : 20,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Run Health Check',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 16 : 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    Expanded(
                      child: Container(
                        height: isTablet ? 52 : 48,
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xffF44336).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      child: OutlinedButton.icon(
                        onPressed: _loadCurrentStatus,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            Ionicons.refresh_outline,
                            size: isTablet ? 22 : 20,
                            color: const Color(0xffF44336),
                          ),
                          label: Text(
                            'Refresh',
                            style: TextStyle(
                              color: const Color(0xffF44336),
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 16 : 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AnalyticsDashboardScreen(),
            ),
          );
        },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Ionicons.stats_chart_outline,
                    color: const Color(0xffF44336),
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics Dashboard',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xff212427),
                                  fontSize: isTablet ? 18 : 16,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User behavior and performance metrics',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xff57636C),
                              fontSize: isTablet ? 14 : 13,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Ionicons.chevron_forward,
                  color: const Color(0xff57636C),
                  size: isTablet ? 20 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataObservabilityGateLoader extends StatefulWidget {
  const _DataObservabilityGateLoader();

  @override
  State<_DataObservabilityGateLoader> createState() =>
      _DataObservabilityGateLoaderState();
}

class _DataObservabilityGateLoaderState
    extends State<_DataObservabilityGateLoader> with TickerProviderStateMixin {
  late AnimationController _gateController;
  late AnimationController _iconController;

  late Animation<double> _gateAnimation;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();

    // Gate animation controller
    _gateController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Icon rotation controller
    _iconController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Gate opening/closing animation
    _gateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gateController,
      curve: Curves.easeInOut,
    ));

    // Icon rotation animation
    _iconAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.linear,
    ));

    // Start animations
    _gateController.repeat(reverse: true);
    _iconController.repeat();
  }

  @override
  void dispose() {
    _gateController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_gateAnimation, _iconAnimation]),
      builder: (context, child) {
        final gateOffset = _gateAnimation.value * 20;

        return SizedBox(
          width: 100,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left gate door
              Positioned(
                left: 15 - gateOffset,
                top: 8,
                child: Container(
                  width: 6,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Right gate door
              Positioned(
                right: 15 - gateOffset,
                top: 8,
                child: Container(
                  width: 6,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Center rotating gate icon
              Transform.rotate(
                angle: _iconAnimation.value * 2 * 3.14159,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xffF44336),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.sensor_door,
                    color: Color(0xffF44336),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
