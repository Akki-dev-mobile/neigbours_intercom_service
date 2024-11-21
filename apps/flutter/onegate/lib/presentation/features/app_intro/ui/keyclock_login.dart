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

class MyAppLogin extends StatefulWidget {
  const MyAppLogin({Key? key}) : super(key: key);

  @override
  State<MyAppLogin> createState() => _MyAppLoginState();
}

class _MyAppLoginState extends State<MyAppLogin> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    initializeKeycloak();
  }

  Future<void> initializeKeycloak() async {
    try {
      keycloakWrapper.initialize();
    } catch (e) {
      log('Error initializing Keycloak: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to initialize Keycloak: $e")),
      );
    }
  }

  Future<void> login(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      if (!keycloakWrapper.isInitialized) {
        log('Keycloak is not initialized');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Keycloak is not initialized. Please try again.")),
        );
        return;
      }

      final isLoggedIn = await keycloakWrapper.login();

      if (keycloakWrapper.accessToken != null) {
        log('Login successful. Access Token: ${keycloakWrapper.accessToken}');

        // Fetch user info
        final userInfo = await keycloakWrapper.getUserInfo();
        log('User Info: $userInfo');

        // Handle navigation based on user roles or other data
        final groupAccessRaw = userInfo?['group_access'] ?? '{}';
        final groupAccess = json.decode(groupAccessRaw) as Map<String, dynamic>;

        handleNavigation(context, userInfo, groupAccess);
      } else {
        log('Login failed.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed. Please try again.")),
        );
      }
    } catch (e) {
      log('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred during login: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void handleNavigation(BuildContext context, Map<String, dynamic>? userInfo,
      Map<String, dynamic> groupAccess) {
    _roleSelectionBottomSheet(context);
  }

  void _roleSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Select Role')),
            ListTile(
              title: const Text('Admin'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminDashboardView()),
                );
              },
            ),
            ListTile(
              title: const Text('Gatekeeper'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GateDashboardView()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keycloak Login')),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Press Login to authenticate',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => login(context),
                    child: const Text('Login'),
                  ),
                ],
              ),
      ),
    );
  }
}
