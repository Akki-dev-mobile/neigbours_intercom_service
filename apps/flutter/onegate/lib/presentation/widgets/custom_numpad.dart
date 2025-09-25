import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enhanced NumPad widget that follows the design specs
class EnhancedNumPad extends StatefulWidget {
  /// Callback when a digit is pressed
  final Function(String) onType;

  /// Optional widget to show on the right bottom position (usually a submit button)
  final Widget? rightWidget;

  /// Text style for the number buttons
  final TextStyle? numberStyle;

  /// The size of each button
  final double buttonSize;

  /// Border radius of each button
  final double radius;

  /// Whether this is for tablet
  final bool isTablet;

  const EnhancedNumPad({
    super.key,
    required this.onType,
    this.rightWidget,
    this.numberStyle,
    this.buttonSize = 48.0,
    this.radius = 24.0,
    this.isTablet = false,
  });

  @override
  State<EnhancedNumPad> createState() => _EnhancedNumPadState();
}

class _EnhancedNumPadState extends State<EnhancedNumPad> {
  int _pressedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        // Handle special cases
        if (index == 9) {
          // Bottom left (delete/backspace)
          return _buildBackspace();
        } else if (index == 10) {
          // Bottom center (0)
          return _buildNumberKey('0', 10);
        } else if (index == 11) {
          // Bottom right (submit)
          return widget.rightWidget ?? const SizedBox.shrink();
        } else {
          // Regular numbers 1-9
          return _buildNumberKey((index + 1).toString(), index);
        }
      },
    );
  }

  Widget _buildNumberKey(String number, int index) {
    bool isPressed = _pressedIndex == index;

    return GestureDetector(
      onTap: () {
        // Trigger animation immediately on single tap
        setState(() {
          _pressedIndex = index;
        });
        widget.onType(number);
        HapticFeedback.lightImpact(); // Tactile feedback

        // Reset animation after a short delay
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _pressedIndex = -1;
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        height: widget.buttonSize,
        width: widget.buttonSize,
        decoration: BoxDecoration(
          color: isPressed
              ? const Color(0xFFD1D5DB) // Darker grey when pressed
              : const Color(0xFFF3F4F6), // Light grey when not pressed
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isPressed
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isPressed ? 6 : 2,
              offset: Offset(0, isPressed ? 2 : 1),
              spreadRadius: isPressed ? 0.5 : 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Ripple effect
            if (isPressed)
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 200),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withOpacity(0.2 * (1 - value)),
                        width: 1.5 * value,
                      ),
                    ),
                  );
                },
              ),
            // Scale animation with enhanced feedback
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 150),
              tween: Tween(begin: 1.0, end: isPressed ? 0.85 : 1.0),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPressed
                          ? Colors.black.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        number,
                        style: widget.numberStyle ??
                            TextStyle(
                              fontSize: widget.isTablet
                                  ? 36
                                  : 32, // Further increased font size
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackspace() {
    return GestureDetector(
      onTap: () {
        // Trigger animation immediately on single tap
        setState(() {
          _pressedIndex = -2; // Special index for backspace
        });
        widget.onType('-'); // Special character to indicate backspace
        HapticFeedback.lightImpact();

        // Reset animation after a short delay
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _pressedIndex = -1;
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        height: widget.buttonSize,
        width: widget.buttonSize,
        decoration: BoxDecoration(
          color: _pressedIndex == -2
              ? const Color(0xFFD1D5DB) // Darker grey when pressed
              : const Color(0xFFF3F4F6), // Light grey when not pressed
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _pressedIndex == -2
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _pressedIndex == -2 ? 6 : 2,
              offset: Offset(0, _pressedIndex == -2 ? 2 : 1),
              spreadRadius: _pressedIndex == -2 ? 0.5 : 0,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_rounded,
            color: Color(0xFF6B7280),
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Enhanced submit button for the numpad
class EnhancedSubmitButton extends StatefulWidget {
  /// Callback when button is pressed
  final VoidCallback onPressed;

  /// Icon to display in the button
  final IconData icon;

  /// Size of the button
  final double size;

  /// Background color of the button
  final Color color;

  const EnhancedSubmitButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.size = 48.0,
    this.color = const Color(0xFF22C55E),
  });

  @override
  State<EnhancedSubmitButton> createState() => _EnhancedSubmitButtonState();
}

class _EnhancedSubmitButtonState extends State<EnhancedSubmitButton>
    with SingleTickerProviderStateMixin {
  // The _isPressed value is used via the _controller animation
  // ignore: unused_field
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onPressed();
        HapticFeedback.mediumImpact();
      },
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
        _controller.reverse();
      },
      borderRadius: BorderRadius.circular(widget.size / 2),
      splashColor: Colors.white.withOpacity(0.3),
      highlightColor: Colors.white.withOpacity(0.2),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        },
        child: Container(
          height: widget.size,
          width: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
