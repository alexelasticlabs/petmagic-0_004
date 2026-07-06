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
    ref.listen<bool>(
      networkStatusControllerProvider.select((state) => state.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
    ref.onDispose(() {
      final lifecycleListener = _appLifecycleListener;
      if (lifecycleListener != null) {
        AppLifecycleSignal.instance.removeListener(lifecycleListener);
        _appLifecycleListener = null;
      }
      _cancelActiveLoad();
      _cancelActiveWalletSync();
      _cancelActiveLedgerLoadMore();
      _cancelActiveCheckout();
      _cancelActiveCheckoutVerification();
      unawaited(purchaseSubscription.cancel());
    });
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (hasInternet) {
      unawaited(_recoverPendingStorePurchase(requestStoreRestore: true));
      return;
    }

    _cancelActiveLoad();
    _cancelActiveWalletSync();
    _cancelActiveLedgerLoadMore();
    _cancelActiveCheckout();
    _cancelActiveCheckoutVerification();
    _loadInFlight = null;
    _isWalletSyncInFlight = false;
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMoreLedger: false,
        isBuying: false,
        clearLedgerLoadMoreError: true,
      ),
    );
  }

  void _handleAppLifecycleSignal() {
    didChangeAppLifecycleState(AppLifecycleSignal.instance.state);
  }

  @override
  void setWalletPageVisible(bool visible) {
    _isWalletPageVisible = visible;
    if (visible) {
      unawaited(_recoverPendingStorePurchase(requestStoreRestore: true));
    }
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

  CancelToken _startLedgerLoadMoreCancelToken() {
    _cancelActiveLedgerLoadMore();
    final cancelToken = CancelToken();
    _activeLedgerLoadMoreCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveLedgerLoadMore() {
    final cancelToken = _activeLedgerLoadMoreCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('wallet_ledger_load_more_cancelled');
    }
    _activeLedgerLoadMoreCancelToken = null;
  }

  void _clearActiveLedgerLoadMore(CancelToken cancelToken) {
    if (identical(_activeLedgerLoadMoreCancelToken, cancelToken)) {
      _activeLedgerLoadMoreCancelToken = null;
    }
  }

  CancelToken _startCheckoutCancelToken() {
    _cancelActiveCheckout();
    final cancelToken = CancelToken();
    _activeCheckoutCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveCheckout() {
    final cancelToken = _activeCheckoutCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('wallet_checkout_cancelled');
    }
    _activeCheckoutCancelToken = null;
  }

  void _clearActiveCheckout(CancelToken cancelToken) {
    if (identical(_activeCheckoutCancelToken, cancelToken)) {
      _activeCheckoutCancelToken = null;
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
      cancelToken.cancel('wallet_checkout_verification_cancelled');
    }
    _activeCheckoutVerificationCancelToken = null;
  }

  void _clearActiveCheckoutVerification(CancelToken cancelToken) {
    if (identical(_activeCheckoutVerificationCancelToken, cancelToken)) {
      _activeCheckoutVerificationCancelToken = null;
    }
  }

  void _updateStateIfMounted(WalletState Function(WalletState current) update) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    if (!ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    unawaited(_recoverPendingStorePurchase(requestStoreRestore: true));
    if (_isWalletPageVisible) {
      return;
    }

    unawaited(_syncWalletSnapshot(forceRefresh: true));
  }
}
