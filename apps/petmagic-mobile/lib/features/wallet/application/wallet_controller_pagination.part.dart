part of 'wallet_controller.dart';

mixin _WalletControllerPagination on _WalletControllerBase {
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

    final loadMoreRequestCancellation =
        _startLedgerLoadMoreRequestCancellation();
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
        cancelToken: loadMoreRequestCancellation,
      );
      if (!ref.mounted || loadMoreRequestCancellation.isCancelled) {
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
      _clearActiveLedgerLoadMore(loadMoreRequestCancellation);
    }
  }

  @override
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
}
