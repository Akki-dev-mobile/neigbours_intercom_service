import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String? userId;
  int? selectedSocietyId;

  @override
  void initState() {
    super.initState();
    initializeKeycloak();
    requestLocationPermission();
  }

  Future<void> requestLocationPermission() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      log("Location permission granted");
    } else if (status.isDenied) {
      log("Location permission denied");
    } else if (status.isPermanentlyDenied) {
      log("Location permission permanently denied. Redirecting to settings...");
      openAppSettings();
    }
  }

  Future<void> initializeKeycloak() async {
    try {
      keycloakWrapper.initialize();
      log("Keycloak initialized successfully");
    } catch (e) {
      log('Error initializing Keycloak: $e');
      _showSnackbar("Failed to initialize Keycloak: $e");
    }
  }

  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();

  Future<void> login(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      if (!keycloakWrapper.isInitialized) {
        log('Keycloak is not initialized');
        _showSnackbar("Keycloak is not initialized. Please try again.");
        return;
      }

      final isLoggedIn = await keycloakWrapper.login();

      if (keycloakWrapper.accessToken != null) {
        log('Login successful. Access Token: ${keycloakWrapper.accessToken}');

        final userInfo = await keycloakWrapper.getUserInfo();
        log('User Info: $userInfo');

        userId = userInfo?["old_sso_user_id"];

        final societies = await fetchSocieties(userId!);
        if (societies.isNotEmpty) {
          _showSocietySelection(context, societies);
        } else {
          _showSnackbar("No societies found for this user.");
        }
      } else {
        log('Login failed.');
        _showSnackbar("Login failed. Please try again.");
      }
    } catch (e) {
      log('Login error: $e');
      _showSnackbar("An error occurred during login: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<dynamic>> fetchSocieties(String userId) async {
    try {
      final response = await Dio().get(
        'http://192.168.1.34:8000/api/admin/companies/list/$userId',
      );

      if (response.statusCode == 200) {
        log('Societies fetched: ${response.data['data']}');
        return response.data['data'];
      } else {
        throw Exception('Failed to load societies');
      }
    } catch (e) {
      log('Error in fetchSocieties: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchGates(int societyId) async {
    try {
      final queryParams = {
        'company_id': societyId
      }; // Ensure `societyId` is an int
      final response = await Dio().get(
        'http://192.168.1.34:8000/api/admin/gates/list',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to load gates');
      }
    } catch (e) {
      log('Error fetching gates: $e');
      rethrow;
    }
  }

  void _showSocietySelection(BuildContext context, List<dynamic> societies) {
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
            const ListTile(title: Text('Select Society')),
            ...societies.map((society) {
              final societyId = society['company_id'];
              final societyName = society['company_name'];
              return ListTile(
                title: Text(societyName ?? 'Unknown Society'),
                onTap: () {
                  selectedSocietyId = societyId;
                  Navigator.pop(ctx);
                  _showRoleSelection(context);
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  void _showRoleSelection(BuildContext context) {
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
              onTap: () async {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminDashboardView()),
                );
                // Navigator.pop(ctx);
                // final gates = await fetchGates(selectedSocietyId!);
                // if (gates.isNotEmpty) {
                //   _showGateSelection(context, gates);
                // } else {
                //   _showSnackbar("No gates found for the selected society.");
                // }
              },
            ),
            ListTile(
              title: const Text('Gatekeeper'),
              onTap: () async {
                Navigator.pop(ctx);
                final gates = await fetchGates(selectedSocietyId!);
                if (gates.isNotEmpty) {
                  _showGateSelection(context, gates);
                } else {
                  _showSnackbar("No gates found for the selected society.");
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showGateSelection(BuildContext context, List<dynamic> gates) {
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
            const ListTile(title: Text('Select Gate')),
            ...gates.map((gate) {
              final gateName = gate['gate_name'] ?? 'Unknown Gate';
              return ListTile(
                title: Text(gateName),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => gateName == "Admin"
                          ? const AdminDashboardView()
                          : const GateDashboardView(),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
