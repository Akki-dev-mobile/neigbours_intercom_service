import 'package:flutter/material.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

/// Helper class to make localization easier to use across the app
class LocalizationHelper {
  /// Get the localized string for a given key
  static AppLocalizations? of(BuildContext context) {
    return AppLocalizations.of(context);
  }

  /// Get the current locale
  static Locale? getLocale(BuildContext context) {
    return Localizations.localeOf(context);
  }

  /// Check if the current locale is RTL
  static bool isRTL(BuildContext context) {
    final locale = getLocale(context);
    return locale != null && Directionality.of(context) == TextDirection.rtl;
  }

  /// Get the current language code
  static String getLanguageCode(BuildContext context) {
    final locale = getLocale(context);
    return locale?.languageCode ?? 'en';
  }

  /// Check if the context has localization delegate
  static bool hasLocalizations(BuildContext context) {
    return AppLocalizations.of(context) != null;
  }
}

/// Extension to make BuildContext.l10n available
extension LocalizationExtension on BuildContext {
  /// Get AppLocalizations instance for this context
  /// Always returns a valid instance or throws an exception
  AppLocalizations get l10n {
    final loc = AppLocalizations.of(this);
    if (loc == null) {
      throw Exception('AppLocalizations not found in context. Make sure MaterialApp has localizationsDelegates configured.');
    }
    return loc;
  }

  /// Get AppLocalizations instance with fallback
  /// Always returns a valid instance or throws an exception
  AppLocalizations get localizations {
    final loc = AppLocalizations.of(this);
    if (loc == null) {
      throw Exception(
          'AppLocalizations not found in context. Make sure MaterialApp has localizationsDelegates configured.');
    }
    return loc;
  }

  /// Get current language code
  String get currentLanguageCode => Localizations.localeOf(this).languageCode;

  /// Check if current language is English
  bool get isEnglish => currentLanguageCode == 'en';

  /// Check if current language is Hindi
  bool get isHindi => currentLanguageCode == 'hi';

  /// Check if current language is Marathi
  bool get isMarathi => currentLanguageCode == 'mr';
}
 