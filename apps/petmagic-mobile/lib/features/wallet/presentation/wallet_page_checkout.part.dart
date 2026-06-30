part of 'wallet_page.dart';

extension _WalletPageCheckoutStateX on _WalletPageState {
  Future<StripePaymentSheetResult> _handleCheckout(
    PurchaseCheckoutModel checkout,
  ) async {
    final text = AppLocalizations.of(context);
    if (!checkout.usesPaymentSheet) {
      final checkoutUrl = checkout.checkoutUrl.trim();
      final uri = parseSafePremiumExternalUri(checkoutUrl);
      if (uri != null) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          _shouldReloadOnResume = true;
          return StripePaymentSheetResult.success;
        }
      }

      return StripePaymentSheetResult.failure(
        error: StateError('wallet.payment_gateway_unavailable'),
        errorMessage: text.walletPaymentGatewayUnavailableError,
      );
    }

    return _presentStripePaymentSheet(checkout);
  }

  Future<StripePaymentSheetResult> _presentStripePaymentSheet(
    PurchaseCheckoutModel checkout,
  ) async {
    final text = AppLocalizations.of(context);
    final clientSecret = checkout.paymentIntentClientSecret;
    final publishableKey = checkout.publishableKey;
    if (clientSecret == null ||
        clientSecret.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      return StripePaymentSheetResult.failure(
        error: StateError('wallet.payment_gateway_unavailable'),
        errorMessage: text.walletPaymentGatewayUnavailableError,
      );
    }

    _shouldReloadOnResume = true;
    final sheetResult = await StripePaymentSheetCoordinator.present(
      context,
      request: StripePaymentSheetRequest(
        paymentIntentClientSecret: clientSecret,
        publishableKey: publishableKey,
        customerId: checkout.customerId,
        customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
      ),
    );

    if (!sheetResult.completed) {
      _shouldReloadOnResume = false;
      return sheetResult;
    }

    if (!mounted) {
      _shouldReloadOnResume = false;
      return StripePaymentSheetResult.failure(
        error: StateError('wallet.context_unmounted'),
        errorMessage: text.walletPaymentGatewayUnavailableError,
      );
    }

    final controller = ref.read(walletControllerProvider.notifier);
    await controller.verifyStripeCheckout(checkout.externalPaymentId);

    // Fallback polling keeps UX resilient when direct verification is delayed.
    var verificationState = ref
        .read(walletControllerProvider)
        .checkoutVerificationState;
    if (verificationState != WalletCheckoutVerificationState.succeeded) {
      await controller.verifyCheckoutStatus();
      verificationState = ref
          .read(walletControllerProvider)
          .checkoutVerificationState;
    }

    _shouldReloadOnResume = false;

    if (verificationState == WalletCheckoutVerificationState.succeeded) {
      return StripePaymentSheetResult.success;
    }

    final currentState = ref.read(walletControllerProvider);
    final message = switch (verificationState) {
      WalletCheckoutVerificationState.pending =>
        text.externalCheckoutPendingVerificationMessage,
      WalletCheckoutVerificationState.error => _friendlyError(
        text,
        currentState.checkoutErrorMessage ??
            currentState.errorMessage ??
            text.walletPaymentGatewayUnavailableError,
      ),
      _ => text.walletPaymentGatewayUnavailableError,
    };

    return StripePaymentSheetResult.failure(
      error: StateError('wallet.checkout_verification_failed'),
      errorMessage: message,
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
  required Future<StripePaymentSheetResult> Function(
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
