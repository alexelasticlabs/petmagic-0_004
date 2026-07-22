part of 'premium_page.dart';

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
