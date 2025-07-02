import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_onegate/services/observatory/observatory_dashboard_service.dart';
import 'package:ionicons/ionicons.dart';

class ObservatoryDashboardScreen extends StatefulWidget {
  const ObservatoryDashboardScreen({super.key});

  @override
  State<ObservatoryDashboardScreen> createState() =>
      _ObservatoryDashboardScreenState();
}

class _ObservatoryDashboardScreenState extends State<ObservatoryDashboardScreen>
    with TickerProviderStateMixin {
  final ObservatoryDashboardService _observatoryService =
      ObservatoryDashboardService();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isInitialized = false;
  List<Map<String, dynamic>> _realtimeMetrics = [];
  List<Map<String, dynamic>> _allMetrics = [];
  Map<String, dynamic> _configuration = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeObservatory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeObservatory() async {
    setState(() => _isLoading = true);

    try {
      await _observatoryService.initialize();
      await _loadData();

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing observatory: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    try {
      final realtimeMetrics = _observatoryService.getRealTimeMetrics();
      final allMetrics = _observatoryService.getAllMetrics();
      final configuration = _observatoryService.getConfiguration();

      setState(() {
        _realtimeMetrics = realtimeMetrics;
        _allMetrics = allMetrics;
        _configuration = configuration;
      });
    } catch (e) {
      debugPrint('Error loading observatory data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return MyScrollView(
      pageTitle: 'Observatory Dashboard',
      pageBody: _isLoading
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xffF44336).withOpacity(0.1),
                            const Color(0xffff5722).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xffF44336)),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading Observatory...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff212427),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Initializing dashboard components',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xff57636C),
                          ),
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? _buildInitializationError(isTablet)
              : Column(
                  children: [
                    _buildStatusCard(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    _buildTabBar(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    Expanded(child: _buildTabContent(isTablet)),
                  ],
                ),
    );
  }

  Widget _buildInitializationError(bool isTablet) {
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
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Ionicons.warning_outline,
                size: isTablet ? 72 : 64,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              'Observatory Initialization Failed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff212427),
                    fontSize: isTablet ? 24 : 22,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              'Unable to initialize the Observatory Dashboard Service. Please check your configuration and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xff57636C),
                    fontSize: isTablet ? 16 : 15,
                    height: 1.4,
                  ),
            ),
            SizedBox(height: isTablet ? 24 : 16),
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
              child: ElevatedButton(
                onPressed: _initializeObservatory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Retry Initialization',
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

  Widget _buildStatusCard(bool isTablet) {
    final isCollecting = _observatoryService.isCollectingMetrics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isCollecting ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observatory Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    isCollecting ? 'Active - Collecting Metrics' : 'Inactive',
                    style: TextStyle(
                      color: isCollecting ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Ionicons.refresh_outline),
              tooltip: 'Refresh Data',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isTablet) {
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
      child: TabBar(
        controller: _tabController,
        tabs: [
          Tab(
            text: 'Real-time',
            icon: Icon(
              Ionicons.pulse_outline,
              size: isTablet ? 22 : 20,
            ),
          ),
          Tab(
            text: 'Analytics',
            icon: Icon(
              Ionicons.analytics_outline,
              size: isTablet ? 22 : 20,
            ),
          ),
          Tab(
            text: 'Platforms',
            icon: Icon(
              Ionicons.server_outline,
              size: isTablet ? 22 : 20,
            ),
          ),
          Tab(
            text: 'Config',
            icon: Icon(
              Ionicons.settings_outline,
              size: isTablet ? 22 : 20,
            ),
          ),
        ],
        labelColor: const Color(0xffF44336),
        unselectedLabelColor: const Color(0xff57636C),
        indicatorColor: const Color(0xffF44336),
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isTablet ? 15 : 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: isTablet ? 15 : 14,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 8,
          vertical: isTablet ? 12 : 8,
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isTablet) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildRealtimeMetrics(isTablet),
        _buildAllMetrics(isTablet),
        _buildConfiguration(isTablet),
        _buildAdvanced(isTablet),
      ],
    );
  }

  Widget _buildRealtimeMetrics(bool isTablet) {
    return ListView.builder(
      itemCount: _realtimeMetrics.length,
      itemBuilder: (context, index) {
        final metric = _realtimeMetrics[index];
        return ListTile(
          title: Text(metric['name']),
          subtitle: Text(metric['value'].toString()),
        );
      },
    );
  }

  Widget _buildAllMetrics(bool isTablet) {
    return ListView.builder(
      itemCount: _allMetrics.length,
      itemBuilder: (context, index) {
        final metric = _allMetrics[index];
        return ListTile(
          title: Text(metric['name']),
          subtitle: Text(metric['value'].toString()),
        );
      },
    );
  }

  Widget _buildConfiguration(bool isTablet) {
    return ListView(
      children: _configuration.entries.map((entry) {
        return ListTile(
          title: Text(entry.key),
          subtitle: Text(entry.value.toString()),
        );
      }).toList(),
    );
  }

  Widget _buildAdvanced(bool isTablet) {
    return const Center(
        child: Text("Advanced monitoring tools can be added here."));
  }

  Widget _buildRealTimeTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMetricsOverview(),
          const SizedBox(height: 16),
          _buildRealTimeChart(),
          const SizedBox(height: 16),
          _buildRecentMetrics(),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview() {
    final latestMetrics =
        _realtimeMetrics.isNotEmpty ? _realtimeMetrics.first : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metrics Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (latestMetrics != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Network Requests',
                      latestMetrics['network_metrics']?['total_requests']
                              ?.toString() ??
                          '0',
                      Ionicons.globe_outline,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Crash Reports',
                      latestMetrics['crash_metrics']?['totalCrashes']
                              ?.toString() ??
                          '0',
                      Ionicons.bug_outline,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Health Status',
                      latestMetrics['health_metrics']?['overall_status'] ??
                          'Unknown',
                      Ionicons.heart_outline,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Analytics Events',
                      latestMetrics['analytics_metrics']?['totalEvents']
                              ?.toString() ??
                          '0',
                      Ionicons.analytics_outline,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ] else
              const Text('No real-time metrics available'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeChart() {
    if (_realtimeMetrics.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Text('No real-time data available'),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _realtimeMetrics.length && i < 20; i++) {
      final metric = _realtimeMetrics[i];
      final networkRequests = metric['network_metrics']?['total_requests'] ?? 0;
      spots.add(FlSpot(i.toDouble(), networkRequests.toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network Requests (Real-time)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_realtimeMetrics.isEmpty)
              const Text('No recent metrics available')
            else
              ...(_realtimeMetrics
                  .take(5)
                  .map((metric) => _buildMetricListItem(metric))),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricListItem(Map<String, dynamic> metric) {
    final timestamp = DateTime.tryParse(metric['timestamp']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Ionicons.time_outline,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timestamp?.toString() ?? 'Unknown time',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Health: ${metric['health_metrics']?['overall_status'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${metric['network_metrics']?['total_requests'] ?? 0} reqs',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAnalyticsOverview(),
          const SizedBox(height: 16),
          _buildAnalyticsChart(),
          const SizedBox(height: 16),
          _buildTopEvents(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsOverview() {
    final totalEvents = _allMetrics.fold<int>(0, (sum, metric) {
      return sum + (metric['analytics_metrics']?['totalEvents'] as int? ?? 0);
    });

    final totalCrashes = _allMetrics.fold<int>(0, (sum, metric) {
      return sum + (metric['crash_metrics']?['totalCrashes'] as int? ?? 0);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Events',
                    totalEvents.toString(),
                    Ionicons.analytics_outline,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Crashes',
                    totalCrashes.toString(),
                    Ionicons.bug_outline,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Data Points',
                    _allMetrics.length.toString(),
                    Ionicons.bar_chart_outline,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Platforms',
                    '6', // Number of monitoring platforms
                    Ionicons.server_outline,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    if (_allMetrics.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Text('No analytics data available'),
          ),
        ),
      );
    }

    final eventSpots = <FlSpot>[];
    final crashSpots = <FlSpot>[];

    for (int i = 0; i < _allMetrics.length && i < 50; i++) {
      final metric = _allMetrics[i];
      final events = metric['analytics_metrics']?['totalEvents'] ?? 0;
      final crashes = metric['crash_metrics']?['totalCrashes'] ?? 0;

      eventSpots.add(FlSpot(i.toDouble(), events.toDouble()));
      crashSpots.add(FlSpot(i.toDouble(), crashes.toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics Trends',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: eventSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: crashSpots,
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Events', Colors.blue),
                const SizedBox(width: 16),
                _buildLegendItem('Crashes', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTopEvents() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_allMetrics.isEmpty)
              const Text('No activity data available')
            else
              ...(_allMetrics
                  .take(5)
                  .map((metric) => _buildActivityItem(metric))),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> metric) {
    final timestamp = DateTime.tryParse(metric['timestamp']?.toString() ?? '');
    final events = metric['analytics_metrics']?['totalEvents'] ?? 0;
    final crashes = metric['crash_metrics']?['totalCrashes'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Ionicons.pulse_outline,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timestamp?.toString() ?? 'Unknown time',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$events events, $crashes crashes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsTab() {
    final platforms = [
      {
        'name': 'SigNoz APM',
        'url': _configuration['signozUrl'],
        'status': 'Active',
        'icon': Ionicons.analytics_outline
      },
      {
        'name': 'Grafana',
        'url': _configuration['grafanaUrl'],
        'status': 'Active',
        'icon': Ionicons.bar_chart_outline
      },
      {
        'name': 'PostHog',
        'url': _configuration['postHogUrl'],
        'status': 'Active',
        'icon': Ionicons.people_outline
      },
      {
        'name': 'HyperDX',
        'url': _configuration['hyperDxUrl'],
        'status': 'Active',
        'icon': Ionicons.document_text_outline
      },
      {
        'name': 'SkyWalking',
        'url': _configuration['skyWalkingUrl'],
        'status': 'Active',
        'icon': Ionicons.airplane_outline
      },
      {
        'name': 'Highlight',
        'url': _configuration['highlightUrl'],
        'status': 'Active',
        'icon': Ionicons.videocam_outline
      },
    ];

    return SingleChildScrollView(
      child: Column(
        children:
            platforms.map((platform) => _buildPlatformCard(platform)).toList(),
      ),
    );
  }

  Widget _buildPlatformCard(Map<String, dynamic> platform) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          platform['icon'] as IconData,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(platform['name'] as String),
        subtitle: Text(platform['url'] as String? ?? 'Not configured'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            platform['status'] as String,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () {
          // Could open platform dashboard in web view
        },
      ),
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildConfigCard(),
          const SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._configuration.entries
                .map((entry) => _buildConfigItem(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              key.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.toString(),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
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
                    onPressed: _loadData,
                    icon: const Icon(Ionicons.refresh_outline),
                    label: const Text('Refresh Data'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Ionicons.download_outline),
                    label: const Text('Export Data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openMainDashboard,
                icon: const Icon(Ionicons.open_outline),
                label: const Text('Open Main Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportData() {
    // Implement data export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data export functionality coming soon')),
    );
  }

  void _openMainDashboard() {
    // Implement opening main dashboard in web view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening main dashboard...')),
    );
  }
}
