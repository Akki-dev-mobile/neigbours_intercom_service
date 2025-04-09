import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/keycloack_config.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/missed_approval_two.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_widgets/common_widgets.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late final LoginService _loginService;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _loginService = LoginService(
      keycloakWrapper:
          KeycloakWrapper(config: KeycloakConfigManager.getConfig()),
      gateStorage: GateStorage(),
      remoteDataSource: RemoteDataSource(),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loginService.initialize();
      await _checkLoginState();
    } catch (e) {
      log('Initialization error: $e');
      _navigateToLogin();
    }
  }

  Future<void> _checkLoginState() async {
    try {
      final accessToken = await _loginService.gateStorage.getAccessToken();
      if (accessToken == null) {
        log("User is not logged in");
        await Future.delayed(const Duration(seconds: 2));
        _navigateToLogin();
        return;
      }

      final role = await _loginService.gateStorage.getRole();
      await Future.delayed(const Duration(seconds: 2));
      _navigateBasedOnRole(role);
    } catch (e) {
      log('Error checking login state: $e');
      await Future.delayed(const Duration(seconds: 2));
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MyAppLogin()),
    );
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
          RegExp regExp = RegExp(r'tower\s*(?:no\.?|number)?\s*(\d+)', caseSensitive: false);
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
        }else {
          // If not tower, check if already went to visitor settings
          if (!hasNavigatedToGateSettings) {
            destination = VisitorSettingsView(comingfrom: true);
            await prefs.setBool('hasNavigatedToGateSettings', true);
          } else {
            destination = GateDashboardView();
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
  void _showError(String message) {
    if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(message)),
    // );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      isScrollable: false,
      hasBackButton: false,
      pageBody: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // SizedBox(height: MediaQuery.of(context).size.height / 10),

            FadeTransition(
              opacity: _animation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.asset(
                    'assets/media/images/oneapp_logo.png',
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height / 20),
            const Text(
              'Welcome to OneGate',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            // const CircularProgressIndicator(
            //   valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            // ),
          ],
        ),
      ),
    );
  }
}
