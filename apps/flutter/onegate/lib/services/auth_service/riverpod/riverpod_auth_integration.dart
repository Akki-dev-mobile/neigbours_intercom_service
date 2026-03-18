import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import 'auth_interceptor.dart';
import 'auth_state.dart';

/// Provider for Dio instance with authentication interceptor
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();

  // Configure Dio
  dio.options.connectTimeout = const Duration(seconds: 30);
  dio.options.receiveTimeout = const Duration(seconds: 30);
  dio.options.sendTimeout = const Duration(seconds: 30);

  // Add authentication interceptor
  dio.interceptors.add(AuthInterceptorFactory.create(ref));

  // Add logging interceptor in debug mode
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (object) => debugPrint('🌐 API: $object'),
    ));
  }

  return dio;
});

/// Provider for API service with automatic authentication
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});

/// Example API service that uses authenticated Dio
class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  /// Example API call that will automatically include authentication
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await _dio.get('/api/user/profile');
    return response.data;
  }

  /// Example API call with error handling
  Future<List<dynamic>> getVisitors() async {
    try {
      final response = await _dio.get('/api/visitors');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // This will be handled automatically by the interceptor
        rethrow;
      }
      throw Exception('Failed to fetch visitors: ${e.message}');
    }
  }

  /// Example POST request
  Future<Map<String, dynamic>> createVisitor(
      Map<String, dynamic> visitorData) async {
    final response = await _dio.post('/api/visitors', data: visitorData);
    return response.data;
  }
}

/// Widget that demonstrates authentication state handling
class AuthStateWidget extends ConsumerWidget {
  final Widget child;

  const AuthStateWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      unauthenticated: () => const LoginScreen(),
      loading: () => const LoadingScreen(),
      authenticated: (tokens, userInfo) => child,
      error: (message) => ErrorScreen(message: message),
    );
  }
}

/// Login screen widget
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Please log in to continue',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final authController =
                    ref.read(authControllerProvider.notifier);
                final success = await authController.login();

                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Login failed. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Login with Keycloak'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading screen widget
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DashboardLoaderIcon(),
            SizedBox(height: 16),
            Text('Authenticating...'),
          ],
        ),
      ),
    );
  }
}

/// Error screen widget
class ErrorScreen extends ConsumerWidget {
  final String message;

  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Authentication Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final authController =
                    ref.read(authControllerProvider.notifier);
                await authController.login();
              },
              child: const Text('Retry Login'),
            ),
          ],
        ),
      ),
    );
  }
}

/// User profile widget that shows authenticated user info
class UserProfileWidget extends ConsumerWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.maybeWhen(
      authenticated: (tokens, userInfo) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${userInfo['name'] ?? 'User'}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Email: ${userInfo['email'] ?? 'N/A'}'),
                Text('Username: ${userInfo['preferred_username'] ?? 'N/A'}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final authController =
                            ref.read(authControllerProvider.notifier);
                        await authController.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final authController =
                            ref.read(authControllerProvider.notifier);
                        await authController.refreshToken();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Token refreshed successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Refresh Token'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Example of how to use the authentication system in your main app
class AuthenticatedApp extends ConsumerWidget {
  const AuthenticatedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'OneGate Authenticated App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: AuthStateWidget(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('OneGate Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  final authController =
                      ref.read(authControllerProvider.notifier);
                  await authController.refreshToken();
                },
              ),
            ],
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                UserProfileWidget(),
                SizedBox(height: 20),
                // Add your other widgets here
                Text('Your authenticated content goes here...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
