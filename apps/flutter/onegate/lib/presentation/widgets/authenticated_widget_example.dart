import 'package:flutter/material.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/api_service/onegate_api_service.dart';
import 'package:flutter_onegate/services/session_manager/user_session_manager.dart';
import 'package:get_it/get_it.dart';

/// Example widget demonstrating the new authentication system
class AuthenticatedWidgetExample extends StatefulWidget {
  const AuthenticatedWidgetExample({Key? key}) : super(key: key);

  @override
  State<AuthenticatedWidgetExample> createState() => _AuthenticatedWidgetExampleState();
}

class _AuthenticatedWidgetExampleState extends State<AuthenticatedWidgetExample> {
  late final AuthService _authService;
  late final OneGateApiService _apiService;
  late final UserSessionManager _sessionManager;
  
  Map<String, dynamic>? _userSession;
  List<String> _userRoles = [];
  Set<String> _userPermissions = {};
  List<dynamic> _visitorLogs = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _authService = GetIt.I<AuthService>();
    _apiService = GetIt.I<OneGateApiService>();
    _sessionManager = GetIt.I<UserSessionManager>();
    
    await _apiService.initialize();
    await _sessionManager.initialize();
    
    // Listen to session state changes
    _sessionManager.sessionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          // Handle session state changes
          if (state == UserSessionState.unauthenticated) {
            _userSession = null;
            _userRoles = [];
            _userPermissions = {};
            _visitorLogs = [];
          }
        });
      }
    });
    
    // Load initial data
    await _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user session
      final session = await _sessionManager.getCurrentUserSession();
      final roles = await _sessionManager.getUserPermissions();
      final permissions = await _sessionManager.getUserPermissions();

      setState(() {
        _userSession = session;
        _userRoles = session?['roles']?.cast<String>() ?? [];
        _userPermissions = permissions;
      });

      // Load visitor logs if user has permission
      if (await _sessionManager.hasPermission('view_visitors')) {
        await _loadVisitorLogs();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVisitorLogs() async {
    try {
      final logs = await _apiService.getVisitorLogs(limit: 10);
      setState(() {
        _visitorLogs = logs;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load visitor logs: $e';
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await _authService.refreshToken();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token refreshed successfully')),
        );
        await _loadUserSession();
      } else {
        throw Exception('Token refresh failed');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await _sessionManager.logout();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshToken,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _loadUserSession,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserSessionCard(),
                      const SizedBox(height: 16),
                      _buildUserRolesCard(),
                      const SizedBox(height: 16),
                      _buildUserPermissionsCard(),
                      const SizedBox(height: 16),
                      if (_userPermissions.contains('view_visitors'))
                        _buildVisitorLogsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildUserSessionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Session',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_userSession != null) ...[
              Text('User ID: ${_userSession!['userId'] ?? 'N/A'}'),
              Text('Username: ${_userSession!['username'] ?? 'N/A'}'),
              Text('Email: ${_userSession!['email'] ?? 'N/A'}'),
              Text('Full Name: ${_userSession!['fullName'] ?? 'N/A'}'),
              Text('Authenticated: ${_userSession!['isAuthenticated'] ?? false}'),
              Text('Session Time: ${_userSession!['sessionTimestamp'] ?? 'N/A'}'),
            ] else
              const Text('No active session'),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRolesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Roles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_userRoles.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _userRoles
                    .map((role) => Chip(
                          label: Text(role),
                          backgroundColor: Colors.blue.shade100,
                        ))
                    .toList(),
              )
            else
              const Text('No roles assigned'),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPermissionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_userPermissions.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _userPermissions
                    .map((permission) => Chip(
                          label: Text(permission),
                          backgroundColor: Colors.green.shade100,
                        ))
                    .toList(),
              )
            else
              const Text('No permissions granted'),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorLogsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Visitor Logs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadVisitorLogs,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_visitorLogs.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _visitorLogs.length,
                itemBuilder: (context, index) {
                  final log = _visitorLogs[index];
                  return ListTile(
                    title: Text(log['visitor_name'] ?? 'Unknown'),
                    subtitle: Text(log['status'] ?? 'Unknown'),
                    trailing: Text(log['created_at'] ?? ''),
                  );
                },
              )
            else
              const Text('No visitor logs available'),
          ],
        ),
      ),
    );
  }
}
