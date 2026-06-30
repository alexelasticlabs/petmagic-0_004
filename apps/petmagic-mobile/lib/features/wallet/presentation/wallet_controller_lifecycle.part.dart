part of 'wallet_controller.dart';

mixin _WalletControllerLifecycle on _WalletControllerBase {
  void _ensureWalletLifecycleStarted() {
    if (_walletLifecycleStarted) {
      return;
    }

    _walletLifecycleStarted = true;
    _appLifecycleListener = _handleAppLifecycleSignal;
    AppLifecycleSignal.instance.addListener(_appLifecycleListener!);
    final purchaseSubscription = _repository.purchaseUpdates.listen(
      _handlePurchaseUpdates,
    );
    ref.onDispose(() {
      final lifecycleListener = _appLifecycleListener;
      if (lifecycleListener != null) {
        AppLifecycleSignal.instance.removeListener(lifecycleListener);
        _appLifecycleListener = null;
      }
      _cancelActiveLoad();
      _cancelActiveWalletSync();
      unawaited(purchaseSubscription.cancel());
    });
  }

  void _handleAppLifecycleSignal() {
    didChangeAppLifecycleState(AppLifecycleSignal.instance.state);
  }

  @override
  void setWalletPageVisible(bool visible) {
    _isWalletPageVisible = visible;
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
      cancelToken.cancel('wallet_load_cancelled');
    }
    _activeLoadCancelToken = null;
  }

  void _clearActiveLoad(CancelToken cancelToken) {
    if (identical(_activeLoadCancelToken, cancelToken)) {
      _activeLoadCancelToken = null;
    }
  }

  CancelToken _startWalletSyncCancelToken() {
    _cancelActiveWalletSync();
    final cancelToken = CancelToken();
    _activeWalletSyncCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveWalletSync() {
    final cancelToken = _activeWalletSyncCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('wallet_sync_cancelled');
    }
    _activeWalletSyncCancelToken = null;
  }

  void _clearActiveWalletSync(CancelToken cancelToken) {
    if (identical(_activeWalletSyncCancelToken, cancelToken)) {
      _activeWalletSyncCancelToken = null;
    }
  }

  void _updateStateIfMounted(WalletState Function(WalletState current) update) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isWalletPageVisible) {
      unawaited(_syncWalletSnapshot(forceRefresh: true));
    }
  }
}
