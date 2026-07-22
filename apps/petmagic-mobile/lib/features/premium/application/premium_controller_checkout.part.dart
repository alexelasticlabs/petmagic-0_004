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
}
// Premium checkout application state machine.
