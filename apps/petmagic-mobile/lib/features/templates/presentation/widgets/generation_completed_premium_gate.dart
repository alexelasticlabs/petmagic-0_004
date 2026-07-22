import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';

const _generationPremiumMascotAsset = 'assets/rewards/premium-upsell-dog.png';

class GenerationCompletedPremiumGate extends StatelessWidget {
  const GenerationCompletedPremiumGate({
    required this.onClose,
    required this.onLater,
    super.key,
  });

  final VoidCallback onClose;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final rightInset = compact ? 124.0 : 162.0;
        final mascotHeight = compact ? 176.0 : 200.0;
        return DecoratedBox(
          key: const ValueKey('generation-completed-premium-gate'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.gold.withValues(alpha: isLight ? 0.78 : 0.9),
              width: 1.15,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: PremiumBannerStyle.gradient(isLight),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 12,
                top: 8,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: colors.textSoft),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 0,
                child: IgnorePointer(
                  child: Image.asset(
                    _generationPremiumMascotAsset,
                    height: mascotHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 20, rightInset, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${text.generationStatusVideoReady}! 🎉',
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: compact ? 27 : 32,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.templateFlowCompletedPremiumHeadline,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: compact ? 15.5 : 17.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.templateFlowCompletedPremiumMessage,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: compact ? 13.4 : 15.2,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    PremiumShimmerButton(
                      label: text.premiumContinueAction,
                      onTap: () =>
                          context.appNavigator.push(const PremiumDestination()),
                      height: 46,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onLater,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colors.border.withValues(
                              alpha: isLight ? 0.9 : 0.78,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          text.templateFlowChooseAnotherTemplateAction,
                          style: TextStyle(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
