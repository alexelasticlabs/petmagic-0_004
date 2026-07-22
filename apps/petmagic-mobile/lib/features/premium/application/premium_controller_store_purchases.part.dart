part of 'premium_controller.dart';

mixin _PremiumControllerStorePurchases
    on
        _PremiumControllerBase,
        _PremiumControllerLifecycle,
        _PremiumControllerCheckout,
        _PremiumControllerVerification {
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
