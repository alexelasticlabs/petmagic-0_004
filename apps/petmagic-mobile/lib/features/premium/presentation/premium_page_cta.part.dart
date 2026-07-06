part of 'premium_page.dart';

class _CtaButton extends StatefulWidget {
  const _CtaButton({
    required this.state,
    required this.isDark,
    required this.onStartCheckout,
  });

  final PremiumState state;
  final bool isDark;
  final Future<void> Function() onStartCheckout;

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void deactivate() {
    _pulseController.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncAnimationState();
  }

  @override
  void dispose() {
    _pulseController.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final text = _premiumText(context);
    final isDark = widget.isDark;
    final isCheckoutDisabled =
        state.isBuying ||
        state.isPremium ||
        state.recentlyActivatedPremium ||
        !state.canStartCheckout;
    final providerLabel = switch (state.selectedProvider) {
      PremiumPaymentProvider.stripe => text.premiumPaymentStripe,
      PremiumPaymentProvider.googlePlay => text.premiumPaymentGooglePlay,
      PremiumPaymentProvider.appStore => text.premiumPaymentApple,
    };
    final ctaLabel = text.paymentContinueViaProviderAction(providerLabel);
    final colors = context.petMagicColors;
    final gradientEnd = isDark
        ? const Color(0xFFFFB300)
        : const Color(0xFFCC9A2D);
    final btnTextColor = colors.on(gradientEnd);
    final glowColor = isDark
        ? const Color(0xFFFFB300)
        : const Color(0xFFE0AB33);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = state.isBuying ? 0.0 : _pulseController.value;
        final animatedBlur = 16 + (t * 8);

        return Transform.scale(
          scale: state.isBuying ? 1 : (0.995 + (t * 0.012)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFFFFE07C), Color(0xFFFFB300)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFE4BB56), Color(0xFFCC9A2D)],
                    ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(
                    alpha: state.isBuying ? 0.22 : 0.32,
                  ),
                  blurRadius: animatedBlur,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: ElevatedButton(
        onPressed: isCheckoutDisabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                unawaited(widget.onStartCheckout());
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: btnTextColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: state.isBuying
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: btnTextColor,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PremiumCrownIcon(size: 26, opacity: btnTextColor.a),
                  const SizedBox(width: 8),
                  Text(
                    ctaLabel,
                    style: TextStyle(
                      color: btnTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _syncAnimationState() {
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      return;
    }

    if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }
}

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) {
        return;
      }
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
