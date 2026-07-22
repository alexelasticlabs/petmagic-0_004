import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petmagic_mobile/app/theme/petmagic_design_tokens.dart';
import 'package:petmagic_mobile/app/theme/petmagic_theme_colors.dart';
import 'package:petmagic_mobile/app/theme/petmagic_typography.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_page_transitions.dart';

export 'petmagic_design_tokens.dart';
export 'petmagic_theme_colors.dart';

class AppTheme {
  static const Duration motionFast = PetMagicMotion.fast;
  static const Duration motionMedium = PetMagicMotion.medium;
  static const Duration motionSlow = PetMagicMotion.slow;
  static const Curve motionEmphasized = PetMagicMotion.emphasized;
  static const Curve motionStandard = PetMagicMotion.standard;

  static ThemeData? _lightTheme;
  static ThemeData? _darkTheme;

  static ThemeData light() {
    return _lightTheme ??= _base(
      Brightness.light,
      PetMagicPalettes.light,
      compactDisplay: _isCompactDisplay(),
    );
  }

  static ThemeData dark() {
    return _darkTheme ??= _base(
      Brightness.dark,
      PetMagicPalettes.dark,
      compactDisplay: _isCompactDisplay(),
    );
  }

  static bool _isCompactDisplay() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return false;
    }

    final primaryView = views.first;
    final logicalWidth =
        primaryView.physicalSize.width / primaryView.devicePixelRatio;
    return logicalWidth <= 380;
  }

  static ThemeData _base(
    Brightness brightness,
    PetMagicColors colors, {
    required bool compactDisplay,
  }) {
    final textTheme = PetMagicTypography.build(
      colors,
      brightness: brightness,
      compactDisplay: compactDisplay,
    );
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: PetMagicPalettes.accent,
          brightness: brightness,
          primary: colors.accent,
          surface: colors.surface,
        ).copyWith(
          primary: colors.accent,
          onPrimary: PetMagicPalettes.onColor(colors.accent),
          surface: colors.surface,
          onSurface: colors.textStrong,
          onSurfaceVariant: colors.textSoft,
          outline: colors.border,
          shadow: colors.shadow,
          surfaceContainerHighest: colors.surfaceStrong,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.backgroundBottom,
      extensions: [colors],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textStrong,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textStrong,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: brightness == Brightness.light ? 2.2 : 0.3,
        shadowColor: colors.shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border, width: 1.05),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        space: 1,
        thickness: 1.05,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PetMagicPageTransitionsBuilder(),
          TargetPlatform.iOS: PetMagicPageTransitionsBuilder(),
          TargetPlatform.macOS: PetMagicPageTransitionsBuilder(),
        },
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        modalBarrierColor: Colors.black.withValues(
          alpha: brightness == Brightness.dark ? 0.62 : 0.38,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: colors.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: brightness == Brightness.light ? 8 : 2,
        shadowColor: colors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceStrong;
          }
          if (states.contains(WidgetState.selected)) {
            return colors.accent;
          }
          return colors.surface;
        }),
        checkColor: WidgetStatePropertyAll(
          PetMagicPalettes.onColor(colors.accent),
        ),
        side: BorderSide(color: colors.border, width: 1.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textMuted;
          }
          if (states.contains(WidgetState.selected)) {
            return PetMagicPalettes.onColor(colors.accent);
          }
          return colors.textSoft;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceStrong.withValues(alpha: 0.62);
          }
          if (states.contains(WidgetState.selected)) {
            return colors.accent.withValues(alpha: 0.72);
          }
          return colors.surfaceStrong;
        }),
        trackOutlineColor: WidgetStatePropertyAll(colors.border),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSoft,
        textColor: colors.textStrong,
        tileColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          backgroundColor: colors.accent,
          foregroundColor: PetMagicPalettes.onColor(colors.accent),
          disabledBackgroundColor: colors.surfaceStrong,
          disabledForegroundColor: colors.textMuted.withValues(alpha: 0.88),
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
          backgroundColor: colors.surface,
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
        fillColor: colors.surface,
        hintStyle: TextStyle(
          color: colors.textMuted.withValues(alpha: 0.88),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}
