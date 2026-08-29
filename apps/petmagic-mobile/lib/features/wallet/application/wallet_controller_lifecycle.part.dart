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
    _walletSyncForceRefreshQueued = false;
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
    if (AppLifecycleSignal.instance.isResumed) {
      handleAppResumed();
    }
  }

  @override
  void setWalletPageVisible(bool visible) {
    _isWalletPageVisible = visible;
    if (visible) {
      unawaited(_recoverPendingStorePurchase(requestStoreRestore: true));
    }
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
      cancelToken.cancel('wallet_load_cancelled');
    }
    _activeLoadRequestCancellation = null;
  }

  void _clearActiveLoad(RequestCancellation cancelToken) {
    if (identical(_activeLoadRequestCancellation, cancelToken)) {
      _activeLoadRequestCancellation = null;
    }
  }

  RequestCancellation _startWalletSyncRequestCancellation() {
    _cancelActiveWalletSync();
    final cancelToken = RequestCancellation();
    _activeWalletSyncRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveWalletSync() {
    final cancelToken = _activeWalletSyncRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('wallet_sync_cancelled');
    }
    _activeWalletSyncRequestCancellation = null;
  }

  void _clearActiveWalletSync(RequestCancellation cancelToken) {
    if (identical(_activeWalletSyncRequestCancellation, cancelToken)) {
      _activeWalletSyncRequestCancellation = null;
    }
  }

  @override
  RequestCancellation _startLedgerLoadMoreRequestCancellation() {
    _cancelActiveLedgerLoadMore();
    final cancelToken = RequestCancellation();
    _activeLedgerLoadMoreRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveLedgerLoadMore() {
    final cancelToken = _activeLedgerLoadMoreRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('wallet_ledger_load_more_cancelled');
    }
    _activeLedgerLoadMoreRequestCancellation = null;
  }

  @override
  void _clearActiveLedgerLoadMore(RequestCancellation cancelToken) {
    if (identical(_activeLedgerLoadMoreRequestCancellation, cancelToken)) {
      _activeLedgerLoadMoreRequestCancellation = null;
    }
  }

  RequestCancellation _startCheckoutRequestCancellation() {
    _cancelActiveCheckout();
    final cancelToken = RequestCancellation();
    _activeCheckoutRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveCheckout() {
    final cancelToken = _activeCheckoutRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('wallet_checkout_cancelled');
    }
    _activeCheckoutRequestCancellation = null;
  }

  void _clearActiveCheckout(RequestCancellation cancelToken) {
    if (identical(_activeCheckoutRequestCancellation, cancelToken)) {
      _activeCheckoutRequestCancellation = null;
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
      cancelToken.cancel('wallet_checkout_verification_cancelled');
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

  @override
  void _updateStateIfMounted(WalletState Function(WalletState current) update) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }

  void handleAppResumed() {
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
// Wallet application lifecycle orchestration.
