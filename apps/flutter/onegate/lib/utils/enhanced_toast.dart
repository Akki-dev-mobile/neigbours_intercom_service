import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EnhancedToast {
  static void show({
    required BuildContext context,
    required String message,
    required ToastType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Haptic feedback based on toast type
    switch (type) {
      case ToastType.success:
        HapticFeedback.lightImpact();
        break;
      case ToastType.error:
        HapticFeedback.heavyImpact();
        break;
      case ToastType.warning:
        HapticFeedback.mediumImpact();
        break;
      case ToastType.info:
        HapticFeedback.selectionClick();
        break;
    }

    // Remove any existing toast
    _removeExistingToast(context);

    // Create overlay entry
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    // Insert overlay
    overlay.insert(overlayEntry);

    // Auto dismiss after duration
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static void _removeExistingToast(BuildContext context) {
    // Note: Overlay entries are managed automatically by Flutter
    // This method is kept for future extensibility
  }

  // Convenience methods
  static void success(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.info);
  }
}

enum ToastType { success, error, warning, info }

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Positioned(
      top: MediaQuery.of(context).padding.top + (isTablet ? 20 : 16),
      left: isTablet ? 24 : 16,
      right: isTablet ? 24 : 16,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 100),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _dismiss,
                  onPanEnd: (details) {
                    if (details.velocity.pixelsPerSecond.dy < -500) {
                      _dismiss();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 16 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: _getBackgroundColor(),
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: _getShadowColor(),
                          blurRadius: isTablet ? 20 : 16,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: isTablet ? 8 : 6,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: _getBorderColor(),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon container
                        Container(
                          width: isTablet ? 40 : 32,
                          height: isTablet ? 40 : 32,
                          decoration: BoxDecoration(
                            color: _getIconBackgroundColor(),
                            borderRadius:
                                BorderRadius.circular(isTablet ? 20 : 16),
                          ),
                          child: Icon(
                            _getIcon(),
                            color: _getIconColor(),
                            size: isTablet ? 20 : 18,
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        // Message text
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: _getTextColor(),
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        // Dismiss button
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            width: isTablet ? 32 : 28,
                            height: isTablet ? 32 : 28,
                            decoration: BoxDecoration(
                              color: _getDismissButtonColor(),
                              borderRadius:
                                  BorderRadius.circular(isTablet ? 16 : 14),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: _getDismissIconColor(),
                              size: isTablet ? 18 : 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF10B981);
      case ToastType.error:
        return const Color(0xFFEF4444);
      case ToastType.warning:
        return const Color(0xFFF59E0B);
      case ToastType.info:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getShadowColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF10B981).withOpacity(0.3);
      case ToastType.error:
        return const Color(0xFFEF4444).withOpacity(0.3);
      case ToastType.warning:
        return const Color(0xFFF59E0B).withOpacity(0.3);
      case ToastType.info:
        return const Color(0xFF3B82F6).withOpacity(0.3);
    }
  }

  Color _getBorderColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF059669);
      case ToastType.error:
        return const Color(0xFFDC2626);
      case ToastType.warning:
        return const Color(0xFFD97706);
      case ToastType.info:
        return const Color(0xFF2563EB);
    }
  }

  Color _getIconBackgroundColor() {
    return Colors.white.withOpacity(0.2);
  }

  Color _getIconColor() {
    return Colors.white;
  }

  Color _getTextColor() {
    return Colors.white;
  }

  Color _getDismissButtonColor() {
    return Colors.white.withOpacity(0.2);
  }

  Color _getDismissIconColor() {
    return Colors.white;
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }
}
