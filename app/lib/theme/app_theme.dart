import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const brandYellow = Color(0xFFFFC629);

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandYellow,
      primary: brandYellow,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFFFFCF5),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF1E1E1E),
      elevation: 0,
      centerTitle: false,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFFFF3CA),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(color: Color(0xFF3C3100)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
  );
}
