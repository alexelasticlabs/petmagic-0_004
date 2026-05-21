import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class PetMagicColors extends ThemeExtension<PetMagicColors> {
  const PetMagicColors({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceGlass,
    required this.surfaceStrong,
    required this.border,
    required this.textStrong,
    required this.textSoft,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.gold,
    required this.purple,
    required this.blue,
    required this.danger,
    required this.shadow,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color surfaceGlass;
  final Color surfaceStrong;
  final Color border;
  final Color textStrong;
  final Color textSoft;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color gold;
  final Color purple;
  final Color blue;
  final Color danger;
  final Color shadow;

  @override
  PetMagicColors copyWith({
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? surface,
    Color? surfaceGlass,
    Color? surfaceStrong,
    Color? border,
    Color? textStrong,
    Color? textSoft,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? gold,
    Color? purple,
    Color? blue,
    Color? danger,
    Color? shadow,
  }) {
    return PetMagicColors(
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      surface: surface ?? this.surface,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      border: border ?? this.border,
      textStrong: textStrong ?? this.textStrong,
      textSoft: textSoft ?? this.textSoft,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      gold: gold ?? this.gold,
      purple: purple ?? this.purple,
      blue: blue ?? this.blue,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  PetMagicColors lerp(ThemeExtension<PetMagicColors>? other, double t) {
    if (other is! PetMagicColors) {
      return this;
    }

    return PetMagicColors(
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textSoft: Color.lerp(textSoft, other.textSoft, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension PetMagicTheme on BuildContext {
  PetMagicColors get petMagicColors =>
      Theme.of(this).extension<PetMagicColors>()!;
}

class AppTheme {
  static const _accent = Color(0xFF10C878);

  static final ThemeData _lightTheme = _base(
    Brightness.light,
    const PetMagicColors(
      backgroundTop: Color(0xFFFFFFFF),
      backgroundBottom: Color(0xFFF5F8FC),
      surface: Color(0xFFFFFFFF),
      surfaceGlass: Color(0xECFFFFFF),
      surfaceStrong: Color(0xFFF8FAFD),
      border: Color(0xFFE2E8F0),
      textStrong: Color(0xFF101B31),
      textSoft: Color(0xFF334155),
      textMuted: Color(0xFF8290A3),
      accent: _accent,
      accentSoft: Color(0xFFE7FAF1),
      gold: Color(0xFFFFB703),
      purple: Color(0xFFA855F7),
      blue: Color(0xFF0EA5E9),
      danger: Color(0xFFEF4444),
      shadow: Color(0x1A0F172A),
    ),
  );

  static final ThemeData _darkTheme = _base(
    Brightness.dark,
    const PetMagicColors(
      backgroundTop: Color(0xFF000306),
      backgroundBottom: Color(0xFF04070D),
      surface: Color(0xFF0A121B),
      surfaceGlass: Color(0xCC101925),
      surfaceStrong: Color(0xFF141E2A),
      border: Color(0xFF1E2A38),
      textStrong: Color(0xFFF8FBFF),
      textSoft: Color(0xFFD0DAE6),
      textMuted: Color(0xFF7F8EA0),
      accent: _accent,
      accentSoft: Color(0x2622C55E),
      gold: Color(0xFFFFC107),
      purple: Color(0xFFB56BFF),
      blue: Color(0xFF38BDF8),
      danger: Color(0xFFFB7185),
      shadow: Color(0xCC00040A),
    ),
  );

  static ThemeData light() => _lightTheme;

  static ThemeData dark() => _darkTheme;

  static ThemeData _base(Brightness brightness, PetMagicColors colors) {
    final textTheme = _buildTextTheme(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: brightness,
        primary: colors.accent,
        surface: colors.surface,
      ),
      scaffoldBackgroundColor: colors.backgroundBottom,
      extensions: [colors],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          backgroundColor: colors.accent,
          foregroundColor: brightness == Brightness.dark
              ? const Color(0xFF04110B)
              : const Color(0xFF082313),
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.textMuted,
          elevation: 0.8,
          shadowColor: colors.accent.withValues(alpha: 0.22),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: colors.textStrong,
          backgroundColor: colors.surfaceGlass,
          side: BorderSide(color: colors.border),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 12.8,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceGlass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: colors.accent, width: 1.4),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(PetMagicColors colors) {
    final base = Typography.material2021(platform: TargetPlatform.iOS).black
        .apply(bodyColor: colors.textStrong, displayColor: colors.textStrong);

    return GoogleFonts.comfortaaTextTheme(base)
        .copyWith(
          displayLarge: GoogleFonts.comfortaa(
            fontSize: 54,
            fontWeight: FontWeight.w700,
            height: 1.06,
            color: colors.textStrong,
          ),
          displayMedium: GoogleFonts.comfortaa(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            height: 1.06,
            color: colors.textStrong,
          ),
          displaySmall: GoogleFonts.comfortaa(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.08,
            color: colors.textStrong,
          ),
          headlineLarge: GoogleFonts.comfortaa(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: colors.textStrong,
          ),
          headlineMedium: GoogleFonts.comfortaa(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: colors.textStrong,
          ),
          headlineSmall: GoogleFonts.comfortaa(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: colors.textStrong,
          ),
          titleLarge: GoogleFonts.comfortaa(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.14,
            color: colors.textStrong,
          ),
          titleMedium: GoogleFonts.comfortaa(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.16,
            color: colors.textStrong,
          ),
          titleSmall: GoogleFonts.comfortaa(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.16,
            color: colors.textStrong,
          ),
          bodyLarge: GoogleFonts.comfortaa(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.22,
            color: colors.textStrong,
          ),
          bodyMedium: GoogleFonts.comfortaa(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.24,
            color: colors.textStrong,
          ),
          bodySmall: GoogleFonts.comfortaa(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.24,
            color: colors.textSoft,
          ),
          labelLarge: GoogleFonts.comfortaa(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.14,
            color: colors.textStrong,
          ),
          labelMedium: GoogleFonts.comfortaa(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.14,
            color: colors.textStrong,
          ),
          labelSmall: GoogleFonts.comfortaa(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: colors.textSoft,
          ),
        )
        .apply(fontSizeFactor: 0.93);
  }
}
