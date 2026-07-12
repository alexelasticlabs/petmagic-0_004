part of 'wallet_controller.dart';

mixin _WalletControllerLoading
    on _WalletControllerBase, _WalletControllerLifecycle {
  @override
  Future<void> load({bool refresh = false}) async {
    final inFlight = _loadInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final loadCancelToken = _startLoadCancelToken();
    final operation = _performLoad(
      refresh: refresh,
      cancelToken: loadCancelToken,
    );
    _loadInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_loadInFlight, operation)) {
        _loadInFlight = null;
      }
      _clearActiveLoad(loadCancelToken);
    }
  }

  Future<void> _performLoad({
    required bool refresh,
    required CancelToken cancelToken,
  }) async {
    _cancelActiveLedgerLoadMore();
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoading: !refresh,
        isRefreshing: refresh,
        isLoadingMoreLedger: false,
        clearError: true,
        clearLedgerLoadMoreError: true,
        clearCheckoutUrl: true,
      ),
    );

    try {
      final wallet = await _repository.fetchWallet(cancelToken: cancelToken);
      if (!ref.mounted || cancelToken.isCancelled) {
        return;
      }

      var ledger = const <WalletLedgerItem>[];
      var ledgerHasMore = false;
      RewardsSummaryModel? rewards;
      var packs = const <CurrencyPackModel>[];
      var paymentMethods = const <WalletPaymentMethodModel>[];
      var storeProductPrices = const <String, String>{};
      var purchases = const <PurchaseHistoryItem>[];
      String? softError;

      await Future.wait<void>([
        () async {
          try {
            final page = await _repository.fetchLedger(
              take: _WalletControllerBase.walletLedgerPageSize,
              cancelToken: cancelToken,
            );
            ledger = page.items;
            ledgerHasMore = page.hasMore;
          } catch (error, stackTrace) {
            if (_isRequestCancelled(error)) {
              rethrow;
            }
            softError ??= 'wallet.ledger_failed';
            _logWalletLoadFailure('fetch_ledger', error, stackTrace);
          }
        }(),
        () async {
          try {
            rewards = await _repository.fetchRewards(cancelToken: cancelToken);
          } catch (error, stackTrace) {
            if (_isRequestCancelled(error)) {
              rethrow;
            }
            softError ??= 'rewards.summary_failed';
            _logWalletLoadFailure('fetch_rewards', error, stackTrace);
          }
        }(),
        () async {
          try {
            final config = await _repository.fetchCheckoutConfig(
              locale: WidgetsBinding.instance.platformDispatcher.locale,
              cancelToken: cancelToken,
            );
            packs = config.packs;
            paymentMethods = config.paymentMethods;
          } catch (error, stackTrace) {
            if (_isRequestCancelled(error)) {
              rethrow;
            }
            softError ??= 'wallet.packs_failed';
            _logWalletLoadFailure('fetch_checkout_config', error, stackTrace);
          }
        }(),
        () async {
          try {
            purchases = (await _repository.fetchPurchases(
              take: 12,
              cancelToken: cancelToken,
            )).items;
          } catch (error, stackTrace) {
            if (_isRequestCancelled(error)) {
              rethrow;
            }
            softError ??= 'wallet.purchases_failed';
            _logWalletLoadFailure('fetch_purchases', error, stackTrace);
          }
        }(),
      ]);

      if (!ref.mounted || cancelToken.isCancelled) {
        return;
      }

      // Native store probing can be slow or unavailable on a physical device.
      // Keep the wallet, rewards, and history usable while payment-method
      // availability is resolved in the background portion of this load.
      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: wallet,
          rewards: rewards,
          ledger: ledger,
          ledgerHasMore: ledgerHasMore,
          packs: packs,
          paymentMethods: paymentMethods,
          purchases: purchases,
          isLoading: false,
          isRefreshing: false,
          errorMessage: softError,
        ),
      );

      if (packs.isNotEmpty && paymentMethods.isNotEmpty) {
        final availability = await _resolvePaymentMethodsAvailability(
          packs: packs,
          paymentMethods: paymentMethods,
        );
        paymentMethods = availability.paymentMethods;
        storeProductPrices = availability.productPrices;
      }
      if (!ref.mounted || cancelToken.isCancelled) {
        return;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: wallet,
          rewards: rewards,
          ledger: ledger,
          ledgerHasMore: ledgerHasMore,
          hasCompletedFullLoad: softError == null,
          packs: packs,
          paymentMethods: paymentMethods,
          storeProductPrices: storeProductPrices,
          purchases: purchases,
          isLoading: false,
          isRefreshing: false,
          errorMessage: softError,
        ),
      );
      unawaited(_recoverPendingStorePurchase(requestStoreRestore: true));
    } catch (error) {
      if (_isRequestCancelled(error)) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: _errorMessage(error),
        ),
      );
    }
  }

  Future<
    ({
      List<WalletPaymentMethodModel> paymentMethods,
      Map<String, String> productPrices,
    })
  >
  _resolvePaymentMethodsAvailability({
    required List<CurrencyPackModel> packs,
    required List<WalletPaymentMethodModel> paymentMethods,
  }) async {
    final resolved = <WalletPaymentMethodModel>[];
    final productPrices = <String, String>{};

    for (final method in paymentMethods) {
      if (!method.isEnabled || !method.isStoreNative) {
        resolved.add(method);
        continue;
      }

      try {
        final availability = await _repository.fetchStoreAvailability(
          packs,
          method,
        );
        productPrices.addAll(availability.productPrices);

        final hasSupportedPack = packs.any((pack) {
          final productId = pack.productIdForProvider(method.provider);
          return productId != null &&
              productId.isNotEmpty &&
              availability.productIds.contains(productId);
        });

        if (availability.isAvailable && hasSupportedPack) {
          resolved.add(method);
          continue;
        }

        resolved.add(_copyPaymentMethodWithEnabled(method, false));
      } catch (error, stackTrace) {
        _logWalletLoadFailure('fetch_store_availability', error, stackTrace);
        resolved.add(_copyPaymentMethodWithEnabled(method, false));
      }
    }

    return (paymentMethods: resolved, productPrices: productPrices);
  }

  WalletPaymentMethodModel _copyPaymentMethodWithEnabled(
    WalletPaymentMethodModel method,
    bool isEnabled,
  ) {
    return WalletPaymentMethodModel(
      provider: method.provider,
      purchaseChannel: method.purchaseChannel,
      platform: method.platform,
      region: method.region,
      isEnabled: isEnabled,
      isSelectedByDefault: method.isSelectedByDefault,
      requiresExternalWarning: method.requiresExternalWarning,
      requiresStoreDisclosure: method.requiresStoreDisclosure,
      isRecommended: method.isRecommended,
      bonusTokensPercent: method.bonusTokensPercent,
      displayLabel: method.displayLabel,
      displaySubtitle: method.displaySubtitle,
      warningTitle: method.warningTitle,
      warningMessage: method.warningMessage,
      notes: method.notes,
    );
  }

  @override
  Future<void> syncSnapshot({bool forceRefresh = false}) {
    return _syncWalletSnapshot(forceRefresh: forceRefresh);
  }

  @override
  Future<void> loadMoreLedger({bool force = false}) async {
    if (!ref.mounted || !_hasAuthenticatedWalletSession()) {
      return;
    }

    if (state.isLoadingMoreLedger ||
        !state.ledgerHasMore ||
        (!force && state.ledgerLoadMoreErrorMessage != null)) {
      return;
    }

    final loadMoreCancelToken = _startLedgerLoadMoreCancelToken();
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoadingMoreLedger: true,
        clearLedgerLoadMoreError: true,
      ),
    );

    try {
      final skip = state.ledger.length;
      final page = await _repository.fetchLedger(
        skip: skip,
        take: _WalletControllerBase.walletLedgerPageSize,
        cancelToken: loadMoreCancelToken,
      );
      if (!ref.mounted || loadMoreCancelToken.isCancelled) {
        return;
      }

      final mergedLedger = _appendUniqueLedgerPage(
        existingLedger: state.ledger,
        nextPage: page.items,
      );
      final didAppendLedgerItems = mergedLedger.length > state.ledger.length;
      _updateStateIfMounted(
        (state) => state.copyWith(
          ledger: mergedLedger,
          ledgerHasMore: page.hasMore && didAppendLedgerItems,
          isLoadingMoreLedger: false,
          clearLedgerLoadMoreError: true,
        ),
      );
    } catch (error) {
      if (_isRequestCancelled(error)) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoadingMoreLedger: false,
            clearLedgerLoadMoreError: true,
          ),
        );
        return;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoadingMoreLedger: false,
          ledgerLoadMoreErrorMessage: _errorMessage(error),
        ),
      );
    } finally {
      _clearActiveLedgerLoadMore(loadMoreCancelToken);
    }
  }

  List<WalletLedgerItem> _mergeRefreshedLedgerPage({
    required List<WalletLedgerItem> existingLedger,
    required List<WalletLedgerItem> refreshedFirstPage,
  }) {
    if (existingLedger.isEmpty || refreshedFirstPage.isEmpty) {
      return refreshedFirstPage;
    }

    final merged = <WalletLedgerItem>[...refreshedFirstPage];
    final seenEntryIds = refreshedFirstPage.map((item) => item.entryId).toSet();

    for (final item in existingLedger) {
      if (seenEntryIds.add(item.entryId)) {
        merged.add(item);
      }
    }

    return merged;
  }

  List<WalletLedgerItem> _appendUniqueLedgerPage({
    required List<WalletLedgerItem> existingLedger,
    required List<WalletLedgerItem> nextPage,
  }) {
    if (existingLedger.isEmpty || nextPage.isEmpty) {
      return nextPage.isEmpty
          ? existingLedger
          : [...existingLedger, ...nextPage];
    }

    final merged = <WalletLedgerItem>[...existingLedger];
    final seenEntryIds = existingLedger.map((item) => item.entryId).toSet();
    for (final item in nextPage) {
      if (seenEntryIds.add(item.entryId)) {
        merged.add(item);
      }
    }
    return merged;
  }

  @override
  Future<void> _syncWalletSnapshot({bool forceRefresh = false}) async {
    if (_isWalletSyncInFlight ||
        _loadInFlight != null ||
        state.isLoadingMoreLedger) {
      return;
    }
    if (!forceRefresh &&
        (state.isBuying ||
            state.isClaimingAd ||
            state.isRedeeming ||
            state.isApplyingReferral)) {
      return;
    }

    _isWalletSyncInFlight = true;
    final syncCancelToken = _startWalletSyncCancelToken();
    try {
      final nextWallet = await _repository.fetchWallet(
        cancelToken: syncCancelToken,
      );
      if (!ref.mounted || syncCancelToken.isCancelled) {
        return;
      }

      final prevWallet = state.wallet;
      if (prevWallet == null) {
        _updateStateIfMounted((state) => state.copyWith(wallet: nextWallet));
        return;
      }

      final balanceChanged =
          prevWallet.balance != nextWallet.balance ||
          prevWallet.isPremium != nextWallet.isPremium;
      final weeklyStateChanged =
          prevWallet.nextWeeklyGrantAtUtc != nextWallet.nextWeeklyGrantAtUtc ||
          prevWallet.adRewardsRemainingToday !=
              nextWallet.adRewardsRemainingToday;

      if (!balanceChanged && !weeklyStateChanged) {
        return;
      }

      OffsetPagedModel<WalletLedgerItem>? latestLedgerPage;
      try {
        latestLedgerPage = await _repository.fetchLedger(
          take: _WalletControllerBase.walletLedgerPageSize,
          cancelToken: syncCancelToken,
        );
        if (!ref.mounted || syncCancelToken.isCancelled) {
          return;
        }
      } catch (error, stackTrace) {
        if (_isRequestCancelled(error)) {
          return;
        }
        _logWalletLoadFailure('sync_fetch_ledger', error, stackTrace);
      }

      if (!ref.mounted || syncCancelToken.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: nextWallet,
          ledger: latestLedgerPage == null
              ? state.ledger
              : _mergeRefreshedLedgerPage(
                  existingLedger: state.ledger,
                  refreshedFirstPage: latestLedgerPage.items,
                ),
          ledgerHasMore: latestLedgerPage?.hasMore ?? state.ledgerHasMore,
          clearError: true,
          clearLedgerLoadMoreError: latestLedgerPage != null,
        ),
      );
    } catch (error, stackTrace) {
      if (_isRequestCancelled(error)) {
        return;
      }
      _logWalletLoadFailure('sync_fetch_wallet', error, stackTrace);
    } finally {
      _isWalletSyncInFlight = false;
      _clearActiveWalletSync(syncCancelToken);
    }
  }
}
// Wallet application loading orchestration.
