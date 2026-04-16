import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

class LocalizationHelper {
  static String translate(
    BuildContext context,
    String key, {
    Map<String, String>? params,
    String? fallback,
  }) {
    final translated = FlutterI18n.translate(
      context,
      key,
      translationParams: params,
    );

    if (translated == key && fallback != null) {
      return fallback;
    }

    return translated;
  }

  static Locale? getLocale(BuildContext context) =>
      Localizations.localeOf(context);

  static bool isRTL(BuildContext context) {
    final locale = getLocale(context);
    return locale != null && Directionality.of(context) == TextDirection.rtl;
  }

  static String getLanguageCode(BuildContext context) {
    final locale = getLocale(context);
    return locale?.languageCode ?? 'en';
  }

  static bool hasLocalizations(BuildContext context) =>
      getLocale(context) != null;

  /// Localizes known visitor purpose category names from the API (e.g. `GUEST`).
  static String translatePurposeCategoryName(
    BuildContext context,
    String categoryName,
  ) {
    final raw = categoryName.trim();
    switch (raw.toUpperCase()) {
      case 'GUEST':
        return translate(context, 'purposeCategoryGuest');
      case 'DELIVERY':
        return translate(context, 'purposeCategoryDelivery');
      case 'STAFF':
        return translate(context, 'purposeCategoryStaff');
      case 'MEMBER STAFF':
        return translate(context, 'purposeCategoryMemberStaff');
      case 'VENDOR':
        return translate(context, 'purposeCategoryVendor');
      case 'CABS':
        return translate(context, 'purposeCategoryCabs');
      default:
        return translate(context, raw, fallback: raw);
    }
  }
}

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  AppLocalizations get localizations => l10n;

  String tr(
    String key, {
    Map<String, String>? params,
    String? fallback,
  }) {
    return LocalizationHelper.translate(
      this,
      key,
      params: params,
      fallback: fallback,
    );
  }

  String trPurposeCategory(String categoryName) =>
      LocalizationHelper.translatePurposeCategoryName(this, categoryName);

  String get currentLanguageCode => Localizations.localeOf(this).languageCode;
  bool get isEnglish => currentLanguageCode == 'en';
  bool get isHindi => currentLanguageCode == 'hi';
  bool get isMarathi => currentLanguageCode == 'mr';
}
