import 'package:flutter/material.dart';

const gameBackground = Color(0xFF070F20);
const gameSurface = Color(0xFF111D34);
const energyCyan = Color(0xFF6FE7F4);
const mint = energyCyan;
const violet = Color(0xFFAFA5FF);
const coral = Color(0xFFFF899B);
const streakAmber = Color(0xFFFFC27D);
const gameRadius = 24.0;
ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: energyCyan,
        brightness: brightness,
      ).copyWith(
        primary: dark ? energyCyan : const Color(0xFF087888),
        surface: dark ? gameSurface : const Color(0xFFF3F5FC),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? gameBackground : const Color(0xFFF3F5FC),
    fontFamily: 'Arial',
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 72,
        fontWeight: FontWeight.w900,
        letterSpacing: -3,
        color: scheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .4),
    ),
  );
}
