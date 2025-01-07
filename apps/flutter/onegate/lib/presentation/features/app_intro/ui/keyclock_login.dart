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

class LoginState1 {
  final bool isLoading;
  final String? userId;
  final int? selectedSocietyId;
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
    int? selectedSocietyId,
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
    await _saveUserData(userInfo);
    return userInfo;
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
  late final ValueNotifier<LoginState1> _LoginState1;

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
    _LoginState1 = ValueNotifier(const LoginState1());
    _initialize();
  }

  Future<void> _initialize() async {
    await _requestLocationPermission();
    await _loginService.initialize();
    await _checkLoginState1();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();

    if (!status.isGranted) {
      if (Platform.isIOS || status.isPermanentlyDenied) {
        _showLocationPermissionDialog();
      }
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
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

  Future<void> _checkLoginState1() async {
    final accessToken = await _loginService.gateStorage.getAccessToken();
    if (accessToken == null) {
      log("User is not logged in");
      return;
    }

    final userId = await _loginService.gateStorage.getUserId();
    final username = await _loginService.gateStorage.getUsername();
    final role = await _loginService.gateStorage.getRole();
    final societyId = await _loginService.gateStorage.getSocietyId();

    _LoginState1.value = _LoginState1.value.copyWith(
      userId: userId,
      username: username,
      selectedSocietyId: societyId,
    );

    _navigateBasedOnRole(role);
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
      _LoginState1.value = _LoginState1.value.copyWith(isLoading: true);

      final userInfo = await _loginService.performLogin();
      if (userInfo == null) throw Exception('No user info received');

      final userId = userInfo["old_sso_user_id"];
      if (userId == null) throw Exception('No user ID found');

      final societies = await _loginService.fetchSocieties(userId);

      if (societies.isEmpty) {
        throw Exception('No societies found for this user');
      } else if (societies.length == 1) {
        await _handleSingleSociety(societies.first);
      } else {
        _showSocietySelection(societies);
      }
    } catch (e) {
      log('Login error: $e');
      _LoginState1.value = _LoginState1.value.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      _showError(e.toString());
    }
  }

  Future<void> _handleSingleSociety(Map<String, dynamic> society) async {
    final societyId = society['company_id'];
    final societyName = society['company_name'];

    if (societyId == null) throw Exception('Invalid society data');

    await _loginService.gateStorage.saveSocietyDetails(societyId, societyName);
    await _loginService.gateStorage.saveSocietyId(societyId);

    _LoginState1.value = _LoginState1.value.copyWith(
      selectedSocietyId: societyId,
      isLoading: false,
    );

    _showRoleSelection();
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
        onSelected: _handleSocietySelected,
      ),
    );
  }

  Future<void> _handleSocietySelected(Map<String, dynamic> society) async {
    try {
      await _handleSingleSociety(society);
      Navigator.pop(context);
      _showRoleSelection();
    } catch (e) {
      _showError('Failed to save society: $e');
    }
  }

  void _showRoleSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RoleSelectionSheet(
        onAdminSelected: () => _handleRoleSelected('admin'),
        onGatekeeperSelected: () => _handleRoleSelected('gatekeeper'),
      ),
    );
  }

  Future<void> _handleRoleSelected(String role) async {
    await _loginService.gateStorage.saveRole(role);

    if (role == 'gatekeeper') {
      final gates = await _loginService.fetchGates();
      if (gates.isNotEmpty) {
        await _showGateSelection(gates);
      } else {
        _showError('No gates found for the selected society');
      }
    } else {
      _navigateBasedOnRole(role);
    }
  }

  Future<void> _showGateSelection(List<dynamic> gates) async {
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
        onGateSelected: (gate) {
          Navigator.pop(context);
          _navigateBasedOnRole('gatekeeper');
        },
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LoginState1>(
      valueListenable: _LoginState1,
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
            if (state.isLoading) const CircularProgressIndicator(),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _LoginState1.dispose();
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
              final societyId = society['company_id'];
              final societyName = society['company_name'];

              if (societyId == null) {
                return const ListTile(
                  title: Text('Invalid Society'),
                  subtitle: Text('This entry has no valid ID'),
                );
              }

              return ListTile(
                title: Text(societyName ?? 'Unknown Society'),
                onTap: () => onSelected(society),
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
  final VoidCallback onAdminSelected;
  final VoidCallback onGatekeeperSelected;

  const RoleSelectionSheet({
    Key? key,
    required this.onAdminSelected,
    required this.onGatekeeperSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(
            'Select Role',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        ListTile(
          title: const Text('Admin'),
          onTap: onAdminSelected,
        ),
        ListTile(
          title: const Text('Gatekeeper'),
          onTap: onGatekeeperSelected,
        ),
        const SizedBox(height: 30),
      ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(
            'Select Gate',
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
          itemCount: widget.gates.length,
          itemBuilder: (context, index) {
            final gate = widget.gates[index];
            final gateName = gate['gate_name'] ?? 'Unknown Gate';
            final isSelected = selectedIndex == index;

            return ListTile(
              title: Text(
                gateName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                  : null,
              onTap: () async {
                setState(() {
                  selectedIndex = index;
                });
                final gateProvider = Provider.of<GateProvider>(context, listen: false);
                await gateProvider.selectGate(index);

                widget.onGateSelected(gate);
              },
            );
          },
        ),
      ],
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
      await showDialog(
        context: context,
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

    return false;
  }
}

// API Service
class ApiService {
  final http.Client _client;
  final GateStorage _storage;

  ApiService({
    http.Client? client,
    GateStorage? storage,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? GateStorage();

  Future<dynamic> get(String url) async {
    try {
      final token = await _storage.getAccessToken();
      if (token == null) throw Exception('No access token found');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      log('API Error: $e');
      rethrow;
    }
  }
}