import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations_en.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/application/premium_error_key_mapper.dart';
import 'package:petmagic_mobile/features/premium/presentation/paywall_feedback_scope.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_stripe_checkout_page.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
part 'premium_page_background.part.dart';
part 'premium_page_plans.part.dart';
part 'premium_page_sections.part.dart';
part 'premium_page_benefits.part.dart';
part 'premium_page_cta.part.dart';
part 'premium_page_footer.part.dart';
part 'premium_page_content.part.dart';
part 'premium_page_checkout.part.dart';
part 'premium_page_feedback.part.dart';

// â”€â”€â”€ Color constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      context.appNavigator.go(const TemplatesDestination());
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
      final justRestored =
          normalizePremiumErrorKey(previous?.successMessage) !=
              'premium.restore_started' &&
          normalizePremiumErrorKey(next.successMessage) ==
              'premium.restore_started';

      final justActivated =
          justActivatedViaCheckoutState ||
          justActivatedViaFlag ||
          justActivatedViaSuccessMessage;

      if ((!justActivated && !justRestored) || !mounted) {
        return;
      }

      final fallbackText = _premiumText(context);
      if (justRestored) {
        PetMagicToast.show(
          context,
          message: fallbackText.premiumRestoreStarted,
          tone: PetMagicToastTone.success,
        );
        return;
      }

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
