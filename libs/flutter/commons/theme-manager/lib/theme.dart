import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_helper.dart';
import 'theme_manager.dart';

class ThemeManager {
  static late ThemeData lightTheme;
  static late ThemeData darkTheme;

  static Future<void> initializeWithAppId(String appId) async {
    final config = await ThemeHelper.loadConfigForApp(appId);
    await _initializeThemes(config);
  }

  static Future<void> _initializeThemes(Map<String, dynamic> config) async {
    lightTheme = await _buildTheme(config, isDark: false);
    darkTheme = await _buildTheme(config, isDark: true);
  }

  static Future<ThemeData> _buildTheme(Map<String, dynamic> config,
      {required bool isDark}) async {
    final themeData = config['themes'][isDark ? 'dark' : 'light'];
    final backgroundColor = HexColor.fromHex(
        ThemeManagerConfig.getColor(themeData, 'colors.background'));
    final onBackgroundColor = HexColor.fromHex(
        ThemeManagerConfig.getColor(themeData, 'colors.onBackground'));
    final primaryColor = HexColor.fromHex(
        ThemeManagerConfig.getColor(themeData, 'colors.primaryContainer'));

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.anekDevanagari().fontFamily,
      dialogBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        modalBarrierColor: onBackgroundColor.withOpacity(0.2),
      ),
      checkboxTheme: _buildCheckboxTheme(themeData),
      radioTheme: _buildRadioTheme(themeData),
      datePickerTheme: _buildDatePickerTheme(themeData),
      textTheme: _buildTextTheme(themeData),
      colorScheme: _buildColorScheme(themeData, isDark),
    );
  }

  static CheckboxThemeData _buildCheckboxTheme(Map<String, dynamic> themeData) {
    final onBackgroundColor = HexColor.fromHex(
        ThemeManagerConfig.getColor(themeData, 'colors.onBackground'));
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.all(onBackgroundColor),
      side: BorderSide(color: onBackgroundColor),
    );
  }

  static RadioThemeData _buildRadioTheme(Map<String, dynamic> themeData) {
    final onBackgroundColor = HexColor.fromHex(
        ThemeManagerConfig.getColor(themeData, 'colors.onBackground'));
    return RadioThemeData(
      fillColor: WidgetStateProperty.all(onBackgroundColor),
    );
  }

  static DatePickerThemeData _buildDatePickerTheme(
      Map<String, dynamic> themeData) {
    final backgroundColor = HexColor.fromHex(
        ThemeManagerConfig.getColor(themeData, 'colors.background'));
    final onBackgroundColor = HexColor.fromHex(
        ThemeManagerConfig.getColor(themeData, 'colors.onBackground'));
    return DatePickerThemeData(
      backgroundColor: backgroundColor,
      headerBackgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      todayForegroundColor: WidgetStateProperty.all(onBackgroundColor),
      dayForegroundColor: WidgetStateProperty.all(onBackgroundColor),
    );
  }

  static TextTheme _buildTextTheme(Map<String, dynamic> themeData) {
    return TextTheme(
      bodyLarge: _buildTextStyle(themeData, 'fonts.bodyLarge'),
      bodyMedium: _buildTextStyle(themeData, 'fonts.bodyMedium'),
      bodySmall: _buildTextStyle(themeData, 'fonts.bodySmall'),
    );
  }

  static TextStyle _buildTextStyle(
      Map<String, dynamic> themeData, String path) {
    return TextStyle(
      fontSize: ThemeManagerConfig.getFontValue(themeData, '$path.size'),
      fontWeight: ThemeManagerConfig.parseFontWeight(
        ThemeManagerConfig.getFontValue(themeData, '$path.weight'),
      ),
      color: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.onBackground')),
    );
  }

  static ColorScheme _buildColorScheme(
      Map<String, dynamic> themeData, bool isDark) {
    return ColorScheme(
      surface: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.background')),
      onSurface: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.onBackground')),
      primary: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.primaryContainer')),
      onPrimary: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.onPrimary')),
      secondary: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.background')),
      onSecondary: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.onBackground')),
      error: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.background')),
      onError: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.onBackground')),
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
  }
}

Color kPrimaryRedColor = const Color(0xffF44336);
Color kPrimaryBlackColor = const Color(0xff121212);
