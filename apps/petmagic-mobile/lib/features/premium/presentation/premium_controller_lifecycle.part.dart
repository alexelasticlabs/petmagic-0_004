part of 'premium_controller.dart';

mixin _PremiumControllerLifecycle on _PremiumControllerBase {
  @override
  void _ensurePremiumLifecycleStarted() {
    if (!_premiumLifecycleStarted) {
      _premiumLifecycleStarted = true;
      ref.onDispose(() {
        _cancelActiveLoad();
        unawaited(_purchaseSubscription?.cancel());
      });
    }

    if (identical(_purchaseSubscriptionRepository, _repository) &&
        _purchaseSubscription != null) {
      return;
    }

    unawaited(_purchaseSubscription?.cancel());
    _purchaseSubscriptionRepository = _repository;
    _purchaseSubscription = _repository.purchaseUpdates.listen(
      _handlePurchaseUpdates,
    );
  }

  @override
  CancelToken _startLoadCancelToken() {
    _cancelActiveLoad();
    final cancelToken = CancelToken();
    _activeLoadCancelToken = cancelToken;
    return cancelToken;
  }

  @override
  void _cancelActiveLoad() {
    final cancelToken = _activeLoadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('premium_load_cancelled');
    }
    _activeLoadCancelToken = null;
  }

  @override
  void _clearActiveLoad(CancelToken cancelToken) {
    if (identical(_activeLoadCancelToken, cancelToken)) {
      _activeLoadCancelToken = null;
    }
  }

  @override
  void _updateStateIfMounted(
    PremiumState Function(PremiumState current) update,
  ) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }
}
