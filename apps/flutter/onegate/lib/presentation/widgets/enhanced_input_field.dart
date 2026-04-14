import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enhanced input field for mobile number and OTP entry
class EnhancedInputField extends StatelessWidget {
  /// Controller for the input field
  final TextEditingController controller;

  /// Focus node for the input field
  final FocusNode? focusNode;

  /// Whether this is a mobile field (true) or OTP field (false)
  final bool isMobileField;

  /// Label to show above the input field
  final String? label;

  /// Hint text for the input field
  final String? hint;

  /// Maximum length of the input
  final int maxLength;

  /// Widget to show as prefix (like country code)
  final Widget? prefixWidget;

  /// Callback for when clear button is pressed
  final VoidCallback? onClear;

  /// Callback for when input changes
  final ValueChanged<String>? onChanged;

  /// Whether the field is tablet-sized
  final bool isTablet;

  /// Whether to suppress the mobile keyboard (use custom keypad only)
  final bool suppressKeyboard;

  const EnhancedInputField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.isMobileField,
    this.label,
    this.hint,
    this.maxLength = 10,
    this.prefixWidget,
    this.onClear,
    this.onChanged,
    this.isTablet = false,
    this.suppressKeyboard = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // Removed drop shadow as requested
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: suppressKeyboard, // Suppress keyboard when enabled
        showCursor: true, // Ensure cursor is always visible
        cursorColor: const Color(0xffF44336), // Red cursor color
        onChanged: onChanged,
        // Suppress keyboard on both platforms
        keyboardType: suppressKeyboard ? TextInputType.none : null,
        enableInteractiveSelection:
            !suppressKeyboard, // Disable text selection when keyboard is suppressed
        style: TextStyle(
          fontSize: isTablet ? 20 : 16,
          color: const Color(0xFF111827),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          // Hide the label inside the input field
          labelText: null,
          hintText: hint ?? (isMobileField ? '0123456789' : '123456'),
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          // Remove character counter
          counterText: '',
          fillColor: Colors.white,
          filled: true,
          prefixIcon: prefixWidget ??
              (isMobileField
                  ? null
                  : const Icon(Icons.lock_rounded, color: Color(0xFF6B7280))),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (onClear != null) {
                  onClear!();
                  HapticFeedback.lightImpact();
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE), // Light red background
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xffF44336)), // Red icon
              ),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9CA3AF), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffF44336), width: 1.0),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          // Remove floating label behavior since we're hiding the label
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
      ),
    );
  }
}
