import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/crash_reporting/analytics_service.dart';
import 'package:flutter_onegate/services/crash_reporting/models/crash_models.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

/// Screen for viewing analytics data and user behavior metrics
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();

  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  List<AnalyticsEvent> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final stats = _analyticsService.getAnalyticsStatistics();
      final events = _analyticsService.getEvents(limit: 50);

      setState(() {
        _statistics = stats;
        _recentEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.analyticsDashboard,
          style: TextStyle(
            color: const Color(0xff212427),
            fontWeight: FontWeight.w700,
            fontSize: isTablet ? 22 : 20,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Ionicons.chevron_back,
            color: const Color(0xff212427),
            size: isTablet ? 26 : 24,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xffF44336),
          labelColor: const Color(0xffF44336),
          unselectedLabelColor: const Color(0xff57636C),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isTablet ? 14 : 13,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: isTablet ? 14 : 13,
          ),
          tabs: [
            Tab(
              icon: Icon(Ionicons.stats_chart, size: isTablet ? 22 : 20),
              text: AppLocalizations.of(context)!.overview,
            ),
            Tab(
              icon: Icon(Ionicons.person, size: isTablet ? 22 : 20),
              text: AppLocalizations.of(context)!.userBehavior,
            ),
            Tab(
              icon: Icon(Ionicons.speedometer, size: isTablet ? 22 : 20),
              text: AppLocalizations.of(context)!.performance,
            ),
            Tab(
              icon: Icon(Ionicons.list, size: isTablet ? 22 : 20),
              text: AppLocalizations.of(context)!.events,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState(isTablet)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isTablet),
                _buildUserBehaviorTab(isTablet),
                _buildPerformanceTab(isTablet),
                _buildEventsTab(isTablet),
              ],
            ),
    );
  }

  Widget _buildLoadingState(bool isTablet) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.1),
                    const Color(0xffff5722).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: CircularProgressIndicator(
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xffF44336)),
                strokeWidth: isTablet ? 4 : 3,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              AppLocalizations.of(context)!.loadingAnalyticsData,
              style: TextStyle(
                color: const Color(0xff57636C),
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isTablet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatisticsCard(isTablet),
          SizedBox(height: isTablet ? 20 : 16),
          _buildSessionInfoCard(isTablet),
          SizedBox(height: isTablet ? 20 : 16),
          _buildEventCategoriesCard(isTablet),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(bool isTablet) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.analytics_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Analytics Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Events',
                    '${_statistics['totalEvents'] ?? 0}',
                    Colors.blue,
                    Ionicons.pulse_outline,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Last 24h',
                    '${_statistics['events24h'] ?? 0}',
                    Colors.green,
                    Ionicons.time_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Sessions',
                    '${_statistics['uniqueSessions'] ?? 0}',
                    Colors.orange,
                    Ionicons.people_outline,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Users',
                    '${_statistics['uniqueUsers'] ?? 0}',
                    Colors.purple,
                    Ionicons.person_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard(bool isTablet) {
    final currentSessionId = _statistics['currentSessionId'];
    final sessionStartTime = _statistics['sessionStartTime'];

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
                  'Current Session',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (currentSessionId != null) ...[
              _buildInfoRow('Session ID', currentSessionId.toString()),
              if (sessionStartTime != null)
                _buildInfoRow('Started', sessionStartTime.toString()),
            ] else ...[
              Text(
                'No active session',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventCategoriesCard(bool isTablet) {
    final categoryCounts =
        _statistics['categoryCounts'] as Map<String, int>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.layers_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Event Categories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (categoryCounts.isEmpty)
              Text(
                'No events recorded yet',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ...categoryCounts.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatCategoryName(entry.key),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBehaviorTab(bool isTablet) {
    final userActionEvents = _analyticsService.getEvents(
      eventName: 'user_action',
      limit: 20,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Column(
        children: [
          _buildTopActionsCard(userActionEvents, isTablet),
          SizedBox(height: isTablet ? 20 : 16),
          _buildNavigationPatternsCard(isTablet),
        ],
      ),
    );
  }

  Widget _buildTopActionsCard(List<AnalyticsEvent> userActions, bool isTablet) {
    final actionCounts = <String, int>{};
    for (final event in userActions) {
      final action = event.parameters['action'] as String? ?? 'Unknown';
      actionCounts[action] = (actionCounts[action] ?? 0) + 1;
    }

    final sortedActions = actionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.finger_print_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Top User Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sortedActions.isEmpty)
              Text(
                'No user actions recorded yet',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ...sortedActions.take(10).map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatActionName(entry.key),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationPatternsCard(bool isTablet) {
    final screenViewEvents = _analyticsService.getEvents(
      eventName: 'screen_view',
      limit: 20,
    );

    final screenCounts = <String, int>{};
    for (final event in screenViewEvents) {
      final screen = event.parameters['screen_name'] as String? ?? 'Unknown';
      screenCounts[screen] = (screenCounts[screen] ?? 0) + 1;
    }

    final sortedScreens = screenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.navigate_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Screen Navigation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sortedScreens.isEmpty)
              Text(
                'No screen navigation recorded yet',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ...sortedScreens.take(10).map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value} visits',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTab(bool isTablet) {
    final performanceEvents = _analyticsService.getEvents(
      category: EventCategory.performance,
      limit: 50,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Column(
        children: [
          _buildPerformanceMetricsCard(performanceEvents, isTablet),
          SizedBox(height: isTablet ? 20 : 16),
          _buildApiPerformanceCard(performanceEvents, isTablet),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricsCard(
      List<AnalyticsEvent> events, bool isTablet) {
    final screenTimeEvents =
        events.where((e) => e.eventName == 'screen_time').toList();
    final avgScreenTime = screenTimeEvents.isNotEmpty
        ? screenTimeEvents
                .map((e) => e.parameters['duration_ms'] as int? ?? 0)
                .reduce((a, b) => a + b) /
            screenTimeEvents.length
        : 0;

    final apiEvents = events.where((e) => e.eventName == 'api_call').toList();
    final avgApiTime = apiEvents.isNotEmpty
        ? apiEvents
                .map((e) => e.parameters['duration_ms'] as int? ?? 0)
                .reduce((a, b) => a + b) /
            apiEvents.length
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.speedometer_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Avg Screen Time',
                    '${(avgScreenTime / 1000).toStringAsFixed(1)}s',
                    Colors.blue,
                    Ionicons.time_outline,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg API Time',
                    '${avgApiTime.toStringAsFixed(0)}ms',
                    Colors.orange,
                    Ionicons.cloud_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiPerformanceCard(List<AnalyticsEvent> events, bool isTablet) {
    final apiEvents = events.where((e) => e.eventName == 'api_call').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.cloud_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'API Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (apiEvents.isEmpty)
              Text(
                'No API calls recorded yet',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ...apiEvents.take(10).map((event) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${event.parameters['method']} ${event.parameters['endpoint']}',
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (event.parameters['is_successful'] as bool? ??
                                        false)
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${event.parameters['duration_ms']}ms',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  (event.parameters['is_successful'] as bool? ??
                                          false)
                                      ? Colors.green
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab(bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: _recentEvents.length,
      itemBuilder: (context, index) {
        final event = _recentEvents[index];
        return _buildEventCard(event, isTablet);
      },
    );
  }

  Widget _buildEventCard(AnalyticsEvent event, bool isTablet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(event.eventCategory),
          child: Icon(
            _getCategoryIcon(event.eventCategory),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          event.eventName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatCategoryName(event.eventCategory),
              style: TextStyle(
                fontSize: 12,
                color: _getCategoryColor(event.eventCategory),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              event.formattedTimestamp,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: event.duration != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${event.duration}ms',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  void _showEventDetails(AnalyticsEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.eventName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(
                  'Category', _formatCategoryName(event.eventCategory)),
              _buildInfoRow('Timestamp', event.timestamp.toString()),
              if (event.userId != null) _buildInfoRow('User ID', event.userId!),
              if (event.gateId != null) _buildInfoRow('Gate ID', event.gateId!),
              if (event.sessionId != null)
                _buildInfoRow('Session ID', event.sessionId!),
              if (event.duration != null)
                _buildInfoRow('Duration', '${event.duration}ms'),
              const SizedBox(height: 8),
              const Text(
                'Parameters:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  event.parameters.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    switch (category) {
      case 'userAction':
        return 'User Action';
      case 'navigation':
        return 'Navigation';
      case 'performance':
        return 'Performance';
      case 'error':
        return 'Error';
      case 'system':
        return 'System';
      default:
        return category;
    }
  }

  String _formatActionName(String action) {
    return action
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word)
        .join(' ');
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'userAction':
        return Colors.blue;
      case 'navigation':
        return Colors.green;
      case 'performance':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'system':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'userAction':
        return Ionicons.finger_print;
      case 'navigation':
        return Ionicons.navigate;
      case 'performance':
        return Ionicons.speedometer;
      case 'error':
        return Ionicons.warning;
      case 'system':
        return Ionicons.settings;
      default:
        return Ionicons.pulse;
    }
  }
}
