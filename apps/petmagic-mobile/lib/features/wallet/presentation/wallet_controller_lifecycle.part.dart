part of 'wallet_controller.dart';

mixin _WalletControllerLifecycle on _WalletControllerBase {
  @override
  void _ensureWalletLifecycleStarted() {
    if (_walletLifecycleStarted) {
      return;
    }

    _walletLifecycleStarted = true;
    WidgetsBinding.instance.addObserver(this);
    _purchaseSubscription = _repository.purchaseUpdates.listen(
      _handlePurchaseUpdates,
    );
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _cancelActiveLoad();
      _cancelActiveWalletSync();
      unawaited(_purchaseSubscription?.cancel());
    });
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
      cancelToken.cancel('wallet_load_cancelled');
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
  CancelToken _startWalletSyncCancelToken() {
    _cancelActiveWalletSync();
    final cancelToken = CancelToken();
    _activeWalletSyncCancelToken = cancelToken;
    return cancelToken;
  }

  @override
  void _cancelActiveWalletSync() {
    final cancelToken = _activeWalletSyncCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('wallet_sync_cancelled');
    }
    _activeWalletSyncCancelToken = null;
  }

  @override
  void _clearActiveWalletSync(CancelToken cancelToken) {
    if (identical(_activeWalletSyncCancelToken, cancelToken)) {
      _activeWalletSyncCancelToken = null;
    }
  }

  @override
  void _updateStateIfMounted(WalletState Function(WalletState current) update) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncWalletSnapshot(forceRefresh: true));
    }
  }
}
