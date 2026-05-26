part of 'rewards_page.dart';

class _RewardsBackdrop extends StatelessWidget {
  const _RewardsBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF030A14), Color(0xFF01060D)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -88,
            right: -96,
            child: _GlowOrb(
              size: 220,
              color: const Color(0xFF0EA86D).withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            top: 120,
            left: -104,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFF1E8CFF).withValues(alpha: 0.05),
            ),
          ),
          const Positioned(
            top: 44,
            right: 108,
            child: _DecorativePaw(size: 36, opacity: 0.12, turns: -0.12),
          ),
          const Positioned(
            top: 74,
            left: 154,
            child: _DecorativePaw(size: 34, opacity: 0.1, turns: 0.1),
          ),
          const Positioned(
            top: 112,
            right: 20,
            child: _DecorativeSpark(size: 18),
          ),
          const Positioned(
            top: 154,
            left: 196,
            child: _DecorativeSpark(size: 14),
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
    required this.opacity,
    required this.turns,
  });

  final double size;
  final double opacity;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: turns,
        child: Icon(
          Icons.pets_rounded,
          size: size,
          color: const Color(0xFF38D77A).withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _DecorativeSpark extends StatelessWidget {
  const _DecorativeSpark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size,
        color: const Color(0xFFFFF0A6).withValues(alpha: 0.95),
      ),
    );
  }
}

class _RewardsHero extends StatelessWidget {
  const _RewardsHero({required this.balance, required this.onHistoryTap});

  static const _balanceImage = 'assets/rewards/balance.png';

  final int? balance;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final balanceValue = balance == null
        ? '...'
        : NumberFormat.decimalPattern(localeTag).format(balance);

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroWidth = constraints.maxWidth;
        final imageWidth = (heroWidth * 0.42).clamp(132.0, 176.0);
        final subtitleWidth = heroWidth * 0.52;
        final balanceRightInset = (imageWidth * 0.74).clamp(104.0, 130.0);

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
                                  color: Colors.black.withValues(alpha: 0.4),
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: _BalancePanel(
                          balanceValue: balanceValue,
                          unit: text.walletBalanceUnit,
                          rightInset: balanceRightInset,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: -2,
                        child: IgnorePointer(
                          child: Image.asset(
                            _balanceImage,
                            width: imageWidth,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF07111C).withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF243143)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_toggle_off_rounded,
                size: 17,
                color: Color(0xFF38E681),
              ),
              const SizedBox(width: 8),
              Text(
                text.rewardsHistoryTitle,
                style: const TextStyle(
                  color: Color(0xFF48E581),
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

    return Container(
      height: 98,
      padding: EdgeInsets.fromLTRB(16, 12, rightInset, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF042E25).withValues(alpha: 0.95),
            const Color(0xFF0C6A40).withValues(alpha: 0.68),
            const Color(0xFF0A1A22).withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF136746).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0DD978).withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text.walletBalanceEyebrow,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF44E681),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            gradient:
                gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF121D2C).withValues(alpha: 0.9),
                    const Color(0xFF07101A).withValues(alpha: 0.92),
                  ],
                ),
            border: Border.all(
              color: borderColor ?? const Color(0xFF1D2B3C),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
