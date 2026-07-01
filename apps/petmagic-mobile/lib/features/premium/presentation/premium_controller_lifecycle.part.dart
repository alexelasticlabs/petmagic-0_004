part of 'premium_controller.dart';

mixin _PremiumControllerLifecycle on _PremiumControllerBase {
  bool _purchaseUpdatesListenerRegistered = false;

  void _ensurePremiumLifecycleStarted() {
    if (!_premiumLifecycleStarted) {
      _premiumLifecycleStarted = true;
      ref.onDispose(() {
        _cancelActiveLoad();
        _cancelActiveStatusRefresh();
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

  void _updateStateIfMounted(
    PremiumState Function(PremiumState current) update,
  ) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }
}
