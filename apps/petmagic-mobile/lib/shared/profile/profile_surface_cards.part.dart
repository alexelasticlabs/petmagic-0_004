part of 'profile_surface_widgets.dart';

class ProfileScreenBackground extends StatelessWidget {
  const ProfileScreenBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.background),
        child: child,
      ),
    );
  }
}

class ProfileGlassCard extends StatelessWidget {
  const ProfileGlassCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final avoidBlur = PerformanceGuard.shouldAvoidBlur(context);
    final borderRadius = BorderRadius.circular(24);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass.withValues(alpha: isLight ? 0.98 : 1),
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.border.withValues(alpha: isLight ? 0.98 : 1),
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: isLight ? 0.28 : 1),
              blurRadius: isLight ? 22 : 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: avoidBlur
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: content,
                ),
        ),
      ),
    );
  }
}

const Color _kAccentCardDarkBase = Color(0xFF101923);
const Color _kAccentCardDarkTop = Color(0xFF172433);
const Color _kAccentCardDarkBottom = Color(0xFF0F1821);
const Color _kAccentCardLightBase = Color(0xFFF6FAFF);
const Color _kAccentCardLightTop = Color(0xFFFFFFFF);
const Color _kAccentCardLightBottom = Color(0xFFF0F5FB);

class PetMagicAccentCard extends StatelessWidget {
  const PetMagicAccentCard({
    required this.accentColor,
    required this.child,
    this.padding,
    this.borderOpacity = 0.26,
    this.glowOpacity = 0.16,
    this.showAccentGlow = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.glowAlignment = Alignment.centerLeft,
    this.glowRadius = 0.86,
    super.key,
  });

  final Color accentColor;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderOpacity;
  final double glowOpacity;
  final bool showAccentGlow;
  final BorderRadius borderRadius;
  final AlignmentGeometry glowAlignment;
  final double glowRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final avoidBlur = PerformanceGuard.shouldAvoidBlur(context);
    final baseColor = isLight ? _kAccentCardLightBase : _kAccentCardDarkBase;
    final topColor = isLight ? _kAccentCardLightTop : _kAccentCardDarkTop;
    final bottomColor = isLight
        ? _kAccentCardLightBottom
        : _kAccentCardDarkBottom;
    final borderColor = isLight
        ? Color.alphaBlend(
            accentColor.withValues(alpha: borderOpacity * 0.6),
            colors.border.withValues(alpha: 0.88),
          )
        : Color.alphaBlend(
            accentColor.withValues(alpha: borderOpacity),
            colors.border.withValues(alpha: 0.9),
          );

    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: baseColor,
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.42, 1],
          colors: [topColor, baseColor, bottomColor],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: isLight ? 0.26 : 0.045),
                      Colors.white.withValues(alpha: isLight ? 0.08 : 0.018),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showAccentGlow)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: RadialGradient(
                      center: glowAlignment,
                      radius: glowRadius,
                      colors: [
                        accentColor.withValues(alpha: glowOpacity),
                        accentColor.withValues(alpha: glowOpacity * 0.34),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
        ],
      ),
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: isLight ? 0.18 : 0.3),
              blurRadius: isLight ? 18 : 24,
              offset: Offset(0, isLight ? 9 : 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: avoidBlur
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: content,
                ),
        ),
      ),
    );
  }
}
