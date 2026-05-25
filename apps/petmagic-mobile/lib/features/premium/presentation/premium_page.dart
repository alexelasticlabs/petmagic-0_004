import 'dart:async';

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

part 'widgets/premium_page_hero_widgets.dart';
part 'widgets/premium_page_plan_widgets.dart';
part 'widgets/premium_page_summary_widgets.dart';

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
      final controller = ref.read(premiumControllerProvider.notifier);
      if (ref.read(premiumControllerProvider).isAwaitingCheckoutVerification) {
        unawaited(controller.verifyCheckoutStatus());
        return;
      }

      controller.load(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(premiumControllerProvider);
    final controller = ref.read(premiumControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicBottomNavInset(context);
    final checkoutStatusMessage = _checkoutStatusMessage(text, state);

    ref.listen(premiumControllerProvider, (previous, next) {
      final externalUrl = next.externalUrl;
      if (externalUrl == null || externalUrl.isEmpty) {
        return;
      }

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
                    if (state.checkoutVerificationState ==
                        PremiumCheckoutVerificationState.checking) ...[
                      ProfileProgressCard(
                        title: text.externalCheckoutCheckingTitle,
                        message: text.externalCheckoutCheckingMessage,
                        tone: colors.accent,
                        isLoading: true,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (checkoutStatusMessage != null) ...[
                      ProfileMessageCard(
                        message: checkoutStatusMessage,
                        tone:
                            state.checkoutVerificationState ==
                                PremiumCheckoutVerificationState.error
                            ? colors.gold
                            : colors.accent,
                      ),
                      const SizedBox(height: 14),
                    ],
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
                      isRecentlyActivated: state.recentlyActivatedPremium,
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
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: state.isManaging
                              ? null
                              : controller.manageBilling,
                          icon: state.isManaging
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.tune_rounded),
                          label: Text(
                            text.premiumManageAction,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            if (state.canStartCheckout && !state.isBuying)
                              BoxShadow(
                                color:
                                    (state.selectedPlan?.isPopular == true
                                            ? colors.accent
                                            : colors.gold)
                                        .withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: -2,
                                offset: const Offset(0, 6),
                              ),
                          ],
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                state.selectedPlan?.isPopular == true
                                ? colors.accent
                                : colors.gold,
                            foregroundColor:
                                state.selectedPlan?.isPopular == true
                                ? Colors.white
                                : colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          onPressed: state.isBuying || !state.canStartCheckout
                              ? null
                              : () => _handleCheckoutTap(state, controller),
                          icon: state.isBuying
                              ? SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      state.selectedPlan?.isPopular == true
                                          ? Colors.white
                                          : colors.surface,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.flash_on_rounded, size: 20),
                          label: Text(
                            _ctaLabel(text, state),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      state.legalNotice.isEmpty
                          ? text.premiumTermsNotice
                          : state.legalNotice,
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

  Future<void> _handleCheckoutTap(
    PremiumState state,
    PremiumController controller,
  ) async {
    if (state.selectedProvider == PremiumPaymentProvider.stripe && mounted) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _ExternalCheckoutWarningSheet(state: state),
      );

      if (confirmed != true) {
        return;
      }
    }

    await controller.startCheckout();
  }
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

String _ctaLabel(AppLocalizations text, PremiumState state) {
  return switch (state.selectedProvider) {
    PremiumPaymentProvider.stripe => '${text.premiumContinueAction} · Stripe',
    PremiumPaymentProvider.googlePlay =>
      '${text.premiumContinueAction} · Google Play',
    PremiumPaymentProvider.appStore =>
      '${text.premiumContinueAction} · App Store',
  };
}

int _estimatedVideoCount(int tokenAllowance) {
  return tokenAllowance ~/ 20;
}

int _estimatedPhotoCount(int tokenAllowance) {
  return tokenAllowance ~/ 5;
}

String? _checkoutStatusMessage(AppLocalizations text, PremiumState state) {
  return switch (state.checkoutVerificationState) {
    PremiumCheckoutVerificationState.idle => null,
    PremiumCheckoutVerificationState.checking => null,
    PremiumCheckoutVerificationState.activated => text.premiumPurchaseActivated,
    PremiumCheckoutVerificationState.pending =>
      text.externalCheckoutPendingVerificationMessage,
    PremiumCheckoutVerificationState.error => _friendlyPremiumMessage(
      text,
      state.checkoutErrorMessage ??
          state.errorMessage ??
          'premium.checkout_failed',
    ),
  };
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
