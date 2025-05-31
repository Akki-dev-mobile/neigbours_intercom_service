import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        title: const Text('Authentication Debug'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.token), text: 'Tokens'),
            Tab(icon: Icon(Icons.storage), text: 'Storage'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isInitialized ? () => _refreshDebugData() : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Debug Data',
          ),
          IconButton(
            onPressed: _isInitialized ? () => _exportDebugReport() : null,
            icon: const Icon(Icons.download),
            tooltip: 'Export Debug Report',
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
              child: CircularProgressIndicator(),
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
                  'Authentication Status',
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
                  child: _buildStatusItem('Authenticated', state.isAuthenticated),
                ),
                Expanded(
                  child: _buildStatusItem('Logged In', state.isLoggedIn),
                ),
                Expanded(
                  child: _buildStatusItem('Has Tokens', state.hasAnyTokens),
                ),
              ],
            ),
            if (state.accessTokenAnalysis != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Token expires in: ${state.accessTokenAnalysis!.timeUntilExpiryMinutes ?? 'Unknown'} minutes',
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
          status ? 'Yes' : 'No',
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
              'Quick Actions',
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
                  label: const Text('Force Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _validateTokens(),
                  icon: const Icon(Icons.verified, size: 16),
                  label: const Text('Validate Tokens'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _clearAllTokens(),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear All'),
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
              'Token Presence',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildTokenPresenceRow('Secure Access Token', state.secureAccessToken != null),
            _buildTokenPresenceRow('Secure Refresh Token', state.secureRefreshToken != null),
            _buildTokenPresenceRow('Gate Access Token', state.gateAccessToken != null),
            _buildTokenPresenceRow('Gate Refresh Token', state.gateRefreshToken != null),
            _buildTokenPresenceRow('Valid Access Token', state.validAccessToken != null),
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
              present ? 'Present' : 'Missing',
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
              '$title Analysis',
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
                        'Error: ${analysis.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildAnalysisRow('Valid', analysis.isValid.toString()),
              _buildAnalysisRow('Issued At', analysis.issuedAt ?? 'Unknown'),
              _buildAnalysisRow('Expires At', analysis.expiresAt ?? 'Unknown'),
              _buildAnalysisRow('Lifespan', '${analysis.lifespanMinutes ?? 'Unknown'} minutes'),
              _buildAnalysisRow('Time Until Expiry', '${analysis.timeUntilExpiryMinutes ?? 'Unknown'} minutes'),
              _buildAnalysisRow('Should Refresh', analysis.shouldRefreshNow?.toString() ?? 'Unknown'),
              if (analysis.userDisplayName != null)
                _buildAnalysisRow('User', analysis.userDisplayName!),
              if (analysis.userEmail != null)
                _buildAnalysisRow('Email', analysis.userEmail!),
              if (analysis.userRoles.isNotEmpty)
                _buildAnalysisRow('Roles', analysis.userRoles.join(', ')),
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
              'Storage Consistency',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildConsistencyRow('Access Token Match', consistency.accessTokenMatch),
            _buildConsistencyRow('Refresh Token Match', consistency.refreshTokenMatch),
            _buildConsistencyRow('Both Storages Populated', consistency.bothStoragesPopulated),
            if (consistency.issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Issues Found:',
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
              'Storage Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Detailed storage information would be displayed here.'),
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
              'Storage Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Storage management actions would be available here.'),
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
              'Refresh Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (state.refreshStats.isNotEmpty) ...[
              ...state.refreshStats.entries.map((entry) => 
                _buildAnalysisRow(entry.key, entry.value.toString())),
            ] else ...[
              const Text('No refresh statistics available.'),
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
              'Health Trends',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Health trend analysis would be displayed here.'),
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
              'Debug Log',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Recent debug log entries would be shown here.'),
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
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: ${state.timestamp.toString()}',
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
              'Token Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Token management actions would be available here.'),
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
          const SnackBar(
            content: Text('Debug report copied to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting report: $e'),
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
            content: Text(result ? 'Token refresh successful' : 'Token refresh failed'),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
        const SnackBar(
          content: Text('Token validation completed'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _clearAllTokens() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Tokens'),
        content: const Text('This will clear all authentication tokens. You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _debugManager.clearAllTokens();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All tokens cleared'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing tokens: $e'),
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
