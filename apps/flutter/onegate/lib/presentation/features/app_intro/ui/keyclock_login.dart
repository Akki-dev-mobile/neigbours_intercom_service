import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/auth/company.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/presentation/features/auth/bloc/login_bloc.dart';
import 'package:flutter_onegate/presentation/features/auth/widgets/native_login_form.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/request_gate_access/ui/request_gate_access_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/config/gateconfig_holder.dart';
import 'package:flutter_onegate/utils/custom_appauth.dart';
import 'package:flutter_onegate/utils/ssl_bypass.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

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
  final AuthService authService;
  final GateStorage gateStorage;
  final RemoteDataSource remoteDataSource;

  LoginService({
    required this.authService,
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

      await authService.initialize();
      log("AppAuth service initialized successfully");
    } catch (e) {
      log('Error initializing AppAuth service: $e');
      throw Exception('Failed to initialize AppAuth service: $e');
    }
  }

  Future<Map<String, dynamic>?> performLogin() async {
    try {
      log('🔐 Starting login process...');

      final userInfo = await authService.login();
      if (userInfo == null) {
        throw Exception('Login failed - no user info received');
      }

      log("✅ Login successful, user info received");
      return userInfo;
    } catch (e) {
      log("❌ Login failed: $e");
      throw Exception('Login failed: $e');
    }
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

enum _NativeLoginSheet { society, role, gate }

class _MyAppLoginState1 extends State<MyAppLogin> {
  late final LoginService _loginService;
  late final ValueNotifier<LoginState1> _loginState;
  bool _isResolvingPostLoginNavigation = false;
  _NativeLoginSheet? _activeNativeSheet;

  @override
  void initState() {
    super.initState();
    // Use dependency injection instead of creating new instances
    _loginService = LoginService(
      authService: GetIt.I<AuthService>(),
      gateStorage: GetIt.I<GateStorage>(),
      remoteDataSource: GetIt.I<RemoteDataSource>(),
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
        title: Text(context.tr('Location Permission Required')),
        content: Text(
          context.tr(
              'Location permissions are required to use this feature. Please enable them in your device settings.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(context.tr('Open Settings')),
          ),
        ],
      ),
    );
  }

  /// On cold start, restore an existing session if tokens are still valid,
  /// refreshing them if needed via AuthService. Only send user to login when
  /// both access and refresh tokens can no longer produce a valid session.
  Future<void> _checkLoginState() async {
    try {
      final authService = GetIt.I<AuthService>();

      // This uses EnhancedTokenRefreshManager under the hood and will:
      // - return a non-null token if access/refresh are still usable
      // - return null only when the session is really gone
      final validAccessToken = await authService.getValidAccessToken();
      if (validAccessToken == null) {
        log("🔐 No valid access token on startup - treating as logged out");
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
      log('🔄 Starting navigation for role: $role');

      final prefs = await SharedPreferences.getInstance();
      bool hasNavigatedToGateSettings =
          prefs.getBool('hasNavigatedToGateSettings') ?? false;

      final selectedGateName = prefs.getString('selected_gate') ?? '';
      final cleanedGateName = selectedGateName.toLowerCase();

      log('📍 Selected gate: $selectedGateName');
      log('📍 Has navigated to gate settings: $hasNavigatedToGateSettings');

      Widget? destination;

      if (role == 'admin') {
        log('👑 Admin role detected - navigating to AdminDashboardView');
        destination = const AdminDashboardView();
      } else if (role == 'gatekeeper') {
        log('🚪 Gatekeeper role detected');
        if (cleanedGateName.contains("tower")) {
          log('🏢 Tower gate detected: $cleanedGateName');
          String formattedTowerName = "TOWER NO ";
          RegExp regExp = RegExp(
            r'tower\s*(?:no\.?|number)?\s*(\d+)',
            caseSensitive: false,
          );
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

          log('🏢 Auto-navigating to tower: $formattedTowerName');
        } else {
          log('🏠 Regular gate detected');
          // If not tower, check if already went to visitor settings
          if (!hasNavigatedToGateSettings) {
            log('⚙️ First time - navigating to VisitorSettingsView');
            destination = VisitorSettingsView(comingfrom: true);
            await prefs.setBool('hasNavigatedToGateSettings', true);
          } else {
            log('🏠 Returning user - navigating to GateDashboardView');
            destination = const GateDashboardView();
          }
        }
      } else {
        log('❌ Unknown role: $role');
      }

      if (destination != null) {
        log('✅ Destination determined: ${destination.runtimeType}');
        log('🔄 Checking context.mounted: ${context.mounted}');
        if (context.mounted) {
          log('🚀 Starting navigation to ${destination.runtimeType}');
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => destination!),
          );
          log('✅ Navigation to ${destination.runtimeType} complete');
        } else {
          log('❌ Context is not mounted. Unable to navigate.');
        }
      } else {
        log('❌ No destination determined for role: $role');
      }
    } catch (e, stackTrace) {
      log('💥 Error during navigation: $e');
      log('📚 Stack trace: $stackTrace');
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

  void _safeUpdateState(LoginState1 newState) {
    if (mounted && !_isDisposed) {
      _loginState.value = newState;
    }
  }

  Future<void> _handleLogin() async {
    try {
      if (_isDisposed) return;
      FocusManager.instance.primaryFocus?.unfocus();
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
        _safeUpdateState(
          _loginState.value.copyWith(error: e.toString(), isLoading: false),
        );
        _showError(e.toString());
      }
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

      await _loginService.gateStorage.saveSocietyDetails(
        societyId!,
        societyName,
      );
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
    List<dynamic> gates,
    String selectedRole,
  ) async {
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
          RegExp regExp = RegExp(
            r'tower\s*(?:no\.?|number)?\s*(\d+)',
            caseSensitive: false,
          );
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
          'selected_gate_id',
          singleGate["gate_id"].toString(),
        );
        log(
          "Automatically selected single gate: $gateName with ID: ${singleGate['gate_id']}",
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff2196F3), Color(0xff1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff2196F3).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Auto-Selected Gate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Only one gate available. Navigating to $gateName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              margin: const EdgeInsets.all(16),
            ),
          );
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
                RegExp regExp = RegExp(
                  r'tower\s*(?:no\.?|number)?\s*(\d+)',
                  caseSensitive: false,
                );
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
                'selected_gate_id',
                gate["gate_id"].toString(),
              );
              // Store gate_type as well
              await prefs.setString(
                'selected_gate_type',
                gate["gate_type"]?.toString() ?? "both",
              );
              log(
                "Gate selected: $gateName with ID: ${gate['gate_id']}, type: ${gate['gate_type']}",
              );

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
    log('🚨 ERROR: $message');
    if (!mounted) {
      log('🚨 Widget not mounted, cannot show error dialog');
      return;
    }

    // Show error in console for debugging
    print('🚨 LOGIN ERROR: $message');

    // Uncomment to show SnackBar
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(message)),
    // );
  }

  /// Prefer native login UI; set to false to respect remote use_native_login only.
  static const bool _preferNativeLogin = true;

  @override
  Widget build(BuildContext context) {
    final useNative = _preferNativeLogin || GateConfigHolder.useNativeLogin;
    if (useNative) {
      return BlocProvider<LoginBloc>(
        create: (_) => GetIt.I<LoginBloc>(),
        child: BlocListener<LoginBloc, LoginState>(
          listener: (context, state) {
            if (!mounted) return;
            if (state is SocietySelectionState) {
              _hidePostLoginTransition();
              SessionManagementCoordinator.setNavigatingToLogin(false);
              _showNativeSocietySelection(context, state);
            } else if (state is RoleSelectionState) {
              _hidePostLoginTransition();
              _showNativeRoleSelection(context, state);
            } else if (state is GateSelectionState) {
              _showNativeGateSelection(context, state);
            } else if (state is LoginErrorState) {
              _hidePostLoginTransition();
            } else if (state is NavigateToAdminDashboardState) {
              SessionManagementCoordinator.setNavigatingToLogin(false);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const VisitorSettingsView()),
              );
            } else if (state is NavigateToGatekeeperDashboardState) {
              SessionManagementCoordinator.setNavigatingToLogin(false);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const VisitorSettingsView()),
              );
            }
          },
          child: BlocBuilder<LoginBloc, LoginState>(
            buildWhen: (_, state) =>
                state is LoginNavigationLoadingState ||
                state is LoginErrorState,
            builder: (context, state) {
              final showPostLoginTransition = _isResolvingPostLoginNavigation ||
                  state is LoginNavigationLoadingState;
              return Scaffold(
                backgroundColor: Colors.white,
                body: showPostLoginTransition
                    ? const _PostLoginTransitionView()
                    : const NativeLoginForm(),
              );
            },
          ),
        ),
      );
    }

    return ValueListenableBuilder<LoginState1>(
      valueListenable: _loginState,
      builder: (context, state, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              LoginContent(
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
              if (state.isLoading) const Center(child: DashboardLoaderIcon()),
            ],
          ),
        );
      },
    );
  }

  void _showNativeSocietySelection(
      BuildContext context, SocietySelectionState state) {
    if (!_markNativeSheetActive(_NativeLoginSheet.society)) return;

    final raw = state.companiesWithAccessToGate;
    if (raw is! List || raw.isEmpty) {
      _clearNativeSheet(_NativeLoginSheet.society);
      return;
    }
    final companies = raw.whereType<Company>().toList();
    final societies = companies
        .map((c) => {
              'company_id': c.companyId,
              'company_name': c.companyName,
            })
        .toList();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SocietySelectionSheet(
        societies: societies,
        onSelected: (map) {
          if (!_consumeNativeSheet(_NativeLoginSheet.society)) return;
          Navigator.pop(ctx);
          final id = map['company_id']?.toString();
          final company = companies.cast<Company?>().firstWhere(
                (c) => c?.companyId.toString() == id,
                orElse: () => null,
              );
          if (company != null) {
            context.read<LoginBloc>().add(SocietySelectionButtonEvent(company));
          }
        },
      ),
    ).whenComplete(() => _clearNativeSheet(_NativeLoginSheet.society));
  }

  void _showNativeRoleSelection(
      BuildContext context, RoleSelectionState state) {
    if (!_markNativeSheetActive(_NativeLoginSheet.role)) return;

    final roles = state.roles.whereType<String>().toList();
    if (roles.isEmpty) {
      _clearNativeSheet(_NativeLoginSheet.role);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => RoleSelectionSheet(
        availableRoles: roles,
        onRoleSelected: (role) {
          if (!_consumeNativeSheet(_NativeLoginSheet.role)) return;
          _showPostLoginTransition();
          Navigator.pop(ctx);
          context.read<LoginBloc>().add(
                RoleSelectionButtonPressedEvent(role.toLowerCase() == 'admin'),
              );
        },
      ),
    ).whenComplete(() => _clearNativeSheet(_NativeLoginSheet.role));
  }

  void _showNativeGateSelection(
      BuildContext context, GateSelectionState state) {
    if (!_markNativeSheetActive(_NativeLoginSheet.gate)) return;

    final gates = state.gates.whereType<Gate>().toList();
    if (gates.isEmpty) {
      _clearNativeSheet(_NativeLoginSheet.gate);
      return;
    }
    final gateMaps = gates.map((g) {
      final m = Map<String, dynamic>.from(g.toJson());
      m['gate_id'] = g.id;
      return m;
    }).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => GateSelectionSheet(
        gates: gateMaps,
        onGateSelected: (map) {
          if (!_consumeNativeSheet(_NativeLoginSheet.gate)) return;
          _showPostLoginTransition();
          Navigator.pop(ctx);
          final gateMap = Map<String, dynamic>.from(map);
          gateMap['id'] = gateMap['gate_id'] ?? gateMap['id'];
          final gate = Gate.fromJson(gateMap);
          context.read<LoginBloc>().add(GateSelectionButtonPressedEvent(gate));
        },
      ),
    ).whenComplete(() => _clearNativeSheet(_NativeLoginSheet.gate));
  }

  bool _markNativeSheetActive(_NativeLoginSheet sheet) {
    if (!mounted) return false;
    if (_activeNativeSheet != null) {
      log('Skipping duplicate native login sheet: $sheet '
          '(active: $_activeNativeSheet)');
      return false;
    }
    _activeNativeSheet = sheet;
    return true;
  }

  bool _consumeNativeSheet(_NativeLoginSheet sheet) {
    if (_activeNativeSheet != sheet) {
      log('Ignoring duplicate native login sheet action: $sheet '
          '(active: $_activeNativeSheet)');
      return false;
    }
    _activeNativeSheet = null;
    return true;
  }

  void _clearNativeSheet(_NativeLoginSheet sheet) {
    if (_activeNativeSheet == sheet) {
      _activeNativeSheet = null;
    }
  }

  void _showPostLoginTransition() {
    if (!mounted || _isResolvingPostLoginNavigation) return;
    setState(() => _isResolvingPostLoginNavigation = true);
  }

  void _hidePostLoginTransition() {
    if (!mounted || !_isResolvingPostLoginNavigation) return;
    setState(() => _isResolvingPostLoginNavigation = false);
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _loginState.dispose();
    super.dispose();
  }
}

class _PostLoginTransitionView extends StatelessWidget {
  const _PostLoginTransitionView();

  @override
  Widget build(BuildContext context) {
    return DashboardLoader(
      title: context.tr('Loading In-Out Book'),
      subtitle: context.tr('dashboardPreparingVisitorLogs'),
    );
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
    return Container(
      height: MediaQuery.of(context).size.height +
          MediaQuery.of(context).padding.top,
      width: double.infinity,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Enhanced Society Gate Illustration
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Society Gate Icon - Enhanced
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xffF44336), Color(0xffD32F2F)],
                        ),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffF44336).withOpacity(0.4),
                            spreadRadius: 0,
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: const Color(0xffF44336).withOpacity(0.2),
                            spreadRadius: 0,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fence,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Society Name
                    Text(
                      'OneGate',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xffF44336),
                        letterSpacing: 1.0,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      context.tr('smartGateManagementTagline'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff57636C),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Enhanced Content Container
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 3,
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Enhanced Title Section
                    Column(
                      children: [
                        Text(
                          context.tr('Welcome Back!'),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.displayLarge?.copyWith(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff212427),
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            "Let's dive in and start recording your visitors",
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                color: const Color(0xff57636C),
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Enhanced Login Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xff212427), Color(0xff57636C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff212427).withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onLoginPressed,
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: Text(
                              context.tr('Login'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Enhanced Sign Up Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr("Don't have an account? "),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xff57636C),
                                fontSize: 16,
                              ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onSignUpPressed,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Hero(
                                tag: 'signUpHero',
                                child: Text(
                                  context.tr('Sign Up'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xffF44336),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
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

  IconData _getSocietyIcon(String societyName) {
    // You can customize icons based on society names if needed
    if (societyName.toLowerCase().contains('residential')) {
      return Icons.home;
    } else if (societyName.toLowerCase().contains('commercial')) {
      return Icons.business;
    } else if (societyName.toLowerCase().contains('apartment')) {
      return Icons.apartment;
    } else {
      return Icons.location_city;
    }
  }

  String _getSocietyDescription(String societyName) {
    return 'Access $societyName facilities and services';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced drag handle
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),

          // Enhanced header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xffF44336).withOpacity(0.08),
                  const Color(0xffff5722).withOpacity(0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Compact icon section
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: Color(0xffF44336),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Simple label section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('Select Your Society'),
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff212427),
                              fontSize: 20,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('Choose your society to continue'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xff57636C),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Enhanced content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 16),
                itemCount: widget.societies.length,
                itemBuilder: (context, index) {
                  final society = widget.societies[index];
                  final societyName =
                      society['company_name'] ?? 'Unknown Society';
                  final isSelected = selectedIndex == index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedIndex = index;
                          });
                          widget.onSelected(society);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xffF44336).withOpacity(0.05)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xffF44336).withOpacity(0.3)
                                  : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? const Color(
                                        0xffF44336,
                                      ).withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                spreadRadius: isSelected ? 2 : 1,
                                blurRadius: isSelected ? 12 : 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Society icon with background
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xffF44336,
                                        ).withOpacity(0.2)
                                      : const Color(
                                          0xffF44336,
                                        ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getSocietyIcon(societyName),
                                  color: const Color(0xffF44336),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Society information
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      societyName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xffF44336)
                                                : const Color(0xff212427),
                                            fontSize: 18,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getSocietyDescription(societyName),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xff57636C),
                                            fontSize: 14,
                                            height: 1.3,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Selection indicator
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xffF44336,
                                        ).withOpacity(0.1)
                                      : const Color(0xffF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.arrow_forward_ios,
                                  size: 16,
                                  color: isSelected
                                      ? const Color(0xffF44336)
                                      : const Color(0xff57636C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
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

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'gatekeeper':
        return Icons.security;
      case 'manager':
        return Icons.manage_accounts;
      case 'supervisor':
        return Icons.supervisor_account;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced drag handle
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),

          // Enhanced header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xffF44336).withOpacity(0.08),
                  const Color(0xffff5722).withOpacity(0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Compact icon section
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_pin_circle,
                    color: Color(0xffF44336),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Simple label section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('Select Your Role'),
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff212427),
                              fontSize: 20,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('Choose your role to continue'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xff57636C),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Enhanced content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 16),
                itemCount: availableRoles.length,
                itemBuilder: (context, index) {
                  final role = availableRoles[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onRoleSelected(role),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Role icon with background
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xffF44336,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getRoleIcon(role),
                                  color: const Color(0xffF44336),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Role information
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getRoleDisplayName(role),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xff212427),
                                            fontSize: 18,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getRoleDescription(role).isNotEmpty
                                          ? _getRoleDescription(role)
                                          : 'Access with ${_getRoleDisplayName(role)} privileges',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xff57636C),
                                            fontSize: 14,
                                            height: 1.3,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Arrow icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Color(0xff57636C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
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

  String _getGateDisplayName(String gateName) {
    // Format gate name for better readability
    if (gateName.toLowerCase().contains("tower")) {
      String formattedTowerName = "TOWER NO ";

      // Extract tower number if available
      RegExp regExp = RegExp(
        r'tower\s*(?:no\.?|number)?\s*(\d+)',
        caseSensitive: false,
      );
      var match = regExp.firstMatch(gateName.toLowerCase());

      if (match != null && match.group(1) != null) {
        formattedTowerName += match.group(1)!.padLeft(2, '0');
      } else {
        formattedTowerName = gateName.toUpperCase();
      }

      return formattedTowerName;
    }

    // Capitalize each word
    return gateName
        .split(' ')
        .map(
          (e) => e.isNotEmpty
              ? e[0].toUpperCase() + e.substring(1).toLowerCase()
              : '',
        )
        .join(' ');
  }

  String _getGateDescription(String gateName) {
    final lowerName = gateName.toLowerCase();

    if (lowerName.contains('main') || lowerName.contains('entrance')) {
      return 'Main entrance access point';
    } else if (lowerName.contains('tower')) {
      return 'Tower residential access';
    } else if (lowerName.contains('society') ||
        lowerName.contains('community')) {
      return 'Society community gate';
    } else if (lowerName.contains('parking')) {
      return 'Parking area access';
    } else if (lowerName.contains('exit')) {
      return 'Exit gate access';
    } else {
      return 'Gate access point';
    }
  }

  IconData _getGateIcon(String gateName) {
    final lowerName = gateName.toLowerCase();

    if (lowerName.contains('main') || lowerName.contains('entrance')) {
      return Icons.home;
    } else if (lowerName.contains('tower')) {
      return Icons.apartment;
    } else if (lowerName.contains('society') ||
        lowerName.contains('community')) {
      return Icons.location_city;
    } else if (lowerName.contains('parking')) {
      return Icons.local_parking;
    } else if (lowerName.contains('exit')) {
      return Icons.exit_to_app;
    } else {
      return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced drag handle
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),

          // Enhanced header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xffF44336).withOpacity(0.08),
                  const Color(0xffff5722).withOpacity(0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Compact icon section
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffF44336).withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.door_front_door,
                    color: Color(0xffF44336),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Simple label section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Select Gate',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff212427),
                              fontSize: 20,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose your gate to continue',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xff57636C),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Enhanced content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 16),
                itemCount: widget.gates.length,
                itemBuilder: (context, index) {
                  final gate = widget.gates[index];
                  final gateName = gate['gate_name'] ?? 'Unknown Gate';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          setState(() {
                            selectedIndex = index;
                          });

                          try {
                            final gateProvider = Provider.of<GateProvider>(
                              context,
                              listen: false,
                            );
                            await gateProvider.selectGate(index);
                            widget.onGateSelected(
                              Map<String, dynamic>.from(gate),
                            );
                          } catch (e) {
                            if (mounted) {
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(content: Text('Failed to select gate: $e')),
                              // );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Gate icon with background
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xffF44336,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getGateIcon(gateName),
                                  color: const Color(0xffF44336),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Gate information
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getGateDisplayName(gateName),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xff212427),
                                            fontSize: 18,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getGateDescription(gateName),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xff57636C),
                                            fontSize: 14,
                                            height: 1.3,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Arrow icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Color(0xff57636C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
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
            title: Text(context.tr('Location Permission Required')),
            content: Text(
              context.tr(
                  'Please enable location permissions in your device settings to use this feature.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cancel')),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: Text(context.tr('Open Settings')),
              ),
            ],
          ),
        );
      }
    }

    return false;
  }
}
