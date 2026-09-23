import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens pulled from the MoveTraq design spec.
class AppColors {
  AppColors._();

  static const Color accent = Color(0xFFCBF24A); // lime accent (--ac)
  static const Color ink = Color(0xFF101319); // near-black text / surfaces
  static const Color inkSoft = Color(0xFF6A7280);
  static const Color muted = Color(0xFF9AA3AF);
  static const Color faint = Color(0xFFC9CDD4);
  static const Color border = Color(0x1A101319); // rgba(16,19,25,.1)
  static const Color borderSoft = Color(0x0F101319); // rgba(16,19,25,.06)
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color pageBg = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF0C0F14);
  static const Color darkSurface2 = Color(0xFF12151C);
  static const Color success = Color(0xFF12B76A);
  static const Color successDeep = Color(0xFF0F9D58);
  static const Color danger = Color(0xFFF2544B);
  static const Color warning = Color(0xFFF5A524);
  static const Color info = Color(0xFF2F6FD1);

  static const Map<String, Color> tint = {
    'lime': Color(0xFFF0F4D9),
    'sky': Color(0xFFE4EDF7),
    'peach': Color(0xFFFBEADA),
    'mint': Color(0xFFDCF1E6),
    'lilac': Color(0xFFECE7F7),
    'sand': Color(0xFFF3ECE1),
  };
}

class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme => TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700, letterSpacing: -0.035, color: AppColors.ink),
        headlineMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700, letterSpacing: -0.03, color: AppColors.ink),
        titleLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600, letterSpacing: -0.02, color: AppColors.ink),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: AppColors.ink),
        bodyMedium: GoogleFonts.inter(fontSize: 13.5, color: AppColors.inkSoft),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.ink),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.ink,
          secondary: AppColors.accent,
          surface: AppColors.cardBg,
          brightness: Brightness.light,
        ),
        fontFamily: GoogleFonts.inter().fontFamily,
        textTheme: _textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: AppColors.ink),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
          ),
        ),
      );
}

/// Common corner radii / spacing used across MoveTraq cards.
class AppRadius {
  AppRadius._();
  static const double card = 22;
  static const double cardLg = 26;
  static const double pill = 100;
  static const double button = 16;
}
