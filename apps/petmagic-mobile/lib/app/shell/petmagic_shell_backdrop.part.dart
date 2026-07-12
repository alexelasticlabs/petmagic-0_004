part of 'petmagic_shell.dart';

class _BottomNavBackdrop extends StatelessWidget {
  const _BottomNavBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isDegraded = PerformanceGuard.isDegradedMode(context);
    final disableGlass = PerformanceGuard.shouldDisableGlassEffects(context);
    final blurSigma = switch ((defaultTargetPlatform, isDegraded)) {
      (TargetPlatform.android, true) => 0.0,
      (TargetPlatform.android, false) => 10.0,
      (_, true) => 8.0,
      _ => 18.0,
    };
    final blurTopInset = isDegraded ? 10.0 : 16.0;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final backdropExtra = disableGlass ? 44.0 : _bottomNavBackdropExtra;
    final height =
        bottomPadding + _bottomNavHeight + _bottomNavOuterGap + backdropExtra;
    final blurLayer = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            colors.surface.withValues(alpha: isLight ? 0.02 : 0.015),
            colors.surface.withValues(alpha: isLight ? 0.06 : 0.04),
            colors.surface.withValues(alpha: isLight ? 0.16 : 0.09),
            colors.surface.withValues(alpha: isLight ? 0.30 : 0.17),
            colors.surface.withValues(alpha: isLight ? 0.40 : 0.23),
          ],
          stops: const [0, 0.28, 0.50, 0.68, 0.84, 0.94, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
    final bottomTint = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            colors.backgroundBottom.withValues(alpha: isLight ? 0.03 : 0.02),
            colors.backgroundBottom.withValues(alpha: isLight ? 0.11 : 0.06),
            colors.backgroundBottom.withValues(alpha: isLight ? 0.24 : 0.14),
            colors.backgroundBottom.withValues(alpha: isLight ? 0.36 : 0.22),
          ],
          stops: const [0, 0.34, 0.58, 0.80, 0.93, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
    final navCoreTintHeight = bottomPadding + _bottomNavHeight + 40;
    final navCoreTint = Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: SizedBox(
          height: navCoreTintHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  colors.backgroundBottom.withValues(
                    alpha: isLight ? 0.24 : 0.16,
                  ),
                  colors.backgroundBottom.withValues(
                    alpha: isLight ? 0.70 : 0.46,
                  ),
                  colors.backgroundBottom.withValues(alpha: 1),
                ],
                stops: const [0, 0.28, 0.66, 1],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final bottomEdgeShade = Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: SizedBox(
          height: bottomPadding + 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  colors.backgroundBottom.withValues(
                    alpha: isLight ? 0.72 : 0.82,
                  ),
                  colors.backgroundBottom.withValues(alpha: 1),
                ],
                stops: const [0, 0.58, 1],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!disableGlass)
                Padding(
                  padding: EdgeInsets.only(top: blurTopInset),
                  child: ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.42),
                          Colors.white.withValues(alpha: 0.86),
                          Colors.white.withValues(alpha: 0.96),
                          Colors.white,
                        ],
                        stops: const [0, 0.14, 0.38, 0.64, 0.84, 0.94, 1],
                      ).createShader(bounds),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: blurLayer,
                      ),
                    ),
                  ),
                ),
              bottomTint,
              navCoreTint,
              bottomEdgeShade,
            ],
          ),
        ),
      ),
    );
  }
}
