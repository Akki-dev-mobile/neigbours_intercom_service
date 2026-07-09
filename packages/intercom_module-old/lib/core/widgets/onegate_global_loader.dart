import 'package:flutter/material.dart';

/// Inline (non-Scaffold) version of the OneGate global loader.
/// Safe to embed inside existing layouts.
class OneGateGlobalLoader extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isTablet;

  const OneGateGlobalLoader({
    super.key,
    required this.title,
    required this.subtitle,
    this.isTablet = false,
  });

  @override
  State<OneGateGlobalLoader> createState() => _OneGateGlobalLoaderState();
}

class _OneGateGlobalLoaderState extends State<OneGateGlobalLoader>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.isTablet || MediaQuery.of(context).size.width > 600;

    // Material ancestor required for Text/Icon in dialog overlays (avoids yellow underlines).
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 40 : 32),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 40 : 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: isTablet ? 120 : 100,
                  height: isTablet ? 120 : 100,
                  child: OneGateGateAnimation(
                    controller: _controller,
                    size: isTablet ? 120 : 100,
                    isTablet: isTablet,
                  ),
                ),
                SizedBox(height: isTablet ? 32 : 24),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: const Color(0xff212427),
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: isTablet ? 12 : 8),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: const Color(0xff57636C),
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact gate-only loader for inline usage.
class OneGateGlobalLoaderIcon extends StatelessWidget {
  final double size;

  const OneGateGlobalLoaderIcon({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return _InlineGateLoadingAnimation(size: size, isTablet: isTablet);
  }
}

class _InlineGateLoadingAnimation extends StatefulWidget {
  final double size;
  final bool isTablet;

  const _InlineGateLoadingAnimation({
    required this.size,
    required this.isTablet,
  });

  @override
  State<_InlineGateLoadingAnimation> createState() =>
      _InlineGateLoadingAnimationState();
}

class _InlineGateLoadingAnimationState
    extends State<_InlineGateLoadingAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final size = widget.size;
        return OneGateGateAnimation(
          controller: _controller,
          size: size,
          isTablet: widget.isTablet,
        );
      },
    );
  }
}

class OneGateGateAnimation extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final bool isTablet;

  const OneGateGateAnimation({
    super.key,
    required this.controller,
    required this.size,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final gateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    final rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          ),
          child: Stack(
            children: [
              // Left gate door
              Positioned(
                left: 0,
                top: isTablet ? 20 : 16,
                bottom: isTablet ? 20 : 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width:
                      (isTablet ? 40 : 32) -
                      (gateAnimation.value * (isTablet ? 15 : 12)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xffF44336), Color(0xffD32F2F)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isTablet ? 8 : 6),
                      bottomLeft: Radius.circular(isTablet ? 8 : 6),
                      topRight: Radius.circular(isTablet ? 4 : 3),
                      bottomRight: Radius.circular(isTablet ? 4 : 3),
                    ),
                  ),
                ),
              ),
              // Right gate door
              Positioned(
                right: 0,
                top: isTablet ? 20 : 16,
                bottom: isTablet ? 20 : 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width:
                      (isTablet ? 40 : 32) -
                      (gateAnimation.value * (isTablet ? 15 : 12)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xffF44336), Color(0xffD32F2F)],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(isTablet ? 8 : 6),
                      bottomRight: Radius.circular(isTablet ? 8 : 6),
                      topLeft: Radius.circular(isTablet ? 4 : 3),
                      bottomLeft: Radius.circular(isTablet ? 4 : 3),
                    ),
                  ),
                ),
              ),
              // Center gate icon
              Center(
                child: Transform.rotate(
                  angle: rotationAnimation.value * 2 * 3.14159,
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: isTablet ? 8 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.sensor_door_rounded,
                      color: const Color(0xffF44336),
                      size: isTablet ? 32 : 24,
                    ),
                  ),
                ),
              ),
              // Loading dots indicator
              Positioned(
                bottom: isTablet ? 8 : 6,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      margin: EdgeInsets.symmetric(
                        horizontal: isTablet ? 3 : 2,
                      ),
                      width: isTablet ? 8 : 6,
                      height: isTablet ? 8 : 6,
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(
                          0.3 +
                              ((controller.value + (index * 0.3)) % 1.0) * 0.7,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
