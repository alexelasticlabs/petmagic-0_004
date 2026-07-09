import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations_en.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/mappers/premium_error_key_mapper.dart';
import 'package:petmagic_mobile/features/premium/presentation/paywall_feedback_scope.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_stripe_checkout_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
part 'premium_page_background.part.dart';
part 'premium_page_plans.part.dart';
part 'premium_page_sections.part.dart';
part 'premium_page_cta.part.dart';
part 'premium_page_footer.part.dart';
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
  static const _paywallFeedbackCooldown = Duration(days: 3);

  bool _shouldReloadOnResume = false;
  bool _didAutoCloseAfterActivation = false;

  bool _hasHydratedPremiumSnapshot(PremiumState state) {
    return state.plans.isNotEmpty &&
        state.legalTexts != null &&
        state.status != null;
  }

  Future<void> _loadPremiumIfOnline({bool refresh = false}) async {
    if (!mounted || !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    await ref.read(premiumControllerProvider.notifier).load(refresh: refresh);
  }

  Future<void> _resumePremiumCheckoutSyncIfOnline() async {
    if (!mounted ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    _shouldReloadOnResume = false;
    final controller = ref.read(premiumControllerProvider.notifier);
    if (ref.read(premiumControllerProvider).isAwaitingCheckoutVerification) {
      await controller.verifyCheckoutStatus();
      return;
    }

    await controller.load(refresh: true);
  }

  void _initializePremiumPage() {
    WidgetsBinding.instance.addObserver(this);
    if (_hasHydratedPremiumSnapshot(ref.read(premiumControllerProvider))) {
      return;
    }

    Future.microtask(() {
      if (!mounted) {
        return;
      }

      if (_hasHydratedPremiumSnapshot(ref.read(premiumControllerProvider))) {
        return;
      }

      unawaited(_loadPremiumIfOnline());
    });
  }

  void _disposePremiumPage() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void _handlePremiumPageLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed && _shouldReloadOnResume) {
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        _shouldReloadOnResume = false;
        return;
      }
      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        return;
      }

      unawaited(_resumePremiumCheckoutSyncIfOnline());
    }
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
    final scopeKey =
        await PaywallFeedbackScopeResolver(
          sessionStorage: ref.read(authSessionStorageProvider),
        ).resolve(
          isAuthenticated: ref
              .read(appLaunchControllerProvider)
              .isAuthenticated,
          profileUserId: ref.read(profileControllerProvider).profile?.userId,
        );
    if (scopeKey == null) {
      return;
    }

    final lastShownKey = buildPaywallFeedbackLastShownStorageKey(scopeKey);
    final legacyLastShownKey = buildLegacyPaywallFeedbackLastShownStorageKey(
      scopeKey,
    );
    final now = DateTime.now().toUtc();
    var lastShownRaw = await preferences.getString(lastShownKey);
    final shouldMigrateLegacy =
        (lastShownRaw == null || lastShownRaw.isEmpty) &&
        legacyLastShownKey != lastShownKey;
    if (legacyLastShownKey != lastShownKey) {
      if (shouldMigrateLegacy) {
        lastShownRaw = await preferences.getString(legacyLastShownKey);
        if (lastShownRaw != null && lastShownRaw.isNotEmpty) {
          await preferences.setString(lastShownKey, lastShownRaw);
        }
      }
      await preferences.remove(legacyLastShownKey);
    }
    final lastShown = lastShownRaw == null
        ? null
        : DateTime.tryParse(lastShownRaw)?.toUtc();
    if (lastShown != null &&
        now.difference(lastShown) < _paywallFeedbackCooldown) {
      return;
    }

    await preferences.setString(lastShownKey, now.toIso8601String());
    if (!mounted) {
      return;
    }

    final result = await _showPaywallFeedbackSheet(context);
    if (!mounted || result == null) {
      return;
    }

    try {
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
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Premium.PaywallFeedback',
        operation: 'submit',
        message: 'Paywall feedback submit failed',
        context: {'category': result.category},
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!mounted) {
      return;
    }

    PetMagicToast.show(
      context,
      message: _paywallFeedbackCopy(context).thanks,
      tone: PetMagicToastTone.success,
    );
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

    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      launched = false;
    }

    if (!launched && mounted) {
      final text = _premiumText(context);
      PetMagicToast.show(
        context,
        message: text.premiumManageFailed,
        tone: PetMagicToastTone.warning,
      );
    }
  }

  Future<bool> _ensureAuthenticatedForCheckout() async {
    if (ref.read(appLaunchControllerProvider).isAuthenticated) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    showAuthRequiredSheet(context, redirectPath: PremiumPage.routePath);
    return false;
  }

  Future<void> _startCheckout() async {
    if (!await _ensureAuthenticatedForCheckout()) {
      return;
    }

    final controller = ref.read(premiumControllerProvider.notifier);
    await controller.startCheckout();
  }

  Future<void> _openPaymentMethodSheetAndCheckout() async {
    final text = _premiumText(context);
    if (!await _ensureAuthenticatedForCheckout()) {
      return;
    }
    if (!mounted) {
      return;
    }

    final state = ref.read(premiumControllerProvider);
    final plan = state.selectedPlan;
    if (plan == null) {
      return;
    }

    final availableMethods = state.paymentMethods
        .where((method) => method.isEnabled)
        .toList(growable: false);
    if (availableMethods.isEmpty) {
      PetMagicToast.show(
        context,
        message: text.premiumStoreUnavailable,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    final options = availableMethods
        .map((method) {
          return PaymentMethodSheetOption(
            id: method.provider.value,
            title: method.displayLabel?.trim().isNotEmpty == true
                ? method.displayLabel!.trim()
                : _providerLabel(text, method.provider),
            subtitle: method.displaySubtitle,
            icon: _providerIcon(method.provider),
            badge: method.isRecommended
                ? text.premiumPaymentRecommendedBadge
                : null,
            warningTitle: method.warningTitle,
            warningMessage: method.warningMessage,
            notes: method.notes,
            legalNotice: state.legalNotice.trim().isEmpty
                ? null
                : state.legalNotice,
          );
        })
        .toList(growable: false);

    final selected = await showPaymentMethodSheet(
      context: context,
      title: text.premiumPaymentTitle,
      continueLabel: text.premiumContinueAction,
      options: options,
      subtitle: text.premiumPaymentChooseSubtitle,
    );
    if (!mounted || selected == null) {
      return;
    }

    final provider = PremiumPaymentProvider.fromValue(selected.id);
    ref.read(premiumControllerProvider.notifier).selectProvider(provider);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    if (provider != PremiumPaymentProvider.stripe) {
      await _startCheckout();
      return;
    }

    final paymentMethodLabel = selected.title.trim().isEmpty
        ? _providerLabel(text, provider)
        : selected.title;
    final opened = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PremiumStripeCheckoutPage(
          plan: plan,
          paymentMethodLabel: paymentMethodLabel,
          onSubmit: () async {
            final controller = ref.read(premiumControllerProvider.notifier);
            final wasPremiumBeforeCheckout = ref
                .read(premiumControllerProvider)
                .isPremium;
            await controller.startCheckout();
            if (!mounted) {
              return const PremiumStripeCheckoutSubmitResult(
                status: PremiumStripeCheckoutActionStatus.failed,
              );
            }
            final checkoutState = ref.read(premiumControllerProvider);
            final externalUrl = checkoutState.externalUrl;
            if (externalUrl != null && externalUrl.isNotEmpty) {
              controller.markCheckoutOpened(
                wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
              );
              return const PremiumStripeCheckoutSubmitResult(
                status: PremiumStripeCheckoutActionStatus.success,
              );
            }

            return PremiumStripeCheckoutSubmitResult(
              status: PremiumStripeCheckoutActionStatus.failed,
              message: _resolveCheckoutErrorMessage(
                text,
                checkoutState.errorMessage ?? 'premium.checkout_failed',
              ),
            );
          },
          onChooseAnotherMethod: () {},
        ),
      ),
    );
    if (opened == true) {
      _shouldReloadOnResume = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePremiumPage();
  }

  @override
  void dispose() {
    _disposePremiumPage();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    _handlePremiumPageLifecycleChange(appState);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(premiumControllerProvider);
    final isLoading = ref.watch(
      premiumControllerProvider.select((state) => state.isLoading),
    );
    final controller = ref.read(premiumControllerProvider.notifier);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showOfflineUnavailable =
        !_hasHydratedPremiumSnapshot(state) && !hasInternet;
    final unavailableKind =
        !_hasHydratedPremiumSnapshot(state) && !state.isInitialLoading
        ? classifyAppUnavailable(
            raw: state.errorMessage,
            hasInternet: hasInternet,
          )
        : null;

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

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      final premiumState = ref.read(premiumControllerProvider);
      final isAuthenticated = ref
          .read(appLaunchControllerProvider)
          .isAuthenticated;
      if ((_shouldReloadOnResume ||
              premiumState.isAwaitingCheckoutVerification) &&
          isAuthenticated) {
        unawaited(_resumePremiumCheckoutSyncIfOnline());
        return;
      }

      if (_hasHydratedPremiumSnapshot(premiumState)) {
        return;
      }

      unawaited(_loadPremiumIfOnline(refresh: true));
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
          normalizePremiumErrorKey(previous?.successMessage) !=
              'premium.purchase_activated' &&
          normalizePremiumErrorKey(next.successMessage) ==
              'premium.purchase_activated' &&
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
              child: showOfflineUnavailable
                  ? SafeArea(
                      key: const ValueKey('premium-offline'),
                      child: PetMagicUnavailableView(
                        kind: AppUnavailableKind.offline,
                        onRetry: () =>
                            unawaited(_loadPremiumIfOnline(refresh: true)),
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                      ),
                    )
                  : unavailableKind != null
                  ? SafeArea(
                      key: const ValueKey('premium-unavailable'),
                      child: PetMagicUnavailableView(
                        kind: unavailableKind,
                        onRetry: () =>
                            unawaited(_loadPremiumIfOnline(refresh: true)),
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                      ),
                    )
                  : isLoading
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

String _resolveCheckoutErrorMessage(AppLocalizations text, String value) {
  final authMessage = mapCommonAuthFeedbackMessage(text, value);
  if (authMessage != null) {
    return authMessage;
  }

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

  return text.premiumCheckoutFailed;
}

String _providerLabel(AppLocalizations text, PremiumPaymentProvider provider) {
  return switch (provider) {
    PremiumPaymentProvider.stripe => text.premiumPaymentStripe,
    PremiumPaymentProvider.googlePlay => text.premiumPaymentGooglePlay,
    PremiumPaymentProvider.appStore => text.premiumPaymentApple,
  };
}

IconData _providerIcon(PremiumPaymentProvider provider) {
  return switch (provider) {
    PremiumPaymentProvider.stripe => Icons.credit_card_rounded,
    PremiumPaymentProvider.googlePlay => Icons.shop_rounded,
    PremiumPaymentProvider.appStore => Icons.phone_iphone_rounded,
  };
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                    ),
                    child: SingleChildScrollView(
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
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _PaywallFeedbackOptions(
                            options: copy.options,
                            selected: selected,
                            isDark: isDark,
                            textColor: textColor,
                            onSelected: (option) =>
                                setState(() => selected = option),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: copy.commentLabel,
                              hintText: copy.commentHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
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
                          ),
                        ],
                      ),
                    ),
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

class _PaywallFeedbackOptions extends StatelessWidget {
  const _PaywallFeedbackOptions({
    required this.options,
    required this.selected,
    required this.isDark,
    required this.textColor,
    required this.onSelected,
  });

  final List<(String, String)> options;
  final (String, String) selected;
  final bool isDark;
  final Color textColor;
  final ValueChanged<(String, String)> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 360 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisExtent: 46,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return _PaywallFeedbackOptionButton(
              label: option.$2,
              selected: selected == option,
              isDark: isDark,
              textColor: textColor,
              onPressed: () => onSelected(option),
            );
          },
        );
      },
    );
  }
}

class _PaywallFeedbackOptionButton extends StatelessWidget {
  const _PaywallFeedbackOptionButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDark
        ? const Color(0xFF385842)
        : const Color(0xFFDCEFE3);
    final borderColor = selected
        ? selectedColor
        : (isDark ? _kDarkBorder : _kLightBorder);

    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: selected
                      ? Icon(Icons.check_rounded, size: 18, color: textColor)
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
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
