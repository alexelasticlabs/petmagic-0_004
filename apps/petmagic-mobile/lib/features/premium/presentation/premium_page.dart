import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumPage extends ConsumerStatefulWidget {
  const PremiumPage({super.key});

  static const routePath = '/profile/premium';

  @override
  ConsumerState<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends ConsumerState<PremiumPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(premiumControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(premiumControllerProvider);
    final controller = ref.read(premiumControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicBottomNavInset(context);

    ref.listen(premiumControllerProvider, (previous, next) {
      final externalUrl = next.externalUrl;
      if (externalUrl == null || externalUrl.isEmpty) {
        return;
      }

      controller.clearExternalUrl();
      _openExternalUrl(externalUrl);
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: () => controller.load(refresh: true),
                color: colors.accent,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _PremiumHeader(
                      onRefresh: () => controller.load(refresh: true),
                    ),
                    const SizedBox(height: 14),
                    if (state.errorMessage != null) ...[
                      ProfileMessageCard(
                        message: _friendlyPremiumMessage(
                          text,
                          state.errorMessage!,
                        ),
                        tone: colors.danger,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (state.successMessage != null) ...[
                      ProfileMessageCard(
                        message: _friendlyPremiumMessage(
                          text,
                          state.successMessage!,
                        ),
                        tone: colors.accent,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _PremiumHero(status: state.status),
                    const SizedBox(height: 16),
                    _BenefitsGrid(),
                    const SizedBox(height: 18),
                    _PlansSection(state: state, controller: controller),
                    const SizedBox(height: 14),
                    _PaymentProviderSection(
                      state: state,
                      onSelect: controller.selectProvider,
                    ),
                    const SizedBox(height: 14),
                    _ComparisonSection(selectedPlan: state.selectedPlan),
                    const SizedBox(height: 14),
                    _SecurePaymentSection(),
                    const SizedBox(height: 18),
                    if (state.isPremium) ...[
                      FilledButton.icon(
                        onPressed: state.isManaging
                            ? null
                            : controller.manageBilling,
                        icon: state.isManaging
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.tune_rounded),
                        label: Text(text.premiumManageAction),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      FilledButton.icon(
                        onPressed: state.isBuying || !state.canStartCheckout
                            ? null
                            : controller.startCheckout,
                        icon: state.isBuying
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          _ctaLabel(text, state.selectedPlan),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextButton.icon(
                      onPressed: state.isRestoring
                          ? null
                          : controller.restorePurchases,
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(text.premiumRestoreAction),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text.premiumTermsNotice,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _openExternalUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.premiumPageTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text.premiumPageSubtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: text.retryAction,
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
      ],
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero({required this.status});

  final PremiumStatusModel? status;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surfaceStrong,
              colors.accent.withValues(alpha: 0.22),
              colors.gold.withValues(alpha: 0.18),
            ],
          ),
          border: Border.all(color: colors.gold.withValues(alpha: 0.28)),
        ),
        child: SizedBox(
          height: 330,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/auth/petmagic-auth-hero.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.surfaceStrong.withValues(alpha: 0.92),
                        colors.surfaceStrong.withValues(alpha: 0.22),
                        colors.surfaceStrong.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                right: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileStatusPill(
                      label: status?.isPremium == true
                          ? text.premiumAlreadyActive
                          : text.premiumHeroEyebrow,
                      leading: Icons.workspace_premium_rounded,
                      backgroundColor: colors.gold.withValues(alpha: 0.18),
                      foregroundColor: colors.gold,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      text.profilePremiumTitle,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 30,
                        height: 1.04,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 310),
                      child: Text(
                        text.profilePremiumSubtitle,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final benefits = [
      _Benefit(Icons.pets_rounded, text.premiumBenefitUnlimitedTemplates),
      _Benefit(Icons.flash_on_rounded, text.premiumBenefitFastGeneration),
      _Benefit(Icons.cloud_upload_rounded, text.premiumBenefitHighQuality),
      _Benefit(Icons.card_giftcard_rounded, text.premiumBenefitExclusive),
    ];

    return Row(
      children: [
        for (final benefit in benefits) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.13),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(benefit.icon, color: colors.accent, size: 25),
                ),
                const SizedBox(height: 8),
                Text(
                  benefit.label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 11.5,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (benefit != benefits.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({required this.state, required this.controller});

  final PremiumState state;
  final PremiumController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumChoosePlanTitle),
        const SizedBox(height: 2),
        for (final plan in state.plans) ...[
          _PlanCard(
            plan: plan,
            selected: plan.planCode == state.selectedPlanCode,
            onTap: () => controller.selectPlan(plan.planCode),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PremiumPlanModel plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final borderColor = selected ? colors.accent : colors.border;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: ProfileGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _planTitle(text, plan),
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (plan.isPopular) ...[
                            const SizedBox(width: 8),
                            ProfileStatusPill(
                              label: text.premiumPopularBadge,
                              leading: Icons.star_rounded,
                              backgroundColor: colors.accent.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: colors.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (plan.compareAtPriceAmount != null) ...[
                            Text(
                              _formatPrice(plan, plan.compareAtPriceAmount!),
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              _formatPrice(plan, plan.priceAmount),
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 27,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              _periodLabel(text, plan),
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.accent : Colors.transparent,
                    border: Border.all(color: borderColor, width: 1.4),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: colors.surface,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlanChip(
                  icon: Icons.pets_rounded,
                  label: _tokensLabel(text, plan),
                ),
                if (plan.discountPercent != null)
                  _PlanChip(
                    icon: Icons.savings_rounded,
                    label: text.premiumDiscountLabel(plan.discountPercent!),
                  ),
                _PlanChip(
                  icon: Icons.event_available_rounded,
                  label: text.premiumCancelAnytime,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentProviderSection extends StatelessWidget {
  const _PaymentProviderSection({required this.state, required this.onSelect});

  final PremiumState state;
  final ValueChanged<PremiumPaymentProvider> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumPaymentTitle),
        const SizedBox(height: 2),
        ProfileGlassCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              for (final provider in state.availableProviders)
                _ProviderRow(
                  provider: provider,
                  enabled: state.isProviderAvailable(provider),
                  selected: provider == state.selectedProvider,
                  onTap: () => onSelect(provider),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final PremiumPaymentProvider provider;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final label = _providerLabel(AppLocalizations.of(context), provider);
    final icon = switch (provider) {
      PremiumPaymentProvider.stripe => Icons.credit_card_rounded,
      PremiumPaymentProvider.googlePlay => Icons.shop_rounded,
      PremiumPaymentProvider.appStore => Icons.phone_iphone_rounded,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled
                  ? (selected ? colors.accent : colors.textMuted)
                  : colors.textMuted.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? colors.textStrong
                      : colors.textMuted.withValues(alpha: 0.75),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              enabled && selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: enabled && selected ? colors.accent : colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumComparisonTitle),
        const SizedBox(height: 2),
        ProfileGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ComparisonHeader(),
              _ComparisonRow(text.premiumComparisonFreeTemplates, true, true),
              _ComparisonRow(
                text.premiumComparisonPremiumTemplates,
                false,
                true,
              ),
              _ComparisonTextRow(
                text.premiumComparisonTokens,
                '20',
                selectedPlan == null
                    ? text.premiumComparisonPremiumTokensFallback
                    : text.premiumComparisonPremiumTokens(
                        selectedPlan!.tokenAllowance,
                      ),
              ),
              _ComparisonRow(text.premiumComparisonFast, false, true),
              _ComparisonRow(text.premiumComparisonHighQuality, false, true),
              _ComparisonRow(text.premiumComparisonNoWatermark, false, true),
              _ComparisonRow(
                text.premiumComparisonPrioritySupport,
                false,
                true,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox.shrink()),
          Expanded(
            flex: 2,
            child: Text(
              text.premiumFreeColumn,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              text.premiumPremiumColumn,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow(
    this.label,
    this.free,
    this.premium, {
    this.showDivider = true,
  });

  final String label;
  final bool free;
  final bool premium;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return _ComparisonBaseRow(
      label: label,
      free: _ComparisonIcon(value: free),
      premium: _ComparisonIcon(value: premium),
      showDivider: showDivider,
    );
  }
}

class _ComparisonTextRow extends StatelessWidget {
  const _ComparisonTextRow(this.label, this.free, this.premium);

  final String label;
  final String free;
  final String premium;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return _ComparisonBaseRow(
      label: label,
      free: Text(
        free,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.textSoft, fontWeight: FontWeight.w800),
      ),
      premium: Text(
        premium,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.accent, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ComparisonBaseRow extends StatelessWidget {
  const _ComparisonBaseRow({
    required this.label,
    required this.free,
    required this.premium,
    this.showDivider = true,
  });

  final String label;
  final Widget free;
  final Widget premium;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(color: colors.border.withValues(alpha: 0.5)),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12.5,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(flex: 2, child: Center(child: free)),
            Expanded(flex: 2, child: Center(child: premium)),
          ],
        ),
      ),
    );
  }
}

class _ComparisonIcon extends StatelessWidget {
  const _ComparisonIcon({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Icon(
      value ? Icons.check_circle_rounded : Icons.close_rounded,
      color: value ? colors.accent : colors.textMuted,
      size: value ? 20 : 18,
    );
  }
}

class _SecurePaymentSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: colors.accent.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.verified_user_rounded, color: colors.textStrong),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.premiumSecurePaymentTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text.premiumSecurePaymentSubtitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.credit_score_rounded, color: colors.accent),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit {
  const _Benefit(this.icon, this.label);

  final IconData icon;
  final String label;
}

String _formatPrice(PremiumPlanModel plan, double amount) {
  return NumberFormat.simpleCurrency(name: plan.currencyCode).format(amount);
}

String _planTitle(AppLocalizations text, PremiumPlanModel plan) {
  return switch (plan.planCode) {
    'weekly' => text.premiumWeeklyPlan,
    'monthly' => text.premiumMonthlyPlan,
    'yearly' => text.premiumYearlyPlan,
    _ => plan.planCode,
  };
}

String _periodLabel(AppLocalizations text, PremiumPlanModel plan) {
  return switch (plan.billingInterval) {
    'week' => text.premiumWeeklyPeriod,
    'month' => text.premiumMonthlyPeriod,
    'year' => text.premiumYearlyPeriod,
    _ => plan.billingInterval,
  };
}

String _tokensLabel(AppLocalizations text, PremiumPlanModel plan) {
  return switch (plan.billingInterval) {
    'week' => text.premiumTokensPerWeek(plan.tokenAllowance),
    _ => text.premiumTokensPerMonth(plan.tokenAllowance),
  };
}

String _providerLabel(AppLocalizations text, PremiumPaymentProvider provider) {
  return switch (provider) {
    PremiumPaymentProvider.stripe => text.premiumPaymentStripe,
    PremiumPaymentProvider.googlePlay => text.premiumPaymentGooglePlay,
    PremiumPaymentProvider.appStore => text.premiumPaymentApple,
  };
}

String _ctaLabel(AppLocalizations text, PremiumPlanModel? plan) {
  if (plan == null) {
    return text.premiumContinueAction;
  }

  return text.premiumContinueWithPlan(
    _planTitle(text, plan).toLowerCase(),
    _formatPrice(plan, plan.priceAmount),
    _periodLabel(text, plan),
  );
}

String _friendlyPremiumMessage(AppLocalizations text, String raw) {
  if (raw.contains('premium.store_unavailable')) {
    return text.premiumStoreUnavailable;
  }

  if (raw.contains('premium.store_product_unavailable')) {
    return text.premiumStoreProductUnavailable;
  }

  if (raw.contains('premium.purchase_activated')) {
    return text.premiumPurchaseActivated;
  }

  if (raw.contains('premium.purchase_cancelled')) {
    return text.premiumPurchaseCancelled;
  }

  if (raw.contains('premium.restore_started')) {
    return text.premiumRestoreStarted;
  }

  if (raw.contains('economy.store_verification_unavailable')) {
    return text.premiumStoreVerificationUnavailable;
  }

  if (raw.contains('economy.store_purchase_invalid')) {
    return text.premiumStorePurchaseInvalid;
  }

  if (raw.contains('economy.store_purchase_inactive')) {
    return text.premiumStorePurchaseInactive;
  }

  if (raw.contains('payment_gateway_failed')) {
    return text.premiumCheckoutFailed;
  }

  if (raw.contains('premium_billing_unavailable')) {
    return text.premiumManageFailed;
  }

  return raw;
}
