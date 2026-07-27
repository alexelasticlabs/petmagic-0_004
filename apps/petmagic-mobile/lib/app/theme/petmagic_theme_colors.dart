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
  }) => PetMagicColors(
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

  @override
  PetMagicColors lerp(ThemeExtension<PetMagicColors>? other, double t) {
    if (other is! PetMagicColors) return this;
    return PetMagicColors(
      backgroundTop: _safeLerp(backgroundTop, other.backgroundTop, t),
      backgroundBottom: _safeLerp(backgroundBottom, other.backgroundBottom, t),
      surface: _safeLerp(surface, other.surface, t),
      surfaceGlass: _safeLerp(surfaceGlass, other.surfaceGlass, t),
      surfaceStrong: _safeLerp(surfaceStrong, other.surfaceStrong, t),
      border: _safeLerp(border, other.border, t),
      textStrong: _safeLerp(textStrong, other.textStrong, t),
      textSoft: _safeLerp(textSoft, other.textSoft, t),
      textMuted: _safeLerp(textMuted, other.textMuted, t),
      accent: _safeLerp(accent, other.accent, t),
      accentSoft: _safeLerp(accentSoft, other.accentSoft, t),
      gold: _safeLerp(gold, other.gold, t),
      purple: _safeLerp(purple, other.purple, t),
      blue: _safeLerp(blue, other.blue, t),
      danger: _safeLerp(danger, other.danger, t),
      shadow: _safeLerp(shadow, other.shadow, t),
    );
  }
}

abstract final class PetMagicPalettes {
  static const accent = Color(0xFF10C878);
  static const onAccentDark = Color(0xFF04110B);
  static const onAccentLight = Color(0xFFF8FBFF);

  static const light = PetMagicColors(
    backgroundTop: Color(0xFFFAFBFC),
    backgroundBottom: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceGlass: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFEAF0F6),
    border: Color(0xFFD8E1EA),
    textStrong: Color(0xFF0F1D35),
    textSoft: Color(0xFF22354D),
    textMuted: Color(0xFF3F5268),
    accent: accent,
    accentSoft: Color(0xFFB4E5CF),
    gold: Color(0xFFFFB703),
    purple: Color(0xFFA855F7),
    blue: Color(0xFF0284C7),
    danger: Color(0xFFEF4444),
    shadow: Color(0x4210203A),
  );

  static const dark = PetMagicColors(
    backgroundTop: Color(0xFF080D13),
    backgroundBottom: Color(0xFF0B1016),
    surface: Color(0xFF101720),
    surfaceGlass: Color(0xFF141D27),
    surfaceStrong: Color(0xFF1B2632),
    border: Color(0xFF2A3746),
    textStrong: Color(0xFFF8FBFF),
    textSoft: Color(0xFFD0DAE6),
    textMuted: Color(0xFF7F8EA0),
    accent: accent,
    accentSoft: Color(0x2622C55E),
    gold: Color(0xFFFFC107),
    purple: Color(0xFFB56BFF),
    blue: Color(0xFF38BDF8),
    danger: Color(0xFFFB7185),
    shadow: Color(0xCC000000),
  );

  static PetMagicColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static Color onColor(Color background) {
    final darkContrast = contrastRatio(onAccentDark, background);
    final lightContrast = contrastRatio(onAccentLight, background);
    return darkContrast >= lightContrast ? onAccentDark : onAccentLight;
  }

  static double contrastRatio(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

extension PetMagicTheme on BuildContext {
  PetMagicColors get petMagicColors =>
      Theme.of(this).extension<PetMagicColors>() ??
      PetMagicPalettes.forBrightness(Theme.of(this).brightness);
}

extension PetMagicSemanticTokens on PetMagicColors {
  Color get background => backgroundBottom;
  Color get surfaceVariant => surfaceStrong;
  Color get cardBackground => surface;
  Color get primaryText => textStrong;
  Color get secondaryText => textSoft;
  Color get mutedText => textMuted;
  Color get divider => border;
  Color get primary => accent;
  Color get primaryContainer => accentSoft;
  Color get success => accent;
  Color get warning => gold;
  Color get error => danger;
  Color get disabled => surfaceStrong;

  Color on(Color background) => PetMagicPalettes.onColor(background);
}

Color _safeLerp(Color start, Color end, double t) =>
    Color.lerp(start, end, t) ?? (t < 0.5 ? start : end);
