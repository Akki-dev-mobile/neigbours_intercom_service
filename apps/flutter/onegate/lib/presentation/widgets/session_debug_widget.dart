import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/services/session_manager/session_debug_tool.dart';
import 'package:flutter_onegate/services/session_manager/five_minute_token_fix.dart';
import 'package:flutter_onegate/utils/session_expiry_debug.dart';
import 'package:flutter_onegate/utils/eleven_minute_session_debug.dart';

/// Debug widget for investigating session management issues
/// Shows real-time session status and debugging information
class SessionDebugWidget extends StatefulWidget {
  const SessionDebugWidget({super.key});

  @override
  State<SessionDebugWidget> createState() => _SessionDebugWidgetState();
}

class _SessionDebugWidgetState extends State<SessionDebugWidget> {
  final SessionDebugTool _debugTool = SessionDebugTool();
  final FiveMinuteTokenFix _tokenFix = FiveMinuteTokenFix();

  Timer? _updateTimer;
  Map<String, dynamic>? _lastDebugResult;
  bool _isDebugging = false;
  final String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _startDebugging();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _debugTool.stopDebugging();
    super.dispose();
  }

  void _startDebugging() {
    setState(() {
      _isDebugging = true;
    });

    _debugTool.startDebugging(interval: const Duration(seconds: 30));

    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _updateDebugInfo();
    });

    // Initial update
    _updateDebugInfo();
  }

  void _stopDebugging() {
    setState(() {
      _isDebugging = false;
    });

    _updateTimer?.cancel();
    _debugTool.stopDebugging();
  }

  Future<void> _updateDebugInfo() async {
    try {
      final result = await _debugTool.performComprehensiveCheck();
      setState(() {
        _lastDebugResult = result;
      });
    } catch (e) {
      log("❌ Error updating debug info: $e");
    }
  }

  Future<void> _forceTokenRefresh() async {
    try {
      final success = await _debugTool.forceTokenRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success
                    ? context.tr('Token refresh successful')
                    : context.tr('Token refresh failed')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
      await _updateDebugInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.tr('Error: {error}', params: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyDebugInfo() async {
    try {
      final summary = await _debugTool.getDebuggingSummary();
      await Clipboard.setData(ClipboardData(text: summary));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Debug info copied to clipboard')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Error copying debug info: {error}', params: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applySessionExpiryFix() async {
    try {
      await SessionExpiryDebug.quickFixSessionExpiry();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Session Expiry Fix applied successfully! Check console logs for details.',
              ),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      await _updateDebugInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Error applying Session Expiry Fix: {error}', params: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _debug11MinuteExpiry() async {
    try {
      await ElevenMinuteSessionDebug.analyzeElevenMinuteSessionExpiry();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '11-Minute Session Expiry Analysis completed! Check console logs for detailed analysis.',
              ),
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      await _updateDebugInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Error during 11-minute expiry debug: {error}', params: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Session Debug Tool')),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isDebugging ? Icons.pause : Icons.play_arrow),
            onPressed: _isDebugging ? _stopDebugging : _startDebugging,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateDebugInfo,
          ),
          IconButton(
            icon: const Icon(Icons.healing),
            onPressed: _applySessionExpiryFix,
            tooltip: context.tr('Apply Session Expiry Fix'),
          ),
          IconButton(
            icon: const Icon(Icons.warning),
            onPressed: _debug11MinuteExpiry,
            tooltip: context.tr('Debug 11-Minute Expiry'),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyDebugInfo,
          ),
        ],
      ),
      body: _lastDebugResult == null
          ? const Center(child: DashboardLoaderIcon())
          : _buildDebugContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _forceTokenRefresh,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildDebugContent() {
    final result = _lastDebugResult!;
    final timestamp = result['timestamp'] as String;
    final checks = result['checks'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(timestamp),
          const SizedBox(height: 16),
          _buildTokenStatusCard(checks['tokenStatus']),
          const SizedBox(height: 16),
          _buildOverridesCard(checks['sessionTimeoutOverrides']),
          const SizedBox(height: 16),
          _buildTimeoutSourcesCard(checks['potentialTimeoutSources']),
          const SizedBox(height: 16),
          _buildFixStatusCard(checks['fiveMinuteTokenFix']),
          const SizedBox(height: 16),
          _buildSessionManagerCard(checks['userSessionManager']),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildStatusCard(String timestamp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isDebugging ? Icons.monitor_heart : Icons.pause_circle,
                  color: _isDebugging ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('Debug Status'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Status: {status}',
                params: {
                  'status': _isDebugging ? context.tr('Active') : context.tr('Paused'),
                },
              ),
            ),
            Text(
              context.tr(
                'Last Update: {time}',
                params: {'time': '${DateTime.parse(timestamp).toLocal()}'},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenStatusCard(Map<String, dynamic>? tokenStatus) {
    if (tokenStatus == null) return const SizedBox();

    final hasToken = tokenStatus['hasAccessToken'] ?? false;
    final isExpired = tokenStatus['isExpired'] ?? true;
    final analysis = tokenStatus['tokenAnalysis'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasToken ? Icons.key : Icons.key_off,
                  color: hasToken ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('Token Status'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusRow(context.tr('Has Access Token'), hasToken),
            _buildStatusRow(context.tr('Is Expired'), isExpired),
            if (analysis != null) ...[
              const Divider(),
              Text(context.tr('Token Analysis:'),
                  style: Theme.of(context).textTheme.titleMedium),
              _buildStatusRow(
                  context.tr('Lifespan'), '${analysis['lifespanMinutes']} ${context.tr('minutes')}'),
              _buildStatusRow(context.tr('Time Until Expiry'),
                  '${analysis['timeUntilExpiryMinutes']} minutes'),
              _buildStatusRow(
                  context.tr('Should Refresh Now'), analysis['shouldRefreshNow']),
              if (analysis['refreshTime'] != null)
                _buildStatusRow(
                    context.tr('Refresh Time'),
                    DateTime.parse(analysis['refreshTime'])
                        .toLocal()
                        .toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverridesCard(Map<String, dynamic>? overrides) {
    if (overrides == null) return const SizedBox();

    final tokenLogoutDisabled =
        overrides['token_expiration_logout_disabled'] ?? false;
    final autoLogoutDisabled = overrides['auto_logout_disabled'] ?? false;
    final sessionTimeoutDisabled =
        overrides['session_timeout_disabled'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  tokenLogoutDisabled ? Icons.shield : Icons.warning,
                  color: tokenLogoutDisabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('Session Overrides'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusRow(context.tr('Token Logout Disabled'), tokenLogoutDisabled),
            _buildStatusRow(context.tr('Auto Logout Disabled'), autoLogoutDisabled),
            _buildStatusRow(context.tr('Session Timeout Disabled'), sessionTimeoutDisabled),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutSourcesCard(Map<String, dynamic>? timeoutSources) {
    if (timeoutSources == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  timeoutSources.isEmpty ? Icons.check_circle : Icons.warning,
                  color: timeoutSources.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('Potential 10-min Timeouts'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (timeoutSources.isEmpty)
              Text(context.tr('No 10-minute timeouts found in SharedPreferences'))
            else
              ...timeoutSources.entries.map((entry) {
                final value = entry.value as Map<String, dynamic>;
                return _buildStatusRow(
                  entry.key,
                  '${value['minutes'].toStringAsFixed(1)} minutes',
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFixStatusCard(Map<String, dynamic>? fixStatus) {
    if (fixStatus == null) return const SizedBox();

    final isInitialized = fixStatus['isInitialized'] ?? false;
    final timeoutOverrideActive = fixStatus['timeoutOverrideActive'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInitialized ? Icons.build_circle : Icons.error,
                  color: isInitialized ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('5-Minute Token Fix'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusRow(context.tr('Initialized'), isInitialized),
            _buildStatusRow(context.tr('Timeout Override Active'), timeoutOverrideActive),
            _buildStatusRow(context.tr('Aggressive Refresh'),
                fixStatus['aggressiveRefreshEnabled'] ?? false),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionManagerCard(Map<String, dynamic>? sessionManager) {
    if (sessionManager == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  context.tr('Session Manager'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
                context.tr('Current State'), sessionManager['currentState'] ?? context.tr('Unknown')),
            if (sessionManager['sessionDurationMinutes'] != null)
              _buildStatusRow('Session Duration',
                  '${sessionManager['sessionDurationMinutes']} minutes'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value) {
    Color? valueColor;
    if (value is bool) {
      valueColor = value ? Colors.green : Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
