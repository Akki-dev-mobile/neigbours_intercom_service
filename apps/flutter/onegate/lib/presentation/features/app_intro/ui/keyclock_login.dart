import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// Import local packages
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/request_gate_access/ui/request_gate_access_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginState1 {
  final bool isLoading;
  final String? userId;
  final String? selectedSocietyId;
  final String? username;
  final String? error;

  const LoginState1({
    this.isLoading = false,
    this.userId,
    this.selectedSocietyId,
    this.username,
    this.error,
  });

  LoginState1 copyWith({
    bool? isLoading,
    String? userId,
    String? selectedSocietyId,
    String? username,
    String? error,
  }) {
    return LoginState1(
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      selectedSocietyId: selectedSocietyId ?? this.selectedSocietyId,
      username: username ?? this.username,
      error: error ?? this.error,
    );
  }
}

class LoginService {
  final KeycloakWrapper keycloakWrapper;
  final GateStorage gateStorage;
  final RemoteDataSource remoteDataSource;

  LoginService({
    required this.keycloakWrapper,
    required this.gateStorage,
    required this.remoteDataSource,
  });

  Future<void> initialize() async {
    try {
      await keycloakWrapper.initialize();
      log("Keycloak initialized successfully");
    } catch (e) {
      log('Error initializing Keycloak: $e');
      throw Exception('Failed to initialize Keycloak: $e');
    }
  }

  Future<Map<String, dynamic>?> performLogin() async {
    if (!keycloakWrapper.isInitialized) {
      throw Exception('Keycloak is not initialized');
    }

    final isLoggedIn = await keycloakWrapper.login();
    if (!isLoggedIn || keycloakWrapper.accessToken == null) {
      throw Exception('Login failed');
    }

    final userInfo = await keycloakWrapper.getUserInfo();
    log("Access token: ${keycloakWrapper.accessToken}");
    await _saveUserData(userInfo);
    return userInfo;
  }

  List<String> getUserRoles(Map society) {
    final List<dynamic> userRoles = society['user_roles'] ?? [];
    List<String> roles = userRoles.map((role) => _mapRole(role.toString())).toList();

    // If user is admin, add both admin and gatekeeper roles
    if (roles.contains('admin')) {
      roles = ['admin', 'gatekeeper'];
    }

    return roles;
  }

  String _mapRole(String apiRole) {
    switch (apiRole.toLowerCase()) {
      case 'master':
        return 'admin';
      case 'gatekeeper':
        return 'gatekeeper';
      default:
        return 'unknown';
    }
  }

  Future<void> _saveUserData(Map<String, dynamic>? userInfo) async {
    if (userInfo == null) return;

    await gateStorage.saveAccessToken(keycloakWrapper.accessToken!);
    await gateStorage.saveUserId(userInfo["old_sso_user_id"] ?? "");
    await gateStorage.saveUsername(userInfo["preferred_username"] ?? "");
  }

  Future<List<dynamic>> fetchSocieties(String userId) async {
    return await remoteDataSource.fetchSocieties(userId);
  }

  Future<List<dynamic>> fetchGates() async {
    return await remoteDataSource.fetchGates();
  }
}

class MyAppLogin extends StatefulWidget {
  const MyAppLogin({Key? key}) : super(key: key);

  @override
  State<MyAppLogin> createState() => _MyAppLoginState1();
}

class _MyAppLoginState1 extends State<MyAppLogin> {
  late final LoginService _loginService;
  late final ValueNotifier<LoginState1> _loginState;

  @override
  void initState() {
    super.initState();
    _loginService = LoginService(
      keycloakWrapper: KeycloakWrapper(config: KeycloakConfigManager.getConfig()),
      gateStorage: GateStorage(),
      remoteDataSource: RemoteDataSource(
        DioSingleton.instance1,
        DioSingleton.instance2,
        DioSingleton.instance3,
      ),
    );
    _loginState = ValueNotifier(const LoginState1());
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _requestLocationPermission();
      await _loginService.initialize();
      await _checkLoginState();
    } catch (e) {
      log('Initialization error: $e');
      _showError('Failed to initialize: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (!status.isGranted && (Platform.isIOS || status.isPermanentlyDenied)) {
      _showLocationPermissionDialog();
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: const Text(
          "Location permissions are required to use this feature. Please enable them in your device settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLoginState() async {
    try {
      final accessToken = await _loginService.gateStorage.getAccessToken();
      if (accessToken == null) {
        log("User is not logged in");
        return;
      }

      final userId = await _loginService.gateStorage.getUserId();
      final username = await _loginService.gateStorage.getUsername();
      final role = await _loginService.gateStorage.getRole();
      final societyId = await _loginService.gateStorage.getSocietyId();

      _loginState.value = _loginState.value.copyWith(
        userId: userId,
        username: username,
        selectedSocietyId: societyId,
      );

      _navigateBasedOnRole(role);
    } catch (e) {
      log('Error checking login state: $e');
      _showError('Failed to check login state: $e');
    }
  }

  void _navigateBasedOnRole(String? role) {
    Widget? destination;
    switch (role) {
      case 'admin':
        destination = const AdminDashboardView();
        break;
      case 'gatekeeper':
        destination = const GateDashboardView();
        break;
    }

    if (destination != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination!),
      );
    }
  }

  Future<void> _handleLogin() async {
    try {
      _loginState.value = _loginState.value.copyWith(isLoading: true);

      final userInfo = await _loginService.performLogin();
      if (userInfo == null) throw Exception('No user info received');

      final userId = userInfo["old_sso_user_id"];
      if (userId == null) throw Exception('No user ID found');

      final societies = await _loginService.fetchSocieties(userId);
      if (societies.isEmpty) {
        throw Exception('No societies found for this user');
      }

      if (societies.length == 1) {
        await _handleSingleSociety(societies.first);
      } else {
        _showSocietySelection(societies);
      }
    } catch (e) {
      log('Login error: $e');
      _loginState.value = _loginState.value.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      _showError(e.toString());
    }
  }

  Future<void> _handleSingleSociety(Map<dynamic, dynamic> society) async {
    try {
      final societyId = society['company_id']?.toString();
      final societyName = society['company_name'];
      final roles = _loginService.getUserRoles(society);

      if (societyId == null || societyId.isEmpty) {
        throw Exception('Invalid society data: societyId is null or empty');
      }

      if (roles.isEmpty) {
        throw Exception('No valid roles found for user');
      }

      await _loginService.gateStorage.saveSocietyDetails(societyId, societyName);
      await _loginService.gateStorage.saveSocietyId(societyId);

      _loginState.value = _loginState.value.copyWith(
        selectedSocietyId: societyId,
        isLoading: false,
      );

      if (roles.length == 1) {
        await _handleRoleSelected(roles.first);
      } else {
        _showRoleSelection(roles);
      }
    } catch (e) {
      _showError('Failed to process society: $e');
      _loginState.value = _loginState.value.copyWith(isLoading: false);
    }
  }

  void _showSocietySelection(List<dynamic> societies) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SocietySelectionSheet(
        societies: societies,
        onSelected: (society) async {
          try {
            await _handleSingleSociety(society);
            Navigator.pop(context);
          } catch (e) {
            _showError('Failed to save society: $e');
          }
        },
      ),
    );
  }

  void _showRoleSelection(List<String> availableRoles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RoleSelectionSheet(
        availableRoles: availableRoles,
        onRoleSelected: _handleRoleSelected,
      ),
    );
  }

  Future<void> _handleRoleSelected(String role) async {
    try {
      await _loginService.gateStorage.saveRole(role);
      final gates = await _loginService.fetchGates();

      if (gates.isEmpty) {
        _showError('No gates found for the selected society');
        return;
      }

      await _showGateSelection(gates, role);
    } catch (e) {
      _showError('Failed to process role selection: $e');
    }
  }

  Future<void> _showGateSelection(List<dynamic> gates, String selectedRole) async {
    try {
      final gateProvider = Provider.of<GateProvider>(context, listen: false);
      await gateProvider.loadGates();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => GateSelectionSheet(
          gates: gates,
          onGateSelected: (gate) async {
            try {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('selected_gate', gate["gate_name"]);
              Navigator.pop(context);
              _navigateBasedOnRole(selectedRole);
            } catch (e) {
              _showError('Failed to save gate selection: $e');
            }
          },
        ),
      );
    } catch (e) {
      _showError('Failed to show gate selection: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LoginState1>(
      valueListenable: _loginState,
      builder: (context, state, child) {
        return Stack(
          children: [
            MyScrollView(
              isScrollable: false,
              hasBackButton: false,
              pageBody: LoginContent(
                onLoginPressed: _handleLogin,
                onSignUpPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestGateAccess(),
                    ),
                  );
                },
              ),
            ),
            if (state.isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _loginState.dispose();
    super.dispose();
  }
}


class LoginContent extends StatelessWidget {
  final VoidCallback onLoginPressed;
  final VoidCallback onSignUpPressed;

  const LoginContent({
    Key? key,
    required this.onLoginPressed,
    required this.onSignUpPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Lottie.network(
            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/auth_Animation_fec8c8284d.json',
            height: MediaQuery.of(context).size.height * 0.3,
            width: double.infinity,
          ),
          ListTile(
            contentPadding: const EdgeInsets.only(top: 20, bottom: 10),
            title: Text(
              'Login',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                "Welcome back! Let's dive in.",
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          CustomLargeBtn(
            text: 'Login',
            onPressed: onLoginPressed,
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextButton(
              onPressed: onSignUpPressed,
              child: Hero(
                tag: 'signUpHero',
                child: Text(
                  'Sign Up',
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// Society Selection Sheet
class SocietySelectionSheet extends StatelessWidget {
  final List<dynamic> societies;
  final Function(Map<String, dynamic>) onSelected;

  const SocietySelectionSheet({
    Key? key,
    required this.societies,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          ListTile(
            title: Text(
              'Select Society',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
            height: 1,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: societies.length,
            itemBuilder: (context, index) {
              final society = societies[index];
              final societyId = society['company_id']?.toString();
              final societyName = society['company_name'];

              if (societyId == null) {
                return const ListTile(
                  title: Text('Invalid Society'),
                  subtitle: Text('This entry has no valid ID'),
                );
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(societyName ?? 'Unknown Society'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => onSelected(Map<String, dynamic>.from(society)),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Role Selection Sheet
class RoleSelectionSheet extends StatelessWidget {
  final List<String> availableRoles;
  final Function(String) onRoleSelected;

  const RoleSelectionSheet({
    Key? key,
    required this.availableRoles,
    required this.onRoleSelected,
  }) : super(key: key);

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Admin / Master';
      case 'gatekeeper':
        return 'Gatekeeper';
      default:
        return 'Unknown Role';
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'admin':
        return 'Full access to manage society and gates';
      case 'gatekeeper':
        return 'Access to manage gate entries and exits';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            title: Text(
              'Select Role',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            subtitle: const Text('Choose your role for this session'),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
            height: 1,
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableRoles.length,
              itemBuilder: (context, index) {
                final role = availableRoles[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      _getRoleDisplayName(role),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _getRoleDescription(role),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => onRoleSelected(role),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Gate Selection Sheet
class GateSelectionSheet extends StatefulWidget {
  final List<dynamic> gates;
  final Function(Map<String, dynamic>) onGateSelected;

  const GateSelectionSheet({
    Key? key,
    required this.gates,
    required this.onGateSelected,
  }) : super(key: key);

  @override
  State<GateSelectionSheet> createState() => _GateSelectionSheetState();
}

class _GateSelectionSheetState extends State<GateSelectionSheet> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            title: Text(
              'Select Gate',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            subtitle: const Text('Choose the gate you want to manage'),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
            height: 1,
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.gates.length,
              itemBuilder: (context, index) {
                final gate = widget.gates[index];
                final gateName = gate['gate_name'] ?? 'Unknown Gate';
                final isSelected = selectedIndex == index;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      gateName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      setState(() {
                        selectedIndex = index;
                      });

                      try {
                        final gateProvider = Provider.of<GateProvider>(
                            context,
                            listen: false
                        );
                        await gateProvider.selectGate(index);
                        widget.onGateSelected(Map<String, dynamic>.from(gate));
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to select gate: $e')),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Location Permission Handler
class LocationPermissionHandler {
  static Future<bool> checkAndRequestPermission(BuildContext context) async {
    final status = await Permission.location.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.location.request();
      if (result.isGranted) {
        return true;
      }
    }

    if (status.isPermanentlyDenied || Platform.isIOS) {
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'Please enable location permissions in your device settings to use this feature.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }

    return false;
  }
}