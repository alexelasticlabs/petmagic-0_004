import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
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
    final storeProvider = _preferredStoreProvider(
      state,
      Theme.of(context).platform,
    );
    final stripeAvailable =
        state.availableProviders.contains(PremiumPaymentProvider.stripe) &&
        state.isProviderAvailable(PremiumPaymentProvider.stripe);
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
                      onRestore: controller.restorePurchases,
                      isRestoring: state.isRestoring,
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
                    const SizedBox(height: 18),
                    if (state.isPremium) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 58,
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
                              : const Icon(Icons.tune_rounded, size: 20),
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
                      _CheckoutActionsSection(
                        state: state,
                        storeProvider: storeProvider,
                        stripeAvailable: stripeAvailable,
                        onStoreCheckout: storeProvider == null
                            ? null
                            : () => _startCheckoutForProvider(
                                storeProvider,
                                controller,
                              ),
                        onStripeCheckout: stripeAvailable
                            ? () => _startCheckoutForProvider(
                                PremiumPaymentProvider.stripe,
                                controller,
                              )
                            : null,
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
                      icon: state.isRestoring
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.restore_rounded),
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
    if (state.showsExternalCheckoutWarning && mounted) {
      final confirmed = await showPetMagicModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context, bottomInset) => Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _ExternalCheckoutWarningSheet(state: state),
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    final checkout = await controller.startCheckout();
    if (checkout != null && mounted) {
      await _presentStripeSubscriptionPaymentSheet(
        checkout,
        wasPremiumBeforeCheckout: state.isPremium,
      );
    }
  }

  Future<void> _presentStripeSubscriptionPaymentSheet(
    PremiumCheckoutModel checkout, {
    required bool wasPremiumBeforeCheckout,
  }) async {
    final text = AppLocalizations.of(context);
    final clientSecret = checkout.paymentIntentClientSecret;
    final publishableKey = checkout.publishableKey;
    if (clientSecret == null ||
        clientSecret.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.premiumCheckoutFailed)));
      return;
    }

    try {
      Stripe.publishableKey = publishableKey;
      Stripe.urlScheme = 'petmagicstripe';
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'PetMagic',
          customerId: checkout.customerId,
          customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
          returnURL: 'petmagicstripe://redirect',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (!mounted) {
        return;
      }

      final controller = ref.read(premiumControllerProvider.notifier);
      controller.markCheckoutOpened(
        wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
      );
      await controller.verifyCheckoutStatus();
    } on StripeException catch (error) {
      if (!mounted) {
        return;
      }

      if (_isStripePaymentCanceled(error)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text.premiumPurchaseCancelled)));
        return;
      }

      final message = error.error.localizedMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (message == null || message.isEmpty)
                ? text.premiumCheckoutFailed
                : message,
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? text.premiumCheckoutFailed)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.premiumCheckoutFailed)));
    }
  }

  Future<void> _startCheckoutForProvider(
    PremiumPaymentProvider provider,
    PremiumController controller,
  ) async {
    controller.selectProvider(provider);
    final selectedState = ref.read(premiumControllerProvider);
    if (selectedState.isBuying || !selectedState.canStartCheckout) {
      return;
    }

    await _handleCheckoutTap(selectedState, controller);
  }
}

PremiumPaymentProvider? _preferredStoreProvider(
  PremiumState state,
  TargetPlatform platform,
) {
  final preferredOrder = switch (platform) {
    TargetPlatform.iOS => const [
      PremiumPaymentProvider.appStore,
      PremiumPaymentProvider.googlePlay,
    ],
    TargetPlatform.android => const [
      PremiumPaymentProvider.googlePlay,
      PremiumPaymentProvider.appStore,
    ],
    _ => const [
      PremiumPaymentProvider.googlePlay,
      PremiumPaymentProvider.appStore,
    ],
  };

  for (final provider in preferredOrder) {
    if (state.availableProviders.contains(provider) &&
        state.isProviderAvailable(provider)) {
      return provider;
    }
  }

  return null;
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

  if (raw.contains('economy.payment_provider_unavailable')) {
    return text.premiumCheckoutFailed;
  }

  if (raw.contains('premium_billing_unavailable')) {
    return text.premiumManageFailed;
  }

  return raw;
}

bool _isStripePaymentCanceled(StripeException error) {
  final message = (error.error.localizedMessage ?? '').toLowerCase();
  return message.contains('canceled') || message.contains('cancelled');
}
