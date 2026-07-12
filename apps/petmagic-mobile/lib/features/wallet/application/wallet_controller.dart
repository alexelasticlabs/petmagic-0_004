import 'dart:async';

// Public wallet application state and use-case orchestration.

import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/lifecycle/app_lifecycle_signal.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/domain/pending_store_wallet_purchase.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_error_key_mapper.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

part 'wallet_controller_checkout.part.dart';
part 'wallet_controller_errors.part.dart';
part 'wallet_controller_lifecycle.part.dart';
part 'wallet_controller_loading.part.dart';

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
    this.ledgerHasMore = false,
    this.hasCompletedFullLoad = false,
    this.isLoadingMoreLedger = false,
    this.ledgerLoadMoreErrorMessage,
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
  final bool ledgerHasMore;
  final bool hasCompletedFullLoad;
  final bool isLoadingMoreLedger;
  final String? ledgerLoadMoreErrorMessage;
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
    bool? ledgerHasMore,
    bool? hasCompletedFullLoad,
    bool? isLoadingMoreLedger,
    String? ledgerLoadMoreErrorMessage,
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
    bool clearLedgerLoadMoreError = false,
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
      ledgerHasMore: ledgerHasMore ?? this.ledgerHasMore,
      hasCompletedFullLoad: hasCompletedFullLoad ?? this.hasCompletedFullLoad,
      isLoadingMoreLedger: isLoadingMoreLedger ?? this.isLoadingMoreLedger,
      ledgerLoadMoreErrorMessage: clearLedgerLoadMoreError
          ? null
          : ledgerLoadMoreErrorMessage ?? this.ledgerLoadMoreErrorMessage,
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

abstract class _WalletControllerBase extends Notifier<WalletState> {
  static const int walletLedgerPageSize = 24;
  static const int _maxStorePurchaseVerificationKeys = 32;

  WalletRepositoryPort get _repository => ref.read(walletRepositoryProvider);
  AppRuntimeInfo get _runtimeInfo => ref.read(appRuntimeInfoProvider);
  Future<void>? _loadInFlight;
  Future<void>? _checkoutVerificationInFlight;
  Future<void>? _storePurchaseRecoveryInFlight;
  RequestCancellation? _activeLoadRequestCancellation;
  RequestCancellation? _activeWalletSyncRequestCancellation;
  RequestCancellation? _activeLedgerLoadMoreRequestCancellation;
  RequestCancellation? _activeCheckoutRequestCancellation;
  RequestCancellation? _activeCheckoutVerificationRequestCancellation;
  final Set<String> _storePurchaseVerificationInFlightKeys = <String>{};
  final Set<String> _storePurchaseVerifiedKeys = <String>{};
  bool _isWalletSyncInFlight = false;
  bool _walletLifecycleStarted = false;
  bool _isWalletPageVisible = false;
  bool _storePurchaseRestoreRequestedThisSession = false;
  void Function()? _appLifecycleListener;

  bool _hasAuthenticatedWalletSession() {
    return ref.read(appLaunchControllerProvider).isAuthenticated;
  }

  Future<void> load({bool refresh = false});

  Future<void> syncSnapshot({bool forceRefresh = false});

  Future<void> loadMoreLedger({bool force = false});

  Future<void> _syncWalletSnapshot({bool forceRefresh = false});

  void setWalletPageVisible(bool visible);

  Future<PurchaseCheckoutModel?> buyPack(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  );

  Future<void> claimAdReward();

  Future<String?> applyRedeemCode(String code);

  Future<String?> applyReferralCode(String code);

  void consumeCheckoutUrl();

  void resetCheckoutVerification();

  Future<void> verifyCheckoutStatus();

  Future<void> verifyStripeCheckout(String? stripeReferenceId);

  Future<void> restoreStorePurchases();

  Future<void> _recoverPendingStorePurchase({
    required bool requestStoreRestore,
  });

  Future<void> _handlePurchaseUpdates(List<StorePurchaseDetails> purchases);
}

class WalletController extends _WalletControllerBase
    with
        _WalletControllerLifecycle,
        _WalletControllerLoading,
        _WalletControllerCheckout {
  @override
  WalletState build() {
    _ensureWalletLifecycleStarted();
    return const WalletState(isLoading: true);
  }
}

// Public wallet application controller.
