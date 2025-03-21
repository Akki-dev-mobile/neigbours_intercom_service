import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:lottie/lottie.dart';

class ErrorScreen extends StatelessWidget {
  final String? message;
  final String? errorCode;
  final VoidCallback? onRetry;
  final bool showHome;

  const ErrorScreen({
    Key? key,
    this.message,
    this.errorCode,
    this.onRetry,
    this.showHome = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Animation
              // Lottie.asset(
              //   'assets/animations/error.json',
              //   width: MediaQuery.of(context).size.width * 0.7,
              //   repeat: true,
              // ),
              const SizedBox(height: 32),

              // Error Message
              Text(
                message ?? 'Oops! Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                textAlign: TextAlign.center,
              ),

              if (errorCode != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Error Code: $errorCode',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],

              const SizedBox(height: 32),

              // Retry Button
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Home Button
              if (showHome)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const MyAppLogin(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Home'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
