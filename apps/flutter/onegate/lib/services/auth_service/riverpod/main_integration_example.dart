import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_bloc/flutter_bloc.dart';

// Import existing OneGate dependencies
import '../../presentation/di/di.dart';
import '../../data/datasources/gate_storage.dart';
import '../../data/datasources/remote_datasource.dart';

// Import new Riverpod authentication system
import 'auth_controller.dart';
import 'auth_state.dart';
import 'riverpod_auth_integration.dart';

// Import existing providers and blocs
import '../../presentation/features/visitor_checkin_flow/purpose/provider/purposeProvider.dart';
import '../../presentation/features/visitor_log/visitorLogProvider.dart';
import '../../presentation/features/settings/pages/visitor_Settings_provider.dart';
import '../../presentation/features/gate_selection/ui/gate_selection_provider.dart';
import '../../presentation/features/settings/pages/camera_provider.dart';
import '../../approval_Status.dart';
import '../../common/internet_check_provider.dart';

final FlutterI18nDelegate _riverpodIntegrationExampleI18nDelegate =
    FlutterI18nDelegate(
  translationLoader: FileTranslationLoader(
    basePath: 'assets/flutter_i18n',
    fallbackFile: 'en',
    useCountryCode: false,
  ),
);

/// Example of how to integrate the new Riverpod authentication system
/// with the existing OneGate app structure
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize existing dependencies
  await setupLocator();
  await GateStorage().init();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    // Wrap the entire app with ProviderScope for Riverpod
    ProviderScope(
      child: const OneGateApp(),
    ),
  );
}

/// Main OneGate app with integrated Riverpod authentication
class OneGateApp extends ConsumerWidget {
  const OneGateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      fontSizeResolver: (num size, ScreenUtil _) => 0.5,
      enableScaleText: () => true,
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => provider.MultiProvider(
        providers: [
          // Keep existing Provider-based providers for gradual migration
          provider.ChangeNotifierProvider<PurposeProvider>(
            create: (_) => PurposeProvider(),
          ),
          provider.ChangeNotifierProvider<VisitorLogsProvider>(
            create: (_) => VisitorLogsProvider(),
          ),
          provider.ChangeNotifierProvider<VisitorSettingsProvider>(
            create: (_) => VisitorSettingsProvider(),
          ),
          provider.ChangeNotifierProvider<GateProvider>(
            create: (_) => GateProvider(),
          ),
          provider.ChangeNotifierProvider(
            create: (_) => InternetCheckProvider(),
          ),
          provider.ChangeNotifierProvider<CameraSettingsProvider>(
            create: (_) => CameraSettingsProvider(),
          ),
          provider.ChangeNotifierProvider<VisitorApprovalTimeProvider>(
            create: (_) => VisitorApprovalTimeProvider(),
          ),
          provider.ChangeNotifierProvider(
            create: (context) => TimerService(),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            // Keep existing BLoC providers
            // BlocProvider(create: (context) => ParcelBloc(RemoteDataSource())),
            // Add other BLoC providers as needed
          ],
          child: MaterialApp(
            onGenerateTitle: (ctx) => ctx.tr('appTitle'),
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
            ),
            localizationsDelegates: [
              AppLocalizations.delegate,
              _riverpodIntegrationExampleI18nDelegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('mr'),
            ],
            // Use the new Riverpod authentication wrapper
            home: const AuthenticatedOneGateHome(),
          ),
        ),
      ),
    );
  }
}

/// Home screen that handles authentication state with Riverpod
class AuthenticatedOneGateHome extends ConsumerWidget {
  const AuthenticatedOneGateHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      // User is not authenticated - show login screen
      unauthenticated: () => const OneGateLoginScreen(),
      
      // Authentication in progress - show loading
      loading: () => const OneGateLoadingScreen(),
      
      // User is authenticated - show main app
      authenticated: (tokens, userInfo) => const OneGateMainScreen(),
      
      // Authentication error - show error screen
      error: (message) => OneGateErrorScreen(message: message),
    );
  }
}

/// OneGate-specific login screen
class OneGateLoginScreen extends ConsumerWidget {
  const OneGateLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // OneGate Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Welcome text
                Text(
                  context.tr('Welcome to OneGate'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('Secure Visitor Management System'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final authController = ref.read(authControllerProvider.notifier);
                      final success = await authController.login();
                      
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr('Login failed. Please try again.'),
                            ),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.tr('Login with Keycloak SSO'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Additional info
                Text(
                  context.tr('Secure authentication powered by Keycloak'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// OneGate-specific loading screen
class OneGateLoadingScreen extends StatelessWidget {
  const OneGateLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DashboardLoaderIcon(),
            SizedBox(height: 16),
            Text(
              context.tr('Authenticating...'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// OneGate-specific error screen
class OneGateErrorScreen extends ConsumerWidget {
  final String message;
  
  const OneGateErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red.shade600,
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('Authentication Error'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final authController = ref.read(authControllerProvider.notifier);
                      await authController.login();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(context.tr('Retry Login')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main OneGate screen (placeholder - replace with your actual main screen)
class OneGateMainScreen extends ConsumerWidget {
  const OneGateMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('OneGate Dashboard')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          // Token refresh button (for debugging)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final authController = ref.read(authControllerProvider.notifier);
              await authController.refreshToken();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('Token refreshed')),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authController = ref.read(authControllerProvider.notifier);
              await authController.logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info card
            authState.maybeWhen(
              authenticated: (tokens, userInfo) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          'Welcome, {name}!',
                          params: {'name': '${userInfo['name'] ?? 'User'}'},
                        ),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          'Email: {value}',
                          params: {'value': '${userInfo['email'] ?? 'N/A'}'},
                        ),
                      ),
                      Text(
                        context.tr(
                          'Username: {value}',
                          params: {
                            'value': '${userInfo['preferred_username'] ?? 'N/A'}',
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Token expires: ${tokens.timeUntilExpiration?.inMinutes ?? 0} minutes',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 20),
            
            // Your existing OneGate content goes here
            Text(
              context.tr('OneGate Dashboard Content'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(
                'Replace this with your actual OneGate dashboard widgets. All API calls will automatically include authentication headers and handle token refresh transparently.',
              ),
            ),
            
            // Example of using the authenticated API service
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  final apiService = ref.read(apiServiceProvider);
                  final profile = await apiService.getUserProfile();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            'API call successful: {value}',
                            params: {'value': profile.toString()},
                          ),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            'API call failed: {error}',
                            params: {'error': '$e'},
                          ),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('Test Authenticated API Call')),
            ),
          ],
        ),
      ),
    );
  }
}
