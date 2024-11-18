import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';

import '../../auth/pages/login_view.dart';

// Keycloak Configuration
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
    keycloakWrapper.initialize();
    keycloakWrapper.onError = (message, _, __) {
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

  // Method to login using Keycloak
  Future<void> login(BuildContext context) async {
    // Step 1: Perform Keycloak login
    final isLoggedIn = await keycloakWrapper.login();

    if (isLoggedIn && keycloakWrapper.accessToken != null) {
      log('Login successful. Access Token: ${keycloakWrapper.accessToken}');

      // Step 2: Fetch user information from Keycloak
      final userInfo = await keycloakWrapper.getUserInfo();
      log('User Info: $userInfo');

      // Step 3: Extract "Old SSO User ID" from userInfo
      int? oldSsoUserId;
      if (userInfo!.containsKey('old_sso_user_id')) {
        oldSsoUserId = int.tryParse(userInfo['old_sso_user_id'].toString());
      }

      // Check if `oldSsoUserId` is extracted successfully
      if (oldSsoUserId != null) {
        log('Extracted Old SSO User ID: $oldSsoUserId');

        // Navigate to the LoginView with the extracted `oldSsoUserId`
        if (context.mounted) {
          // RemoteDataSource.fetchGates;
          log('Extracted mounted Old SSO User ID: $oldSsoUserId');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginView(oldSsoUserId: oldSsoUserId),
            ),
          );
        }
      } else {
        log('Failed to extract Old SSO User ID');
        _showErrorSnackBar(context, 'Failed to extract Old SSO User ID');
      }
    } else {
      log('Keycloak login failed');
      _showErrorSnackBar(context, 'Keycloak login failed');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => login(context),
            child: const Text('Login with Keycloak'),
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Home Screen'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await keycloakWrapper.logout();
              },
            ),
          ],
        ),
        body: Center(
          child: const Text('Welcome! You are logged in.'),
        ),
      );
}
