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
    final translated = _translateRaw(context, key, params: params);

    if (translated != key) {
      return translated;
    }

    final canonicalKey = _canonicalTranslationKey(key);
    if (canonicalKey != null && canonicalKey != key) {
      final canonicalTranslated = _translateRaw(
        context,
        canonicalKey,
        params: params,
      );
      if (canonicalTranslated != canonicalKey) {
        return canonicalTranslated;
      }
    }

    final generatedTranslated = _translateWithGeneratedL10n(
      context,
      canonicalKey ?? key,
    );
    if (generatedTranslated != null) {
      return generatedTranslated;
    }

    if (translated == key && fallback != null) {
      return fallback;
    }

    return translated;
  }

  static String _translateRaw(
    BuildContext context,
    String key, {
    Map<String, String>? params,
  }) {
    final direct = FlutterI18n.translate(
      context,
      key,
      translationParams: params,
    );
    if (direct != key) return direct;

    // flutter_i18n uses dot notation for nested keys.
    // Many legacy keys are full sentences containing periods/ellipses.
    // Retry with escaped dots so sentence keys can resolve.
    if (key.contains('.')) {
      final escapedDotKey = key.replaceAll('.', r'\.');
      final escaped = FlutterI18n.translate(
        context,
        escapedDotKey,
        translationParams: params,
      );
      if (escaped != escapedDotKey) {
        return escaped;
      }
    }

    return direct;
  }

  static String? _canonicalTranslationKey(String key) {
    final normalized = _normalizeTranslationKey(key);
    return _translationAliases[normalized];
  }

  static String _normalizeTranslationKey(String key) {
    return key
        .trim()
        .toLowerCase()
        .replaceAll('–', '-')
        .replaceAllMapped(RegExp(r'\s+'), (_) => ' ')
        .replaceAllMapped(RegExp(r'\s+:'), (_) => ':')
        .replaceAllMapped(RegExp(r'\s+,'), (_) => ',')
        .replaceAllMapped(RegExp(r'\s+\.'), (_) => '.')
        .replaceAllMapped(RegExp(r'\s+\?'), (_) => '?')
        .replaceAllMapped(RegExp(r'\s+!'), (_) => '!')
        .replaceAllMapped(RegExp(r'\s*-\s*'), (_) => '-');
  }

  static String? _translateWithGeneratedL10n(
    BuildContext context,
    String key,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (_normalizeTranslationKey(key)) {
      case 'welcome back!':
        return l10n.welcomeBack;
      case 'login':
        return l10n.login;
      case 'logout':
        return l10n.logout;
      case 'confirm':
        return l10n.confirm;
      case 'ok':
        return l10n.ok;
      case 'forgot password':
      case 'forgot password?':
        return l10n.forgotPassword;
      case 'sign up':
        return l10n.signUp;
      case 'please wait':
      case 'please wait...':
        return l10n.pleaseWait;
      case 'approval timeout duration':
        return l10n.approvalTimeoutDuration;
      case 'in out book':
        return l10n.inOutBook;
      case 'visitor in':
        return l10n.visitorIn;
      case 'visitor out':
        return l10n.visitorOut;
      case 'otp verification failed. please try again.':
        return l10n.otpVerificationFailedPleaseTryAgain;
      case 'otp verified successfully!':
        return l10n.otpVerifiedSuccessfully;
      case 'please wait while we load your dashboard':
        return l10n.pleaseWaitPreparingDashboard;
      case 'guest, delivery, staff, member staff, vendor, cabs':
      case 'guest,delivery,staff,member staff,vendor,cabs':
        return '${translate(context, 'Guest')}, ${translate(context, 'Delivery')}, ${translate(context, 'Staff')}, ${translate(context, 'Member Staff')}, ${translate(context, 'Vendor')}, ${translate(context, 'Cabs')}';
      default:
        return null;
    }
  }

  static final Map<String, String> _translationAliases = {
    'loading': 'loading',
    'loading ': 'loading',
    'this is an example preview. tap enter deatils to preview':
        'This is an example preview. Tap Enter details to proceed.',
    'this is an example preview. tap enter details to preview':
        'This is an example preview. Tap Enter details to proceed.',
    'this is an example preview. tap enter deatils to preview ':
        'This is an example preview. Tap Enter details to proceed.',
    'this is an example preview. tap enter details to proceed.':
        'This is an example preview. Tap Enter details to proceed.',
    'not a oneapp user': 'Not a one app user',
    'invite': 'Invite',
    'no parcel found today': 'No parcels found today.',
    'no parcels found today.': 'No parcels found today.',
    'search parcel by member, unit, or category':
        'Search parcel by member, unit, or category...',
    'search parcel by member, unit , or category':
        'Search parcel by member, unit, or category...',
    'search parcel by member, unit, or category...':
        'Search parcel by member, unit, or category...',
    'approval timeout duration': 'Approval timeout duration',
    'seconds': 'seconds',
    'search staff by name, category, or phone number':
        'Search staff by name, category, or phone...',
    'search staff by name , category , or phone number':
        'Search staff by name, category, or phone...',
    'search staff by name, category, or phone...':
        'Search staff by name, category, or phone...',
    'no staff member match your search. try a different keyword.':
        'No staff members match your search. Try a different keyword.',
    'no staff members match your search. try a different keyword.':
        'No staff members match your search. Try a different keyword.',
    'looks quiet right now. visitors entries will appear here as soon as someone checks in.':
        'Looks quiet right now. Visitor entries will appear here as soon as someone checks in.',
    'looks quite right now. visitors entries will appear here as soon as someone checks in.':
        'Looks quiet right now. Visitor entries will appear here as soon as someone checks in.',
    'looks quiet right now. visitor entries will appear here as soon as someone checks in.':
        'Looks quiet right now. Visitor entries will appear here as soon as someone checks in.',
    'in out book': 'In Out Book',
    'in out book, visitor in, visitor out': 'In Out Book',
    'in out book , visitor in , visitor out': 'In Out Book',
    'visitor in': 'Visitor In',
    'visitor out': 'Visitor Out',
    'preparing visitors logs': 'Preparing visitor logs...',
    'preparing visitor logs...': 'Preparing visitor logs...',
    'processing': 'Processing...',
    'processing...': 'Processing...',
    'guest': 'Guest',
    'delivery': 'Delivery',
    'staff': 'Staff',
    'member staff': 'Member Staff',
    'vendor': 'Vendor',
    'cabs': 'Cabs',
    'take photo': 'Take Photo',
    'search by name, unit number, or building':
        'Search by name, unit number, or building...',
    'search by name , unit number, or building':
        'Search by name, unit number, or building...',
    'search by name, unit number, or building...':
        'Search by name, unit number, or building...',
    'no member found': 'No member found',
    'no results': 'No results',
    'please wait while we fetch available units':
        'Please wait while we fetch available units...',
    'please wait while we fetch available units...':
        'Please wait while we fetch available units...',
    'confirm': 'Confirm',
    'logout': 'Logout',
    'welcome back!': 'Welcome Back!',
    'sign in with your mobile number': 'Sign in with your mobile number',
    'forgot password': 'Forgot password?',
    'forgot password?': 'Forgot password?',
    "don't have an account ? sign up": "Don't have an account? Sign up",
    "don't have an account? sign up": "Don't have an account? Sign up",
    "don't have an account? ": "Don't have an account? ",
    'enter your registered mobile number to receive an otp.':
        'Enter your registered mobile number to receive an OTP.',
    'enter your registred mobile number to receive an otp':
        'Enter your registered mobile number to receive an OTP.',
    'please wait': 'Please wait',
    'enter the otp sent your registered mobile number':
        'Enter the OTP sent to your registered mobile number.',
    'enter the otp sent your registred mobile number':
        'Enter the OTP sent to your registered mobile number.',
    'enter the otp sent to your registered mobile number.':
        'Enter the OTP sent to your registered mobile number.',
    'error: otp verification failed. please try again':
        'Error: OTP verification failed. Please try again',
    'error : otp verification failed. please try again':
        'Error: OTP verification failed. Please try again',
    'otp verification failed. please try again.':
        'OTP verification failed. Please try again.',
    'otp verified please set you new password':
        'OTP verified. Please set your new password.',
    'otp verified. please set your new password.':
        'OTP verified. Please set your new password.',
    'password do not match': 'Passwords do not match',
    'passwords do not match': 'Passwords do not match',
    'password successfully reset. now you can login with your new password':
        'Password reset successful. You can now login with your new password.',
    'password reset successful. you can now login with your new password.':
        'Password reset successful. You can now login with your new password.',
    'request call back': 'Request Call Back',
    'already have an account ? login': 'Already have an account? Login',
    'already have an account? login': 'Already have an account? Login',
    'already have an account? ': 'Already have an account? ',
    'ready to roll?': 'Ready to Roll?',
    'request now & hear from us in 24-48 hours!':
        'Request now & hear from us in 24-48 hours!',
    'request now & hear from us in 24 -48 hours!':
        'Request now & hear from us in 24-48 hours!',
    'request submitted': 'Request Submitted',
    'thank you for your request.': 'Thank you for your request.',
    'our team will reach out within 24-48 hours to verify deatils and get you strated':
        'Our team will reach out within 24–48 hours to verify details and get you started.',
    'our team will reach out within 24 -48 hours to verify deatils and get you strated':
        'Our team will reach out within 24–48 hours to verify details and get you started.',
    'our team will reach out within 24-48 hours to verify details and get you started':
        'Our team will reach out within 24–48 hours to verify details and get you started.',
    'our team will reach out within 24-48 hours to verify details and get you started.':
        'Our team will reach out within 24–48 hours to verify details and get you started.',
    'ok': 'OK',
    'the user credentails were incorrect':
        'The user credentials were incorrect.',
    'the user credentials were incorrect.':
        'The user credentials were incorrect.',
    'select your society': 'Select Your Society',
    'choose your society to continue': 'Choose your society to continue',
    'select your role': 'Select Your Role',
    'choose your role to continue': 'Choose your role to continue',
    'please wait while we load your dashboard':
        'Please wait while we load your dashboard',
    'please wait while we load your dashbaord':
        'Please wait while we load your dashboard',
    'sacn your qr code for instant chekc in. most convenient method for regular visitors':
        'Scan your QR code for instant check-in. Most convenient method for regular visitors.',
    'scan your qr code for instant chekc in. most convenient method for regular visitors':
        'Scan your QR code for instant check-in. Most convenient method for regular visitors.',
    'scan your qr code for instant check in. most convenient method for regular visitors':
        'Scan your QR code for instant check-in. Most convenient method for regular visitors.',
    'scan your qr code for instant check-in. most convenient method for regular visitors.':
        'Scan your QR code for instant check-in. Most convenient method for regular visitors.',
    'use your password for quick and sceure chekc in without otp verification':
        'Use your passcode for quick and secure check-in without OTP verification.',
    'use your password for quick and secure check in without otp verification':
        'Use your passcode for quick and secure check-in without OTP verification.',
    'use your passcode for quick and secure check-in without otp verification.':
        'Use your passcode for quick and secure check-in without OTP verification.',
    'please enter a 10 digit mobile number':
        'Please enter a 10 digit mobile number',
    'please enter 10 digit mobile number':
        'Please enter 10 digit mobile number',
    'access granted switching to gatekeeper dashboard':
        'accessGrantedSwitchingToGatekeeperDashboard',
    'access granted switching to gatekeeper dashbaord':
        'accessGrantedSwitchingToGatekeeperDashboard',
    'your visitor entery has been succesfully recorded':
        'Your visitor entry has been successfully recorded.',
    'your visitor entry has been successfully recorded.':
        'Your visitor entry has been successfully recorded.',
    'please ask the receptionist to assign an assess card for you':
        'Please ask the receptionist to assign an access card for you.',
    'please ask the receptionist to assign an access card for you.':
        'Please ask the receptionist to assign an access card for you.',
    'this will allow the easy access to the lift and your designated floor':
        'This will allow easy access to the lift and your designated floor.',
    'this will allow easy access to the lift and your designated floor.':
        'This will allow easy access to the lift and your designated floor.',
  };

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
