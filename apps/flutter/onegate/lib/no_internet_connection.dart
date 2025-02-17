import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common/internet_check_provider.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No Internet Connection'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<InternetCheckProvider>().checkInternetAccess();
                onRetry?.call();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
