import 'dart:developer';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:http/http.dart' as http;

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
  const MyAppLogin({super.key});

  @override
  _MyAppLoginState createState() => _MyAppLoginState();
}

class _MyAppLoginState extends State<MyAppLogin> {
  @override
  void initState() {
    super.initState();
    initializeKeycloak();
  }

  void initializeKeycloak() {
    // Initialize the plugin at the start of your app.
    keycloakWrapper.initialize();
    // Listen to the errors caught by the plugin.
    keycloakWrapper.onError = (message, _, __) {
      // Display the error message inside a snackbar.
      scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    };
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          key: scaffoldMessengerKey,
          body: StreamBuilder<bool>(
            initialData: false,
            stream: keycloakWrapper.authenticationStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              } else if (snapshot.data!) {
                return const HomeScreen();
              } else {
                return const LoginScreen();
              }
            },
          ),
        ),
      );
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Login using the given configuration.
  Future<void> login() async {
    // Login using Keycloak wrapper
    final isLoggedIn = await keycloakWrapper.login();

    if (keycloakWrapper.accessToken != null) {
      log('Login successful, Access Token: ${keycloakWrapper.accessToken}');
      log('Login successful, Access Token: ${keycloakWrapper.accessToken}');
      log('Login successful Refresh Token: ${keycloakWrapper.refreshToken}');
      log('Login successful ID Token: ${keycloakWrapper.idToken}');
      log('Login successful User Info: ${await keycloakWrapper.getUserInfo()}');
    } else {
      log('Login failed');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: login,
            child: const Text('Login'),
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<List<dynamic>> fetchUserGroups() async {
    final realm = keycloakConfig.realm;
    final baseUrl = keycloakConfig.frontendUrl;
    const userId = '4a928944-dbd6-43b9-b581-c8bc4d78615c';
    final url = Uri.parse('$baseUrl/admin/realms/$realm/users/$userId/groups');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${keycloakWrapper.accessToken}',
    });

    if (response.statusCode == 200) {
      log('User groups: ${response.body}');
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load user groups ${response.statusCode}');
    }
  }

  Future<void> logout() async {
    await keycloakWrapper.logout();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.medium(
              title: const Text('Keycloak Example'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: logout,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: FutureBuilder(
                future: keycloakWrapper.getUserInfo(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (snapshot.hasData) {
                    final name = snapshot.data?['name'] ?? 'No name available';
                    return Center(child: Text('Hello, $name'));
                  } else {
                    return const Center(
                        child: Text('No user information available'));
                  }
                },
              ),
            ),
            FutureBuilder<List<dynamic>>(
              future: fetchUserGroups(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                } else if (snapshot.hasData) {
                  final groups = snapshot.data!;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = groups[index];
                        return ListTile(
                          title: Text(group['name'] ?? 'No name'),
                        );
                      },
                      childCount: groups.length,
                    ),
                  );
                } else {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No groups available')),
                  );
                }
              },
            ),
          ],
        ),
      );
}
