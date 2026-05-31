import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations_en.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/payments/stripe_paymentsheet_coordinator.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:url_launcher/url_launcher.dart';
part 'premium_page_content.part.dart';

// ─── Color constants ────────────────────────────────────────────────────────
const _kDarkBg = Color(0xFF090A10);
const _kDarkSurface = Color(0xFF13141F);
const _kDarkText = Colors.white;
const _kDarkSubtitle = Color(0xFFD7D8E3);
const _kDarkAccent = Color(0xFFF7CD5A);
const _kDarkBorder = Color(0xFF232431);
const _kDarkFreeBg = Color(0xFF0F1019);

const _kLightBg = Color(0xFFEFF4FA);
const _kLightSurface = Color(0xFFFFFFFF);
const _kLightText = Color(0xFF0F1D35);
const _kLightSubtitle = Color(0xFF2A3E56);
const _kLightAccent = Color(0xFFCC9A2D);
const _kLightBorder = Color(0xFFA8B9CC);
const _kLightFreeBg = Color(0xFFE9F0F8);

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
    final uri = parseSafeExternalUri(
      url,
      allowedHttpsHosts: premiumExternalAllowedHosts(),
    );
    if (uri == null) {
      if (mounted) {
        final text = _premiumText(context);
        PetMagicToast.show(
          context,
          message: text.premiumManageFailed,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      final text = _premiumText(context);
      PetMagicToast.show(
        context,
        message: text.premiumManageFailed,
        tone: PetMagicToastTone.warning,
      );
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
      subtitle: text.premiumPaymentChooseSubtitle,
      continueLabel: text.premiumContinueAction,
      continueLabelBuilder: (option) =>
          text.paymentContinueViaProviderAction(option.title),
      options: options,
      trustTitle: text.premiumSecurePaymentTitle,
      trustLines: [
        text.premiumPaymentTrustStripeProcesses,
        text.premiumPaymentTrustNoStorage,
        text.premiumPaymentTrustManageInApp,
      ],
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
    final text = _premiumText(context);
    final clientSecret = checkout.paymentIntentClientSecret;
    final publishableKey = checkout.publishableKey;
    if (clientSecret == null ||
        clientSecret.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      if (mounted) {
        PetMagicToast.show(
          context,
          message: text.premiumCheckoutFailed,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final result = await StripePaymentSheetCoordinator.present(
      context,
      request: StripePaymentSheetRequest(
        paymentIntentClientSecret: clientSecret,
        publishableKey: publishableKey,
        customerId: checkout.customerId,
        customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
      ),
    );
    if (!result.completed || !mounted) {
      if (mounted) {
        final failureMessage = result.errorMessage?.trim();
        final resolved = result.cancelled
            ? text.premiumPurchaseCancelled
            : (failureMessage == null || failureMessage.isEmpty)
            ? text.premiumCheckoutFailed
            : failureMessage;
        PetMagicToast.show(
          context,
          message: resolved,
          tone: result.cancelled
              ? PetMagicToastTone.info
              : PetMagicToastTone.warning,
        );
      }
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
          subtitle: method.displaySubtitle?.trim().isNotEmpty == true
              ? method.displaySubtitle
              : _providerSubtitle(provider, text),
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

  String _providerSubtitle(
    PremiumPaymentProvider provider,
    AppLocalizations text,
  ) {
    return switch (provider) {
      PremiumPaymentProvider.stripe => text.premiumPaymentStripeSubtitle,
      PremiumPaymentProvider.googlePlay =>
        text.premiumPaymentGooglePlaySubtitle,
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
      final navigator = Navigator.of(context);

      if (navigator.canPop()) {
        navigator.pop();
      }

      PetMagicToast.show(
        context,
        message: fallbackText.premiumPurchaseActivated,
        tone: PetMagicToastTone.success,
      );
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _PremiumGoldenBackground(isDark: isDark),
              ),
            ),
            AnimatedSwitcher(
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
          ],
        ),
      ),
    );
  }
}
