import 'package:flutter/material.dart';

/// Palette from design/StyleGuide.md (mahogany/parchment/gold/jade Xiangqi
/// aesthetic). Custom serif/CJK-friendly typography is left as a follow-up
/// once font assets are added to the project; system fonts already render
/// the Chinese piece glyphs correctly on iOS/Android.
class XiangqiColors {
  XiangqiColors._();

  static const mahogany = Color(0xFF2C1810);
  static const walnut = Color(0xFF4A2E1B);
  static const parchment = Color(0xFFF4E8C1);
  static const crimson = Color(0xFFA8342A);
  static const gold = Color(0xFFC9A24B);
  static const jade = Color(0xFF2E5A44);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: XiangqiColors.mahogany,
    colorScheme: ColorScheme.fromSeed(
      seedColor: XiangqiColors.crimson,
      brightness: Brightness.dark,
      primary: XiangqiColors.crimson,
      secondary: XiangqiColors.gold,
      surface: XiangqiColors.walnut,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: XiangqiColors.mahogany,
      foregroundColor: XiangqiColors.parchment,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: XiangqiColors.crimson,
        foregroundColor: XiangqiColors.parchment,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: XiangqiColors.jade,
        side: const BorderSide(color: XiangqiColors.jade),
        shape: const StadiumBorder(),
      ),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: XiangqiColors.parchment, displayColor: XiangqiColors.parchment),
  );
}
