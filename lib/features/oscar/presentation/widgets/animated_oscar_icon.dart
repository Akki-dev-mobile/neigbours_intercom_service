import 'package:flutter/material.dart';

class AnimatedOscarIcon extends StatefulWidget {
  final double size;
  final bool showGlow;
  final double animationSpeed;

  const AnimatedOscarIcon({
    super.key,
    this.size = 24,
    this.showGlow = false,
    this.animationSpeed = 1.0,
  });

  @override
  State<AnimatedOscarIcon> createState() => _AnimatedOscarIconState();
}

class _AnimatedOscarIconState extends State<AnimatedOscarIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: Duration(
            milliseconds: (1000 / widget.animationSpeed).clamp(200, 4000).round(),
          ),
        )
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Icon(Icons.mic, size: widget.size),
    );
  }
}
