part of 'wallet_page.dart';

extension _WalletPageCheckoutStateX on _WalletPageState {
  Future<ExternalCheckoutResult> _handleCheckout(
    PurchaseCheckoutModel checkout,
  ) async {
    final text = AppLocalizations.of(context);
    if (checkout.hasNativeStripePaymentSheet) {
      final paymentResult = await ref
          .read(stripePaymentSheetProvider)
          .present(
            StripePaymentSheetRequest(
              paymentIntentClientSecret: checkout.paymentIntentClientSecret,
              customerId: checkout.customerId,
              customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
              publishableKey: checkout.publishableKey,
              primaryButtonLabel: text.premiumContinueAction,
            ),
          );
      if (paymentResult == StripePaymentSheetResult.cancelled) {
        await ref
            .read(walletControllerProvider.notifier)
            .cancelStripeCheckout(checkout.orderId);
        return ExternalCheckoutResult.cancelledResult;
      }

      await ref
          .read(walletControllerProvider.notifier)
          .verifyStripeCheckout(checkout.externalPaymentId);
      return ExternalCheckoutResult.success;
    }

    final checkoutUrl = checkout.checkoutUrl.trim();
    final uri = parseSafePremiumExternalUri(checkoutUrl);
    if (uri != null) {
      var launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Object {
        launched = false;
      }
      if (launched) {
        _shouldReloadOnResume = true;
        return ExternalCheckoutResult.success;
      }
    }

    return ExternalCheckoutResult.failure(
      error: StateError('wallet.payment_gateway_unavailable'),
      errorMessage: text.walletPaymentGatewayUnavailableError,
    );
  }
}

Future<void> _showPackDetailSheet(
  BuildContext context,
  List<CurrencyPackModel> packs, {
  required List<WalletPaymentMethodModel> paymentMethods,
  required CurrencyPackModel initialPack,
  required bool isBuying,
  required Future<PurchaseCheckoutModel?> Function(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  )
  onBuy,
  required Future<ExternalCheckoutResult> Function(
    PurchaseCheckoutModel checkout,
  )
  onCheckoutReady,
}) async {
  final text = AppLocalizations.of(context);
  if (packs.isEmpty) {
    return;
  }

  final selectedPack = packs.firstWhere(
    (pack) => pack.packId == initialPack.packId,
    orElse: () => packs.first,
  );

  final enabledMethods = paymentMethods
      .where((method) => method.isEnabled)
      .toList(growable: false);
  if (enabledMethods.isEmpty) {
    return;
  }

  var selectedMethod =
      enabledMethods
          .where((method) => method.isSelectedByDefault)
          .cast<WalletPaymentMethodModel?>()
          .firstOrNull ??
      enabledMethods
          .where((method) => method.isRecommended)
          .cast<WalletPaymentMethodModel?>()
          .firstOrNull ??
      enabledMethods.first;

  List<PaymentMethodSheetOption> buildMethodOptions() {
    return paymentMethods
        .map((method) {
          final provider = method.provider.trim().toLowerCase();
          final legalNotice = switch (provider) {
            'stripe' => text.walletCheckoutTrustText,
            'google_play' ||
            'app_store' => text.premiumStorePaymentDisclaimerBody,
            _ => null,
          };
          final storeUnavailableSubtitle =
              !method.isEnabled && method.isStoreNative
              ? _walletStoreUnavailableSubtitle(text, method)
              : null;

          return PaymentMethodSheetOption(
            id: method.provider,
            title: _walletProviderLabel(text, method),
            icon: _walletProviderIcon(method),
            subtitle: storeUnavailableSubtitle ?? method.displaySubtitle,
            badge: method.isRecommended
                ? text.premiumPaymentRecommendedBadge
                : (method.isSelectedByDefault
                      ? text.premiumPaymentDefaultBadge
                      : null),
            warningTitle: method.warningTitle,
            warningMessage: method.warningMessage,
            notes: method.notes,
            legalNotice: legalNotice,
            isEnabled: method.isEnabled,
          );
        })
        .toList(growable: false);
  }

  final selectedOption = await showPaymentMethodSheet(
    context: context,
    title: text.premiumPaymentTitle,
    subtitle: text.walletPaymentMethodChooseSubtitle,
    continueLabel: text.premiumContinueAction,
    continueLabelBuilder: (option) =>
        text.paymentContinueViaProviderAction(option.title),
    options: buildMethodOptions(),
    trustTitle: text.walletPaymentTrustTitle,
    trustLines: [
      text.walletPaymentTrustStripeProcesses,
      text.walletPaymentTrustNoStorage,
      text.walletPaymentTrustTopUpAnytime,
    ],
  );
  if (selectedOption == null || !context.mounted) {
    return;
  }

  for (final method in enabledMethods) {
    if (method.provider == selectedOption.id) {
      selectedMethod = method;
      break;
    }
  }

  if (!selectedMethod.isStripe) {
    final checkout = await onBuy(selectedPack, selectedMethod);
    if (!context.mounted || checkout == null) {
      return;
    }

    final result = await onCheckoutReady(checkout);
    if (!context.mounted || result.completed) {
      return;
    }

    if (!result.cancelled) {
      PetMagicToast.show(
        context,
        message: text.walletPaymentGatewayUnavailableError,
        tone: PetMagicToastTone.warning,
      );
    }
    return;
  }

  final checkoutCompleted = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (pageContext) => WalletStripeCheckoutPage(
        pack: selectedPack,
        paymentMethodLabel: _walletProviderLabel(text, selectedMethod),
        onChooseAnotherMethod: () {},
        onSubmit: () async {
          final checkout = await onBuy(selectedPack, selectedMethod);
          if (checkout == null) {
            return WalletStripeCheckoutSubmitResult(
              status: WalletStripeCheckoutActionStatus.failed,
              message: text.walletPaymentUnavailableError,
            );
          }

          final paymentResult = await onCheckoutReady(checkout);
          if (paymentResult.completed) {
            return const WalletStripeCheckoutSubmitResult(
              status: WalletStripeCheckoutActionStatus.success,
            );
          }

          if (paymentResult.cancelled) {
            return WalletStripeCheckoutSubmitResult(
              status: WalletStripeCheckoutActionStatus.cancelled,
              message: text.premiumPurchaseCancelled,
            );
          }

          return WalletStripeCheckoutSubmitResult(
            status: WalletStripeCheckoutActionStatus.failed,
            message: text.walletPaymentGatewayUnavailableError,
          );
        },
      ),
    ),
  );

  if (checkoutCompleted == false && context.mounted) {
    await _showPackDetailSheet(
      context,
      packs,
      paymentMethods: paymentMethods,
      initialPack: selectedPack,
      isBuying: isBuying,
      onBuy: onBuy,
      onCheckoutReady: onCheckoutReady,
    );
  }
}
