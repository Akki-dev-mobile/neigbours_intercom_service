import 'package:flutter/material.dart';

/// Minimal color palette used by the extracted module.
///
/// Host apps can override via Theme, but keeping these constants avoids having
/// to rewrite large parts of the legacy UI.
class AppColors {
  static const Color primary = Color(0xFF2F80ED);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFEF4444);

  // Legacy module color names (kept for compatibility).
  static const Color background = Color(0xFFF9FAFB);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF3F4F6);
  static const Color coolGrey = Color(0xFF9CA3AF);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  static const LinearGradient lightGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
  );
  static const LinearGradient blackToGreyGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF6B7280)],
  );
  static const LinearGradient redToGreyGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFF6B7280)],
  );
}
