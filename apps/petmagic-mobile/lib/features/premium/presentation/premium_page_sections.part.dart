part of 'premium_page.dart';

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

    const heroHeight = 220.0;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: heroHeight * 0.88,
            child: Image.asset(
              assetName,
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
          ),
          Positioned(
            left: 16,
            top: 12,
            right: heroHeight * 0.88 - 8,
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
              Container(width: 1, color: border),
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
