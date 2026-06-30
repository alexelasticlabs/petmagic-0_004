part of 'profile_page.dart';

class _PremiumBannerCard extends StatelessWidget {
  const _PremiumBannerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = context.petMagicColors;
    const accent = Color(0xFFFFC107);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            child: PetMagicAccentCard(
              accentColor: accent,
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.zero,
              borderOpacity: isLight ? 0.2 : 0.28,
              glowOpacity: isLight ? 0.1 : 0.15,
              glowAlignment: const Alignment(-0.92, -0.9),
              child: SizedBox(
                height: 168,
                child: Stack(
                  children: [
                    Positioned(
                      top: 14,
                      left: 16,
                      child: IgnorePointer(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accent.withValues(alpha: isLight ? 0.12 : 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: isLight ? 0.82 : 0.94,
                          child: Image.asset(
                            _profilePremiumDogAsset,
                            height: 136,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 140, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.24),
                              ),
                              color: accent.withValues(
                                alpha: isLight ? 0.1 : 0.14,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PremiumCrownIcon(size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  text.premiumLabel,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD666),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text.premiumUpsellHeadline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            text.premiumUpsellSubtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSoft.withValues(alpha: 0.86),
                              fontSize: 11,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          PremiumShimmerButton(
                            label: text.profilePremiumOpenAction,
                            onTap: onTap,
                            height: 42,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
