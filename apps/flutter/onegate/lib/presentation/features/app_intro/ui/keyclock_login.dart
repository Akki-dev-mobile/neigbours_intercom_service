import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/request_gate_access/ui/request_gate_access_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/utils/custom_appauth.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/utils/ssl_bypass.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'missed_approval_two.dart';

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
    RemoteDataSource().fetchAndStoreFaceRecConfig();
    try {
      // Set up SSL certificate bypass for debug mode
      initializeSSLBypass();

      // Configure AppAuth to allow insecure connections
      await CustomAppAuth.configureAppAuth();

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
    List<String> roles =
        userRoles.map((role) => _mapRole(role.toString())).toList();

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
      case 'admin':
        return 'admin';
      default:
        return apiRole;
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
      keycloakWrapper:
          KeycloakWrapper(config: KeycloakConfigManager.getConfig()),
      gateStorage: GateStorage(),
      remoteDataSource: RemoteDataSource(),
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

  Future<void> _navigateBasedOnRole(String? role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool hasNavigatedToGateSettings =
          prefs.getBool('hasNavigatedToGateSettings') ?? false;

      final selectedGateName = prefs.getString('selected_gate') ?? '';
      final cleanedGateName = selectedGateName.toLowerCase();

      Widget? destination;

      if (role == 'admin') {
        destination = const AdminDashboardView();
      } else if (role == 'gatekeeper') {
        if (cleanedGateName.contains("tower")) {
          String formattedTowerName = "TOWER NO ";
          RegExp regExp = RegExp(r'tower\s*(?:no\.?|number)?\s*(\d+)',
              caseSensitive: false);
          var match = regExp.firstMatch(cleanedGateName);

          if (match != null && match.group(1) != null) {
            formattedTowerName += match.group(1)!.padLeft(2, '0');
          } else {
            formattedTowerName = selectedGateName.toUpperCase();
          }

          await prefs.setString('selected_gate', formattedTowerName);

          destination = MissedApprovalsScreen2(
            remoteDataSource: RemoteDataSource(),
            towerName: formattedTowerName,
          );

          log('Auto-navigating to tower: $formattedTowerName');
        } else {
          // If not tower, check if already went to visitor settings
          if (!hasNavigatedToGateSettings) {
            destination = VisitorSettingsView(comingfrom: true);
            await prefs.setBool('hasNavigatedToGateSettings', true);
          } else {
            destination = const GateDashboardView();
          }
        }
      }

      if (destination != null) {
        log('Navigating to $role -> ${destination.runtimeType}');
        if (context.mounted) {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => destination!),
          );
          log('Navigation to ${destination.runtimeType} complete');
        } else {
          log('Context is not mounted. Unable to navigate.');
        }
      } else {
        log('No valid role found or no destination for role: $role');
      }
    } catch (e, stackTrace) {
      log('Error during navigation: $e');
      log('Stack trace: $stackTrace');
      _showError('Failed to navigate based on role: $e');
    }
  }

  // void _showError(String message) {
  //   if (context.mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(message)),
  //     );
  //   }
  // }

  // void _showError(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text(message)),
  //   );
  // }
  Future<void> _handleLogin() async {
    try {
      if (_isDisposed) return;
      _safeUpdateState(_loginState.value.copyWith(isLoading: true));

      final userInfo = await _loginService.performLogin();
      if (userInfo == null) throw Exception('No user info received');

      final userId = userInfo["old_sso_user_id"];
      if (userId == null) throw Exception('No user ID found');

      final societies = await _loginService.fetchSocieties(userId);
      if (societies.isEmpty) {
        throw Exception('No societies found for this user');
      }

      if (_isDisposed) return;

      if (societies.length == 1) {
        await _handleSingleSociety(societies.first);
      } else {
        _showSocietySelection(societies);
      }
    } catch (e) {
      log('Login error: $e');
      if (!_isDisposed) {
        _safeUpdateState(_loginState.value.copyWith(
          error: e.toString(),
          isLoading: false,
        ));
        _showError(e.toString());
      }
    }
  }

  void _safeUpdateState(LoginState1 newState) {
    if (mounted && !_isDisposed) {
      _loginState.value = newState;
    }
  }

  Future<void> _handleSingleSociety(Map<dynamic, dynamic> society) async {
    try {
      final societyId = society['company_id']?.toString();
      final societyName = society['company_name'];

      // Extract roles or fallback to 'member'
      final roles = extractRoles(society['user_roles']);
      log('Raw roles from society: $roles');

      final mappedRoles =
          roles.map((role) => _loginService._mapRole(role)).toSet().toList();

      if (mappedRoles.isEmpty) {
        log('No roles found, assigning default "member" role');
        mappedRoles.add('member');
      }

      log('Mapped roles after processing: $mappedRoles');

      await _loginService.gateStorage
          .saveSocietyDetails(societyId!, societyName);
      await _loginService.gateStorage.saveSocietyId(societyId);

      if (!mounted) return; // Add this check

      _loginState.value = _loginState.value.copyWith(
        selectedSocietyId: societyId,
        isLoading: false,
      );

      _showRoleSelection(mappedRoles);
    } catch (e) {
      if (mounted) {
        // Add this check
        _showError('Failed to process society: $e');
        _loginState.value = _loginState.value.copyWith(isLoading: false);
      }
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
                  Navigator.pop(context);
                  await _handleSingleSociety(society);
                } catch (e) {
                  _showError('Failed to save society: $e');
                }
              },
            ));
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
      log('Role selected by user: $role');
      await _loginService.gateStorage.saveRole(role);

      final gates = await _loginService.fetchGates();
      log('Fetched gates: $gates');

      if (gates.isEmpty) {
        _showError('No gates found for the selected society');
        return;
      }

      await _showGateSelection(gates, role);
    } catch (e) {
      _showError('Failed to process role selection: $e');
    }
  }

  List<String> extractRoles(dynamic userRoles) {
    if (userRoles is List) {
      return userRoles.map((e) => e.toString()).toList();
    } else if (userRoles is Map) {
      return userRoles.values.map((e) => e.toString()).toList();
    } else {
      return [];
    }
  }

  Future<void> _showGateSelection(
      List<dynamic> gates, String selectedRole) async {
    try {
      if (gates.isEmpty) {
        _showError('No gates available for selection.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      if (gates.length == 1) {
        final singleGate = gates.first;
        String gateName = singleGate["gate_name"];

        // Format tower name if needed
        if (gateName.toLowerCase().contains("tower")) {
          String formattedTowerName = "TOWER NO ";

          // Extract tower number if available
          RegExp regExp = RegExp(r'tower\s*(?:no\.?|number)?\s*(\d+)',
              caseSensitive: false);
          var match = regExp.firstMatch(gateName.toLowerCase());

          if (match != null && match.group(1) != null) {
            formattedTowerName += match.group(1)!.padLeft(2, '0');
          } else {
            formattedTowerName = gateName.toUpperCase();
          }

          gateName = formattedTowerName;
        }

        await prefs.setString('selected_gate', gateName);
        await prefs.setString(
            'selected_gate_id', singleGate["gate_id"].toString());
        log("Automatically selected single gate: $gateName with ID: ${singleGate['gate_id']}");

        if (context.mounted) {
          myFluttertoast(
              msg: 'Only one gate available. Navigating to $gateName');
        }

        await _navigateBasedOnRole(selectedRole);
        return;
      }

      log("Opening gate selection sheet...");
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => GateSelectionSheet(
          gates: gates,
          onGateSelected: (gate) async {
            try {
              String gateName = gate["gate_name"];

              // Format tower name if needed
              if (gateName.toLowerCase().contains("tower")) {
                String formattedTowerName = "TOWER NO ";

                // Extract tower number if available
                RegExp regExp = RegExp(r'tower\s*(?:no\.?|number)?\s*(\d+)',
                    caseSensitive: false);
                var match = regExp.firstMatch(gateName.toLowerCase());

                if (match != null && match.group(1) != null) {
                  formattedTowerName += match.group(1)!.padLeft(2, '0');
                } else {
                  formattedTowerName = gateName.toUpperCase();
                }

                gateName = formattedTowerName;
              }

              await prefs.setString('selected_gate', gateName);
              await prefs.setString(
                  'selected_gate_id', gate["gate_id"].toString());
              // Store gate_type as well
              await prefs.setString('selected_gate_type',
                  gate["gate_type"]?.toString() ?? "both");
              log("Gate selected: $gateName with ID: ${gate['gate_id']}, type: ${gate['gate_type']}");

              Navigator.pop(context); // Close the bottom sheet
              await _navigateBasedOnRole(selectedRole);
            } catch (e) {
              _showError('Failed to save gate selection: $e');
            }
          },
        ),
      );
    } catch (e, stackTrace) {
      log('Error showing gate selection: $e');
      log('Stack trace: $stackTrace');
      _showError('Failed to show gate selection: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(message)),
    // );
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

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
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
class SocietySelectionSheet extends StatefulWidget {
  final List<dynamic> societies;
  final Function(Map<String, dynamic>) onSelected;

  const SocietySelectionSheet({
    Key? key,
    required this.societies,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<SocietySelectionSheet> createState() => _SocietySelectionSheetState();
}

class _SocietySelectionSheetState extends State<SocietySelectionSheet> {
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
              'Select Society',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            subtitle: const Text('Choose the society you want to access'),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
            height: 1,
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.societies.length,
              itemBuilder: (context, index) {
                final society = widget.societies[index];
                final societyName =
                    society['company_name'] ?? 'Unknown Society';
                final isSelected = selectedIndex == index;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      societyName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                      });

                      widget.onSelected(society);
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
    // Capitalize the first letter of each role for better readability
    return role
        .split('_')
        .map((e) => e[0].toUpperCase() + e.substring(1))
        .join(' ');
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
                      'Access with role: ${_getRoleDisplayName(role)}',
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                        final gateProvider =
                            Provider.of<GateProvider>(context, listen: false);
                        await gateProvider.selectGate(index);
                        widget.onGateSelected(Map<String, dynamic>.from(gate));
                      } catch (e) {
                        if (mounted) {
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(content: Text('Failed to select gate: $e')),
                          // );
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
