library one_theme;

// import 'package:flutter/material.dart';

// import 'theme_helper.dart';

// class ThemeManager {
//   static ThemeData lightTheme = ThemeData.light();
//   static ThemeData darkTheme = ThemeData.dark();

//   static Future<void> initializeThemes() async {
//     Map<String, dynamic> config = await ThemeHelper.loadConfig();

//     lightTheme = ThemeData.light().copyWith(
//       textTheme: TextTheme(
//         displayLarge: TextStyle(
//           fontSize: getConfigValue(config, 'fonts.headline.size'),
//           fontWeight:
//               parseFontWeight(getConfigValue(config, 'fonts.headline.weight')),
//         ),
//         displayMedium: TextStyle(
//           fontSize: getConfigValue(config, 'fonts.subheadline.size'),
//           fontWeight: parseFontWeight(
//               getConfigValue(config, 'fonts.subheadline.weight')),
//         ),
//         bodyLarge: TextStyle(
//           fontSize: getConfigValue(config, 'fonts.primary.size'),
//           fontWeight:
//               parseFontWeight(getConfigValue(config, 'fonts.primary.weight')),
//         ),
//       ),
//       colorScheme: ColorScheme.light(
//         primary: HexColor.fromHex(getConfigValue(config, 'colors.primary')),
//         secondary: HexColor.fromHex(getConfigValue(config, 'colors.secondary')),
//         background:
//             HexColor.fromHex(getConfigValue(config, 'colors.background')),
//         onPrimary: HexColor.fromHex(getConfigValue(config, 'colors.text')),
//         onSecondary: HexColor.fromHex(getConfigValue(config, 'colors.text')),
//       ),
//     );

//     darkTheme = ThemeData.dark().copyWith(
//       textTheme: TextTheme(
//         displayLarge: TextStyle(
//           fontSize: getConfigValue(config, 'fonts.headline.size'),
//           fontWeight:
//               parseFontWeight(getConfigValue(config, 'fonts.headline.weight')),
//         ),
//         displayMedium: TextStyle(
//           fontSize: getConfigValue(config, 'fonts.subheadline.size'),
//           fontWeight: parseFontWeight(
//               getConfigValue(config, 'fonts.subheadline.weight')),
//         ),
//         bodyLarge: TextStyle(
//           fontSize: getConfigValue(config, 'fonts.primary.size'),
//           fontWeight:
//               parseFontWeight(getConfigValue(config, 'fonts.primary.weight')),
//         ),
//       ),
//       colorScheme: ColorScheme.dark(
//         primary: HexColor.fromHex(getConfigValue(config, 'colors.primary')),
//         secondary: HexColor.fromHex(getConfigValue(config, 'colors.secondary')),
//         background:
//             HexColor.fromHex(getConfigValue(config, 'colors.background')),
//         onPrimary: HexColor.fromHex(getConfigValue(config, 'colors.text')),
//         onSecondary: HexColor.fromHex(getConfigValue(config, 'colors.text')),
//       ),
//     );
//   }

//   static dynamic getConfigValue(Map<String, dynamic> config, String path) {
//     List<String> keys = path.split('.');
//     dynamic value = config;
//     for (String key in keys) {
//       value = value[key];
//     }
//     return value;
//   }

//   static FontWeight parseFontWeight(String value) {
//     switch (value) {
//       case 'bold':
//         return FontWeight.bold;
//       case 'normal':
//       default:
//         return FontWeight.normal;
//     }
//   }

//   static initializeWithAppId(String appId) {}
// }

// class HexColor extends Color {
//   static int _getColorFromHex(String hexColor) {
//     hexColor = hexColor.toUpperCase().replaceAll('#', '');
//     if (hexColor.length == 6) {
//       hexColor = 'FF' + hexColor;
//     }
//     return int.parse(hexColor, radix: 16);
//   }

//   HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

//   static Color fromHex(String hexColor) {
//     return HexColor(hexColor);
//   }
// }
