import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing the application language state
/// Supports English (en), Hindi (hi), and Marathi (mr)
class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _defaultLanguage = 'en';

  Locale _currentLocale = const Locale(_defaultLanguage);
  int _rebuildKey = 0;

  /// Get the current locale
  Locale get currentLocale => _currentLocale;

  /// Get the current language code
  String get currentLanguageCode => _currentLocale.languageCode;

  /// Get the rebuild key that changes when language changes
  int get rebuildKey => _rebuildKey;

  /// Get the current language display name
  String get currentLanguageName {
    switch (_currentLocale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'mr':
        return 'Marathi';
      default:
        return 'English';
    }
  }

  /// Get list of supported languages
  List<Map<String, String>> get supportedLanguages => [
        {'code': 'en', 'name': 'English', 'nativeName': 'English'},
        {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिंदी'},
        {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी'},
      ];

  /// Initialize the language provider and load saved language preference
  Future<void> initialize() async {
    try {
      await _loadLanguagePreference();
      _rebuildKey++;
      notifyListeners();
      log('🌐 LanguageProvider initialized with locale: ${_currentLocale.languageCode}');
    } catch (e) {
      log('❌ Error initializing LanguageProvider: $e');
      // Fallback to default language
      _currentLocale = const Locale(_defaultLanguage);
      _rebuildKey++;
      notifyListeners();
    }
  }

  /// Change the application language
  Future<void> changeLanguage(BuildContext context, String languageCode) async {
    try {
      // Validate the language code
      if (!_isValidLanguageCode(languageCode)) {
        log('❌ Invalid language code: $languageCode');
        throw Exception('Invalid language code: $languageCode');
      }

      // Create new locale
      final newLocale = Locale(languageCode);

      // Save the preference
      await _saveLanguagePreference(languageCode);

      // Refresh the FlutterI18n engine used by context.tr(...) callers.
      await FlutterI18n.refresh(context, newLocale);

      // Update the current locale after translations are reloaded.
      _currentLocale = newLocale;
      _rebuildKey++;

      log('🌐 Language changed to: $languageCode (${_getLanguageName(languageCode)})');
      log('🔄 Notifying all listeners about language change...');
      notifyListeners();

      log('✅ Language change notification completed');
    } catch (e) {
      log('❌ Error changing language: $e');
      rethrow;
    }
  }

  /// Load language preference from SharedPreferences
  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey) ?? _defaultLanguage;

      // Validate saved language
      if (_isValidLanguageCode(savedLanguage)) {
        _currentLocale = Locale(savedLanguage);
        log('🌐 Loaded saved language: $savedLanguage');
      } else {
        log('⚠️ Invalid saved language: $savedLanguage, using default');
        _currentLocale = const Locale(_defaultLanguage);
      }
    } catch (e) {
      log('❌ Error loading language preference: $e');
      _currentLocale = const Locale(_defaultLanguage);
    }
  }

  /// Save language preference to SharedPreferences
  Future<void> _saveLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      log('💾 Language preference saved: $languageCode');
    } catch (e) {
      log('❌ Error saving language preference: $e');
      rethrow;
    }
  }

  /// Check if the language code is valid
  bool _isValidLanguageCode(String languageCode) {
    return ['en', 'hi', 'mr'].contains(languageCode);
  }

  /// Get the display name for a language code
  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'mr':
        return 'Marathi';
      default:
        return 'Unknown';
    }
  }

  /// Check if a language is currently selected
  bool isLanguageSelected(String languageCode) {
    return _currentLocale.languageCode == languageCode;
  }

  /// Get the native name for a language code
  String getNativeName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी';
      case 'mr':
        return 'मराठी';
      default:
        return 'English';
    }
  }

  /// Show language change confirmation dialog
  Future<bool> showLanguageChangeDialog(
    BuildContext context,
    String newLanguage,
  ) async {
    final languageName = _getLanguageName(newLanguage);
    final isTablet = MediaQuery.of(context).size.width > 768;
    final screenSize = MediaQuery.of(context).size;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: isTablet ? 500 : double.infinity,
              constraints: BoxConstraints(
                maxWidth: isTablet ? 500 : screenSize.width * 0.9,
                maxHeight: screenSize.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 24 : 20),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFE0E3E7),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Language',
                                style: TextStyle(
                                  fontSize: isTablet ? 20 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff212427),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Are you sure you want to change the language?',
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  color: const Color(0xff57636C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 24 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Language: $languageName',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff212427),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The app will apply the new language immediately.',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: const Color(0xff57636C),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xff57636C),
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isTablet ? 16 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 16 : 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isTablet ? 16 : 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xffF44336),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isTablet ? 16 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 16 : 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }
}
