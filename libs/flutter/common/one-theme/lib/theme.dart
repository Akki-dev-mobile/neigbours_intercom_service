// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme_helper.dart';
import 'theme_manager_config.dart';

class ThemeManager {
  static ThemeData lightTheme = ThemeData.light();
  static ThemeData darkTheme = ThemeData.dark();

  static Future<void> initializeWithAppId(
      String appId, BuildContext context) async {
    Map<String, dynamic> config = await ThemeHelper.loadConfigForApp(appId);
    await _initializeThemes(config, context);
  }

  static Future<void> _initializeThemes(
      Map<String, dynamic> config, BuildContext context) async {
    lightTheme = await _buildTheme(
      config,
      false,
      context,
    );
    darkTheme = await _buildTheme(
      config,
      true,
      context,
    );
  }

  static Future<ThemeData> _buildTheme(
      Map<String, dynamic> config, bool isDark, BuildContext context) async {
    Map<String, dynamic> themeData =
        config['themes'][isDark ? 'dark' : 'light'];

    return ThemeData(
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: getResponsiveFontSize(
              context,
              ThemeManagerConfig.getFontValue(
                  themeData, 'fonts.displayLarge.size')),
          fontWeight: ThemeManagerConfig.parseFontWeight(
            ThemeManagerConfig.getFontValue(
                themeData, 'fonts.displayLarge.weight'),
          ),
          color: HexColor.fromHex(
            ThemeManagerConfig.getColor(themeData, 'colors.onBackground'),
          ),
        ),
        displayMedium: TextStyle(
          fontSize: ThemeManagerConfig.getFontValue(
              themeData, 'fonts.displayMedium.size'),
          fontWeight: ThemeManagerConfig.parseFontWeight(
            ThemeManagerConfig.getFontValue(
                themeData, 'fonts.displayMedium.weight'),
          ),
          color: HexColor.fromHex(
            ThemeManagerConfig.getColor(themeData, 'colors.onBackground'),
          ),
        ),
        displaySmall: TextStyle(
          fontSize: ThemeManagerConfig.getFontValue(
              themeData, 'fonts.displaySmall.size'),
          fontWeight: ThemeManagerConfig.parseFontWeight(
            ThemeManagerConfig.getFontValue(
                themeData, 'fonts.displaySmall.weight'),
          ),
          color: HexColor.fromHex(
            ThemeManagerConfig.getColor(themeData, 'colors.onBackground'),
          ),
        ),
        bodyLarge: TextStyle(
          fontSize: ThemeManagerConfig.getFontValue(
              themeData, 'fonts.bodyLarge.size'),
          fontWeight: ThemeManagerConfig.parseFontWeight(
            ThemeManagerConfig.getFontValue(
                themeData, 'fonts.bodyLarge.weight'),
          ),
          color: HexColor.fromHex(
            ThemeManagerConfig.getColor(themeData, 'colors.onBackground'),
          ),
        ),
        bodyMedium: TextStyle(
          fontSize: ThemeManagerConfig.getFontValue(
              themeData, 'fonts.bodyMedium.size'),
          fontWeight: ThemeManagerConfig.parseFontWeight(
            ThemeManagerConfig.getFontValue(
                themeData, 'fonts.bodyMedium.weight'),
          ),
          color: HexColor.fromHex(
            ThemeManagerConfig.getColor(themeData, 'colors.onBackground'),
          ),
        ),
        labelMedium: TextStyle(
          fontSize: ThemeManagerConfig.getFontValue(
              themeData, 'fonts.labelMedium.size'),
          fontWeight: ThemeManagerConfig.parseFontWeight(
            ThemeManagerConfig.getFontValue(
                themeData, 'fonts.labelMedium.weight'),
          ),
          color: HexColor.fromHex(
            ThemeManagerConfig.getColor(themeData, 'colors.onPrimary'),
          ),
        ),
        labelSmall: TextStyle(
          fontSize: ThemeManagerConfig.getFontValue(
              themeData, 'fonts.labelSmall.size'),
          fontWeight: ThemeManagerConfig.parseFontWeight(
            ThemeManagerConfig.getFontValue(
                themeData, 'fonts.labelSmall.weight'),
          ),
          color: HexColor.fromHex(
            ThemeManagerConfig.getColor(themeData, 'colors.onPrimary'),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      colorScheme: ColorScheme.light(
        background: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.primaryBackground'),
        ),
        onBackground: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.onBackground'),
        ),
        primary: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.primaryContainer'),
        ),
        onPrimary: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.onPrimary'),
        ),

        // "primaryContainer": "#FAFAFA",
      ),
    );
  }
}
