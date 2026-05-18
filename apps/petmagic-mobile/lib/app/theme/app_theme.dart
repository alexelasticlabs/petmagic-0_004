import 'package:flutter/material.dart';

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

  static ThemeData light() {
    const colors = PetMagicColors(
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
    );
    return _base(Brightness.light, colors);
  }

  static ThemeData dark() {
    const colors = PetMagicColors(
      backgroundTop: Color(0xFF020811),
      backgroundBottom: Color(0xFF07111E),
      surface: Color(0xFF101A27),
      surfaceGlass: Color(0xD9142233),
      surfaceStrong: Color(0xFF182434),
      border: Color(0xFF263445),
      textStrong: Color(0xFFF8FBFF),
      textSoft: Color(0xFFD6E0EC),
      textMuted: Color(0xFF8A99AA),
      accent: _accent,
      accentSoft: Color(0x3322C55E),
      gold: Color(0xFFFFC107),
      purple: Color(0xFFB56BFF),
      blue: Color(0xFF38BDF8),
      danger: Color(0xFFFB7185),
      shadow: Color(0x99000612),
    );
    return _base(Brightness.dark, colors);
  }

  static ThemeData _base(Brightness brightness, PetMagicColors colors) {
    final textTheme = Typography.material2021(platform: TargetPlatform.iOS)
        .black
        .apply(bodyColor: colors.textStrong, displayColor: colors.textStrong);

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
}
