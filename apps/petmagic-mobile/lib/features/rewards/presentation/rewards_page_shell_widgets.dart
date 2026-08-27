part of 'rewards_page.dart';

class _RewardsBackdrop extends StatelessWidget {
  const _RewardsBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final topGlowColor = colors.accent.withValues(alpha: 0.12);
    final sideGlowColor = colors.blue.withValues(alpha: 0.07);
    final pawColor = colors.accent.withValues(alpha: 0.12);
    final sparkColor = colors.gold.withValues(alpha: 0.9);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -88,
            right: -96,
            child: _GlowOrb(size: 220, color: topGlowColor),
          ),
          Positioned(
            top: 120,
            left: -104,
            child: _GlowOrb(size: 180, color: sideGlowColor),
          ),
          Positioned(
            top: 44,
            right: 108,
            child: _DecorativePaw(size: 36, color: pawColor, turns: -0.12),
          ),
          Positioned(
            top: 74,
            left: 154,
            child: _DecorativePaw(size: 34, color: pawColor, turns: 0.1),
          ),
          Positioned(
            top: 112,
            right: 20,
            child: _DecorativeSpark(size: 18, color: sparkColor),
          ),
          Positioned(
            top: 154,
            left: 196,
            child: _DecorativeSpark(size: 14, color: sparkColor),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _DecorativePaw extends StatelessWidget {
  const _DecorativePaw({
    required this.size,
    required this.color,
    required this.turns,
  });

  final double size;
  final Color color;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: turns,
        child: Icon(Icons.pets_rounded, size: size, color: color),
      ),
    );
  }
}

class _DecorativeSpark extends StatelessWidget {
  const _DecorativeSpark({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Icon(Icons.auto_awesome_rounded, size: size, color: color),
    );
  }
}

class _RewardsHero extends StatelessWidget {
  const _RewardsHero({required this.balance, required this.onHistoryTap});

  final int? balance;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final balanceValue = balance == null
        ? text.profileLoadingAction
        : NumberFormat.decimalPattern(localeTag).format(balance);

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroWidth = constraints.maxWidth;
        final subtitleWidth = heroWidth * 0.52;

        return SizedBox(
          height: 238,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.rewardsPageTitle,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 33,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: colors.shadow.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: subtitleWidth,
                            child: Text(
                              text.rewardsPageSubtitle,
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HistoryButton(onPressed: onHistoryTap),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 104,
                  child: _BalancePanel(
                    balanceValue: balanceValue,
                    unit: text.walletBalanceUnit,
                    rightInset: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final buttonBackground = colors.surfaceGlass;
    final buttonBorder = colors.border;
    final accentColor = colors.accent;
    final borderRadius = BorderRadius.circular(14);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: buttonBackground,
            borderRadius: borderRadius,
            border: Border.all(color: buttonBorder),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 17,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                text.rewardsHistoryTitle,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({
    required this.balanceValue,
    required this.unit,
    required this.rightInset,
  });

  final String balanceValue;
  final String unit;
  final double rightInset;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final panelBorder = colors.accent.withValues(alpha: 0.38);
    final eyebrowColor = colors.accent;

    return Container(
      height: 98,
      padding: EdgeInsets.fromLTRB(16, 12, rightInset, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colors.surfaceStrong,
        border: Border.all(color: panelBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 54,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text.walletBalanceEyebrow,
                  maxLines: 1,
                  style: TextStyle(
                    color: eyebrowColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          balanceValue,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 39,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const PawSparkIcon(size: 22),
                        const SizedBox(width: 6),
                        Text(
                          unit,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsGlassPanel extends StatelessWidget {
  const _RewardsGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? borderColor;

  static const _radius = 26.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final borderRadius = BorderRadius.circular(_radius);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient:
            gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surfaceGlass,
                colors.surfaceStrong.withValues(alpha: 0.94),
              ],
            ),
        border: Border.all(color: borderColor ?? colors.border, width: 1.1),
      ),
      child: Padding(padding: padding, child: child),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.26),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: PerformanceGuard.shouldAvoidBlur(context)
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: content,
              ),
      ),
    );
  }
}
