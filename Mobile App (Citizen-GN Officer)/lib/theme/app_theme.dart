import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary: hsl(232, 66%, 30%) → navy blue
  static const primary = Color(0xFF1B2E8F);
  static const primaryForeground = Colors.white;

  // Secondary: Sky Blue for a blue-white aesthetic
  static const secondary = Color(0xFF0EA5E9);
  static const secondaryForeground = Colors.white;

  // Background: hsl(210, 25%, 97.6%) → very light blue-grey
  static const background = Color(0xFFF4F6F9);

  // Card: white
  static const card = Colors.white;
  static const cardForeground = Color(0xFF424242);

  // Foreground: hsl(0,0%,25.9%)
  static const foreground = Color(0xFF424242);

  // Muted: hsl(210,17%,93%)
  static const muted = Color(0xFFE8ECF0);
  static const mutedForeground = Color(0xFF737373);

  // Warning: hsl(27,100%,47%) → orange
  static const warning = Color(0xFFEF7000);
  static const warningForeground = Colors.white;

  // Success: green (kept separate from secondary)
  static const success = Color(0xFF28A745);
  static const successForeground = Colors.white;

  // Destructive
  static const destructive = Color(0xFFEF4444);
  static const destructiveForeground = Colors.white;

  // Border
  static const border = Color(0xFFDEE4EA);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
        error: AppColors.destructive,
        onError: AppColors.destructiveForeground,
        surface: AppColors.background,
        onSurface: AppColors.foreground,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.openSansTextTheme().copyWith(
        displayLarge: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: AppColors.primary),
        displayMedium: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: AppColors.primary),
        displaySmall: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: AppColors.primary),
        headlineLarge: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: AppColors.primary),
        headlineMedium: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: AppColors.primary),
        headlineSmall: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: AppColors.primary),
        titleLarge: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: AppColors.foreground),
        titleMedium: GoogleFonts.roboto(fontWeight: FontWeight.w600, color: AppColors.foreground),
        bodyLarge: GoogleFonts.openSans(color: AppColors.foreground),
        bodyMedium: GoogleFonts.openSans(color: AppColors.foreground),
        bodySmall: GoogleFonts.openSans(color: AppColors.mutedForeground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: GoogleFonts.openSans(color: AppColors.mutedForeground),
        labelStyle: GoogleFonts.openSans(color: AppColors.foreground, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        elevation: 0,
        titleTextStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: AppColors.primaryForeground,
        ),
      ),
    );
  }
}
