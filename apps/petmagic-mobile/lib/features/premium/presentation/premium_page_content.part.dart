part of 'premium_page.dart';

class _PremiumBody extends StatelessWidget {
  const _PremiumBody({
    super.key,
    required this.state,
    required this.controller,
    required this.isDark,
    required this.onOpenUrl,
    required this.onStartCheckout,
    required this.onClose,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;
  final Future<void> Function(String) onOpenUrl;
  final Future<void> Function() onStartCheckout;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        _Header(
          state: state,
          controller: controller,
          isDark: isDark,
          onClose: onClose,
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FadeSlideIn(delayMs: 40, child: _HeroBlock(isDark: isDark)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FadeSlideIn(
                  delayMs: 120,
                  child: _ComparisonCard(isDark: isDark),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FadeSlideIn(
                  delayMs: 190,
                  child: _PlansSection(
                    state: state,
                    controller: controller,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _FadeSlideIn(
                delayMs: 250,
                child: _BenefitsSection(isDark: isDark),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FadeSlideIn(
                  delayMs: 320,
                  child: _CtaButton(
                    state: state,
                    isDark: isDark,
                    onStartCheckout: onStartCheckout,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _FadeSlideIn(
                  delayMs: 380,
                  child: _Footer(
                    isDark: isDark,
                    state: state,
                    controller: controller,
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.controller,
    required this.isDark,
    required this.onClose,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final textColor = isDark ? _kDarkText : _kLightText;
    final accent = isDark ? _kDarkAccent : _kLightAccent;

    return SliverSafeArea(
      bottom: false,
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: textColor,
                      size: 16,
                    ),
                  ),
                  onPressed: () => unawaited(onClose()),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: state.isRestoring
                      ? null
                      : controller.restorePurchases,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  icon: state.isRestoring
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: accent,
                          ),
                        )
                      : Icon(Icons.refresh_rounded, size: 14, color: accent),
                  label: Text(
                    text.premiumRestoreAction,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero block ──────────────────────────────────────────────────────────────
class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactScreen = screenWidth < 380;
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final assetName = isDark
        ? 'assets/branding/premium-hero-dark.png'
        : 'assets/branding/premium-hero-light.png';

    // Height of the hero: ~220–240 px regardless of screen.
    const heroHeight = 220.0;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Decorative glow behind dog ──
          if (isDark)
            Positioned(
              right: -20,
              top: 0,
              bottom: 0,
              width: 260,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.centerRight,
                    radius: 0.9,
                    colors: [
                      const Color(0xFFFFD163).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // ── Dog image — right side only, fits height ──
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: heroHeight * 0.88, // keep aspect ~square
            child: Image.asset(
              assetName,
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
          ),

          // ── Text — left side ──
          Positioned(
            left: 16,
            top: 12,
            right: heroHeight * 0.88 - 8, // don't overlap dog
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: textColor,
                    ),
                    children: [
                      TextSpan(text: '${text.premiumHeroTitle}\n'),
                      TextSpan(
                        text: ' ✦',
                        style: TextStyle(color: accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  text.premiumHeroSubtitle,
                  style: TextStyle(
                    fontSize: isCompactScreen ? 12 : 13,
                    color: sub,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: isCompactScreen ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comparison Card ─────────────────────────────────────────────────────────
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final freeBg = isDark ? _kDarkFreeBg : _kLightFreeBg;
    final surface = isDark ? _kDarkSurface : _kLightSurface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        color: surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Free column
                  Expanded(
                    child: Container(
                      color: freeBg,
                      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              text.premiumFreeColumn,
                              style: TextStyle(
                                color: sub,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _cmpRow(
                            false,
                            text.premiumComparisonFreeTemplates,
                            isDark,
                            sub,
                          ),
                          _cmpRow(
                            false,
                            text.premiumFreeSummaryTokens,
                            isDark,
                            sub,
                          ),
                          _cmpRow(
                            false,
                            text.premiumFreeSummaryQuality,
                            isDark,
                            sub,
                          ),
                          _cmpRow(
                            false,
                            text.premiumFreeSummaryWatermark,
                            isDark,
                            sub,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Premium column
                  Expanded(
                    child: Container(
                      color: surface,
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              text.premiumPremiumColumn,
                              style: TextStyle(
                                color: accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _cmpRow(
                            true,
                            text.premiumComparisonPremiumTemplates,
                            isDark,
                            textColor,
                            accent: accent,
                          ),
                          _cmpRow(
                            true,
                            text.premiumTokensPerWeek(40),
                            isDark,
                            textColor,
                            accent: accent,
                          ),
                          _cmpRow(
                            true,
                            text.premiumComparisonHighQuality,
                            isDark,
                            textColor,
                            accent: accent,
                          ),
                          _cmpRow(
                            true,
                            text.premiumComparisonNoWatermark,
                            isDark,
                            textColor,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Divider
              Container(width: 1, color: border),
              // VS bubble
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1D1F2D)
                      : const Color(0xFFE6E8F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: isDark ? Colors.white : _kLightText,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cmpRow(
    bool premium,
    String label,
    bool isDark,
    Color textColor, {
    Color? accent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            premium ? Icons.check_circle_rounded : Icons.close_rounded,
            size: 15,
            color: premium
                ? accent
                : (isDark ? const Color(0xFF3A3B4E) : const Color(0xFF97A8BD)),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Benefits Section ─────────────────────────────────────────────────────────
class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final surface = isDark ? _kDarkSurface : _kLightSurface;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final items = <_BenefitItem>[
      _BenefitItem(
        icon: Icons.flash_on_rounded,
        title: text.premiumBenefitAiGenerationsTitle,
        sub: text.premiumBenefitAiGenerationsSubtitle,
        color: const Color(0xFF6B4BFF),
      ),
      _BenefitItem(
        icon: Icons.photo_library_rounded,
        title: text.premiumBenefitPremiumTemplatesTitle,
        sub: text.premiumBenefitPremiumTemplatesSubtitle,
        color: const Color(0xFFFF9F43),
      ),
      _BenefitItem(
        icon: Icons.rocket_launch_rounded,
        title: text.premiumBenefitPriorityVideoQueueTitle,
        sub: text.premiumBenefitPriorityVideoQueueSubtitle,
        color: const Color(0xFFFF6B9D),
      ),
      _BenefitItem(
        icon: Icons.verified_user_rounded,
        title: text.premiumBenefitNoWatermarkTitle,
        sub: text.premiumBenefitNoWatermarkSubtitle,
        color: const Color(0xFF4CA1AF),
      ),
      _BenefitItem(
        icon: Icons.diamond_rounded,
        title: text.premiumBenefitBiggerRewardsTitle,
        sub: text.premiumBenefitBiggerRewardsSubtitle,
        color: const Color(0xFFFFD700),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              text.premiumIncludesTitle,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: const [0.0, 0.04, 0.93, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  width: 110,
                  margin: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.color.withValues(alpha: 0.15),
                        ),
                        child: Icon(item.icon, color: item.color, size: 26),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.sub,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: sub, fontSize: 10, height: 1.2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitItem {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String sub;
  final Color color;
}

// ─── CTA Button ───────────────────────────────────────────────────────────────
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
    final btnTextColor = isDark ? const Color(0xFF13141F) : Colors.white;
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
      if (!mounted) return;
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

bool _isYearlyPlan(PremiumPlanModel plan) {
  return plan.billingInterval.toLowerCase().contains('year') ||
      plan.planCode.toLowerCase().contains('annual');
}

// ─── Footer ───────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({
    required this.isDark,
    required this.state,
    required this.controller,
  });

  final bool isDark;
  final PremiumState state;
  final PremiumController controller;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final accent = isDark ? const Color(0xFFAA8FFF) : _kLightAccent;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: sub),
            const SizedBox(width: 5),
            Text(
              text.premiumStorePaymentDisclaimerTitle,
              style: TextStyle(
                color: sub,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text.premiumStorePaymentDisclaimerBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sub.withValues(alpha: 0.84),
            fontSize: 10,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 8,
          children: [
            _Link(
              text: text.premiumRestoreAction,
              accent: accent,
              onTap: state.isRestoring ? null : controller.restorePurchases,
            ),
            Text(' • ', style: TextStyle(color: sub, fontSize: 11)),
            _Link(
              text: text.profileSettingsTermsTitle,
              accent: accent,
              url: 'https://petmagic.app/terms',
            ),
            Text(' • ', style: TextStyle(color: sub, fontSize: 11)),
            _Link(
              text: text.profileSettingsPrivacyTitle,
              accent: accent,
              url: 'https://petmagic.app/privacy',
            ),
          ],
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.text, required this.accent, this.url, this.onTap});

  final String text;
  final Color accent;
  final String? url;
  final VoidCallback? onTap;

  Future<void> _handleUrlTap(BuildContext context) async {
    final safeUri = parseSafePremiumExternalUri(url);
    if (safeUri == null) {
      final text = _premiumText(context);
      PetMagicToast.show(
        context,
        message: text.premiumManageFailed,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    final launched = await launchUrl(
      safeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted) {
      return;
    }

    if (!launched) {
      final text = _premiumText(context);
      PetMagicToast.show(
        context,
        message: text.premiumManageFailed,
        tone: PetMagicToastTone.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          (url != null ? () => unawaited(_handleUrlTap(context)) : null),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: accent.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
