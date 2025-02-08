import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_provider.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LoginProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Login",
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: provider.isLoading ? null : () => provider.login(),
                  child: provider.isLoading
                      ? CircularProgressIndicator()
                      : Text("Login"),
                ),
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(provider.error!,
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
