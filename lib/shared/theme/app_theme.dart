import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const _darkPrimary = Color(0xFF37C6A6);

  static ThemeData get light {
    const surface = Color(0xFFF3F7FB);
    const primary = Color(0xFF1D6FD6);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: surface,
        primary: primary,
        secondary: const Color(0xFF2A9DCC),
      ),
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
      focusColor: primary.withValues(alpha: 0.22),
      textTheme: _textTheme,
      iconButtonTheme: IconButtonThemeData(
        style: _iconButtonStyle(primary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(primary),
      ),
    );
  }

  static ThemeData get dark {
    const surface = Color(0xFF101216);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _darkPrimary,
        brightness: Brightness.dark,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
      focusColor: _darkPrimary.withValues(alpha: 0.28),
      textTheme: _textTheme,
      iconButtonTheme: IconButtonThemeData(
        style: _iconButtonStyle(_darkPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(_darkPrimary),
      ),
    );
  }

  static ButtonStyle _iconButtonStyle(Color accent) {
    return IconButton.styleFrom(
      minimumSize: const Size.square(58),
      iconSize: 28,
      focusColor: accent.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(14),
    ).copyWith(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: accent, width: 2.5);
        }
        return const BorderSide(color: Colors.transparent);
      }),
      shadowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return accent.withValues(alpha: 0.38);
        }
        return Colors.transparent;
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.focused) ? 5 : 0;
      }),
    );
  }

  static ButtonStyle _filledButtonStyle(Color accent) {
    return FilledButton.styleFrom(
      minimumSize: const Size(58, 58),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    ).copyWith(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: accent, width: 2.5);
        }
        return null;
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.focused) ? 5 : 0;
      }),
    );
  }

  static const _textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(fontSize: 18, letterSpacing: 0),
    bodyMedium: TextStyle(fontSize: 15, letterSpacing: 0),
  );
}
