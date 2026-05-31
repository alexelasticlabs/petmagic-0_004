import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      backgroundTop: AppTheme._safeLerpColor(
        backgroundTop,
        other.backgroundTop,
        t,
      ),
      backgroundBottom: AppTheme._safeLerpColor(
        backgroundBottom,
        other.backgroundBottom,
        t,
      ),
      surface: AppTheme._safeLerpColor(surface, other.surface, t),
      surfaceGlass: AppTheme._safeLerpColor(
        surfaceGlass,
        other.surfaceGlass,
        t,
      ),
      surfaceStrong: AppTheme._safeLerpColor(
        surfaceStrong,
        other.surfaceStrong,
        t,
      ),
      border: AppTheme._safeLerpColor(border, other.border, t),
      textStrong: AppTheme._safeLerpColor(textStrong, other.textStrong, t),
      textSoft: AppTheme._safeLerpColor(textSoft, other.textSoft, t),
      textMuted: AppTheme._safeLerpColor(textMuted, other.textMuted, t),
      accent: AppTheme._safeLerpColor(accent, other.accent, t),
      accentSoft: AppTheme._safeLerpColor(accentSoft, other.accentSoft, t),
      gold: AppTheme._safeLerpColor(gold, other.gold, t),
      purple: AppTheme._safeLerpColor(purple, other.purple, t),
      blue: AppTheme._safeLerpColor(blue, other.blue, t),
      danger: AppTheme._safeLerpColor(danger, other.danger, t),
      shadow: AppTheme._safeLerpColor(shadow, other.shadow, t),
    );
  }
}

extension PetMagicTheme on BuildContext {
  PetMagicColors get petMagicColors {
    final theme = Theme.of(this);
    final colors = theme.extension<PetMagicColors>();
    if (colors != null) {
      return colors;
    }

    return AppTheme._fallbackColors(theme.brightness);
  }
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
}

class AppTheme {
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionMedium = Duration(milliseconds: 260);
  static const Duration motionSlow = Duration(milliseconds: 380);

  static const Curve motionEmphasized = Curves.easeOutCubic;
  static const Curve motionStandard = Curves.easeOut;

  static const _accent = Color(0xFF10C878);
  static const _onAccentDark = Color(0xFF04110B);
  static const _onAccentLight = Color(0xFFF8FBFF);

  static const PetMagicColors _lightColors = PetMagicColors(
    backgroundTop: Color(0xFFF9FAFC), // off-white top — cards (white) stand out
    backgroundBottom: Color(
      0xFFE7EDF5,
    ), // tinted bottom — stronger page gradient
    surface: Color(0xFFFFFFFF), // pure white cards on tinted background
    surfaceGlass: Color(0xFFF0F4FA), // glass containers — noticeably tinted
    surfaceStrong: Color(0xFFDCE5F0), // strong surfaces — clear hierarchy
    border: Color(0xFFA8B9CC), // stronger border — cards don't blend
    textStrong: Color(0xFF0F1D35),
    textSoft: Color(0xFF22354D),
    textMuted: Color(0xFF3F5268), // darker muted — meets AA on small text
    accent: _accent,
    accentSoft: Color(0xFFB4E5CF), // deeper soft-accent for readable badges
    gold: Color(0xFFFFB703),
    purple: Color(0xFFA855F7),
    blue: Color(0xFF0284C7),
    danger: Color(0xFFEF4444),
    shadow: Color(0x4210203A), // stronger shadow — card elevation visible
  );

  static const PetMagicColors _darkColors = PetMagicColors(
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
  );

  static ThemeData? _lightTheme;
  static ThemeData? _darkTheme;

  static ThemeData light() {
    return _lightTheme ??= _base(
      Brightness.light,
      _lightColors,
      compactDisplay: _isCompactDisplay(),
    );
  }

  static ThemeData dark() {
    return _darkTheme ??= _base(
      Brightness.dark,
      _darkColors,
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

  static PetMagicColors _fallbackColors(Brightness brightness) {
    return brightness == Brightness.dark ? _darkColors : _lightColors;
  }

  static Color _safeLerpColor(Color start, Color end, double t) {
    return Color.lerp(start, end, t) ?? (t < 0.5 ? start : end);
  }

  static Color _onColor(Color background) {
    final darkContrast = _contrastRatio(_onAccentDark, background);
    final lightContrast = _contrastRatio(_onAccentLight, background);
    return darkContrast >= lightContrast ? _onAccentDark : _onAccentLight;
  }

  static double _contrastRatio(Color foreground, Color background) {
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

  static ThemeData _base(
    Brightness brightness,
    PetMagicColors colors, {
    required bool compactDisplay,
  }) {
    final textTheme = _buildTextTheme(
      colors,
      brightness: brightness,
      compactDisplay: compactDisplay,
    );
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: brightness,
          primary: colors.accent,
          surface: colors.surface,
        ).copyWith(
          primary: colors.accent,
          onPrimary: _onColor(colors.accent),
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
          foregroundColor: _onColor(colors.accent),
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

  static TextTheme _buildTextTheme(
    PetMagicColors colors, {
    required Brightness brightness,
    required bool compactDisplay,
  }) {
    final compactLight = compactDisplay && brightness == Brightness.light;
    final displayLargeSize = compactLight ? 50.0 : 54.0;
    final displayMediumSize = compactLight ? 41.0 : 44.0;
    final displaySmallSize = compactLight ? 34.0 : 36.0;
    final headlineLargeSize = compactLight ? 28.0 : 30.0;
    final headlineMediumSize = compactLight ? 24.0 : 26.0;
    final headlineSmallSize = compactLight ? 20.5 : 22.0;
    final titleLargeSize = compactLight ? 19.0 : 20.0;
    final titleMediumSize = compactLight ? 14.5 : 15.0;
    final titleSmallSize = compactLight ? 12.5 : 13.0;
    final bodyLargeSize = compactLight ? 14.5 : 15.0;
    final bodyMediumSize = compactLight ? 13.0 : 13.5;
    final bodySmallSize = compactLight ? 11.5 : 12.0;
    final labelLargeSize = compactLight ? 13.0 : 13.5;
    final labelMediumSize = compactLight ? 11.5 : 12.0;
    final labelSmallSize = compactLight ? 10.5 : 11.0;
    final bodyWeight = compactLight ? FontWeight.w600 : FontWeight.w500;

    final base = Typography.material2021(platform: TargetPlatform.iOS).black
        .apply(bodyColor: colors.textStrong, displayColor: colors.textStrong);

    return GoogleFonts.comfortaaTextTheme(base)
        .copyWith(
          displayLarge: GoogleFonts.comfortaa(
            fontSize: displayLargeSize,
            fontWeight: FontWeight.w700,
            height: 1.06,
            color: colors.textStrong,
          ),
          displayMedium: GoogleFonts.comfortaa(
            fontSize: displayMediumSize,
            fontWeight: FontWeight.w700,
            height: 1.06,
            color: colors.textStrong,
          ),
          displaySmall: GoogleFonts.comfortaa(
            fontSize: displaySmallSize,
            fontWeight: FontWeight.w700,
            height: 1.08,
            color: colors.textStrong,
          ),
          headlineLarge: GoogleFonts.comfortaa(
            fontSize: headlineLargeSize,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: colors.textStrong,
          ),
          headlineMedium: GoogleFonts.comfortaa(
            fontSize: headlineMediumSize,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: colors.textStrong,
          ),
          headlineSmall: GoogleFonts.comfortaa(
            fontSize: headlineSmallSize,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: colors.textStrong,
          ),
          titleLarge: GoogleFonts.comfortaa(
            fontSize: titleLargeSize,
            fontWeight: compactLight ? FontWeight.w800 : FontWeight.w700,
            height: 1.14,
            color: colors.textStrong,
          ),
          titleMedium: GoogleFonts.comfortaa(
            fontSize: titleMediumSize,
            fontWeight: compactLight ? FontWeight.w800 : FontWeight.w700,
            height: 1.16,
            color: colors.textStrong,
          ),
          titleSmall: GoogleFonts.comfortaa(
            fontSize: titleSmallSize,
            fontWeight: compactLight ? FontWeight.w800 : FontWeight.w700,
            height: 1.16,
            color: colors.textStrong,
          ),
          bodyLarge: GoogleFonts.comfortaa(
            fontSize: bodyLargeSize,
            fontWeight: bodyWeight,
            height: 1.22,
            color: colors.textStrong,
          ),
          bodyMedium: GoogleFonts.comfortaa(
            fontSize: bodyMediumSize,
            fontWeight: bodyWeight,
            height: 1.24,
            color: colors.textStrong,
          ),
          bodySmall: GoogleFonts.comfortaa(
            fontSize: bodySmallSize,
            fontWeight: bodyWeight,
            height: 1.24,
            color: colors.textSoft,
          ),
          labelLarge: GoogleFonts.comfortaa(
            fontSize: labelLargeSize,
            fontWeight: FontWeight.w700,
            height: 1.14,
            color: colors.textStrong,
          ),
          labelMedium: GoogleFonts.comfortaa(
            fontSize: labelMediumSize,
            fontWeight: FontWeight.w700,
            height: 1.14,
            color: colors.textStrong,
          ),
          labelSmall: GoogleFonts.comfortaa(
            fontSize: labelSmallSize,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: colors.textSoft,
          ),
        )
        .apply(fontSizeFactor: compactLight ? 0.91 : 0.93);
  }
}
