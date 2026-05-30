import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations_en.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/payments/stripe_paymentsheet_coordinator.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Color constants ────────────────────────────────────────────────────────
const _kDarkBg = Color(0xFF090A10);
const _kDarkSurface = Color(0xFF13141F);
const _kDarkText = Colors.white;
const _kDarkSubtitle = Color(0xFFD7D8E3);
const _kDarkAccent = Color(0xFFF7CD5A);
const _kDarkBorder = Color(0xFF232431);
const _kDarkFreeBg = Color(0xFF0F1019);

const _kLightBg = Color(0xFFF6F7FB);
const _kLightSurface = Color(0xFFFFFFFF);
const _kLightText = Color(0xFF171723);
const _kLightSubtitle = Color(0xFF595C70);
const _kLightAccent = Color(0xFF7C4DFF);
const _kLightBorder = Color(0xFFEBEDF5);
const _kLightFreeBg = Color(0xFFF0F1F7);

AppLocalizations _premiumText(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizationsEn();
}

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
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed && _shouldReloadOnResume) {
      _shouldReloadOnResume = false;
      final controller = ref.read(premiumControllerProvider.notifier);
      if (ref.read(premiumControllerProvider).isAwaitingCheckoutVerification) {
        unawaited(controller.verifyCheckoutStatus());
        return;
      }
      controller.load(refresh: true);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startCheckout() async {
    final controller = ref.read(premiumControllerProvider.notifier);
    final wasPremiumBeforeCheckout = ref
        .read(premiumControllerProvider)
        .isPremium;
    final checkout = await controller.startCheckout();
    if (!mounted || checkout == null || !checkout.usesPaymentSheet) {
      return;
    }

    await _presentStripePaymentSheet(
      checkout: checkout,
      wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
    );
  }

  Future<void> _openPaymentMethodSheetAndCheckout() async {
    final text = _premiumText(context);
    final controller = ref.read(premiumControllerProvider.notifier);
    final currentState = ref.read(premiumControllerProvider);
    if (currentState.isPremium || currentState.recentlyActivatedPremium) {
      return;
    }

    final options = _buildPaymentMethodOptions(currentState, text);
    if (options.isEmpty) {
      return;
    }

    final selected = await showPaymentMethodSheet(
      context: context,
      title: text.premiumPaymentTitle,
      subtitle: text.premiumSecurePaymentSubtitle,
      continueLabel: text.premiumContinueAction,
      options: options,
    );
    if (!mounted || selected == null) {
      return;
    }

    final provider = _providerFromOptionId(selected.id);
    if (provider == null) {
      return;
    }

    controller.selectProvider(provider);
    await _startCheckout();
  }

  Future<void> _presentStripePaymentSheet({
    required PremiumCheckoutModel checkout,
    required bool wasPremiumBeforeCheckout,
  }) async {
    final clientSecret = checkout.paymentIntentClientSecret;
    final publishableKey = checkout.publishableKey;
    if (clientSecret == null ||
        clientSecret.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      return;
    }

    try {
      final result = await StripePaymentSheetCoordinator.present(
        context,
        request: StripePaymentSheetRequest(
          paymentIntentClientSecret: clientSecret,
          publishableKey: publishableKey,
          customerId: checkout.customerId,
          customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
        ),
      );
      if (!result.completed) {
        throw result.error ?? Exception('stripe.payment_sheet_failed');
      }

      if (!mounted) {
        return;
      }

      final controller = ref.read(premiumControllerProvider.notifier);
      controller.markCheckoutOpened(
        wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
      );
      _shouldReloadOnResume = true;
      final selectedPlanCode = ref
          .read(premiumControllerProvider)
          .selectedPlanCode;
      await controller.verifyCheckoutStatus(
        stripePlanCode: selectedPlanCode,
        stripeExternalSubscriptionId: checkout.externalSubscriptionId,
      );
    } on StripeException {
      // User canceled/dismissed PaymentSheet.
    } on PlatformException {
      // Keep page responsive if native Stripe SDK returns an error.
    }
  }

  List<PaymentMethodSheetOption> _buildPaymentMethodOptions(
    PremiumState state,
    AppLocalizations text,
  ) {
    final options = <PaymentMethodSheetOption>[];

    for (final method in state.paymentMethods) {
      if (!method.isEnabled) {
        continue;
      }

      final provider = method.provider;
      final badges = <String>[];
      if (method.isSelectedByDefault) {
        badges.add(text.premiumPaymentDefaultBadge);
      }
      if (method.isRecommended) {
        badges.add(text.premiumPaymentRecommendedBadge);
      }
      if (method.bonusTokensPercent > 0) {
        badges.add(text.paymentBonusPercentBadge(method.bonusTokensPercent));
      }

      final legalNotice = switch (provider) {
        PremiumPaymentProvider.stripe => state.legalTexts?.stripeNotice,
        PremiumPaymentProvider.googlePlay ||
        PremiumPaymentProvider.appStore => state.legalTexts?.storeNotice,
      };

      options.add(
        PaymentMethodSheetOption(
          id: provider.value,
          title: method.displayLabel?.trim().isNotEmpty == true
              ? method.displayLabel!.trim()
              : _providerLabel(provider, text),
          icon: _providerIcon(provider),
          subtitle: method.displaySubtitle,
          badge: badges.isEmpty ? null : badges.first,
          warningTitle: method.warningTitle,
          warningMessage: method.warningMessage,
          notes: method.notes,
          legalNotice: legalNotice,
          isEnabled: state.isProviderAvailable(provider),
        ),
      );
    }

    return options;
  }

  PremiumPaymentProvider? _providerFromOptionId(String value) {
    for (final provider in PremiumPaymentProvider.values) {
      if (provider.value == value) {
        return provider;
      }
    }

    return null;
  }

  String _providerLabel(
    PremiumPaymentProvider provider,
    AppLocalizations text,
  ) {
    return switch (provider) {
      PremiumPaymentProvider.stripe => text.premiumPaymentStripe,
      PremiumPaymentProvider.googlePlay => text.premiumPaymentGooglePlay,
      PremiumPaymentProvider.appStore => text.premiumPaymentApple,
    };
  }

  IconData _providerIcon(PremiumPaymentProvider provider) {
    return switch (provider) {
      PremiumPaymentProvider.stripe => Icons.credit_card_rounded,
      PremiumPaymentProvider.googlePlay => Icons.android_rounded,
      PremiumPaymentProvider.appStore => Icons.apple_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(premiumControllerProvider);
    final controller = ref.read(premiumControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? _kDarkBg : _kLightBg;
    final accent = isDark ? _kDarkAccent : _kLightAccent;

    ref.listen(premiumControllerProvider, (previous, next) {
      final externalUrl = next.externalUrl;
      if (externalUrl == null || externalUrl.isEmpty) return;

      final openedForCheckout =
          previous?.isBuying == true &&
          next.selectedProvider == PremiumPaymentProvider.stripe;

      if (openedForCheckout) {
        controller.markCheckoutOpened(
          wasPremiumBeforeCheckout: previous?.isPremium ?? false,
        );
      }

      controller.consumeExternalUrl();
      _openExternalUrl(externalUrl);
    });

    ref.listen(premiumControllerProvider, (previous, next) {
      final justActivated =
          previous?.checkoutVerificationState !=
              PremiumCheckoutVerificationState.activated &&
          next.checkoutVerificationState ==
              PremiumCheckoutVerificationState.activated;
      if (!justActivated || !mounted) {
        return;
      }

      final fallbackText = _premiumText(context);
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      if (navigator.canPop()) {
        navigator.pop();
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(fallbackText.premiumPurchaseActivated)));
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: state.isLoading
              ? Center(
                  key: const ValueKey('premium-loading'),
                  child: CircularProgressIndicator(color: accent),
                )
              : _PremiumBody(
                  key: const ValueKey('premium-content'),
                  state: state,
                  controller: controller,
                  isDark: isDark,
                  onOpenUrl: _openExternalUrl,
                  onStartCheckout: _openPaymentMethodSheetAndCheckout,
                ),
        ),
      ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────
class _PremiumBody extends StatelessWidget {
  const _PremiumBody({
    super.key,
    required this.state,
    required this.controller,
    required this.isDark,
    required this.onOpenUrl,
    required this.onStartCheckout,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;
  final Future<void> Function(String) onOpenUrl;
  final Future<void> Function() onStartCheckout;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        _Header(state: state, controller: controller, isDark: isDark),
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
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;

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
                  onPressed: () => Navigator.of(context).maybePop(),
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
                      const Color(0xFF4A1FBF).withValues(alpha: 0.4),
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
                      TextSpan(text: ' ✦', style: TextStyle(color: accent)),
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
        borderRadius: BorderRadius.circular(19),
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
                : (isDark ? const Color(0xFF3A3B4E) : const Color(0xFFBEC0D0)),
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

// ─── Plans Section ────────────────────────────────────────────────────────────
class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.state,
    required this.controller,
    required this.isDark,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final monthlyPlans = state.plans
        .where((plan) => !_isYearlyPlan(plan))
        .toList();
    final yearlyPlans = state.plans.where(_isYearlyPlan).toList();

    PremiumPlanModel? selectedPlan;
    for (final plan in state.plans) {
      if (plan.planCode == state.selectedPlanCode) {
        selectedPlan = plan;
        break;
      }
    }

    final selectedIsYearly =
        selectedPlan != null && _isYearlyPlan(selectedPlan);
    final canChangePlan =
        !state.isPremium && !state.recentlyActivatedPremium && !state.isBuying;

    if (state.plans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            text.premiumChoosePlanTitle,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BillingChip(
                label: text.premiumMonthlyPlan,
                isActive: !selectedIsYearly,
                accent: accent,
                border: border,
                textColor: textColor,
                mutedColor: sub,
                onTap: monthlyPlans.isEmpty
                    ? null
                    : () {
                        if (!canChangePlan) {
                          return;
                        }

                        HapticFeedback.selectionClick();
                        controller.selectPlan(monthlyPlans.first.planCode);
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BillingChip(
                label: text.premiumYearlyPlan,
                isActive: selectedIsYearly,
                accent: accent,
                border: border,
                textColor: textColor,
                mutedColor: sub,
                onTap: yearlyPlans.isEmpty
                    ? null
                    : () {
                        if (!canChangePlan) {
                          return;
                        }

                        HapticFeedback.selectionClick();
                        controller.selectPlan(yearlyPlans.first.planCode);
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...state.plans.map(
          (plan) => _PlanCard(
            plan: plan,
            isSelected: state.selectedPlanCode == plan.planCode,
            isDark: isDark,
            onTap: () {
              if (!canChangePlan) {
                return;
              }

              controller.selectPlan(plan.planCode);
            },
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final PremiumPlanModel plan;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final surface = isDark ? _kDarkSurface : _kLightSurface;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    final isYearly = _isYearlyPlan(plan);
    final title =
        '${text.premiumPageTitle} ${isYearly ? text.premiumYearlyPlan : text.premiumMonthlyPlan}';
    final priceStr = '\$${plan.priceAmount.toStringAsFixed(2)}';
    final interval = isYearly ? text.premiumYearlyPeriod : text.premiumMonthlyPeriod;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
      builder: (context, glow, child) {
        return AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          scale: isSelected ? 1.0 : 0.985,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2 + (0.08 * glow)),
                    blurRadius: 16 + (8 * glow),
                    spreadRadius: 0.2 + (0.6 * glow),
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: accent.withValues(alpha: 0.16),
          highlightColor: accent.withValues(alpha: 0.08),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isSelected ? accent.withValues(alpha: 0.05) : surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? accent : border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.08),
                                Colors.transparent,
                                accent.withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                key: ValueKey(
                                  '${plan.planCode}:${isSelected ? 'on' : 'off'}',
                                ),
                                color: isSelected
                                    ? accent
                                    : (isDark
                                          ? const Color(0xFF3A3B4E)
                                          : const Color(0xFFBEC0D0)),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (isSelected)
                                    _PlanBadge(
                                      label: text.premiumSelectedBadge,
                                      textColor: accent,
                                      fill: accent.withValues(alpha: 0.14),
                                      stroke: accent.withValues(alpha: 0.36),
                                    ),
                                  if (isYearly)
                                    _PlanBadge(
                                      label: text.premiumBestValueBadge,
                                      textColor: isDark
                                          ? const Color(0xFF13141F)
                                          : Colors.white,
                                      fill: isSelected
                                          ? accent
                                          : accent.withValues(alpha: 0.7),
                                      stroke: Colors.transparent,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 30),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isYearly
                                        ? text.premiumCancelAnytime
                                        : text.premiumCancelAnytime,
                                    style: TextStyle(color: sub, fontSize: 12),
                                  ),
                                  if (isYearly) ...[
                                    const SizedBox(height: 6),
                                    _PlanBadge(
                                      label: text.premiumDiscountLabel(33),
                                      textColor: accent,
                                      fill: accent.withValues(alpha: 0.14),
                                      stroke: Colors.transparent,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  priceStr,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  interval,
                                  style: TextStyle(color: sub, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
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

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    required this.textColor,
    required this.fill,
    required this.stroke,
  });

  final String label;
  final Color textColor;
  final Color fill;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
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
                  margin: EdgeInsets.only(
                    right: i < items.length - 1 ? 10 : 0,
                  ),
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
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = widget.isDark;
    final isCheckoutDisabled =
        state.isBuying ||
        state.isPremium ||
        state.recentlyActivatedPremium ||
        !state.canStartCheckout;
    final btnTextColor = isDark ? const Color(0xFF13141F) : Colors.white;
    final glowColor = isDark
        ? const Color(0xFFFFB300)
        : const Color(0xFF7C4DFF);

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
                      colors: [Color(0xFF9D6FFF), Color(0xFF6D28D9)],
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
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: btnTextColor,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Start Premium',
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

class _BillingChip extends StatelessWidget {
  const _BillingChip({
    required this.label,
    required this.isActive,
    required this.accent,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color accent;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive ? accent.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(color: isActive ? accent : border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  isActive ? Icons.bolt_rounded : Icons.circle_outlined,
                  key: ValueKey('$label:$isActive'),
                  size: 15,
                  color: isActive ? accent : mutedColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? textColor : mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
            color: sub.withValues(alpha: 0.7),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? (url != null ? () => launchUrl(Uri.parse(url!)) : null),
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
