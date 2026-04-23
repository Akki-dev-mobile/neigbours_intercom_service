import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ToastType { success, error, warning, info }

class EnhancedToast {
  static OverlayEntry? _currentOverlayEntry;

  static void show(
    BuildContext context, {
    required String message,
    required ToastType type,
    Duration duration = const Duration(seconds: 3),
    String? title,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final appearance = _appearanceFor(type);
    _triggerHaptic(type);
    _removeExistingToast();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        title: title,
        appearance: appearance,
        duration: duration,
        onDismissed: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (identical(_currentOverlayEntry, entry)) {
            _currentOverlayEntry = null;
          }
        },
      ),
    );

    _currentOverlayEntry = entry;
    overlay.insert(entry);
  }

  static void _triggerHaptic(ToastType type) {
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
  }

  static void _removeExistingToast() {
    final entry = _currentOverlayEntry;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
    _currentOverlayEntry = null;
  }

  static void success(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.success,
      title: title,
      duration: duration,
    );
  }

  static void error(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: ToastType.error,
      title: title,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      title: title,
      duration: duration,
    );
  }

  static void info(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.info,
      title: title,
      duration: duration,
    );
  }

  static _ToastAppearance _appearanceFor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return const _ToastAppearance(
          backgroundColor: Color(0xFF10B981),
          iconColor: Color(0xFF059669),
          borderColor: Color(0xFF34D399),
          icon: Icons.check_circle_rounded,
        );
      case ToastType.error:
        return const _ToastAppearance(
          backgroundColor: Color(0xFFEF4444),
          iconColor: Color(0xFFDC2626),
          borderColor: Color(0xFFF87171),
          icon: Icons.error_rounded,
        );
      case ToastType.warning:
        return const _ToastAppearance(
          backgroundColor: Color(0xFFF59E0B),
          iconColor: Color(0xFFD97706),
          borderColor: Color(0xFFFBBF24),
          icon: Icons.warning_rounded,
        );
      case ToastType.info:
        return const _ToastAppearance(
          backgroundColor: Color(0xFF3B82F6),
          iconColor: Color(0xFF2563EB),
          borderColor: Color(0xFF60A5FA),
          icon: Icons.info_rounded,
        );
    }
  }
}

class _ToastAppearance {
  final Color backgroundColor;
  final Color iconColor;
  final Color borderColor;
  final IconData icon;

  const _ToastAppearance({
    required this.backgroundColor,
    required this.iconColor,
    required this.borderColor,
    required this.icon,
  });
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final _ToastAppearance appearance;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastWidget({
    required this.message,
    this.title,
    required this.appearance,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _animationController.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    final textColor = Colors.white;
    final iconBg = Colors.white.withValues(alpha: 0.2);
    final dismissBg = Colors.white.withValues(alpha: 0.2);

    return Positioned(
      top: MediaQuery.of(context).padding.top + (isTablet ? 20 : 16),
      left: isTablet ? 24 : 16,
      right: isTablet ? 24 : 16,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (_, __) {
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
                      color: widget.appearance.backgroundColor,
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      border: Border.all(
                        color: widget.appearance.borderColor,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.appearance.backgroundColor.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: isTablet ? 20 : 16,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: isTablet ? 8 : 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isTablet ? 40 : 32,
                          height: isTablet ? 40 : 32,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(
                              isTablet ? 20 : 16,
                            ),
                          ),
                          child: Icon(
                            widget.appearance.icon,
                            color: widget.appearance.iconColor,
                            size: isTablet ? 20 : 18,
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        Expanded(
                          child:
                              widget.title != null &&
                                  widget.title!.trim().isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title!,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: isTablet ? 16 : 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.message,
                                      style: TextStyle(
                                        color: textColor.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontSize: isTablet ? 14 : 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                        ),
                        SizedBox(width: isTablet ? 10 : 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            width: isTablet ? 32 : 28,
                            height: isTablet ? 32 : 28,
                            decoration: BoxDecoration(
                              color: dismissBg,
                              borderRadius: BorderRadius.circular(
                                isTablet ? 16 : 14,
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: textColor,
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
}
