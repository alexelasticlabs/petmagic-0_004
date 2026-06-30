part of 'premium_controller.dart';

mixin _PremiumControllerCheckout
    on _PremiumControllerBase, _PremiumControllerLifecycle {
  Future<void> _refreshPremiumStatusSnapshot() async {
    try {
      final status = await _repository.fetchStatus();
      if (!ref.mounted) {
        return;
      }
      ref.invalidate(premiumSubscriptionSummaryProvider);
      _updateStateIfMounted(
        (state) => state.copyWith(status: status, clearError: true),
      );
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          errorMessage: _premiumErrorMessage(error, 'premium.request_failed'),
        ),
      );
    }
  }

  @override
  Future<PremiumCheckoutModel?> startCheckout() async {
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

    try {
      if (state.selectedProvider == PremiumPaymentProvider.stripe) {
        final checkout = await _repository.createStripeCheckout(
          plan,
          WidgetsBinding.instance.platformDispatcher.locale,
        );
        if (!ref.mounted) {
          return null;
        }
        if (!checkout.usesPaymentSheet) {
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

        _updateStateIfMounted((state) => state.copyWith(isBuying: false));
        return checkout;
      }

      await _repository.startStoreCheckout(plan, state.selectedProvider);
      if (!ref.mounted) {
        return null;
      }
      return null;
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          errorMessage: _premiumErrorMessage(error, 'premium.checkout_failed'),
        ),
      );
      return null;
    }
  }

  @override
  Future<void> manageBilling() async {
    _updateStateIfMounted(
      (state) => state.copyWith(
        isManaging: true,
        clearError: true,
        clearExternalUrl: true,
        clearSuccess: true,
      ),
    );

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

      final managementUrl = await _repository.createManagementUrl(status);
      if (!ref.mounted) {
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
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isManaging: false,
          errorMessage: _premiumErrorMessage(error, 'premium.manage_failed'),
        ),
      );
    }
  }

  @override
  Future<void> restorePurchases() async {
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
    if (!state.isAwaitingCheckoutVerification) {
      return;
    }

    final normalizedPlanCode = stripePlanCode?.trim();
    final normalizedSubscriptionId = stripeExternalSubscriptionId?.trim();
    if ((normalizedPlanCode?.isNotEmpty ?? false) &&
        (normalizedSubscriptionId?.isNotEmpty ?? false)) {
      try {
        await _repository.verifyStripeSubscriptionCheckout(
          planCode: normalizedPlanCode!,
          externalSubscriptionId: normalizedSubscriptionId!,
        );
      } catch (error, stackTrace) {
        _logPremiumCheckoutFailure(
          'verify_stripe_subscription_checkout',
          error,
          stackTrace,
        );
        // Keep polling fallback even when explicit Stripe verification fails.
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
      await _refreshProfile();
      if (!ref.mounted) {
        return;
      }
      // Poll subscription status only; paywall config does not need a full reload here.
      await _refreshPremiumStatusSnapshot();
      if (!ref.mounted) {
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
        if (!ref.mounted) {
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
    if (Platform.isAndroid) {
      return PremiumPaymentProvider.googlePlay;
    }

    if (Platform.isIOS) {
      return PremiumPaymentProvider.appStore;
    }

    return null;
  }

  @override
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!ref.mounted) {
        return;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: true,
              clearError: true,
              clearSuccess: true,
            ),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
          break;
        case PurchaseStatus.error:
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
        case PurchaseStatus.canceled:
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

  Future<void> _verifyStorePurchase(PurchaseDetails purchase) async {
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

    try {
      final verified = await _repository.verifyStorePurchase(
        plan: matchedPlan,
        provider: provider,
        purchase: purchase,
      );
      if (!ref.mounted) {
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
    } catch (error) {
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
    }
  }
}
