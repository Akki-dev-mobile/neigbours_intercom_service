import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'dart:developer';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/centralized_logout_service.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';
import 'package:flutter_onegate/main.dart';

/// Animated bottom sheet that appears when session expires
/// Provides a smooth user experience for session expiration scenarios
class SessionExpiredBottomSheet extends StatefulWidget {
  final String? errorMessage;
  final VoidCallback? onLoginComplete;

  const SessionExpiredBottomSheet({
    super.key,
    this.errorMessage,
    this.onLoginComplete,
  });

  @override
  State<SessionExpiredBottomSheet> createState() =>
      _SessionExpiredBottomSheetState();
}

class _SessionExpiredBottomSheetState extends State<SessionExpiredBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _iconController;
  late AnimationController _buttonController;

  late Animation<double> _slideAnimation;
  late Animation<double> _iconRotationAnimation;
  late Animation<double> _iconPulseAnimation;
  late Animation<double> _buttonScaleAnimation;

  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Slide animation for bottom sheet
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Icon animations
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Button animation
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Create animations
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    _iconRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.linear,
    ));

    _iconPulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeInOut,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _slideController.forward();
    _iconController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _iconController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _handleLoginAgain() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    // Button press animation
    await _buttonController.forward();
    await _buttonController.reverse();

    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      log("🚪 Session expired - starting centralized logout process");

      // Use centralized logout service for consistent behavior
      await CentralizedLogoutService.performLogoutWithNavigation(
        context: null, // Use global navigator for session expired modal
        source: 'Session Expired Modal',
        showNotifications: true,
        onComplete: () {
          log("✅ Session expired modal logout completed successfully");
          // Call completion callback if provided
          if (widget.onLoginComplete != null) {
            widget.onLoginComplete!();
          }
        },
      );
    } catch (e) {
      log("❌ Error during logout process: $e");
      setState(() {
        _isLoggingOut = false;
      });

      // Show error feedback
      HapticFeedback.heavyImpact();

      // Fallback: Try to navigate to login anyway
      try {
        await CentralizedLogoutService.navigateToLogin(
          null,
          source: 'Session Expired Modal (fallback)',
        );
      } catch (navError) {
        log("❌ Fallback navigation also failed: $navError");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button dismissal
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _slideAnimation.value) * 300),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Icon
                    _buildAnimatedIcon(),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Session Expired',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Message
                    Text(
                      widget.errorMessage ??
                          'Your session has expired for security reasons. Please log in again to continue.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Login Again Button
                    _buildLoginButton(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_iconRotationAnimation, _iconPulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _iconPulseAnimation.value,
          child: Transform.rotate(
            angle: _iconRotationAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.shade200,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.lock_clock,
                size: 40,
                color: Colors.red.shade600,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: _buttonScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonScaleAnimation.value,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoggingOut ? null : _handleLoginAgain,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.red.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: _isLoggingOut
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Logging out...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.login,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Login Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Show the session expired bottom sheet
/// This is the main entry point for displaying session expiration UI
Future<void> showSessionExpiredBottomSheet({
  String? errorMessage,
  VoidCallback? onLoginComplete,
}) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    log("⚠️ No context available for session expired bottom sheet");
    return;
  }

  log("🔒 Showing session expired bottom sheet");

  // Show the bottom sheet with modal behavior
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false, // Cannot be dismissed by tapping outside
    enableDrag: false, // Cannot be dismissed by swiping down
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor:
        Colors.black.withValues(alpha: 0.6), // Semi-transparent backdrop
    builder: (BuildContext context) {
      return SessionExpiredBottomSheet(
        errorMessage: errorMessage,
        onLoginComplete: onLoginComplete,
      );
    },
  );
}
