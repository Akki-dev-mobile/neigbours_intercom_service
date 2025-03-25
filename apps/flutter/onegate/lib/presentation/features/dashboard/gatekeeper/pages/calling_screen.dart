import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CallingScreen extends StatelessWidget {
  final String memberName;
  final String phoneNumber;

  const CallingScreen({
    Key? key,
    required this.memberName,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Profile Avatar
              Hero(
                tag: 'member_avatar',
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    memberName.isNotEmpty ? memberName[0].toUpperCase() : '-',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                  ),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.easeOutBack)
                    .fade(duration: 600.ms),
              ),

              const SizedBox(height: 24),

              // Member Name
              Text(
                memberName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              )
                  .animate()
                  .moveY(begin: 20, end: 0, duration: 500.ms)
                  .fade(duration: 500.ms),

              const SizedBox(height: 8),

              // Phone Number
              Text(
                phoneNumber,
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                ),
              )
                  .animate()
                  .moveY(begin: 20, end: 0, duration: 500.ms, delay: 200.ms)
                  .fade(duration: 500.ms, delay: 200.ms),

              const SizedBox(height: 40),

              // Calling Indicator
              const Text(
                "Calling...",
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
              )
                  .animate(
                      onPlay: (controller) => controller.repeat(reverse: true))
                  .fadeIn(duration: 1000.ms)
                  .then()
                  .fade(duration: 1000.ms),

              const SizedBox(height: 40),

              // Animated Progress Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ).animate().scale(duration: 600.ms).fade(duration: 600.ms),

              const SizedBox(height: 60),

              // Hang Up Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  elevation: 6,
                ),
                child: const Icon(
                  Icons.call_end,
                  size: 36,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut)
                  .fade(duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
