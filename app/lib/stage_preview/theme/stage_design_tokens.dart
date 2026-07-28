import 'package:flutter/material.dart';

abstract final class StageDesignTokens {
  static const charcoal = Color(0xFF17131F);
  static const purple = Color(0xFF6C3BFF);
  static const pink = Color(0xFFFF5A8C);
  static const page = Color(0xFFF7F6FB);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF1EDFF);
  static const border = Color(0xFFDED9EA);
  static const textPrimary = Color(0xFF17131F);
  static const textSecondary = Color(0xFF6B647E);
  static const textMuted = Color(0xFF9A93AC);
  static const success = Color(0xFF28A974);
  static const warning = Color(0xFFFFB020);
  static const error = Color(0xFFD8496B);
  static const info = Color(0xFF3D7BE0);

  static const brandGradient = LinearGradient(
    colors: [purple, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF5630D9), Color(0xFFFF5A8C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  static const radius8 = 8.0;
  static const radius12 = 12.0;
  static const radius16 = 16.0;
  static const radius20 = 20.0;
  static const radiusPill = 999.0;

  static const iconSmall = 18.0;
  static const iconMedium = 22.0;
  static const iconLarge = 28.0;
  static const headerHeight = 58.0;
  static const bottomNavigationHeight = 64.0;
  static const maxContentWidth = 430.0;
  static const mediumBreakpoint = 600.0;

  static const cardShadow = [
    BoxShadow(color: Color(0x120F0B18), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static double horizontalPadding(double width) {
    if (width >= mediumBreakpoint) return space24;
    if (width <= 340) return space12;
    return space16;
  }

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.light,
      primary: purple,
      secondary: pink,
      surface: surface,
      error: error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: page,
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 11,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space16,
          vertical: space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: purple, width: 1.5),
        ),
      ),
    );
  }
}
