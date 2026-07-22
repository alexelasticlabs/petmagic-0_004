part of 'premium_controller.dart';

mixin _PremiumControllerVerification
    on
        _PremiumControllerBase,
        _PremiumControllerLifecycle,
        _PremiumControllerCheckout {
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
}
