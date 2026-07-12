part of 'premium_controller.dart';

mixin _PremiumControllerCheckout
    on _PremiumControllerBase, _PremiumControllerLifecycle {
  bool _hasAuthenticatedPremiumSession() {
    return ref.read(appLaunchControllerProvider).isAuthenticated;
  }

  void _resetCheckoutVerificationForSignedOutSession() {
    _updateStateIfMounted(
      (state) => state.copyWith(
        status: _guestPremiumStatus,
        checkoutVerificationState: PremiumCheckoutVerificationState.idle,
        isAwaitingCheckoutVerification: false,
        recentlyActivatedPremium: false,
        clearCheckoutError: true,
        clearError: true,
      ),
    );
  }

  Future<void> _refreshPremiumStatusSnapshot() async {
    if (!_hasAuthenticatedPremiumSession()) {
      _resetCheckoutVerificationForSignedOutSession();
      return;
    }

    final cancelToken = _startStatusRefreshRequestCancellation();
    try {
      final status = await _repository.fetchStatus(cancelToken: cancelToken);
      if (!ref.mounted || cancelToken.isCancelled) {
        return;
      }
      ref.invalidate(premiumSubscriptionSummaryProvider);
      _updateStateIfMounted(
        (state) => state.copyWith(status: status, clearError: true),
      );
    } on RequestCancelledException {
      return;
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          errorMessage: _premiumErrorMessage(error, 'premium.request_failed'),
        ),
      );
    } finally {
      _clearActiveStatusRefresh(cancelToken);
    }
  }

  @override
  Future<PremiumCheckoutModel?> startCheckout() async {
    if (!_hasAuthenticatedPremiumSession()) {
      return null;
    }

    final plan = state.selectedPlan;
    if (plan == null) {
      return null;
    }

    if (!state.canStartCheckout) {
      _updateStateIfMounted(
        (state) =>
            state.copyWith(errorMessage: 'premium.store_product_unavailable'),
      );
      return null;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        isBuying: true,
        clearError: true,
        clearExternalUrl: true,
        clearSuccess: true,
        checkoutVerificationState: PremiumCheckoutVerificationState.idle,
        isAwaitingCheckoutVerification: false,
        clearCheckoutError: true,
        recentlyActivatedPremium: false,
      ),
    );

    final cancelToken = _startPremiumActionRequestCancellation();
    try {
      if (state.selectedProvider == PremiumPaymentProvider.stripe) {
        final checkout = await _repository.createStripeCheckout(
          plan,
          _runtimeInfo.locale,
          cancelToken: cancelToken,
        );
        if (!ref.mounted || cancelToken.isCancelled) {
          return null;
        }
        final safeCheckoutUri = parseSafePremiumExternalUri(
          checkout.checkoutUrl,
        );
        if (safeCheckoutUri != null) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              externalUrl: safeCheckoutUri.toString(),
            ),
          );
          return null;
        }

        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            errorMessage: 'premium.checkout_failed',
          ),
        );
        return null;
      }

      await _repository.startStoreCheckout(plan, state.selectedProvider);
      if (!ref.mounted || cancelToken.isCancelled) {
        return null;
      }
      return null;
    } on RequestCancelledException {
      _updateStateIfMounted((state) => state.copyWith(isBuying: false));
      return null;
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          errorMessage: _premiumErrorMessage(error, 'premium.checkout_failed'),
        ),
      );
      return null;
    } finally {
      _clearActivePremiumAction(cancelToken);
    }
  }

  @override
  Future<void> manageBilling() async {
    if (!_hasAuthenticatedPremiumSession()) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        isManaging: true,
        clearError: true,
        clearExternalUrl: true,
        clearSuccess: true,
      ),
    );

    final cancelToken = _startPremiumActionRequestCancellation();
    try {
      final status = state.status;
      if (status == null) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isManaging: false,
            errorMessage: 'premium.manage_failed',
          ),
        );
        return;
      }

      final managementUrl = await _repository.createManagementUrl(
        status,
        cancelToken: cancelToken,
      );
      if (!ref.mounted || cancelToken.isCancelled) {
        return;
      }
      final safeManagementUri = parseSafePremiumExternalUri(managementUrl);
      if (safeManagementUri == null) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isManaging: false,
            errorMessage: 'premium.manage_failed',
          ),
        );
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isManaging: false,
          externalUrl: safeManagementUri.toString(),
        ),
      );
    } on RequestCancelledException {
      _updateStateIfMounted((state) => state.copyWith(isManaging: false));
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isManaging: false,
          errorMessage: _premiumErrorMessage(error, 'premium.manage_failed'),
        ),
      );
    } finally {
      _clearActivePremiumAction(cancelToken);
    }
  }

  @override
  Future<void> restorePurchases() async {
    if (!_hasAuthenticatedPremiumSession()) {
      return;
    }

    if (state.selectedProvider != PremiumPaymentProvider.stripe) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isRestoring: true,
          clearError: true,
          clearSuccess: true,
        ),
      );

      try {
        await _repository.restoreStorePurchases();
        if (!ref.mounted) {
          return;
        }
        await _refreshProfile();
        if (!ref.mounted) {
          return;
        }
        await load(refresh: true);
        if (!ref.mounted) {
          return;
        }
        ref.invalidate(premiumSubscriptionSummaryProvider);
        _updateStateIfMounted(
          (state) => state.copyWith(
            isRestoring: false,
            successMessage: 'premium.restore_started',
          ),
        );
      } catch (error) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isRestoring: false,
            errorMessage: _premiumErrorMessage(
              error,
              'premium.checkout_failed',
            ),
          ),
        );
      }

      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        isRestoring: true,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      await _refreshProfile();
      if (!ref.mounted) {
        return;
      }
      await load(refresh: true);
      if (!ref.mounted) {
        return;
      }
      ref.invalidate(premiumSubscriptionSummaryProvider);

      _updateStateIfMounted(
        (state) => state.copyWith(
          isRestoring: false,
          successMessage: 'premium.restore_started',
        ),
      );
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isRestoring: false,
          errorMessage: _premiumErrorMessage(error, 'premium.checkout_failed'),
        ),
      );
    }
  }

  @override
  void consumeExternalUrl() {
    state = state.copyWith(clearExternalUrl: true);
  }

  @override
  void markCheckoutOpened({required bool wasPremiumBeforeCheckout}) {
    state = state.copyWith(
      isAwaitingCheckoutVerification: true,
      wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
      checkoutVerificationState: PremiumCheckoutVerificationState.idle,
      clearCheckoutError: true,
      recentlyActivatedPremium: false,
    );
  }

  @override
  Future<void> verifyCheckoutStatus({
    String? stripePlanCode,
    String? stripeExternalSubscriptionId,
  }) async {
    final inFlight = _checkoutVerificationInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _performCheckoutStatusVerification(
      stripePlanCode: stripePlanCode,
      stripeExternalSubscriptionId: stripeExternalSubscriptionId,
    );
    _checkoutVerificationInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_checkoutVerificationInFlight, operation)) {
        _checkoutVerificationInFlight = null;
      }
    }
  }

  Future<void> _performCheckoutStatusVerification({
    String? stripePlanCode,
    String? stripeExternalSubscriptionId,
  }) async {
    if (!_hasInternet) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          checkoutVerificationState: PremiumCheckoutVerificationState.error,
          isAwaitingCheckoutVerification: false,
          checkoutErrorMessage: 'templates.network_unavailable',
        ),
      );
      return;
    }

    if (!state.isAwaitingCheckoutVerification) {
      return;
    }

    if (!_hasAuthenticatedPremiumSession()) {
      _resetCheckoutVerificationForSignedOutSession();
      return;
    }

    final normalizedPlanCode = stripePlanCode?.trim();
    final normalizedSubscriptionId = stripeExternalSubscriptionId?.trim();
    if ((normalizedPlanCode?.isNotEmpty ?? false) &&
        (normalizedSubscriptionId?.isNotEmpty ?? false)) {
      final verificationRequestCancellation =
          _startCheckoutVerificationRequestCancellation();
      try {
        await _repository.verifyStripeSubscriptionCheckout(
          planCode: normalizedPlanCode!,
          externalSubscriptionId: normalizedSubscriptionId!,
          cancelToken: verificationRequestCancellation,
        );
        if (!ref.mounted ||
            !_hasInternet ||
            verificationRequestCancellation.isCancelled) {
          return;
        }
      } on RequestCancelledException {
        return;
      } catch (error, stackTrace) {
        _logPremiumCheckoutFailure(
          'verify_stripe_subscription_checkout',
          error,
          stackTrace,
        );
        // Keep polling fallback even when explicit Stripe verification fails.
      } finally {
        _clearActiveCheckoutVerification(verificationRequestCancellation);
      }
    }

    if (!ref.mounted) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: PremiumCheckoutVerificationState.checking,
        clearCheckoutError: true,
        recentlyActivatedPremium: false,
      ),
    );

    const maxAttempts = 4;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!_hasInternet) {
        return;
      }
      if (!_hasAuthenticatedPremiumSession()) {
        _resetCheckoutVerificationForSignedOutSession();
        return;
      }
      await _refreshProfile();
      if (!ref.mounted || !_hasInternet) {
        return;
      }
      if (!_hasAuthenticatedPremiumSession()) {
        _resetCheckoutVerificationForSignedOutSession();
        return;
      }
      // Poll subscription status only; paywall config does not need a full reload here.
      await _refreshPremiumStatusSnapshot();
      if (!ref.mounted || !_hasInternet) {
        return;
      }
      if (!_hasAuthenticatedPremiumSession()) {
        _resetCheckoutVerificationForSignedOutSession();
        return;
      }

      final updatedState = state;
      if (updatedState.errorMessage != null) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            checkoutVerificationState: PremiumCheckoutVerificationState.error,
            checkoutErrorMessage: updatedState.errorMessage,
            isAwaitingCheckoutVerification: false,
            recentlyActivatedPremium: false,
          ),
        );
        return;
      }

      final recentlyActivated =
          !updatedState.wasPremiumBeforeCheckout && updatedState.isPremium;
      if (recentlyActivated) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            checkoutVerificationState:
                PremiumCheckoutVerificationState.activated,
            isAwaitingCheckoutVerification: false,
            recentlyActivatedPremium: true,
            clearCheckoutError: true,
          ),
        );
        return;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!ref.mounted || !_hasInternet) {
          return;
        }
      }
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: PremiumCheckoutVerificationState.pending,
        isAwaitingCheckoutVerification: false,
        recentlyActivatedPremium: false,
        clearCheckoutError: true,
      ),
    );
  }

  PremiumPaymentProvider? _platformStoreProvider() {
    if (_runtimeInfo.platform == AppRuntimePlatform.android) {
      return PremiumPaymentProvider.googlePlay;
    }

    if (_runtimeInfo.platform == AppRuntimePlatform.ios) {
      return PremiumPaymentProvider.appStore;
    }

    return null;
  }

  @override
  Future<void> _handlePurchaseUpdates(
    List<StorePurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (!ref.mounted) {
        return;
      }

      switch (purchase.status) {
        case StorePurchaseStatus.pending:
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: true,
              clearError: true,
              clearSuccess: true,
            ),
          );
          break;
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
          break;
        case StorePurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
            if (!ref.mounted) {
              return;
            }
          }

          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              isRestoring: false,
              errorMessage: _premiumPurchaseErrorMessage(
                purchase.error?.message,
              ),
            ),
          );
          break;
        case StorePurchaseStatus.canceled:
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              isRestoring: false,
              errorMessage: 'premium.purchase_cancelled',
            ),
          );
          break;
      }
    }
  }

  Future<void> _verifyStorePurchase(StorePurchaseDetails purchase) async {
    final wasPremiumBeforeCheckout = state.isPremium;
    final provider = _platformStoreProvider();
    if (provider == null) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          isRestoring: false,
          errorMessage: 'premium.store_unavailable',
        ),
      );
      return;
    }

    PremiumPlanModel? matchedPlan;
    for (final plan in state.plans) {
      if (plan.productIdFor(provider) == purchase.productID) {
        matchedPlan = plan;
        break;
      }
    }

    if (matchedPlan == null) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          isRestoring: false,
          errorMessage: 'premium.store_product_unavailable',
        ),
      );
      return;
    }

    final verificationKey = _storePurchaseVerificationKey(
      provider: provider,
      purchase: purchase,
    );
    if (verificationKey != null) {
      if (_storePurchaseVerifiedKeys.contains(verificationKey)) {
        if (purchase.pendingCompletePurchase) {
          await _repository.completePurchase(purchase);
        }
        return;
      }

      if (!_storePurchaseVerificationInFlightKeys.add(verificationKey)) {
        return;
      }
    }

    final verificationRequestCancellation =
        _startCheckoutVerificationRequestCancellation();
    try {
      final verified = await _repository.verifyStorePurchase(
        plan: matchedPlan,
        provider: provider,
        purchase: purchase,
        cancelToken: verificationRequestCancellation,
      );
      if (verificationKey != null) {
        _rememberStorePurchaseVerifiedKey(verificationKey);
      }
      if (!ref.mounted || verificationRequestCancellation.isCancelled) {
        return;
      }

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }

      await _refreshProfile();
      if (!ref.mounted) {
        return;
      }
      await load(refresh: true);
      if (!ref.mounted) {
        return;
      }

      if (verified.isActive) {
        final recentlyActivated = !wasPremiumBeforeCheckout && state.isPremium;
        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            isRestoring: false,
            successMessage: 'premium.purchase_activated',
            checkoutVerificationState: recentlyActivated
                ? PremiumCheckoutVerificationState.activated
                : PremiumCheckoutVerificationState.idle,
            isAwaitingCheckoutVerification: false,
            recentlyActivatedPremium: recentlyActivated,
            clearCheckoutError: true,
          ),
        );
        return;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(isBuying: false, isRestoring: false),
      );
      markCheckoutOpened(wasPremiumBeforeCheckout: wasPremiumBeforeCheckout);
      await verifyCheckoutStatus();
    } on RequestCancelledException {
      return;
    } catch (error) {
      if (verificationRequestCancellation.isCancelled) {
        return;
      }

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          isRestoring: false,
          errorMessage: _premiumErrorMessage(error, 'premium.checkout_failed'),
        ),
      );
    } finally {
      _clearActiveCheckoutVerification(verificationRequestCancellation);
      if (verificationKey != null) {
        _storePurchaseVerificationInFlightKeys.remove(verificationKey);
      }
    }
  }

  String? _storePurchaseVerificationKey({
    required PremiumPaymentProvider provider,
    required StorePurchaseDetails purchase,
  }) {
    final purchaseId = purchase.purchaseID?.trim();
    if (purchaseId != null && purchaseId.isNotEmpty) {
      return '${provider.value}:${purchase.productID}:purchase:$purchaseId';
    }

    final transactionDate = purchase.transactionDate?.trim();
    if (transactionDate != null && transactionDate.isNotEmpty) {
      return '${provider.value}:${purchase.productID}:transaction:$transactionDate';
    }

    return null;
  }

  void _rememberStorePurchaseVerifiedKey(String verificationKey) {
    _storePurchaseVerifiedKeys.add(verificationKey);
    while (_storePurchaseVerifiedKeys.length >
        _PremiumControllerBase._maxStorePurchaseVerificationKeys) {
      _storePurchaseVerifiedKeys.remove(_storePurchaseVerifiedKeys.first);
    }
  }
}
// Premium checkout application state machine.
