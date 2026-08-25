part of 'premium_page.dart';

extension on _PremiumPageState {
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

    context.appNavigator.go(const TemplatesDestination());
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
        now.difference(lastShown) <
            _PremiumPageState._paywallFeedbackCooldown) {
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
          final legalNotice = state.legalNoticeFor(method).trim();
          return PaymentMethodSheetOption(
            id: method.provider.value,
            title: _providerLabel(text, method.provider),
            subtitle: _providerSubtitle(text, method.provider),
            icon: _providerIcon(method.provider),
            badge: method.isRecommended
                ? text.premiumPaymentRecommendedBadge
                : null,
            warningTitle: method.warningTitle,
            warningMessage: method.warningMessage,
            notes: method.notes,
            legalNotice: legalNotice.isEmpty ? null : legalNotice,
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
            final checkout = await controller.startCheckout();
            if (!mounted) {
              return const PremiumStripeCheckoutSubmitResult(
                status: PremiumStripeCheckoutActionStatus.failed,
              );
            }
            if (checkout?.hasNativeStripePaymentSheet == true) {
              final paymentResult = await ref
                  .read(stripePaymentSheetProvider)
                  .present(
                    StripePaymentSheetRequest(
                      paymentIntentClientSecret:
                          checkout!.paymentIntentClientSecret,
                      customerId: checkout.customerId,
                      customerEphemeralKeySecret:
                          checkout.customerEphemeralKeySecret,
                      publishableKey: checkout.publishableKey,
                      primaryButtonLabel: text.premiumContinueAction,
                    ),
                  );
              if (paymentResult == StripePaymentSheetResult.cancelled) {
                return PremiumStripeCheckoutSubmitResult(
                  status: PremiumStripeCheckoutActionStatus.cancelled,
                  message: text.premiumPurchaseCancelled,
                );
              }

              controller.markCheckoutOpened(
                wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
              );
              await controller.verifyCheckoutStatus(
                stripePlanCode: plan.planCode,
                stripeExternalSubscriptionId: checkout.externalSubscriptionId,
              );
              return const PremiumStripeCheckoutSubmitResult(
                status: PremiumStripeCheckoutActionStatus.success,
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

String _providerSubtitle(
  AppLocalizations text,
  PremiumPaymentProvider provider,
) {
  return switch (provider) {
    PremiumPaymentProvider.stripe => text.premiumPaymentStripeSubtitle,
    PremiumPaymentProvider.googlePlay => text.premiumPaymentGooglePlaySubtitle,
    PremiumPaymentProvider.appStore => text.premiumPaymentAppleSubtitle,
  };
}

IconData _providerIcon(PremiumPaymentProvider provider) {
  return switch (provider) {
    PremiumPaymentProvider.stripe => Icons.credit_card_rounded,
    PremiumPaymentProvider.googlePlay => Icons.shop_rounded,
    PremiumPaymentProvider.appStore => Icons.phone_iphone_rounded,
  };
}
