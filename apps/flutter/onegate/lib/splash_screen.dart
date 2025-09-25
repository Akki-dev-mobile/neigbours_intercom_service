import 'dart:developer';
import 'dart:async';
import 'dart:math' show sin;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/missed_approval_two.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_widgets/common_widgets.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late final LoginService _loginService;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _loginService = LoginService(
      authService: GetIt.I<AuthService>(),
      gateStorage: GetIt.I<GateStorage>(),
      remoteDataSource: GetIt.I<RemoteDataSource>(),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    log('🚀 Starting splash screen initialization...');

    // Set a maximum timeout for the entire initialization process
    const maxInitializationTime = Duration(seconds: 10);

    try {
      // Start a timer to guarantee navigation after maximum time
      Timer(maxInitializationTime, () {
        if (mounted) {
          log('⏰ Maximum initialization time reached, forcing navigation to login');
          _navigateToLogin();
        }
      });

      // Step 1: Initialize core services with timeout
      log('📋 Step 1: Initializing core services...');
      await _initializeServicesWithTimeout();

      // Step 2: Initialize gate information (non-blocking)
      log('📋 Step 2: Initializing gate information...');
      _initializeGateInfoAsync(); // Run in background, don't wait

      // Step 3: Check login state and navigate
      log('📋 Step 3: Checking login state...');
      await _checkLoginStateWithTimeout();
    } catch (e) {
      log('💥 Critical initialization error: $e');
      log('📍 Stack trace: ${StackTrace.current}');
      _navigateToLogin();
    }
  }

  /// Initialize core services with timeout
  Future<void> _initializeServicesWithTimeout() async {
    try {
      await _loginService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log('⏰ Service initialization timed out, continuing anyway...');
          throw TimeoutException(
              'Service initialization timeout', const Duration(seconds: 5));
        },
      );
      log('✅ Core services initialized successfully');
    } catch (e) {
      log('⚠️ Service initialization failed: $e');
      // Continue anyway - we can still check stored credentials
      rethrow;
    }
  }

  /// Initialize gate information asynchronously (non-blocking)
  void _initializeGateInfoAsync() {
    // Run in background without blocking splash screen navigation
    _loginService.remoteDataSource
        .fetchAndUpdateGateInfo('splash_screen_initialization')
        .timeout(const Duration(seconds: 8))
        .then((_) {
      log('✅ Gate information initialized successfully in background');
    }).catchError((e) {
      log('⚠️ Background gate info initialization failed: $e');
      // This is OK - gate info can be fetched later when needed
    });
  }

  /// Check login state with timeout and enhanced error handling
  Future<void> _checkLoginStateWithTimeout() async {
    try {
      await _checkLoginState().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          log('⏰ Login state check timed out, navigating to login');
          _navigateToLogin();
          throw TimeoutException(
              'Login state check timeout', const Duration(seconds: 8));
        },
      );
    } catch (e) {
      log('💥 Login state check failed: $e');
      _navigateToLogin();
    }
  }

  Future<void> _checkLoginState() async {
    try {
      log('🔍 Checking stored access token...');
      final accessToken = await _loginService.gateStorage.getAccessToken();

      if (accessToken == null) {
        log("❌ User is not logged in - no access token found");
        await Future.delayed(const Duration(seconds: 2));
        _navigateToLogin();
        return;
      }

      log("✅ Access token found, checking user role...");
      final role = await _loginService.gateStorage.getRole();
      log("👤 User role: $role");

      await Future.delayed(const Duration(seconds: 2));
      _navigateBasedOnRole(role);
    } catch (e) {
      log('💥 Error checking login state: $e');
      log('📍 Stack trace: ${StackTrace.current}');
      await Future.delayed(const Duration(seconds: 2));
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (!mounted) {
      log('❌ Cannot navigate to login - widget not mounted');
      return;
    }

    try {
      log('🔄 Navigating to login screen...');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyAppLogin()),
      );
      log('✅ Successfully navigated to login screen');
    } catch (e) {
      log('💥 Failed to navigate to login: $e');
      log('📍 Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _navigateBasedOnRole(String? role) async {
    if (!mounted) {
      log('❌ Cannot navigate based on role - widget not mounted');
      return;
    }

    try {
      log('🎯 Processing role-based navigation for role: $role');

      // Add timeout for the entire navigation process
      await _performRoleBasedNavigation(role).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log('⏰ Role-based navigation timed out, falling back to login');
          _navigateToLogin();
          throw TimeoutException(
              'Role-based navigation timeout', const Duration(seconds: 5));
        },
      );
    } catch (e, stackTrace) {
      log('💥 Error during role-based navigation: $e');
      log('📍 Stack trace: $stackTrace');
      _showError('Failed to navigate based on role: $e');
      // Always have a fallback
      _navigateToLogin();
    }
  }

  Future<void> _performRoleBasedNavigation(String? role) async {
    final prefs = await SharedPreferences.getInstance();
    bool hasNavigatedToGateSettings =
        prefs.getBool('hasNavigatedToGateSettings') ?? false;

    final selectedGateName = prefs.getString('selected_gate') ?? '';
    final cleanedGateName = selectedGateName.toLowerCase();

    Widget? destination;

    if (role == 'admin') {
      log('📊 Admin role detected - navigating to admin dashboard');
      destination = const AdminDashboardView();
    } else if (role == 'gatekeeper') {
      log('🚪 Gatekeeper role detected');
      if (cleanedGateName.contains("tower")) {
        String formattedTowerName = "TOWER NO ";
        RegExp regExp =
            RegExp(r'tower\s*(?:no\.?|number)?\s*(\d+)', caseSensitive: false);
        var match = regExp.firstMatch(cleanedGateName);

        if (match != null && match.group(1) != null) {
          formattedTowerName += match.group(1)!.padLeft(2, '0');
        } else {
          formattedTowerName = selectedGateName.toUpperCase();
        }

        await prefs.setString('selected_gate', formattedTowerName);

        destination = MissedApprovalsScreen2(
          remoteDataSource: RemoteDataSource(),
          towerName: formattedTowerName,
        );

        log('🏢 Auto-navigating to tower: $formattedTowerName');
      } else {
        // If not tower, check if already went to visitor settings
        if (!hasNavigatedToGateSettings) {
          log('⚙️ First time gatekeeper - navigating to visitor settings');
          destination = VisitorSettingsView(comingfrom: true);
          await prefs.setBool('hasNavigatedToGateSettings', true);
        } else {
          log('🏠 Returning gatekeeper - navigating to gate dashboard');
          destination = const GateDashboardView();
        }
      }
    } else {
      log('❓ Unknown or null role: $role - defaulting to login');
      _navigateToLogin();
      return;
    }

    log('🚀 Navigating to $role -> ${destination.runtimeType}');
    if (mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination!),
      );
      log('✅ Navigation to ${destination.runtimeType} completed successfully');
    } else {
      log('❌ Context no longer mounted during navigation');
      // Context became unmounted, but we can't do much here
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(message)),
    // );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      isScrollable: false,
      hasBackButton: false,
      pageBody: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // SizedBox(height: MediaQuery.of(context).size.height / 10),

            FadeTransition(
              opacity: _animation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.asset(
                    'assets/media/images/oneapp_logo.png',
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height / 20),
            Text(
              AppLocalizations.of(context)!.welcomeToOnegate,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            // Gate Loading Animation
            const _SplashGateLoader(),
          ],
        ),
      ),
    );
  }
}

class _SplashGateLoader extends StatefulWidget {
  const _SplashGateLoader();

  @override
  State<_SplashGateLoader> createState() => _SplashGateLoaderState();
}

class _SplashGateLoaderState extends State<_SplashGateLoader>
    with TickerProviderStateMixin {
  late AnimationController _gateController;
  late AnimationController _iconController;
  late AnimationController _dotsController;

  late Animation<double> _gateAnimation;
  late Animation<double> _iconAnimation;
  late Animation<double> _dotsAnimation;

  @override
  void initState() {
    super.initState();

    // Gate animation controller
    _gateController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Icon rotation controller
    _iconController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Dots animation controller
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Gate opening/closing animation
    _gateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gateController,
      curve: Curves.easeInOut,
    ));

    // Icon rotation animation
    _iconAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.linear,
    ));

    // Dots staggered animation
    _dotsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dotsController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _gateController.repeat(reverse: true);
    _iconController.repeat();
    _dotsController.repeat();
  }

  @override
  void dispose() {
    _gateController.dispose();
    _iconController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Gate Animation
        AnimatedBuilder(
          animation: Listenable.merge([_gateAnimation, _iconAnimation]),
          builder: (context, child) {
            final gateOffset = _gateAnimation.value * 20;

            return SizedBox(
              width: 100,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left gate door
                  Positioned(
                    left: 15 - gateOffset,
                    top: 8,
                    child: Container(
                      width: 6,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Right gate door
                  Positioned(
                    right: 15 - gateOffset,
                    top: 8,
                    child: Container(
                      width: 6,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Center rotating gate icon
                  Transform.rotate(
                    angle: _iconAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xffF44336),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.sensor_door,
                        color: Color(0xffF44336),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Loading Dots
        AnimatedBuilder(
          animation: _dotsAnimation,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final animationValue =
                    (_dotsAnimation.value - delay).clamp(0.0, 1.0);
                final opacity =
                    (sin(animationValue * 3.14159) * 0.5 + 0.5).clamp(0.3, 1.0);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),

        const SizedBox(height: 16),

        const Text(
          'Loading...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
