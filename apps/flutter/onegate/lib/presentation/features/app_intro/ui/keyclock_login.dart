import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/request_gate_access/ui/request_gate_access_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:lottie/lottie.dart';
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
  bool isSending = false;
  String? userId;
  int? selectedSocietyId;
  String? username;
  final gateStorage = GateStorage();

  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  @override
  void initState() {
    super.initState();
    initializeKeycloak();
    requestLocationPermission();
    checkLoginState();
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
        final accessToken = keycloakWrapper.accessToken!;
        log('Login successful. Access Token: $accessToken');

        final userInfo = await keycloakWrapper.getUserInfo();
        username = userInfo?["preferred_username"];
        userId = userInfo?["old_sso_user_id"];
        log("here i am ${userInfo?["old_sso_user_id"]}");
        await gateStorage.saveAccessToken(accessToken);
        await gateStorage.saveUserId(userInfo?["old_sso_user_id"] ?? "");
        await gateStorage.saveUsername(userInfo?["preferred_username"] ?? "");

        log('Access Token and user details stored in GateStorage.');

        final societies =
            await remoteDataSource.fetchSocieties(userInfo?["old_sso_user_id"]);
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

  Future<void> makeApiCall(String url) async {
    final token = gateStorage.getAccessToken();

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      print('Response: ${response.body}');
    } else {
      print('Error: ${response.statusCode}');
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

              if (societyId == null) {
                return const ListTile(
                  title: Text('Invalid Society'),
                  subtitle: Text('This entry has no valid ID'),
                );
              }

              return ListTile(
                title: Text(societyName ?? 'Unknown Society'),
                onTap: () async {
                  try {
                    // Show a loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    );

                    selectedSocietyId =
                        societyId; // Ensure this is the resolved ID
                    log("Selected Society ID: $selectedSocietyId");

                    await gateStorage.saveSocietyId(selectedSocietyId!);

                    log("Society ID saved successfully.");
                    Navigator.pop(context); // Close the loading dialog
                    Navigator.pop(ctx); // Close the bottom sheet

                    _showRoleSelection(context);
                  } catch (e) {
                    log("Error saving society ID: $e");
                    Navigator.pop(context); // Close the loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to save society ID'),
                      ),
                    );
                  }
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> checkLoginState() async {
    final accessToken = await gateStorage.getAccessToken();
    if (accessToken != null) {
      log("User is already logged in.");
      final userId = await gateStorage.getUserId();
      final username = await gateStorage.getUsername();
      final role = await gateStorage.getRole();
      final societyId = await gateStorage.getSocietyId();

      setState(() {
        this.userId = userId;
        this.username = username;
        this.selectedSocietyId = societyId;
      });

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminDashboardView(),
          ),
        );
      } else if (role == 'gatekeeper') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const GateDashboardView(),
          ),
        );
      } else {
        log("Unknown role. Redirecting to login.");
      }
    } else {
      log("User is not logged in. Showing login screen.");
    }
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
                await gateStorage.saveRole('admin');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminDashboardView()),
                );
              },
            ),
            ListTile(
              title: const Text('Gatekeeper'),
              onTap: () async {
                await gateStorage.saveRole('gatekeeper');
                Navigator.pop(ctx);
                final gates =
                    await remoteDataSource.fetchGates(selectedSocietyId!);
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
          children: gates.map((gate) {
            final gateName = gate['gate_name'] ?? 'Unknown Gate';
            return ListTile(
              title: Text(gateName),
              onTap: () async {
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
    return MyScrollView(
      isScrollable: false,
      hasBackButton: false,
      pageBody: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Lottie.network(
              'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/auth_Animation_fec8c8284d.json?updated_at=2023-08-23T06:28:49.839Z',
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
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.1,
            ),
            CustomLargeBtn(
              text: 'Login',
              onPressed: () {
                // _submitForm();
                login(context);
              },
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestGateAccess(),
                    ),
                  );
                },
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
            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }
}
