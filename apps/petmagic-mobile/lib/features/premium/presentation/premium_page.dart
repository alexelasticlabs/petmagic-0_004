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

class _PremiumPageState extends ConsumerState<PremiumPage>
    with WidgetsBindingObserver {
  bool _shouldReloadOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(premiumControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldReloadOnResume) {
      _shouldReloadOnResume = false;
      ref.read(premiumControllerProvider.notifier).load(refresh: true);
    }
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
                  padding: EdgeInsets.fromLTRB(18, 12, 18, bottomNavInset),
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
                    _PremiumHero(
                      status: state.status,
                      selectedPlan: state.selectedPlan,
                    ),
                    const SizedBox(height: 16),
                    _PlansSection(state: state, controller: controller),
                    const SizedBox(height: 14),
                    _PaymentProviderSection(
                      state: state,
                      onSelect: controller.selectProvider,
                    ),
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
                          _ctaLabel(text),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _TrustSummary(selectedPlan: state.selectedPlan),
                    const SizedBox(height: 18),
                    _BenefitsList(selectedPlan: state.selectedPlan),
                    const SizedBox(height: 14),
                    _ComparisonSection(selectedPlan: state.selectedPlan),
                    const SizedBox(height: 10),
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

    _shouldReloadOnResume = true;
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.premiumPageTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: text.retryAction,
        ),
      ],
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero({required this.status, required this.selectedPlan});

  final PremiumStatusModel? status;
  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final selectedPlanLabel = selectedPlan == null
        ? null
        : '${_planTitle(text, selectedPlan!)} · ${_tokensLabel(text, selectedPlan!)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong,
            colors.surfaceStrong.withValues(alpha: 0.96),
            colors.gold.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileStatusPill(
                  label: status?.isPremium == true
                      ? text.premiumAlreadyActive
                      : text.premiumHeroEyebrow,
                  leading: Icons.workspace_premium_rounded,
                  backgroundColor: colors.gold.withValues(alpha: 0.16),
                  foregroundColor: colors.gold,
                ),
                const Spacer(),
                Icon(Icons.auto_awesome_rounded, color: colors.gold, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              text.premiumHeroTitle,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text.premiumHeroSubtitle,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selectedPlanLabel != null) ...[
              const SizedBox(height: 14),
              Text(
                selectedPlanLabel,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final tokenAllowance = selectedPlan?.tokenAllowance;
    final benefits = [
      _Benefit(
        Icons.workspace_premium_rounded,
        text.premiumComparisonPremiumTemplates,
      ),
      _Benefit(Icons.visibility_off_rounded, text.premiumComparisonNoWatermark),
      _Benefit(Icons.flash_on_rounded, text.premiumComparisonFast),
      _Benefit(
        Icons.auto_awesome_rounded,
        tokenAllowance == null
            ? text.premiumComparisonPremiumTokensFallback
            : text.premiumComparisonPremiumTokens(tokenAllowance),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumIncludesTitle),
        const SizedBox(height: 2),
        ProfileGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              for (var index = 0; index < benefits.length; index++) ...[
                _BenefitLine(benefit: benefits[index]),
                if (index < benefits.length - 1) const SizedBox(height: 10),
              ],
              if (selectedPlan != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text.premiumTokenEstimate(
                      _estimatedVideoCount(selectedPlan!.tokenAllowance),
                      _estimatedPhotoCount(selectedPlan!.tokenAllowance),
                    ),
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({required this.benefit});

  final _Benefit benefit;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: colors.textStrong, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            benefit.label,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(benefit.icon, color: colors.textMuted, size: 18),
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
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: ProfileGlassCard(
        padding: const EdgeInsets.all(14),
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
                                fontSize: 16,
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
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (plan.compareAtPriceAmount != null) ...[
                            Text(
                              _formatPrice(plan, plan.compareAtPriceAmount!),
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
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
                                fontSize: 23,
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
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tokensLabel(text, plan),
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.accent : Colors.transparent,
                    border: Border.all(color: borderColor, width: 1.4),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colors.surface,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
              _ComparisonRow(text.premiumComparisonNoWatermark, false, true),
              _ComparisonRow(
                text.premiumComparisonHighQuality,
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

class _TrustSummary extends StatelessWidget {
  const _TrustSummary({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final selectedPlanText = selectedPlan == null
        ? null
        : '${_planTitle(text, selectedPlan!)} · ${_formatPrice(selectedPlan!, selectedPlan!.priceAmount)} ${_periodLabel(text, selectedPlan!)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceStrong.withValues(alpha: 0.58),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedPlanText != null) ...[
              Text(
                selectedPlanText,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlanChip(
                  icon: Icons.workspace_premium_rounded,
                  label: text.premiumPopularBadge,
                ),
                _PlanChip(
                  icon: Icons.event_available_rounded,
                  label: text.premiumCancelAnytime,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text.premiumSocialProof,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text.premiumSecurePaymentSubtitle,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 11,
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

String _ctaLabel(AppLocalizations text) {
  return text.premiumContinueAction;
}

int _estimatedVideoCount(int tokenAllowance) {
  return tokenAllowance ~/ 20;
}

int _estimatedPhotoCount(int tokenAllowance) {
  return tokenAllowance ~/ 5;
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
