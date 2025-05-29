import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/data_health/data_health_service.dart';
import 'package:flutter_onegate/services/background/data_observability_service.dart';
import 'package:flutter_onegate/services/notifications/custom_notification_service.dart';
import 'package:flutter_onegate/services/notifications/notification_manager.dart';
import 'package:flutter_onegate/presentation/features/settings/custom_notifications_screen.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_screen.dart';
import 'package:flutter_onegate/presentation/features/settings/crash_reports_screen.dart';
import 'package:flutter_onegate/presentation/features/settings/analytics_dashboard_screen.dart';
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

  bool _isLoading = true;
  HealthCheckResult? _lastHealthCheck;
  bool _backgroundTasksEnabled = false;
  bool _notificationsEnabled = false;
  bool _meilisearchHealthy = false;

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
    setState(() => _isLoading = true);

    try {
      final success = await _observabilityService.performImmediateIndexSync();
      setState(() => _meilisearchHealthy = success);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Index sync completed successfully'
                : 'Index sync failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing index: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
    return MyScrollView(
      pageTitle: 'Data Observability',
      pageBody: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHealthStatusCard(),
                const SizedBox(height: 16),
                _buildMonitoringCardsRow(),
                const SizedBox(height: 16),
                _buildMeilisearchCard(),
                const SizedBox(height: 16),
                _buildNotificationsCard(),
                const SizedBox(height: 16),
                _buildBackgroundTasksCard(),
                const SizedBox(height: 16),
                _buildActionsCard(),
              ],
            ),
    );
  }

  Widget _buildHealthStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.pulse_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'System Health',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_lastHealthCheck != null) ...[
              Row(
                children: [
                  Icon(
                    _getStatusIcon(_lastHealthCheck!.overallStatus),
                    color: _getStatusColor(_lastHealthCheck!.overallStatus),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Overall Status: ${_lastHealthCheck!.overallStatus.displayName}',
                    style: TextStyle(
                      color: _getStatusColor(_lastHealthCheck!.overallStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last Check: ${_lastHealthCheck!.timestamp?.toString().split('.')[0] ?? 'Unknown'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _buildHealthCheckDetails(),
            ] else ...[
              const Text('No health check data available'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCheckDetails() {
    if (_lastHealthCheck == null) return const SizedBox.shrink();

    final checks = [
      ('Resident Data', _lastHealthCheck!.residentDataCheck),
      ('Visitor Data', _lastHealthCheck!.visitorDataCheck),
      ('API Health', _lastHealthCheck!.apiHealthCheck),
      ('Meilisearch', _lastHealthCheck!.meilisearchHealthCheck),
    ];

    return Column(
      children: checks.map((check) {
        final (name, result) = check;
        if (result == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                _getStatusIcon(result.status),
                size: 16,
                color: _getStatusColor(result.status),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(name)),
              Text(
                result.status.displayName,
                style: TextStyle(
                  color: _getStatusColor(result.status),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonitoringCardsRow() {
    return Row(
      children: [
        Expanded(child: _buildNetworkLogsCard()),
        const SizedBox(width: 8),
        Expanded(child: _buildCrashReportsCard()),
      ],
    );
  }

  Widget _buildNetworkLogsCard() {
    return Card(
      child: ListTile(
        leading: Icon(Ionicons.analytics_outline,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Network Logs'),
        subtitle: const Text('API monitoring'),
        trailing: const Icon(Ionicons.chevron_forward),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NetworkLogScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCrashReportsCard() {
    return Card(
      child: ListTile(
        leading: Icon(Ionicons.bug_outline,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Crash Reports'),
        subtitle: const Text('Error tracking'),
        trailing: const Icon(Ionicons.chevron_forward),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CrashReportsScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeilisearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.search_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Meilisearch',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _meilisearchHealthy
                      ? Ionicons.checkmark_circle
                      : Ionicons.close_circle,
                  color: _meilisearchHealthy ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _meilisearchHealthy ? 'Healthy' : 'Unhealthy',
                  style: TextStyle(
                    color: _meilisearchHealthy ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _syncMeilisearchIndex,
                  child: const Text('Sync Index'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.notifications_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Custom Notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _notificationsEnabled
                      ? Ionicons.checkmark_circle
                      : Ionicons.close_circle,
                  color: _notificationsEnabled ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _notificationsEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    color: _notificationsEnabled ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _testNotification,
                      child: const Text('Test'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CustomNotificationsScreen(),
                          ),
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundTasksCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.time_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Background Tasks',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _backgroundTasksEnabled
                      ? Ionicons.checkmark_circle
                      : Ionicons.close_circle,
                  color: _backgroundTasksEnabled ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _backgroundTasksEnabled ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: _backgroundTasksEnabled ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (!kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                'Background tasks are only available in debug mode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Column(
      children: [
        _buildAnalyticsCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _runHealthCheck,
                        icon: const Icon(Ionicons.pulse_outline),
                        label: const Text('Run Health Check'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loadCurrentStatus,
                        icon: const Icon(Ionicons.refresh_outline),
                        label: const Text('Refresh'),
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

  Widget _buildAnalyticsCard() {
    return Card(
      child: ListTile(
        leading: Icon(Ionicons.stats_chart_outline,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Analytics Dashboard'),
        subtitle: const Text('User behavior and performance metrics'),
        trailing: const Icon(Ionicons.chevron_forward),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AnalyticsDashboardScreen(),
            ),
          );
        },
      ),
    );
  }
}
