import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

/// Placeholder login page. Use app_intro Keycloak/native login in production.
class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(context.tr('Login'))),
    );
  }
}
