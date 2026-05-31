import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

final walletControllerProvider =
    NotifierProvider<WalletController, WalletState>(WalletController.new);

enum WalletCheckoutVerificationState {
  idle,
  checking,
  succeeded,
  pending,
  error,
}

void _checkoutInfo(
  String operation, {
  Map<String, Object?> context = const {},
}) {
  AppLogger.info(
    feature: 'Wallet.Checkout',
    operation: operation,
    context: context,
  );
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
  static const _walletSyncInterval = Duration(seconds: 10);

  late final WalletRepository _repository;
  bool _repositoryInitialized = false;
  Future<void>? _loadInFlight;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _walletSyncTimer;
  bool _isWalletSyncInFlight = false;

  @override
  WalletState build() {
    if (!_repositoryInitialized) {
      _repository = ref.read(walletRepositoryProvider);
      _repositoryInitialized = true;
    }
    WidgetsBinding.instance.addObserver(this);
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _repository.purchaseUpdates.listen(
      _handlePurchaseUpdates,
    );
    _walletSyncTimer?.cancel();
    _walletSyncTimer = Timer.periodic(_walletSyncInterval, (_) {
      unawaited(_syncWalletSnapshot());
    });
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _walletSyncTimer?.cancel();
      unawaited(_purchaseSubscription?.cancel());
    });
    return const WalletState(isLoading: true);
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

    final operation = _performLoad(refresh: refresh);
    _loadInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_loadInFlight, operation)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> _performLoad({required bool refresh}) async {
    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
      clearCheckoutUrl: true,
    );

    try {
      final wallet = await _repository.fetchWallet();
      var ledger = const <WalletLedgerItem>[];
      RewardsSummaryModel? rewards;
      var packs = const <CurrencyPackModel>[];
      var paymentMethods = const <WalletPaymentMethodModel>[];
      var purchases = const <PurchaseHistoryItem>[];
      String? softError;

      await Future.wait<void>([
        () async {
          try {
            ledger = (await _repository.fetchLedger(take: 24)).items;
          } catch (error, stackTrace) {
            softError ??= 'wallet.ledger_failed';
            _logWalletLoadFailure('fetch_ledger', error, stackTrace);
          }
        }(),
        () async {
          try {
            rewards = await _repository.fetchRewards();
          } catch (error, stackTrace) {
            softError ??= 'rewards.summary_failed';
            _logWalletLoadFailure('fetch_rewards', error, stackTrace);
          }
        }(),
        () async {
          try {
            final config = await _repository.fetchCheckoutConfig(
              locale: WidgetsBinding.instance.platformDispatcher.locale,
            );
            packs = config.packs;
            paymentMethods = config.paymentMethods;
          } catch (error, stackTrace) {
            softError ??= 'wallet.packs_failed';
            _logWalletLoadFailure('fetch_checkout_config', error, stackTrace);
          }
        }(),
        () async {
          try {
            purchases = (await _repository.fetchPurchases(take: 12)).items;
          } catch (error, stackTrace) {
            softError ??= 'wallet.purchases_failed';
            _logWalletLoadFailure('fetch_purchases', error, stackTrace);
          }
        }(),
      ]);

      state = state.copyWith(
        wallet: wallet,
        rewards: rewards,
        ledger: ledger,
        packs: packs,
        paymentMethods: paymentMethods,
        purchases: purchases,
        isLoading: false,
        isRefreshing: false,
        errorMessage: softError,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
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
    try {
      final nextWallet = await _repository.fetchWallet();
      final prevWallet = state.wallet;
      if (prevWallet == null) {
        state = state.copyWith(wallet: nextWallet);
        return;
      }

      final balanceChanged =
          prevWallet.balance != nextWallet.balance ||
          prevWallet.isPremium != nextWallet.isPremium;
      final weeklyStateChanged =
          prevWallet.nextWeeklyGrantAtUtc != nextWallet.nextWeeklyGrantAtUtc ||
          prevWallet.adRewardsRemainingToday != nextWallet.adRewardsRemainingToday;

      if (!balanceChanged && !weeklyStateChanged) {
        return;
      }

      List<WalletLedgerItem>? latestLedger;
      try {
        latestLedger = (await _repository.fetchLedger(take: 24)).items;
      } catch (error, stackTrace) {
        _logWalletLoadFailure('sync_fetch_ledger', error, stackTrace);
      }

      state = state.copyWith(
        wallet: nextWallet,
        ledger: latestLedger ?? state.ledger,
        clearError: true,
      );
    } catch (error, stackTrace) {
      _logWalletLoadFailure('sync_fetch_wallet', error, stackTrace);
    } finally {
      _isWalletSyncInFlight = false;
    }
  }

  Future<PurchaseCheckoutModel?> buyPack(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  ) async {
    if (!paymentMethod.isEnabled) {
      state = state.copyWith(errorMessage: 'wallet.payment_unavailable');
      return null;
    }

    _checkoutInfo(
      'checkout_started',
      context: {
        'pack_code': pack.code,
        'provider': paymentMethod.provider,
        'currency': pack.currencyCode,
        'amount': pack.priceAmount,
      },
    );

    state = state.copyWith(
      isBuying: true,
      clearError: true,
      clearCheckoutUrl: true,
      clearPendingCheckout: true,
      checkoutVerificationState: WalletCheckoutVerificationState.idle,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
    );

    try {
      if (paymentMethod.isStoreNative) {
        final expectedProductId = pack.productIdForProvider(
          paymentMethod.provider,
        );
        if (expectedProductId == null || expectedProductId.isEmpty) {
          state = state.copyWith(
            isBuying: false,
            errorMessage: 'wallet.payment_unavailable',
          );
          return null;
        }

        final availability = await _repository.fetchStoreAvailability([
          pack,
        ], paymentMethod);
        if (!availability.isAvailable ||
            !availability.productIds.contains(expectedProductId)) {
          state = state.copyWith(
            isBuying: false,
            errorMessage: 'wallet.payment_unavailable',
          );
          return null;
        }
      }

      final checkout = await _repository.createPurchase(
        pack,
        paymentMethod,
        WidgetsBinding.instance.platformDispatcher.locale,
      );

      _checkoutInfo(
        'checkout_created',
        context: {
          'order_id': checkout.orderId,
          'status': checkout.status,
          'checkout_url_length': checkout.checkoutUrl.length,
        },
      );

      if (paymentMethod.isStoreNative) {
        state = state.copyWith(
          pendingCheckoutOrderId: checkout.orderId,
          pendingStoreProvider: paymentMethod.provider,
          isBuying: true,
        );

        await _repository.startStoreCheckout(pack, paymentMethod);
        state = state.copyWith(isBuying: false);
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

        state = state.copyWith(
          isBuying: false,
          clearCheckoutUrl: true,
          clearPendingCheckout: true,
          clearPendingStoreProvider: true,
          errorMessage: 'payment_gateway_failed',
        );
        return null;
      }

      state = state.copyWith(
        isBuying: false,
        checkoutUrl: checkoutUrl,
        pendingCheckoutOrderId: checkout.orderId,
        clearPendingStoreProvider: true,
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
      state = state.copyWith(
        isBuying: false,
        clearPendingCheckout: true,
        clearPendingStoreProvider: true,
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  Future<void> claimAdReward() async {
    state = state.copyWith(isClaimingAd: true, clearError: true);

    try {
      final wallet = await _repository.claimAdReward();
      final ledger = await _repository.fetchLedger(take: 24);
      state = state.copyWith(
        wallet: wallet,
        ledger: ledger.items,
        isClaimingAd: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isClaimingAd: false,
        errorMessage: _errorMessage(error),
      );
    }
  }

  Future<String?> applyRedeemCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    state = state.copyWith(isRedeeming: true, clearError: true);

    try {
      final wallet = await _repository.applyRedeemCode(code);
      final ledger = await _repository.fetchLedger(take: 24);
      final rewards = await _repository.fetchRewards();
      state = state.copyWith(
        wallet: wallet,
        rewards: rewards,
        ledger: ledger.items,
        isRedeeming: false,
        clearError: true,
      );
      return null;
    } catch (error) {
      final message = _errorMessage(error);
      state = state.copyWith(isRedeeming: false, errorMessage: message);
      return message;
    }
  }

  Future<String?> applyReferralCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    state = state.copyWith(isApplyingReferral: true, clearError: true);

    try {
      final rewards = await _repository.applyReferralCode(code);
      state = state.copyWith(
        rewards: rewards,
        isApplyingReferral: false,
        clearError: true,
      );
      return null;
    } catch (error) {
      final message = _errorMessage(error);
      state = state.copyWith(isApplyingReferral: false, errorMessage: message);
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

    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.checking,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
    );

    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          state = state.copyWith(
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: purchase.sparkToGrant,
            highlightedPurchaseOrderId: purchase.orderId,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            clearCheckoutError: true,
          );
          return;
        }
      } catch (error) {
        state = state.copyWith(
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: error.toString(),
        );
        return;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.pending,
      clearCheckoutError: true,
    );
  }

  Future<void> verifyStripeCheckout(String? stripeReferenceId) async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    if (pendingOrderId == null || pendingOrderId.isEmpty) {
      return;
    }

    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.checking,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
    );

    const maxAttempts = 5;
    final normalizedReference = stripeReferenceId?.trim();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final purchase = await _repository.verifyStripeCheckoutSession(
          orderId: pendingOrderId,
          stripeReferenceId: normalizedReference,
        );

        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          state = state.copyWith(
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: purchase.sparkToGrant,
            highlightedPurchaseOrderId: purchase.orderId,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            clearCheckoutError: true,
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
            'reference': normalizedReference ?? '',
          },
          error: error,
        );
      }

      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          state = state.copyWith(
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: purchase.sparkToGrant,
            highlightedPurchaseOrderId: purchase.orderId,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            clearCheckoutError: true,
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
      }
    }

    await verifyCheckoutStatus();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(isBuying: true, clearError: true);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
          break;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
          }
          state = state.copyWith(
            isBuying: false,
            checkoutVerificationState: WalletCheckoutVerificationState.error,
            checkoutErrorMessage:
                purchase.error?.message ?? 'wallet.payment_unavailable',
            errorMessage:
                purchase.error?.message ?? 'wallet.payment_unavailable',
          );
          break;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
          }
          state = state.copyWith(
            isBuying: false,
            errorMessage: 'wallet.payment_unavailable',
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
      }
      state = state.copyWith(
        isBuying: false,
        checkoutVerificationState: WalletCheckoutVerificationState.error,
        checkoutErrorMessage: 'wallet.payment_unavailable',
        errorMessage: 'wallet.payment_unavailable',
      );
      return;
    }

    try {
      state = state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.checking,
        clearCheckoutError: true,
      );

      final verified = await _repository.verifyStorePurchase(
        orderId: pendingOrderId,
        paymentMethod: paymentMethod,
        purchase: purchase,
      );

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }

      if (verified.status == 'succeeded') {
        await load(refresh: true);
        state = state.copyWith(
          isBuying: false,
        checkoutVerificationState: WalletCheckoutVerificationState.succeeded,
        checkoutGrantedSpark: verified.sparkToGrant,
        highlightedPurchaseOrderId: verified.orderId,
        clearPendingCheckout: true,
        clearPendingStoreProvider: true,
        clearCheckoutError: true,
      );
      return;
    }

      state = state.copyWith(
        isBuying: false,
        checkoutVerificationState: WalletCheckoutVerificationState.pending,
        clearCheckoutError: true,
      );
      await verifyCheckoutStatus();
    } catch (error) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }
      state = state.copyWith(
        isBuying: false,
        checkoutVerificationState: WalletCheckoutVerificationState.error,
        checkoutErrorMessage: error.toString(),
        errorMessage: error.toString(),
      );
    }
  }
}

String _errorMessage(Object error) {
  if (error is AppException) {
    if (error.message.trim().isNotEmpty) {
      return error.message;
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

  return error.toString();
}
