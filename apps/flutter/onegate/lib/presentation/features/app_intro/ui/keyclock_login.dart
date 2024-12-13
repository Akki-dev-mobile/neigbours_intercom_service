import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:flutter/material.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

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
  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);
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
      isLoading = true; // Start showing a loader
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

        // Store the access token in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        log('Access Token stored in SharedPreferences.');

        final userInfo = await keycloakWrapper.getUserInfo();
        log('User Info: $userInfo');

        userId = userInfo?["old_sso_user_id"];
        GlobalUser.setsocId(userId ?? "");
        username = userInfo?["preferred_username"];

        // Fetch societies
        setState(() {
          isLoading = true; // Show loader while fetching societies
        });

        final societies = await remoteDataSource.fetchSocieties(userId!);

        if (societies.isNotEmpty) {
          // Societies found, show selection
          _showSocietySelection(context, societies);
        } else {
          // No societies found
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
        isLoading = false; // Stop showing the loader
      });
    }
  }

  Future<void> makeApiCall(String url) async {
    final token = keycloakWrapper.accessToken;

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

              print('Society ID: $societyId, Society Name: $societyName');
              return ListTile(
                title: Text(societyName ?? 'Unknown Society'),
                onTap: () {
                  selectedSocietyId = societyId;
                  if (societyId != null) {
                    GlobalUser.setUserId(societyId ?? "");
                    log("User ID set: $societyId");
                  }

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
                _preferenceUtils.setIsAdmin(true);
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
                Navigator.pop(ctx); // Close the role selection modal

                // Show loading dialog while fetching gates
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            const SizedBox(width: 16),
                            Text(
                              "Loading gates...",
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

                try {
                  final gates =
                      await remoteDataSource.fetchGates(selectedSocietyId!);

                  Navigator.pop(context); // Dismiss the loading dialog

                  if (gates.isNotEmpty) {
                    _showGateSelection(context, gates); // Show gate selection
                  } else {
                    _showSnackbar("No gates found for the selected society.");
                  }
                } catch (e) {
                  Navigator.pop(context); // Dismiss the loading dialog
                  log("Error fetching gates: $e");
                  _showSnackbar("Error fetching gates. Please try again.");
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
                onTap: () async {
                  setState(() {
                    isSending = true; // Show loader
                  });
                  await sendMesg(gateName, userId!, selectedSocietyId!);
                  setState(() {
                    isSending = false; // Hide loader
                  });
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

  Future<void> sendMesg(String gateName, String userId, int societyId) async {
    try {
      // Prepare the message as a JSON object
      Map<String, dynamic> message = {
        "user_name": gateName,
        "user_id": userId,
        "company_id": societyId,
      };

      // Log the message
      log("Sending message: $message");

      // RabbitMQ connection settings
      ConnectionSettings settings = ConnectionSettings(
        host: "65.1.230.119",
        // port: 5672,
        authProvider:
            const PlainAuthenticator("dinesh.koli", "7nqRG&I!FesI&7zCrii0"),
      );
      Client client = Client(settings: settings);

      // Publish the message
      Channel channel = await client.channel();
      Exchange exchange = await channel.exchange(
        "logs",
        ExchangeType.FANOUT,
        durable: false,
      );
      exchange.publish(
        message,
        null,
        properties: MessageProperties.persistentMessage()
          ..replyTo = 'approval_requests_8191',
      );

      log("Message sent successfully.");
    } catch (e) {
      log("Error sending message: $e");
      _showSnackbar("Failed to send message.");
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MyScrollView(
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
                        style:
                            Theme.of(context).textTheme.labelMedium!.copyWith(
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
        ),
        if (isLoading)
          Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

class GlobalUser {
  static int? userId;

  static void setUserId(int id) {
    userId = id;
  }

  static int? getUserId() {
    return userId;
  }

  static String? socId;
  static void setsocId(String id) {
    socId = id;
  }

  static String? getsocId() {
    return socId;
  }
}
