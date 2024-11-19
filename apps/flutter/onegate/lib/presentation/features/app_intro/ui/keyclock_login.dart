import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';

final keycloakConfig = KeycloakConfig(
  bundleIdentifier: 'com.cubeonebiz.gate',
  clientId: 'onegate-sso',
  frontendUrl: 'https://stgsso.cubeone.in',
  realm: 'fstech',
  clientSecret: 'zXpmFL8WzkDoL379FesFl2pgm8vxPa58',
);

final keycloakWrapper = KeycloakWrapper(config: keycloakConfig);
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyAppLogin extends StatefulWidget {
  static int userId = 0;

  const MyAppLogin({super.key});

  @override
  _MyAppLoginState createState() => _MyAppLoginState();
}

class _MyAppLoginState extends State<MyAppLogin> {
  String statusMessage = "Press Login to authenticate";

  @override
  void initState() {
    super.initState();
    initializeKeycloak();
  }

  void initializeKeycloak() {
    keycloakWrapper.initialize();
    keycloakWrapper.onError = (message, _, __) {
      scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    };
  }

  Future<void> login() async {
    try {
      final isLoggedIn = await keycloakWrapper.login();

      if (keycloakWrapper.accessToken != null) {
        log('Login successful. Access Token: ${keycloakWrapper.accessToken}');

        // Fetch user information
        final userInfo = await keycloakWrapper.getUserInfo();
        log('User Info: $userInfo');

        // Parse and process group access
        final groupAccessRaw = userInfo?['group_access'] ?? '{}';
        final groupAccess = json.decode(groupAccessRaw) as Map<String, dynamic>;

        bool isMaster = false;
        bool isGatekeeper = false;

        groupAccess.forEach((key, value) {
          final roles = (value['vizlog'] ?? '').split(',');
          if (roles.contains('master')) isMaster = true;
          if (roles.contains('gatekeeper')) isGatekeeper = true;
        });

        // Navigate based on roles
        if (isMaster) {
          navigateToAdminDashboard();
        } else if (isGatekeeper) {
          navigateToGatekeeperDashboard();
        } else {
          showGateSelectionBottomSheet(context);
        }

        // Update state with user ID
        setState(() {
          MyAppLogin.userId =
              int.tryParse(userInfo?['old_sso_user_id']?.toString() ?? '0') ??
                  0;
          statusMessage = "Welcome, User ID: ${MyAppLogin.userId}";
        });
      } else {
        setState(() {
          statusMessage = "Login failed. Please try again.";
        });
        log('Login failed');
      }
    } catch (e) {
      setState(() {
        statusMessage = "An error occurred during login: $e";
      });
      log('Login error: $e');
    }
  }

  void navigateToAdminDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboardView()),
    );
  }

  void navigateToGatekeeperDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GateDashboardView()),
    );
  }

  void showGateSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select your gate',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  // Replace this with your dynamic list of gates
                  ListTile(
                    title: const Text('Gate 1'),
                    subtitle: const Text('Enable/Disable Gate 1'),
                    onTap: () {
                      Navigator.pop(context);
                      log("Gate 1 Selected");
                    },
                  ),
                  ListTile(
                    title: const Text('Gate 2'),
                    subtitle: const Text('Enable/Disable Gate 2'),
                    onTap: () {
                      Navigator.pop(context);
                      log("Gate 2 Selected");
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Keycloak Login')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: login,
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
}
