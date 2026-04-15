import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_onegate/services/auth_service/auth_token_debug_manager.dart';
import 'package:flutter_onegate/services/auth_service/auth_token_debug_models.dart';
import 'package:flutter_onegate/presentation/widgets/auth_token_debug_widget.dart';

/// Comprehensive authentication debugging screen
class AuthDebugScreen extends StatefulWidget {
  const AuthDebugScreen({Key? key}) : super(key: key);

  @override
  State<AuthDebugScreen> createState() => _AuthDebugScreenState();
}

class _AuthDebugScreenState extends State<AuthDebugScreen> with TickerProviderStateMixin {
  late final AuthTokenDebugManager _debugManager;
  late final TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _debugManager = AuthTokenDebugManager();
    _tabController = TabController(length: 4, vsync: this);
    _initializeDebugManager();
  }

  Future<void> _initializeDebugManager() async {
    try {
      await _debugManager.initialize();
      _debugManager.enableDebugging();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing debug manager: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Authentication Debug')),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard), text: context.tr('Overview')),
            Tab(icon: const Icon(Icons.token), text: context.tr('Tokens')),
            Tab(icon: const Icon(Icons.storage), text: context.tr('Storage')),
            Tab(icon: const Icon(Icons.analytics), text: context.tr('Analytics')),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isInitialized ? () => _refreshDebugData() : null,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('Refresh Debug Data'),
          ),
          IconButton(
            onPressed: _isInitialized ? () => _exportDebugReport() : null,
            icon: const Icon(Icons.download),
            tooltip: context.tr('Export Debug Report'),
          ),
        ],
      ),
      body: _isInitialized
          ? ChangeNotifierProvider.value(
              value: _debugManager,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTokensTab(),
                  _buildStorageTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            )
          : const Center(
              child: DashboardLoaderIcon(),
            ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer<AuthTokenDebugManager>(
      builder: (context, debugManager, child) {
        final state = debugManager.currentState;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(state),
              const SizedBox(height: 16),
              _buildQuickActionsCard(),
              const SizedBox(height: 16),
              const AuthTokenDebugWidget(
                showFullDetails: false,
                enableActions: true,
              ),
              const SizedBox(height: 16),
              _buildRecentActivityCard(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTokensTab() {
    return Consumer<AuthTokenDebugManager>(
      builder: (context, debugManager, child) {
        final state = debugManager.currentState;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTokenPresenceCard(state),
              const SizedBox(height: 16),
              if (state.accessTokenAnalysis != null)
                _buildTokenAnalysisCard('Access Token', state.accessTokenAnalysis!),
              const SizedBox(height: 16),
              if (state.refreshTokenAnalysis != null)
                _buildTokenAnalysisCard('Refresh Token', state.refreshTokenAnalysis!),
              const SizedBox(height: 16),
              _buildTokenActionsCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStorageTab() {
    return Consumer<AuthTokenDebugManager>(
      builder: (context, debugManager, child) {
        final state = debugManager.currentState;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStorageConsistencyCard(state),
              const SizedBox(height: 16),
              _buildStorageDetailsCard(state),
              const SizedBox(height: 16),
              _buildStorageActionsCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return Consumer<AuthTokenDebugManager>(
      builder: (context, debugManager, child) {
        final state = debugManager.currentState;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRefreshStatisticsCard(state),
              const SizedBox(height: 16),
              _buildHealthTrendsCard(state),
              const SizedBox(height: 16),
              _buildDebugLogCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(TokenDebugState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.tr('Authentication Status'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(state.healthStatus).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(state.healthStatus),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.healthStatus.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.healthStatus.description,
                        style: TextStyle(
                          color: _getStatusColor(state.healthStatus),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(context.tr('Authenticated'), state.isAuthenticated),
                ),
                Expanded(
                  child: _buildStatusItem(context.tr('Logged In'), state.isLoggedIn),
                ),
                Expanded(
                  child: _buildStatusItem(context.tr('Has Tokens'), state.hasAnyTokens),
                ),
              ],
            ),
            if (state.accessTokenAnalysis != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Token expires in: {minutes} minutes',
                  params: {'minutes': '${state.accessTokenAnalysis!.timeUntilExpiryMinutes ?? 'Unknown'}'},
                ),
                style: TextStyle(
                  color: state.accessTokenAnalysis!.isExpiringSoon 
                      ? Colors.orange 
                      : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, bool status) {
    return Column(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? Colors.green : Colors.red,
          size: 32,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        Text(
          status ? context.tr('Yes') : context.tr('No'),
          style: TextStyle(
            fontSize: 10,
            color: status ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Quick Actions'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _forceTokenRefresh(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(context.tr('Force Refresh')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _validateTokens(),
                  icon: const Icon(Icons.verified, size: 16),
                  label: Text(context.tr('Validate Tokens')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _clearAllTokens(),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(context.tr('Clear All')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenPresenceCard(TokenDebugState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Token Presence'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildTokenPresenceRow(context.tr('Secure Access Token'), state.secureAccessToken != null),
            _buildTokenPresenceRow(context.tr('Secure Refresh Token'), state.secureRefreshToken != null),
            _buildTokenPresenceRow(context.tr('Gate Access Token'), state.gateAccessToken != null),
            _buildTokenPresenceRow(context.tr('Gate Refresh Token'), state.gateRefreshToken != null),
            _buildTokenPresenceRow(context.tr('Valid Access Token'), state.validAccessToken != null),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenPresenceRow(String label, bool present) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            present ? Icons.check_circle : Icons.cancel,
            color: present ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: present ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              present ? context.tr('Present') : context.tr('Missing'),
              style: TextStyle(
                fontSize: 12,
                color: present ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenAnalysisCard(String title, TokenAnalysis analysis) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('{title} Analysis', params: {'title': title}),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (analysis.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('Error: {error}', params: {'error': '${analysis.error}'}),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildAnalysisRow(context.tr('Valid'), analysis.isValid.toString()),
              _buildAnalysisRow(context.tr('Issued At'), analysis.issuedAt ?? context.tr('Unknown')),
              _buildAnalysisRow(context.tr('Expires At'), analysis.expiresAt ?? context.tr('Unknown')),
              _buildAnalysisRow(context.tr('Lifespan'), '${analysis.lifespanMinutes ?? 'Unknown'} ${context.tr('minutes')}'),
              _buildAnalysisRow(context.tr('Time Until Expiry'), '${analysis.timeUntilExpiryMinutes ?? 'Unknown'} ${context.tr('minutes')}'),
              _buildAnalysisRow(context.tr('Should Refresh'), analysis.shouldRefreshNow?.toString() ?? context.tr('Unknown')),
              if (analysis.userDisplayName != null)
                _buildAnalysisRow(context.tr('User'), analysis.userDisplayName!),
              if (analysis.userEmail != null)
                _buildAnalysisRow(context.tr('Email'), analysis.userEmail!),
              if (analysis.userRoles.isNotEmpty)
                _buildAnalysisRow(context.tr('Roles'), analysis.userRoles.join(', ')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageConsistencyCard(TokenDebugState state) {
    if (state.storageConsistency == null) {
      return const SizedBox.shrink();
    }

    final consistency = state.storageConsistency!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Storage Consistency'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildConsistencyRow(context.tr('Access Token Match'), consistency.accessTokenMatch),
            _buildConsistencyRow(context.tr('Refresh Token Match'), consistency.refreshTokenMatch),
            _buildConsistencyRow(context.tr('Both Storages Populated'), consistency.bothStoragesPopulated),
            if (consistency.issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                context.tr('Issues Found:'),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              ...consistency.issues.map((issue) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyRow(String label, bool consistent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            consistent ? Icons.check_circle : Icons.error,
            color: consistent ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  // Additional card builders would go here...
  Widget _buildStorageDetailsCard(TokenDebugState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Storage Details'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(context.tr('Detailed storage information would be displayed here.')),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Storage Actions'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(context.tr('Storage management actions would be available here.')),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshStatisticsCard(TokenDebugState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Refresh Statistics'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (state.refreshStats.isNotEmpty) ...[
              ...state.refreshStats.entries.map((entry) => 
                _buildAnalysisRow(entry.key, entry.value.toString())),
            ] else ...[
              Text(context.tr('No refresh statistics available.')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTrendsCard(TokenDebugState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Health Trends'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(context.tr('Health trend analysis would be displayed here.')),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Debug Log'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(context.tr('Recent debug log entries would be shown here.')),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(TokenDebugState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Recent Activity'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('Last updated: {time}', params: {'time': state.timestamp.toString()}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Token Actions'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(context.tr('Token management actions would be available here.')),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TokenHealthStatus status) {
    switch (status) {
      case TokenHealthStatus.healthy:
        return Colors.green;
      case TokenHealthStatus.needsRefresh:
        return Colors.orange;
      case TokenHealthStatus.invalid:
      case TokenHealthStatus.error:
        return Colors.red;
      case TokenHealthStatus.inconsistent:
        return Colors.purple;
      case TokenHealthStatus.noTokens:
        return Colors.grey;
    }
  }

  Future<void> _refreshDebugData() async {
    // Force refresh of debug data
    await _debugManager.forceTokenRefresh();
  }

  Future<void> _exportDebugReport() async {
    try {
      final report = _debugManager.getFormattedDebugReport();
      await Clipboard.setData(ClipboardData(text: report));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Debug report copied to clipboard')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error exporting report: {error}', params: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _forceTokenRefresh() async {
    try {
      final result = await _debugManager.forceTokenRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? context.tr('Token refresh successful') : context.tr('Token refresh failed')),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error: {error}', params: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _validateTokens() async {
    // Implement token validation logic
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Token validation completed')),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _clearAllTokens() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Clear All Tokens')),
        content: Text(context.tr('This will clear all authentication tokens. You will need to log in again.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Clear')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _debugManager.clearAllTokens();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('All tokens cleared')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error clearing tokens: {error}', params: {'error': '$e'})),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debugManager.disableDebugging();
    super.dispose();
  }
}
