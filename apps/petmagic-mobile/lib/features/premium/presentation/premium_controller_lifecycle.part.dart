part of 'premium_controller.dart';

mixin _PremiumControllerLifecycle on _PremiumControllerBase {
  bool _purchaseUpdatesListenerRegistered = false;

  void _ensurePremiumLifecycleStarted() {
    if (!_premiumLifecycleStarted) {
      _premiumLifecycleStarted = true;
      _hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
      ref.listen<bool>(
        networkStatusControllerProvider.select((state) => state.hasInternet),
        (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
      );
      ref.onDispose(() {
        _cancelActiveLoad();
        _cancelActiveStatusRefresh();
        _cancelActivePremiumAction();
        _cancelActiveCheckoutVerification();
      });
    }

    if (_purchaseUpdatesListenerRegistered) {
      return;
    }

    _purchaseUpdatesListenerRegistered = true;
    ref.listen<AsyncValue<List<PurchaseDetails>>>(
      premiumPurchaseUpdatesProvider,
      (previous, next) {
        final purchases = next.asData?.value;
        if (purchases == null ||
            identical(previous?.asData?.value, purchases)) {
          return;
        }

        unawaited(_handlePurchaseUpdates(purchases));
      },
    );
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (_hasInternet == hasInternet) {
      return;
    }

    _hasInternet = hasInternet;
    if (hasInternet) {
      return;
    }

    _cancelActiveLoad();
    _cancelActiveStatusRefresh();
    _cancelActivePremiumAction();
    _cancelActiveCheckoutVerification();
    _loadInFlight = null;
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoading: false,
        isBuying: false,
        isManaging: false,
        checkoutVerificationState: state.isAwaitingCheckoutVerification
            ? PremiumCheckoutVerificationState.error
            : state.checkoutVerificationState,
        isAwaitingCheckoutVerification: false,
        checkoutErrorMessage: state.isAwaitingCheckoutVerification
            ? 'templates.network_unavailable'
            : state.checkoutErrorMessage,
      ),
    );
  }

  CancelToken _startLoadCancelToken() {
    _cancelActiveLoad();
    final cancelToken = CancelToken();
    _activeLoadCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveLoad() {
    final cancelToken = _activeLoadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_load_cancelled');
    }
    _activeLoadCancelToken = null;
  }

  void _clearActiveLoad(CancelToken cancelToken) {
    if (identical(_activeLoadCancelToken, cancelToken)) {
      _activeLoadCancelToken = null;
    }
  }

  CancelToken _startStatusRefreshCancelToken() {
    _cancelActiveStatusRefresh();
    final cancelToken = CancelToken();
    _activeStatusRefreshCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveStatusRefresh() {
    final cancelToken = _activeStatusRefreshCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_status_refresh_cancelled');
    }
    _activeStatusRefreshCancelToken = null;
  }

  void _clearActiveStatusRefresh(CancelToken cancelToken) {
    if (identical(_activeStatusRefreshCancelToken, cancelToken)) {
      _activeStatusRefreshCancelToken = null;
    }
  }

  CancelToken _startPremiumActionCancelToken() {
    _cancelActivePremiumAction();
    final cancelToken = CancelToken();
    _activePremiumActionCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActivePremiumAction() {
    final cancelToken = _activePremiumActionCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_action_cancelled');
    }
    _activePremiumActionCancelToken = null;
  }

  void _clearActivePremiumAction(CancelToken cancelToken) {
    if (identical(_activePremiumActionCancelToken, cancelToken)) {
      _activePremiumActionCancelToken = null;
    }
  }

  CancelToken _startCheckoutVerificationCancelToken() {
    _cancelActiveCheckoutVerification();
    final cancelToken = CancelToken();
    _activeCheckoutVerificationCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveCheckoutVerification() {
    final cancelToken = _activeCheckoutVerificationCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_checkout_verification_cancelled');
    }
    _activeCheckoutVerificationCancelToken = null;
  }

  void _clearActiveCheckoutVerification(CancelToken cancelToken) {
    if (identical(_activeCheckoutVerificationCancelToken, cancelToken)) {
      _activeCheckoutVerificationCancelToken = null;
    }
  }

  void _updateStateIfMounted(
    PremiumState Function(PremiumState current) update,
  ) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }
}
