import 'package:flutter/material.dart';

/// Enhanced stepper widget for mobile number and OTP screens
class StepProgressIndicator extends StatelessWidget {
  /// Current active step (0 for mobile, 1 for OTP)
  final int activeStep;

  /// Color for active elements
  final Color activeColor;

  /// Color for inactive elements
  final Color inactiveColor;

  /// Labels for the steps
  final List<String> labels;

  const StepProgressIndicator({
    super.key,
    required this.activeStep,
    this.activeColor = const Color(0xFF2563EB), // Blue
    this.inactiveColor = const Color(0xFFD1D5DB), // Gray
    this.labels = const ['Mobile Number', 'OTP'],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildStepItem(
              isActive: true, // First step is always visible
              isCompleted: activeStep > 0,
              label: labels[0],
              isFirst: true,
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 2,
                decoration: BoxDecoration(
                  color: activeStep > 0 ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            _buildStepItem(
              isActive: activeStep >= 1,
              isCompleted: activeStep > 1,
              label: labels[1],
              isFirst: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required bool isActive,
    required bool isCompleted,
    required String label,
    required bool isFirst,
  }) {
    return Column(
      crossAxisAlignment:
          isFirst ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isActive ? 24 : 18,
          height: isActive ? 24 : 18,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isCompleted
              ? const Center(
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              : isActive
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: isActive ? 14 : 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? activeColor : const Color(0xFF6B7280),
          ),
          child: Text(
            label,
            textAlign: isFirst ? TextAlign.start : TextAlign.end,
          ),
        ),
      ],
    );
  }
}
