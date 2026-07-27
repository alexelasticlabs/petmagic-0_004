import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

void main() {
  test('PetMagicColors.lerp returns stable palette', () {
    const lightColors = PetMagicColors(
      backgroundTop: Color(0xFFFFFFFF),
      backgroundBottom: Color(0xFFF5F8FC),
      surface: Color(0xFFFFFFFF),
      surfaceGlass: Color(0xECFFFFFF),
      surfaceStrong: Color(0xFFF8FAFD),
      border: Color(0xFFE2E8F0),
      textStrong: Color(0xFF101B31),
      textSoft: Color(0xFF334155),
      textMuted: Color(0xFF8290A3),
      accent: Color(0xFF10C878),
      accentSoft: Color(0xFFE7FAF1),
      gold: Color(0xFFFFB703),
      purple: Color(0xFFA855F7),
      blue: Color(0xFF0EA5E9),
      danger: Color(0xFFEF4444),
      shadow: Color(0x1A0F172A),
    );

    const darkColors = PetMagicColors(
      backgroundTop: Color(0xFF000306),
      backgroundBottom: Color(0xFF04070D),
      surface: Color(0xFF0A121B),
      surfaceGlass: Color(0xCC101925),
      surfaceStrong: Color(0xFF141E2A),
      border: Color(0xFF1E2A38),
      textStrong: Color(0xFFF8FBFF),
      textSoft: Color(0xFFD0DAE6),
      textMuted: Color(0xFF7F8EA0),
      accent: Color(0xFF10C878),
      accentSoft: Color(0x2622C55E),
      gold: Color(0xFFFFC107),
      purple: Color(0xFFB56BFF),
      blue: Color(0xFF38BDF8),
      danger: Color(0xFFFB7185),
      shadow: Color(0xCC00040A),
    );

    final blended = lightColors.lerp(darkColors, 0.35);

    expect(blended, isA<PetMagicColors>());
    expect(blended.backgroundTop, isNot(equals(lightColors.backgroundTop)));
    expect(blended.backgroundTop, isNot(equals(darkColors.backgroundTop)));
  });

  test('PetMagicColors resolves readable foregrounds for custom tones', () {
    final light = AppTheme.light().extension<PetMagicColors>()!;
    final dark = AppTheme.dark().extension<PetMagicColors>()!;

    for (final colors in [light, dark]) {
      for (final background in [colors.accent, colors.gold, colors.purple]) {
        final foreground = colors.on(background);
        final contrast = _contrastRatio(foreground, background);

        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets('petMagicColors falls back safely for light ThemeData', (
    tester,
  ) async {
    late PetMagicColors colors;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Builder(
          builder: (context) {
            colors = context.petMagicColors;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(colors.backgroundTop, const Color(0xFFFAFBFC));
    expect(colors.textStrong, const Color(0xFF0F1D35));
  });

  testWidgets('petMagicColors falls back safely for dark ThemeData', (
    tester,
  ) async {
    late PetMagicColors colors;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            colors = context.petMagicColors;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(colors.backgroundTop, const Color(0xFF080D13));
    expect(colors.textStrong, const Color(0xFFF8FBFF));
  });
}

double _contrastRatio(Color foreground, Color background) {
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
