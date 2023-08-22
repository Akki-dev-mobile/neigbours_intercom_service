import 'package:flutter/material.dart';
import 'theme_helper.dart';
import 'theme_manager_config.dart';

class ThemeManager {
  static ThemeData lightTheme = ThemeData.light();
  static ThemeData darkTheme = ThemeData.dark();

  static Future<void> initializeWithAppId(String appId) async {
    Map<String, dynamic> config = await ThemeHelper.loadConfigForApp(appId);
    _initializeThemes(config);
  }

  static void _initializeThemes(Map<String, dynamic> config) {
    lightTheme = _buildTheme(config, true);
    darkTheme = _buildTheme(config, false);
  }

  static ThemeData _buildTheme(Map<String, dynamic> config, bool isDark) {
    Map<String, dynamic> themeData =
        config['themes'][isDark ? 'dark' : 'light'];

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: ThemeManagerConfig.getFontValue(
              themeData, 'fonts.titleLarge.size'),
          fontWeight: ThemeManagerConfig.parseFontWeight(
              ThemeManagerConfig.getFontValue(
                  themeData, 'fonts.titleLarge.weight')),
          // color: HexColor.fromHex(
          //     ThemeManagerConfig.getColor(themeData, 'titleLarge.color')),
        ),
      ),
      colorScheme: ColorScheme.light(
        background: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.primaryBackground'),
        ),
        primary: HexColor.fromHex(
          ThemeManagerConfig.getColor(themeData, 'colors.surfaceTint'),
        ),
        // secondary: HexColor.fromHex(
        //     ThemeManagerConfig.getColor(themeData, 'secondary')),
        // surface:
        //     HexColor.fromHex(ThemeManagerConfig.getColor(themeData, 'surface')),
        // onBackground: HexColor.fromHex(
        //     ThemeManagerConfig.getColor(themeData, 'onBackground')),
        // onSurface: HexColor.fromHex(
        //     ThemeManagerConfig.getColor(themeData, 'onSurface')),
        // error:
        //     HexColor.fromHex(ThemeManagerConfig.getColor(themeData, 'error')),
        // onError:
        //     HexColor.fromHex(ThemeManagerConfig.getColor(themeData, 'onError')),
        // brightness: isDark ? Brightness.dark : Brightness.light,
        // onPrimary:
        //     HexColor.fromHex(ThemeManagerConfig.getColor(themeData, 'onError')),
        // onSecondary:
        //     HexColor.fromHex(ThemeManagerConfig.getColor(themeData, 'onError')),
      ),
    );
  }
}
