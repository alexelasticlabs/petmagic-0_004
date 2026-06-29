import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations_en.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_stripe_checkout_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/payments/stripe_paymentsheet_coordinator.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
part 'premium_page_background.part.dart';
part 'premium_page_plans.part.dart';
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
  static const _paywallFeedbackLastShownKey =
      'feedback_paywall_last_shown_utc_v1';
  static const _paywallFeedbackCooldown = Duration(days: 3);

  bool _shouldReloadOnResume = false;
  bool _didAutoCloseAfterActivation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      ref.read(premiumControllerProvider.notifier).load();
    });
  }

  void _closeAfterSuccessfulActivation() {
    if (!mounted || _didAutoCloseAfterActivation) {
      return;
    }

    _didAutoCloseAfterActivation = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (context.mounted) {
      context.go(TemplatesPage.routePath);
    }
  }

  Future<void> _closePaywall() async {
    await _maybeAskPaywallFeedback();
    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go(TemplatesPage.routePath);
  }

  Future<void> _maybeAskPaywallFeedback() async {
    final preferences = SharedPreferencesAsync();
    final now = DateTime.now().toUtc();
    final lastShownRaw = await preferences.getString(
      _paywallFeedbackLastShownKey,
    );
    final lastShown = lastShownRaw == null
        ? null
        : DateTime.tryParse(lastShownRaw)?.toUtc();
    if (lastShown != null &&
        now.difference(lastShown) < _paywallFeedbackCooldown) {
      return;
    }

    await preferences.setString(
      _paywallFeedbackLastShownKey,
      now.toIso8601String(),
    );
    if (!mounted) {
      return;
    }

    final result = await _showPaywallFeedbackSheet(context);
    if (!mounted || result == null) {
      return;
    }

    await ref
        .read(templateGenerationRepositoryProvider)
        .submitFeedback(
          type: result.category == 'payment_problem'
              ? 'PaymentIssue'
              : 'General',
          category: result.category,
          message: result.message,
          sourceScreen: 'paywall_close',
        );
    if (!mounted) {
      return;
    }

    PetMagicToast.show(
      context,
      message: _paywallFeedbackCopy(context).thanks,
      tone: PetMagicToastTone.success,
    );
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
    final uri = parseSafePremiumExternalUri(url);
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
      continueLabel: text.premiumCheckoutContinueAction(
        text.premiumPaymentStripe,
      ),
      continueLabelBuilder: (option) =>
          text.premiumCheckoutContinueAction(option.title),
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
    if (provider == PremiumPaymentProvider.stripe) {
      final selectedPlan = ref.read(premiumControllerProvider).selectedPlan;
      if (selectedPlan == null) {
        return;
      }

      final checkoutCompleted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (pageContext) => PremiumStripeCheckoutPage(
            plan: selectedPlan,
            paymentMethodLabel: selected.title,
            onChooseAnotherMethod: () {},
            onSubmit: () => _submitStripeCheckout(
              wasPremiumBeforeCheckout: currentState.isPremium,
            ),
          ),
        ),
      );

      if (checkoutCompleted == false && mounted) {
        await _openPaymentMethodSheetAndCheckout();
      }
      return;
    }

    await _startCheckout();
  }

  Future<PremiumStripeCheckoutSubmitResult> _submitStripeCheckout({
    required bool wasPremiumBeforeCheckout,
  }) async {
    final text = _premiumText(context);
    final controller = ref.read(premiumControllerProvider.notifier);
    final checkout = await controller.startCheckout();
    if (!mounted || checkout == null) {
      final state = ref.read(premiumControllerProvider);
      final externalUrl = state.externalUrl;
      if (externalUrl != null && externalUrl.isNotEmpty) {
        return const PremiumStripeCheckoutSubmitResult(
          status: PremiumStripeCheckoutActionStatus.success,
        );
      }

      return PremiumStripeCheckoutSubmitResult(
        status: PremiumStripeCheckoutActionStatus.failed,
        message: _resolveCheckoutErrorMessage(
          text,
          state.errorMessage ?? text.premiumCheckoutFailed,
        ),
      );
    }

    if (!checkout.usesPaymentSheet) {
      return PremiumStripeCheckoutSubmitResult(
        status: PremiumStripeCheckoutActionStatus.failed,
        message: text.premiumCheckoutFailed,
      );
    }

    return _presentStripePaymentSheet(
      checkout: checkout,
      wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
    );
  }

  Future<PremiumStripeCheckoutSubmitResult> _presentStripePaymentSheet({
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
      return PremiumStripeCheckoutSubmitResult(
        status: PremiumStripeCheckoutActionStatus.failed,
        message: text.premiumCheckoutFailed,
      );
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
      return PremiumStripeCheckoutSubmitResult(
        status: result.cancelled
            ? PremiumStripeCheckoutActionStatus.cancelled
            : PremiumStripeCheckoutActionStatus.failed,
        message: result.cancelled
            ? text.premiumPurchaseCancelled
            : text.premiumCheckoutFailed,
      );
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

    final state = ref.read(premiumControllerProvider);
    if (state.checkoutVerificationState ==
        PremiumCheckoutVerificationState.error) {
      return PremiumStripeCheckoutSubmitResult(
        status: PremiumStripeCheckoutActionStatus.failed,
        message: _resolveCheckoutErrorMessage(
          text,
          state.checkoutErrorMessage ??
              state.errorMessage ??
              text.premiumCheckoutFailed,
        ),
      );
    }

    if (state.checkoutVerificationState ==
            PremiumCheckoutVerificationState.pending ||
        state.checkoutVerificationState ==
            PremiumCheckoutVerificationState.activated ||
        state.isPremium) {
      return const PremiumStripeCheckoutSubmitResult(
        status: PremiumStripeCheckoutActionStatus.success,
      );
    }

    return PremiumStripeCheckoutSubmitResult(
      status: PremiumStripeCheckoutActionStatus.failed,
      message: text.premiumCheckoutFailed,
    );
  }

  String _resolveCheckoutErrorMessage(AppLocalizations text, String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('premium.purchase_cancelled')) {
      return text.premiumPurchaseCancelled;
    }
    if (normalized.contains('premium.store_unavailable')) {
      return text.premiumStoreUnavailable;
    }
    if (normalized.contains('templates.network_unavailable')) {
      return text.templateFlowNetworkError;
    }
    if (normalized.contains('premium.store_product_unavailable')) {
      return text.premiumStoreProductUnavailable;
    }
    if (normalized.contains('premium.checkout_failed')) {
      return text.premiumCheckoutFailed;
    }
    if (normalized.isEmpty) {
      return text.premiumCheckoutFailed;
    }
    return text.premiumCheckoutFailed;
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
    final isLoading = ref.watch(
      premiumControllerProvider.select((state) => state.isLoading),
    );
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
        _shouldReloadOnResume = true;
      }

      controller.consumeExternalUrl();
      _openExternalUrl(externalUrl);
    });

    ref.listen(premiumControllerProvider, (previous, next) {
      final justActivatedViaCheckoutState =
          previous?.checkoutVerificationState !=
              PremiumCheckoutVerificationState.activated &&
          next.checkoutVerificationState ==
              PremiumCheckoutVerificationState.activated;
      final justActivatedViaFlag =
          previous?.recentlyActivatedPremium != true &&
          next.recentlyActivatedPremium;
      final justActivatedViaSuccessMessage =
          previous?.successMessage != 'premium.purchase_activated' &&
          next.successMessage == 'premium.purchase_activated' &&
          next.isPremium;

      final justActivated =
          justActivatedViaCheckoutState ||
          justActivatedViaFlag ||
          justActivatedViaSuccessMessage;

      if (!justActivated || !mounted) {
        return;
      }

      final fallbackText = _premiumText(context);
      _closeAfterSuccessfulActivation();

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
              child: isLoading
                  ? Center(
                      key: const ValueKey('premium-loading'),
                      child: CircularProgressIndicator(color: accent),
                    )
                  : _PremiumBodySlot(
                      key: const ValueKey('premium-content'),
                      isDark: isDark,
                      onOpenUrl: _openExternalUrl,
                      onStartCheckout: _openPaymentMethodSheetAndCheckout,
                      onClose: _closePaywall,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBodySlot extends ConsumerWidget {
  const _PremiumBodySlot({
    required super.key,
    required this.isDark,
    required this.onOpenUrl,
    required this.onStartCheckout,
    required this.onClose,
  });

  final bool isDark;
  final Future<void> Function(String url) onOpenUrl;
  final Future<void> Function() onStartCheckout;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(premiumControllerProvider);
    final controller = ref.read(premiumControllerProvider.notifier);

    return _PremiumBody(
      key: const ValueKey('premium-body-inner'),
      state: state,
      controller: controller,
      isDark: isDark,
      onOpenUrl: onOpenUrl,
      onStartCheckout: onStartCheckout,
      onClose: onClose,
    );
  }
}

class _PaywallFeedbackResult {
  const _PaywallFeedbackResult(this.category, this.message);

  final String category;
  final String? message;
}

class _PaywallFeedbackCopy {
  const _PaywallFeedbackCopy({
    required this.title,
    required this.commentLabel,
    required this.commentHint,
    required this.submit,
    required this.thanks,
    required this.options,
  });

  final String title;
  final String commentLabel;
  final String commentHint;
  final String submit;
  final String thanks;
  final List<(String, String)> options;
}

_PaywallFeedbackCopy _paywallFeedbackCopy(BuildContext context) {
  final text = AppLocalizations.of(context);
  return _PaywallFeedbackCopy(
    title: text.premiumPaywallFeedbackTitle,
    commentLabel: text.premiumPaywallFeedbackCommentLabel,
    commentHint: text.premiumPaywallFeedbackCommentHint,
    submit: text.premiumPaywallFeedbackSubmitAction,
    thanks: text.premiumPaywallFeedbackThanksMessage,
    options: [
      ('expensive', text.premiumPaywallFeedbackOptionExpensive),
      ('low_value', text.premiumPaywallFeedbackOptionLowValue),
      ('payment_problem', text.premiumPaywallFeedbackOptionPaymentProblem),
      ('just_browsing', text.premiumPaywallFeedbackOptionJustBrowsing),
      ('other', text.premiumPaywallFeedbackOptionOther),
    ],
  );
}

Future<_PaywallFeedbackResult?> _showPaywallFeedbackSheet(
  BuildContext context,
) {
  final copy = _paywallFeedbackCopy(context);
  final controller = TextEditingController();
  var selected = copy.options.first;

  return showModalBottomSheet<_PaywallFeedbackResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final brightness = Theme.of(context).brightness;
          final isDark = brightness == Brightness.dark;
          final surface = isDark ? _kDarkSurface : _kLightSurface;
          final textColor = isDark ? _kDarkText : _kLightText;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark ? _kDarkBorder : _kLightBorder,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        copy.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in copy.options)
                            ChoiceChip(
                              selected: selected == option,
                              label: Text(option.$2),
                              onSelected: (_) =>
                                  setState(() => selected = option),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: copy.commentLabel,
                          hintText: copy.commentHint,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _PaywallFeedbackResult(
                              selected.$1,
                              controller.text.trim().isEmpty
                                  ? null
                                  : controller.text.trim(),
                            ),
                          );
                        },
                        child: Text(copy.submit),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}
