import 'package:flutter/material.dart';

/// Placeholder login page. Use app_intro Keycloak/native login in production.
class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Login')),
    );
  }
}
