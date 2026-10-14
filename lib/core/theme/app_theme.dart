import 'package:flutter/material.dart';
import '../../theme/app_theme.dart' as existing;
export '../../theme/app_theme.dart' show AppColors, AppRadius;

abstract final class AppTheme {
  static const charcoal = existing.AppColors.ink;
  static const lime = existing.AppColors.accent;
  static const sage = Color(0xFFF0F4D9),
      sky = Color(0xFFE4EDF7),
      peach = Color(0xFFFBEADA),
      mint = Color(0xFFDCF1E6),
      lilac = Color(0xFFECE7F7),
      muted = existing.AppColors.muted,
      bodyMuted = Color(0xFF7B8590),
      border = existing.AppColors.cardBorder;
  static ThemeData get light => existing.AppTheme.light;
  static TextStyle heading(double size,
          {FontWeight weight = FontWeight.w700, Color color = charcoal}) =>
      TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: size,
          fontWeight: weight,
          letterSpacing: 0,
          height: 1.15,
          color: color);
}
