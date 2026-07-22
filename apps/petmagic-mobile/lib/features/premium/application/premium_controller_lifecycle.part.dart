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
    ref.listen<AsyncValue<List<StorePurchaseDetails>>>(
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

  RequestCancellation _startLoadRequestCancellation() {
    _cancelActiveLoad();
    final cancelToken = RequestCancellation();
    _activeLoadRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveLoad() {
    final cancelToken = _activeLoadRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_load_cancelled');
    }
    _activeLoadRequestCancellation = null;
  }

  void _clearActiveLoad(RequestCancellation cancelToken) {
    if (identical(_activeLoadRequestCancellation, cancelToken)) {
      _activeLoadRequestCancellation = null;
    }
  }

  RequestCancellation _startStatusRefreshRequestCancellation() {
    _cancelActiveStatusRefresh();
    final cancelToken = RequestCancellation();
    _activeStatusRefreshRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveStatusRefresh() {
    final cancelToken = _activeStatusRefreshRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_status_refresh_cancelled');
    }
    _activeStatusRefreshRequestCancellation = null;
  }

  void _clearActiveStatusRefresh(RequestCancellation cancelToken) {
    if (identical(_activeStatusRefreshRequestCancellation, cancelToken)) {
      _activeStatusRefreshRequestCancellation = null;
    }
  }

  RequestCancellation _startPremiumActionRequestCancellation() {
    _cancelActivePremiumAction();
    final cancelToken = RequestCancellation();
    _activePremiumActionRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActivePremiumAction() {
    final cancelToken = _activePremiumActionRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_action_cancelled');
    }
    _activePremiumActionRequestCancellation = null;
  }

  void _clearActivePremiumAction(RequestCancellation cancelToken) {
    if (identical(_activePremiumActionRequestCancellation, cancelToken)) {
      _activePremiumActionRequestCancellation = null;
    }
  }

  RequestCancellation _startCheckoutVerificationRequestCancellation() {
    _cancelActiveCheckoutVerification();
    final cancelToken = RequestCancellation();
    _activeCheckoutVerificationRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveCheckoutVerification() {
    final cancelToken = _activeCheckoutVerificationRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_checkout_verification_cancelled');
    }
    _activeCheckoutVerificationRequestCancellation = null;
  }

  void _clearActiveCheckoutVerification(RequestCancellation cancelToken) {
    if (identical(
      _activeCheckoutVerificationRequestCancellation,
      cancelToken,
    )) {
      _activeCheckoutVerificationRequestCancellation = null;
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
// Premium application lifecycle orchestration.
