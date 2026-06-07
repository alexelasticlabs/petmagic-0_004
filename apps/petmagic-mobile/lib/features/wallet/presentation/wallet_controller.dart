import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

final walletControllerProvider =
    NotifierProvider<WalletController, WalletState>(WalletController.new);

enum WalletCheckoutVerificationState {
  idle,
  checking,
  succeeded,
  pending,
  error,
}

void _logWalletLoadFailure(String stage, Object error, StackTrace stackTrace) {
  AppLogger.error(
    feature: 'Wallet.Load',
    operation: stage,
    message: 'Wallet load stage failed',
    error: error,
    stackTrace: stackTrace,
    context: {'stage': stage},
  );
}

class WalletState {
  const WalletState({
    this.wallet,
    this.rewards,
    this.ledger = const [],
    this.packs = const [],
    this.paymentMethods = const [],
    this.purchases = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isBuying = false,
    this.isClaimingAd = false,
    this.isRedeeming = false,
    this.isApplyingReferral = false,
    this.errorMessage,
    this.checkoutUrl,
    this.pendingCheckoutOrderId,
    this.pendingStoreProvider,
    this.storeProductPrices = const <String, String>{},
    this.checkoutVerificationState = WalletCheckoutVerificationState.idle,
    this.checkoutGrantedSpark,
    this.checkoutErrorMessage,
    this.highlightedPurchaseOrderId,
  });

  final WalletStateModel? wallet;
  final RewardsSummaryModel? rewards;
  final List<WalletLedgerItem> ledger;
  final List<CurrencyPackModel> packs;
  final List<WalletPaymentMethodModel> paymentMethods;
  final List<PurchaseHistoryItem> purchases;
  final bool isLoading;
  final bool isRefreshing;
  final bool isBuying;
  final bool isClaimingAd;
  final bool isRedeeming;
  final bool isApplyingReferral;
  final String? errorMessage;
  final String? checkoutUrl;
  final String? pendingCheckoutOrderId;
  final String? pendingStoreProvider;
  final Map<String, String> storeProductPrices;
  final WalletCheckoutVerificationState checkoutVerificationState;
  final int? checkoutGrantedSpark;
  final String? checkoutErrorMessage;
  final String? highlightedPurchaseOrderId;

  bool get isInitialLoading => isLoading && wallet == null;

  WalletPaymentMethodModel? get selectedPaymentMethod {
    final enabledStripeMethods = paymentMethods
        .where((method) => method.isEnabled && method.isStripe)
        .toList(growable: false);
    if (enabledStripeMethods.isEmpty) {
      return null;
    }

    return enabledStripeMethods
            .where((method) => method.isSelectedByDefault)
            .cast<WalletPaymentMethodModel?>()
            .firstOrNull ??
        enabledStripeMethods
            .where((method) => method.isRecommended)
            .cast<WalletPaymentMethodModel?>()
            .firstOrNull ??
        enabledStripeMethods.first;
  }

  WalletState copyWith({
    WalletStateModel? wallet,
    RewardsSummaryModel? rewards,
    List<WalletLedgerItem>? ledger,
    List<CurrencyPackModel>? packs,
    List<WalletPaymentMethodModel>? paymentMethods,
    List<PurchaseHistoryItem>? purchases,
    bool? isLoading,
    bool? isRefreshing,
    bool? isBuying,
    bool? isClaimingAd,
    bool? isRedeeming,
    bool? isApplyingReferral,
    String? errorMessage,
    String? checkoutUrl,
    String? pendingCheckoutOrderId,
    String? pendingStoreProvider,
    Map<String, String>? storeProductPrices,
    WalletCheckoutVerificationState? checkoutVerificationState,
    int? checkoutGrantedSpark,
    String? checkoutErrorMessage,
    String? highlightedPurchaseOrderId,
    bool clearError = false,
    bool clearCheckoutUrl = false,
    bool clearPendingCheckout = false,
    bool clearPendingStoreProvider = false,
    bool clearCheckoutGrantedSpark = false,
    bool clearCheckoutError = false,
    bool clearHighlightedPurchaseOrderId = false,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      rewards: rewards ?? this.rewards,
      ledger: ledger ?? this.ledger,
      packs: packs ?? this.packs,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isBuying: isBuying ?? this.isBuying,
      isClaimingAd: isClaimingAd ?? this.isClaimingAd,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      isApplyingReferral: isApplyingReferral ?? this.isApplyingReferral,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      checkoutUrl: clearCheckoutUrl ? null : checkoutUrl ?? this.checkoutUrl,
      pendingCheckoutOrderId: clearPendingCheckout
          ? null
          : pendingCheckoutOrderId ?? this.pendingCheckoutOrderId,
      pendingStoreProvider: clearPendingStoreProvider
          ? null
          : pendingStoreProvider ?? this.pendingStoreProvider,
      storeProductPrices: storeProductPrices ?? this.storeProductPrices,
      checkoutVerificationState:
          checkoutVerificationState ?? this.checkoutVerificationState,
      checkoutGrantedSpark: clearCheckoutGrantedSpark
          ? null
          : checkoutGrantedSpark ?? this.checkoutGrantedSpark,
      checkoutErrorMessage: clearCheckoutError
          ? null
          : checkoutErrorMessage ?? this.checkoutErrorMessage,
      highlightedPurchaseOrderId: clearHighlightedPurchaseOrderId
          ? null
          : highlightedPurchaseOrderId ?? this.highlightedPurchaseOrderId,
    );
  }
}

class WalletController extends Notifier<WalletState>
    with WidgetsBindingObserver {
  late final WalletRepository _repository;
  bool _repositoryInitialized = false;
  Future<void>? _loadInFlight;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  CancelToken? _activeLoadCancelToken;
  CancelToken? _activeWalletSyncCancelToken;
  bool _isWalletSyncInFlight = false;
  bool _walletLifecycleStarted = false;

  @override
  WalletState build() {
    if (!_repositoryInitialized) {
      _repository = ref.read(walletRepositoryProvider);
      _repositoryInitialized = true;
    }
    _ensureWalletLifecycleStarted();
    return const WalletState(isLoading: true);
  }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncWalletSnapshot(forceRefresh: true));
    }
  }

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
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoading: !refresh,
        isRefreshing: refresh,
        clearError: true,
        clearCheckoutUrl: true,
      ),
    );

    try {
      final wallet = await _repository.fetchWallet(cancelToken: cancelToken);
      if (!ref.mounted) {
        return;
      }

      var ledger = const <WalletLedgerItem>[];
      RewardsSummaryModel? rewards;
      var packs = const <CurrencyPackModel>[];
      var paymentMethods = const <WalletPaymentMethodModel>[];
      var storeProductPrices = const <String, String>{};
      var purchases = const <PurchaseHistoryItem>[];
      String? softError;

      await Future.wait<void>([
        () async {
          try {
            ledger = (await _repository.fetchLedger(
              take: 24,
              cancelToken: cancelToken,
            )).items;
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

      if (!ref.mounted) {
        return;
      }

      if (packs.isNotEmpty && paymentMethods.isNotEmpty) {
        final availability = await _resolvePaymentMethodsAvailability(
          packs: packs,
          paymentMethods: paymentMethods,
        );
        paymentMethods = availability.paymentMethods;
        storeProductPrices = availability.productPrices;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: wallet,
          rewards: rewards,
          ledger: ledger,
          packs: packs,
          paymentMethods: paymentMethods,
          storeProductPrices: storeProductPrices,
          purchases: purchases,
          isLoading: false,
          isRefreshing: false,
          errorMessage: softError,
        ),
      );
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

  Future<void> _syncWalletSnapshot({bool forceRefresh = false}) async {
    if (_isWalletSyncInFlight || _loadInFlight != null) {
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
      if (!ref.mounted) {
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

      List<WalletLedgerItem>? latestLedger;
      try {
        latestLedger = (await _repository.fetchLedger(
          take: 24,
          cancelToken: syncCancelToken,
        )).items;
      } catch (error, stackTrace) {
        if (_isRequestCancelled(error)) {
          return;
        }
        _logWalletLoadFailure('sync_fetch_ledger', error, stackTrace);
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: nextWallet,
          ledger: latestLedger ?? state.ledger,
          clearError: true,
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

  Future<PurchaseCheckoutModel?> buyPack(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  ) async {
    if (!paymentMethod.isEnabled) {
      _updateStateIfMounted(
        (state) => state.copyWith(errorMessage: 'wallet.payment_unavailable'),
      );
      return null;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        isBuying: true,
        clearError: true,
        clearCheckoutUrl: true,
        clearPendingCheckout: true,
        checkoutVerificationState: WalletCheckoutVerificationState.idle,
        clearCheckoutGrantedSpark: true,
        clearCheckoutError: true,
        clearHighlightedPurchaseOrderId: true,
      ),
    );

    try {
      if (paymentMethod.isStoreNative) {
        final expectedProductId = pack.productIdForProvider(
          paymentMethod.provider,
        );
        if (expectedProductId == null || expectedProductId.isEmpty) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              errorMessage: 'wallet.payment_unavailable',
            ),
          );
          return null;
        }

        final availability = await _repository.fetchStoreAvailability([
          pack,
        ], paymentMethod);
        if (!ref.mounted) {
          return null;
        }
        if (!availability.isAvailable ||
            !availability.productIds.contains(expectedProductId)) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              errorMessage: 'wallet.payment_unavailable',
            ),
          );
          return null;
        }
      }

      final checkout = await _repository.createPurchase(
        pack,
        paymentMethod,
        WidgetsBinding.instance.platformDispatcher.locale,
      );
      if (!ref.mounted) {
        return null;
      }

      if (paymentMethod.isStoreNative) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            pendingCheckoutOrderId: checkout.orderId,
            pendingStoreProvider: paymentMethod.provider,
            isBuying: true,
          ),
        );

        await _repository.startStoreCheckout(pack, paymentMethod);
        _updateStateIfMounted((state) => state.copyWith(isBuying: false));
        return null;
      }

      final checkoutUrl = checkout.checkoutUrl.trim();
      if (checkoutUrl.isEmpty && !checkout.usesPaymentSheet) {
        final payload = <String, Object>{
          'pack_id': pack.packId,
          'pack_code': pack.code,
          'provider': paymentMethod.provider,
          'order_id': checkout.orderId,
          'status': checkout.status,
        };
        AppLogger.warn(
          feature: 'Wallet.Checkout',
          operation: 'empty_checkout_url',
          message: 'Empty checkout URL received from purchase create API',
          context: payload,
          error: 'wallet.checkout_empty_url',
        );

        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            clearCheckoutUrl: true,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            errorMessage: 'payment_gateway_failed',
          ),
        );
        return null;
      }

      final safeCheckoutUri = checkout.usesPaymentSheet
          ? null
          : parseSafePremiumExternalUri(checkoutUrl);
      if (!checkout.usesPaymentSheet && safeCheckoutUri == null) {
        final payload = <String, Object>{
          'pack_id': pack.packId,
          'pack_code': pack.code,
          'provider': paymentMethod.provider,
          'order_id': checkout.orderId,
          'status': checkout.status,
        };
        AppLogger.warn(
          feature: 'Wallet.Checkout',
          operation: 'unsafe_checkout_url',
          message: 'Unsafe checkout URL received from purchase create API',
          context: payload,
          error: 'wallet.checkout_unsafe_url',
        );

        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            clearCheckoutUrl: true,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            errorMessage: 'payment_gateway_failed',
          ),
        );
        return null;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutUrl: safeCheckoutUri?.toString() ?? checkoutUrl,
          pendingCheckoutOrderId: checkout.orderId,
          clearPendingStoreProvider: true,
        ),
      );
      return checkout;
    } catch (error) {
      AppLogger.error(
        feature: 'Wallet.Checkout',
        operation: 'checkout_failed',
        message: 'Checkout failed',
        context: {'pack_code': pack.code, 'provider': paymentMethod.provider},
        error: error,
      );
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          clearPendingCheckout: true,
          clearPendingStoreProvider: true,
          errorMessage: _errorMessage(error),
        ),
      );
      return null;
    }
  }

  Future<void> claimAdReward() async {
    _updateStateIfMounted(
      (state) => state.copyWith(isClaimingAd: true, clearError: true),
    );

    try {
      final wallet = await _repository.claimAdReward();
      final ledger = await _repository.fetchLedger(take: 24);
      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: wallet,
          ledger: ledger.items,
          isClaimingAd: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isClaimingAd: false,
          errorMessage: _errorMessage(error),
        ),
      );
    }
  }

  Future<String?> applyRedeemCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(isRedeeming: true, clearError: true),
    );

    try {
      final wallet = await _repository.applyRedeemCode(code);
      final ledger = await _repository.fetchLedger(take: 24);
      final rewards = await _repository.fetchRewards();
      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: wallet,
          rewards: rewards,
          ledger: ledger.items,
          isRedeeming: false,
          clearError: true,
        ),
      );
      return null;
    } catch (error) {
      final message = _errorMessage(error);
      _updateStateIfMounted(
        (state) => state.copyWith(isRedeeming: false, errorMessage: message),
      );
      return message;
    }
  }

  Future<String?> applyReferralCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(isApplyingReferral: true, clearError: true),
    );

    try {
      final rewards = await _repository.applyReferralCode(code);
      _updateStateIfMounted(
        (state) => state.copyWith(
          rewards: rewards,
          isApplyingReferral: false,
          clearError: true,
        ),
      );
      return null;
    } catch (error) {
      final message = _errorMessage(error);
      _updateStateIfMounted(
        (state) =>
            state.copyWith(isApplyingReferral: false, errorMessage: message),
      );
      return message;
    }
  }

  void consumeCheckoutUrl() {
    state = state.copyWith(clearCheckoutUrl: true);
  }

  void resetCheckoutVerification() {
    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.idle,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
    );
  }

  Future<void> verifyCheckoutStatus() async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    if (pendingOrderId == null || pendingOrderId.isEmpty) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.checking,
        clearCheckoutGrantedSpark: true,
        clearCheckoutError: true,
        clearHighlightedPurchaseOrderId: true,
      ),
    );

    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!ref.mounted) {
        return;
      }

      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (!ref.mounted) {
          return;
        }
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          _updateStateIfMounted(
            (state) => state.copyWith(
              checkoutVerificationState:
                  WalletCheckoutVerificationState.succeeded,
              checkoutGrantedSpark: purchase.sparkToGrant,
              highlightedPurchaseOrderId: purchase.orderId,
              clearPendingCheckout: true,
              clearPendingStoreProvider: true,
              clearCheckoutError: true,
            ),
          );
          return;
        }
      } catch (error) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            checkoutVerificationState: WalletCheckoutVerificationState.error,
            checkoutErrorMessage: _errorMessage(error),
          ),
        );
        return;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!ref.mounted) {
          return;
        }
      }
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.pending,
        clearCheckoutError: true,
      ),
    );
  }

  Future<void> verifyStripeCheckout(String? stripeReferenceId) async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    if (pendingOrderId == null || pendingOrderId.isEmpty) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.checking,
        clearCheckoutGrantedSpark: true,
        clearCheckoutError: true,
        clearHighlightedPurchaseOrderId: true,
      ),
    );

    const maxAttempts = 5;
    final normalizedReference = stripeReferenceId?.trim();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!ref.mounted) {
        return;
      }

      try {
        final purchase = await _repository.verifyStripeCheckoutSession(
          orderId: pendingOrderId,
          stripeReferenceId: normalizedReference,
        );
        if (!ref.mounted) {
          return;
        }

        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          _updateStateIfMounted(
            (state) => state.copyWith(
              checkoutVerificationState:
                  WalletCheckoutVerificationState.succeeded,
              checkoutGrantedSpark: purchase.sparkToGrant,
              highlightedPurchaseOrderId: purchase.orderId,
              clearPendingCheckout: true,
              clearPendingStoreProvider: true,
              clearCheckoutError: true,
            ),
          );
          return;
        }
      } catch (error) {
        AppLogger.warn(
          feature: 'Wallet.Checkout',
          operation: 'stripe_verify_attempt_failed',
          message: 'Stripe verify attempt failed',
          context: {
            'order_id': pendingOrderId,
            'attempt': attempt + 1,
            'reference_type': _stripeReferenceType(normalizedReference),
          },
          error: error,
        );
      }

      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (!ref.mounted) {
          return;
        }
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          _updateStateIfMounted(
            (state) => state.copyWith(
              checkoutVerificationState:
                  WalletCheckoutVerificationState.succeeded,
              checkoutGrantedSpark: purchase.sparkToGrant,
              highlightedPurchaseOrderId: purchase.orderId,
              clearPendingCheckout: true,
              clearPendingStoreProvider: true,
              clearCheckoutError: true,
            ),
          );
          return;
        }
      } catch (error, stackTrace) {
        _logWalletLoadFailure(
          'fetch_purchase_for_verification',
          error,
          stackTrace,
        );
        // Keep retrying verify endpoint; failures here should not interrupt confirmation loop.
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!ref.mounted) {
          return;
        }
      }
    }

    await verifyCheckoutStatus();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!ref.mounted) {
        return;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _updateStateIfMounted(
            (state) => state.copyWith(isBuying: true, clearError: true),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
          break;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
            if (!ref.mounted) {
              return;
            }
          }
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              checkoutVerificationState: WalletCheckoutVerificationState.error,
              checkoutErrorMessage: _purchaseErrorMessage(
                purchase.error?.message,
              ),
              errorMessage: _purchaseErrorMessage(purchase.error?.message),
            ),
          );
          break;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
            if (!ref.mounted) {
              return;
            }
          }
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              errorMessage: 'wallet.payment_unavailable',
            ),
          );
          break;
      }
    }
  }

  Future<void> _verifyStorePurchase(PurchaseDetails purchase) async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    final provider = state.pendingStoreProvider;
    if (pendingOrderId == null ||
        pendingOrderId.isEmpty ||
        provider == null ||
        provider.isEmpty) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }
      return;
    }

    WalletPaymentMethodModel? paymentMethod;
    for (final method in state.paymentMethods) {
      if (method.provider == provider) {
        paymentMethod = method;
        break;
      }
    }

    if (paymentMethod == null) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: 'wallet.payment_unavailable',
          errorMessage: 'wallet.payment_unavailable',
        ),
      );
      return;
    }

    try {
      _updateStateIfMounted(
        (state) => state.copyWith(
          checkoutVerificationState: WalletCheckoutVerificationState.checking,
          clearCheckoutError: true,
        ),
      );

      final verified = await _repository.verifyStorePurchase(
        orderId: pendingOrderId,
        paymentMethod: paymentMethod,
        purchase: purchase,
      );
      if (!ref.mounted) {
        return;
      }

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }

      if (verified.status == 'succeeded') {
        await load(refresh: true);
        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: verified.sparkToGrant,
            highlightedPurchaseOrderId: verified.orderId,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            clearCheckoutError: true,
          ),
        );
        return;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.pending,
          clearCheckoutError: true,
        ),
      );
      await verifyCheckoutStatus();
    } catch (error) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: _errorMessage(error),
          errorMessage: _errorMessage(error),
        ),
      );
    }
  }
}

String _errorMessage(Object error) {
  if (error is AppException) {
    final message = error.message.trim();
    if (_isSafeWalletErrorKey(message)) {
      return message;
    }

    return switch (error.statusCode) {
      400 => 'wallet.request_failed',
      401 => 'auth.session_expired',
      403 => 'wallet.payment_unavailable',
      404 => 'wallet.request_failed',
      409 => 'wallet.request_failed',
      _ => 'wallet.server_unavailable',
    };
  }

  return 'wallet.request_failed';
}

String _purchaseErrorMessage(String? rawMessage) {
  final message = rawMessage?.trim();
  return message != null && _isSafeWalletErrorKey(message)
      ? message
      : 'wallet.payment_unavailable';
}

bool _isRequestCancelled(Object error) {
  return error is RequestCancelledException ||
      (error is DioException && CancelToken.isCancel(error));
}

String _stripeReferenceType(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'missing';
  }

  if (trimmed.startsWith('pi_')) {
    return 'payment_intent';
  }

  if (trimmed.startsWith('cs_')) {
    return 'checkout_session';
  }

  return 'unknown';
}

bool _isSafeWalletErrorKey(String value) {
  return value == 'auth.sign_in_required' ||
      value == 'auth.session_expired' ||
      value == 'wallet.ledger_failed' ||
      value == 'wallet.packs_failed' ||
      value == 'wallet.purchases_failed' ||
      value == 'wallet.payment_unavailable' ||
      value == 'wallet.network_unavailable' ||
      value == 'wallet.server_unavailable' ||
      value == 'wallet.request_failed' ||
      value == 'payment_gateway_failed' ||
      value == 'economy.pack_not_found' ||
      value == 'economy.insufficient_balance' ||
      value == 'redeem_code_not_found' ||
      value == 'redeem_code_already_used' ||
      value == 'redeem_code_expired' ||
      value == 'redeem_code_inactive' ||
      value == 'redeem_code_exhausted' ||
      value == 'redeem_code_user_limit_reached';
}
