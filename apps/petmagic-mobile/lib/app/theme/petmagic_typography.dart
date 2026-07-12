import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/theme/petmagic_theme_colors.dart';

abstract final class PetMagicTypography {
  static TextTheme build(
    PetMagicColors colors, {
    required Brightness brightness,
    required bool compactDisplay,
  }) {
    final compactLight = compactDisplay && brightness == Brightness.light;
    final base = Typography.material2021(platform: TargetPlatform.iOS).black
        .apply(bodyColor: colors.textStrong, displayColor: colors.textStrong);
    final bodyWeight = compactLight ? FontWeight.w600 : FontWeight.w500;

    return GoogleFonts.comfortaaTextTheme(base)
        .copyWith(
          displayLarge: _style(colors, 54, FontWeight.w700, 1.06),
          displayMedium: _style(colors, 44, FontWeight.w700, 1.06),
          displaySmall: _style(colors, 36, FontWeight.w700, 1.08),
          headlineLarge: _style(colors, 30, FontWeight.w700, 1.1),
          headlineMedium: _style(colors, 26, FontWeight.w700, 1.12),
          headlineSmall: _style(colors, 22, FontWeight.w700, 1.12),
          titleLarge: _style(
            colors,
            20,
            compactLight ? FontWeight.w800 : FontWeight.w700,
            1.14,
          ),
          titleMedium: _style(
            colors,
            15,
            compactLight ? FontWeight.w800 : FontWeight.w700,
            1.16,
          ),
          titleSmall: _style(
            colors,
            13,
            compactLight ? FontWeight.w800 : FontWeight.w700,
            1.16,
          ),
          bodyLarge: _style(colors, 15, bodyWeight, 1.22),
          bodyMedium: _style(colors, 13.5, bodyWeight, 1.24),
          bodySmall: _style(
            colors,
            12,
            bodyWeight,
            1.24,
            color: colors.textSoft,
          ),
          labelLarge: _style(colors, 13.5, FontWeight.w700, 1.14),
          labelMedium: _style(colors, 12, FontWeight.w700, 1.14),
          labelSmall: _style(
            colors,
            11,
            FontWeight.w700,
            1.12,
            color: colors.textSoft,
          ),
        )
        .apply(fontSizeFactor: compactLight ? 0.91 : 0.93);
  }

  static TextStyle _style(
    PetMagicColors colors,
    double size,
    FontWeight weight,
    double height, {
    Color? color,
  }) => GoogleFonts.comfortaa(
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color ?? colors.textStrong,
  );
}
