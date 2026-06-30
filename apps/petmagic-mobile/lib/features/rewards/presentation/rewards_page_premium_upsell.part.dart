part of 'rewards_page.dart';

class _RewardsPremiumUpsellCard extends StatelessWidget {
  const _RewardsPremiumUpsellCard({required this.onOpenPremium});

  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpenPremium,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(
                  0xFFE0A91E,
                ).withValues(alpha: isLight ? 0.78 : 0.88),
                width: 1.15,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: PremiumBannerStyle.gradient(isLight),
              ),
              boxShadow: [
                BoxShadow(
                  color: isLight
                      ? const Color(0xFFD7B35D).withValues(alpha: 0.25)
                      : const Color(0xFF02070F).withValues(alpha: 0.55),
                  blurRadius: isLight ? 12 : 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 168,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, 0.35),
                          radius: 1.2,
                          colors: [
                            const Color(
                              0xFFF4C64D,
                            ).withValues(alpha: isLight ? 0.2 : 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Image.asset(
                        _kRewardsPremiumMascotAsset,
                        height: 136,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
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
                              color: const Color(
                                0xFFE0A91E,
                              ).withValues(alpha: isLight ? 0.7 : 0.8),
                            ),
                            color: const Color(
                              0xFF201300,
                            ).withValues(alpha: isLight ? 0.08 : 0.24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PremiumCrownIcon(size: 12),
                              const SizedBox(width: 5),
                              Text(
                                text.premiumLabel,
                                style: TextStyle(
                                  color: const Color(0xFFEABA47),
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
                            color: isLight
                                ? const Color(0xFF1E1608)
                                : const Color(0xFFEABF55),
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
                            color: isLight
                                ? const Color(0xFF3B3324)
                                : const Color(0xFFE3DFD2),
                            fontSize: 11,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        PremiumShimmerButton(
                          label: text.profilePremiumOpenAction,
                          onTap: onOpenPremium,
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
    );
  }
}
