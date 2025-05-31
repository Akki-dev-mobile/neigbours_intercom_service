import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_onegate/services/auth_service/auth_token_debug_manager.dart';
import 'package:flutter_onegate/services/auth_service/auth_token_debug_models.dart';

/// Comprehensive authentication token debugging widget
class AuthTokenDebugWidget extends StatefulWidget {
  final bool showFullDetails;
  final bool enableActions;

  const AuthTokenDebugWidget({
    Key? key,
    this.showFullDetails = true,
    this.enableActions = true,
  }) : super(key: key);

  @override
  State<AuthTokenDebugWidget> createState() => _AuthTokenDebugWidgetState();
}

class _AuthTokenDebugWidgetState extends State<AuthTokenDebugWidget> {
  late final AuthTokenDebugManager _debugManager;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _debugManager = AuthTokenDebugManager();
    _initializeDebugManager();
  }

  Future<void> _initializeDebugManager() async {
    try {
      await _debugManager.initialize();
      _debugManager.enableDebugging();
    } catch (e) {
      debugPrint('Error initializing debug manager: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _debugManager,
      child: Consumer<AuthTokenDebugManager>(
        builder: (context, debugManager, child) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ExpansionTile(
              title: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: _getStatusColor(debugManager.currentState.healthStatus),
                  ),
                  const SizedBox(width: 8),
                  const Text('Auth Token Debug'),
                  const Spacer(),
                  Text(
                    debugManager.currentState.healthStatus.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
              subtitle: Text(
                debugManager.currentState.healthStatus.description,
                style: TextStyle(
                  color: _getStatusColor(debugManager.currentState.healthStatus),
                  fontSize: 12,
                ),
              ),
              initiallyExpanded: _isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _isExpanded = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickStatus(debugManager.currentState),
                      const SizedBox(height: 16),
                      if (widget.showFullDetails) ...[
                        _buildTokenPresence(debugManager.currentState),
                        const SizedBox(height: 16),
                        _buildTokenAnalysis(debugManager.currentState),
                        const SizedBox(height: 16),
                        _buildStorageConsistency(debugManager.currentState),
                        const SizedBox(height: 16),
                      ],
                      if (widget.enableActions) _buildActionButtons(debugManager),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStatus(TokenDebugState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(state.healthStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(state.healthStatus).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Status: ${state.healthStatus.description}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(state.healthStatus),
                ),
              ),
              const Spacer(),
              Text(
                state.healthStatus.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatusChip('Authenticated', state.isAuthenticated),
              const SizedBox(width: 8),
              _buildStatusChip('Logged In', state.isLoggedIn),
              const SizedBox(width: 8),
              _buildStatusChip('Has Tokens', state.hasAnyTokens),
            ],
          ),
          if (state.accessTokenAnalysis != null) ...[
            const SizedBox(height: 8),
            Text(
              'Token expires in: ${state.accessTokenAnalysis!.timeUntilExpiryMinutes ?? 'Unknown'} minutes',
              style: TextStyle(
                fontSize: 12,
                color: state.accessTokenAnalysis!.isExpiringSoon 
                    ? Colors.orange 
                    : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: status ? Colors.green[700] : Colors.red[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTokenPresence(TokenDebugState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Token Presence',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildTokenRow('Secure Access Token', state.secureAccessToken != null),
        _buildTokenRow('Secure Refresh Token', state.secureRefreshToken != null),
        _buildTokenRow('Gate Access Token', state.gateAccessToken != null),
        _buildTokenRow('Gate Refresh Token', state.gateRefreshToken != null),
        _buildTokenRow('Valid Access Token', state.validAccessToken != null),
      ],
    );
  }

  Widget _buildTokenRow(String label, bool present) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            present ? Icons.check_circle : Icons.cancel,
            color: present ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            present ? 'Present' : 'Missing',
            style: TextStyle(
              fontSize: 12,
              color: present ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenAnalysis(TokenDebugState state) {
    if (state.accessTokenAnalysis == null) {
      return const SizedBox.shrink();
    }

    final analysis = state.accessTokenAnalysis!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Access Token Analysis',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildAnalysisRow('Valid', analysis.isValid.toString()),
        _buildAnalysisRow('Expires At', analysis.expiresAt ?? 'Unknown'),
        _buildAnalysisRow('Time Until Expiry', '${analysis.timeUntilExpiryMinutes ?? 'Unknown'} minutes'),
        _buildAnalysisRow('Should Refresh', analysis.shouldRefreshNow?.toString() ?? 'Unknown'),
        _buildAnalysisRow('Lifespan', '${analysis.lifespanMinutes ?? 'Unknown'} minutes'),
        if (analysis.userDisplayName != null)
          _buildAnalysisRow('User', analysis.userDisplayName!),
        if (analysis.userEmail != null)
          _buildAnalysisRow('Email', analysis.userEmail!),
      ],
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageConsistency(TokenDebugState state) {
    if (state.storageConsistency == null) {
      return const SizedBox.shrink();
    }

    final consistency = state.storageConsistency!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Storage Consistency',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildConsistencyRow('Access Token Match', consistency.accessTokenMatch),
        _buildConsistencyRow('Refresh Token Match', consistency.refreshTokenMatch),
        _buildConsistencyRow('Both Storages Populated', consistency.bothStoragesPopulated),
        if (consistency.issues.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Issues:',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red),
          ),
          ...consistency.issues.map((issue) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                  '• $issue',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildConsistencyRow(String label, bool consistent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            consistent ? Icons.check_circle : Icons.error,
            color: consistent ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AuthTokenDebugManager debugManager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debug Actions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _forceRefresh(debugManager),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Force Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _clearTokens(debugManager),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear Tokens'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _copyReport(debugManager),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _forceRefresh(AuthTokenDebugManager debugManager) async {
    try {
      final result = await debugManager.forceTokenRefresh();
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

  Future<void> _clearTokens(AuthTokenDebugManager debugManager) async {
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
        await debugManager.clearAllTokens();
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

  Future<void> _copyReport(AuthTokenDebugManager debugManager) async {
    try {
      final report = debugManager.getFormattedDebugReport();
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
            content: Text('Error copying report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  @override
  void dispose() {
    _debugManager.disableDebugging();
    super.dispose();
  }
}
