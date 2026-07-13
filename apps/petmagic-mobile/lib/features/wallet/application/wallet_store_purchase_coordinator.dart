import 'dart:async';

import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_store_purchase_resolver.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_store_purchase_state_change.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';

class WalletStorePurchaseHost {
  const WalletStorePurchaseHost({
    required this.repository,
    required this.isActive,
    required this.hasAuthenticatedSession,
    required this.hasInternet,
    required this.pendingOrderId,
    required this.pendingProvider,
    required this.paymentMethods,
    required this.packs,
    required this.reloadWallet,
    required this.verifyCheckoutStatus,
    required this.errorMessage,
    required this.purchaseErrorMessage,
    required this.onStateChange,
  });

  final WalletRepositoryPort repository;
  final bool Function() isActive;
  final bool Function() hasAuthenticatedSession;
  final bool Function() hasInternet;
  final String? Function() pendingOrderId;
  final String? Function() pendingProvider;
  final List<WalletPaymentMethodModel> Function() paymentMethods;
  final List<CurrencyPackModel> Function() packs;
  final Future<void> Function() reloadWallet;
  final Future<void> Function() verifyCheckoutStatus;
  final String Function(Object error) errorMessage;
  final String Function(String? message) purchaseErrorMessage;
  final void Function(WalletStorePurchaseStateChange change) onStateChange;
}

class WalletStorePurchaseCoordinator {
  WalletStorePurchaseCoordinator(
    this._host, {
    WalletStorePurchaseResolver resolver = const WalletStorePurchaseResolver(),
  }) : _resolver = resolver;

  static const int _maxVerificationKeys = 32;

  final WalletStorePurchaseHost _host;
  final WalletStorePurchaseResolver _resolver;
  final Set<String> _verificationInFlightKeys = <String>{};
  final Set<String> _verifiedKeys = <String>{};
  Future<void>? _recoveryInFlight;
  bool _restoreRequestedThisSession = false;

  Future<void> restoreStorePurchases() async {
    if (_host.hasAuthenticatedSession()) {
      await _host.repository.restoreStorePurchases();
    }
  }

  Future<void> handlePurchaseUpdates(
    List<StorePurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (!_host.isActive()) {
        return;
      }

      switch (purchase.status) {
        case StorePurchaseStatus.pending:
          _host.onStateChange(
            const WalletStorePurchaseStateChange(
              WalletStorePurchasePhase.purchasePending,
            ),
          );
          break;
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          await _verifyPurchase(purchase);
          break;
        case StorePurchaseStatus.error:
          await _completeFailedPurchaseIfRequired(purchase);
          if (!_host.isActive()) {
            return;
          }
          _host.onStateChange(
            WalletStorePurchaseStateChange(
              WalletStorePurchasePhase.error,
              errorMessage: _host.purchaseErrorMessage(purchase.error?.message),
            ),
          );
          break;
        case StorePurchaseStatus.canceled:
          await _completeFailedPurchaseIfRequired(purchase);
          if (!_host.isActive()) {
            return;
          }
          _host.onStateChange(
            const WalletStorePurchaseStateChange(
              WalletStorePurchasePhase.cancelled,
              errorMessage: 'wallet.payment_unavailable',
            ),
          );
          break;
      }
    }
  }

  Future<void> recoverPendingPurchase({
    required bool requestStoreRestore,
  }) async {
    final inFlight = _recoveryInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _performRecovery(
      requestStoreRestore: requestStoreRestore,
    );
    _recoveryInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_recoveryInFlight, operation)) {
        _recoveryInFlight = null;
      }
    }
  }

  Future<void> _verifyPurchase(StorePurchaseDetails purchase) async {
    final durablePending = await _host.repository.readPendingStorePurchase();
    if (!_host.isActive()) {
      return;
    }

    final provider = _resolver.provider(
      purchase: purchase,
      durablePending: durablePending,
      stateProvider: _host.pendingProvider(),
      paymentMethods: _host.paymentMethods(),
      packs: _host.packs(),
    );
    if (provider == null || provider.isEmpty) {
      _host.onStateChange(
        const WalletStorePurchaseStateChange(
          WalletStorePurchasePhase.pending,
          errorMessage: 'wallet.payment_unavailable',
        ),
      );
      return;
    }

    final pendingOrderId = _resolver.pendingOrderId(
      purchase: purchase,
      durablePending: durablePending,
      stateOrderId: _host.pendingOrderId(),
    );
    final paymentMethod = _resolver.paymentMethodForProvider(
      provider,
      _host.paymentMethods(),
    );

    if ((pendingOrderId == null || pendingOrderId.isEmpty) &&
        durablePending != null) {
      _host.onStateChange(
        WalletStorePurchaseStateChange(
          WalletStorePurchasePhase.pendingWithoutOrder,
          pendingPurchase: durablePending,
        ),
      );
    }

    final verificationKey = _resolver.verificationKey(
      orderId: pendingOrderId ?? 'recover',
      provider: provider,
      purchase: purchase,
    );
    if (!await _acquireVerification(purchase, verificationKey)) {
      return;
    }

    try {
      _host.onStateChange(
        const WalletStorePurchaseStateChange(WalletStorePurchasePhase.checking),
      );

      if (pendingOrderId != null &&
          pendingOrderId.isNotEmpty &&
          paymentMethod != null) {
        await _verifyKnownOrder(
          purchase: purchase,
          orderId: pendingOrderId,
          paymentMethod: paymentMethod,
          verificationKey: verificationKey,
        );
        return;
      }

      await _validateRecoveredPurchase(
        purchase: purchase,
        provider: provider,
        pendingOrderId: pendingOrderId,
        verificationKey: verificationKey,
      );
    } catch (error) {
      _host.onStateChange(
        WalletStorePurchaseStateChange(
          WalletStorePurchasePhase.error,
          errorMessage: _host.errorMessage(error),
        ),
      );
    } finally {
      if (verificationKey != null) {
        _verificationInFlightKeys.remove(verificationKey);
      }
    }
  }

  Future<bool> _acquireVerification(
    StorePurchaseDetails purchase,
    String? verificationKey,
  ) async {
    if (verificationKey == null) {
      return true;
    }
    if (_verifiedKeys.contains(verificationKey)) {
      if (purchase.pendingCompletePurchase) {
        await _host.repository.consumeVerifiedPurchase(purchase);
      }
      return false;
    }
    return _verificationInFlightKeys.add(verificationKey);
  }

  Future<void> _verifyKnownOrder({
    required StorePurchaseDetails purchase,
    required String orderId,
    required WalletPaymentMethodModel paymentMethod,
    required String? verificationKey,
  }) async {
    final verified = await _host.repository.verifyStorePurchase(
      orderId: orderId,
      paymentMethod: paymentMethod,
      purchase: purchase,
    );
    if (!_host.isActive()) {
      return;
    }
    if (verified.status != 'succeeded') {
      _host.onStateChange(
        const WalletStorePurchaseStateChange(WalletStorePurchasePhase.pending),
      );
      await _host.verifyCheckoutStatus();
      return;
    }

    await _settlePurchase(
      purchase: purchase,
      orderId: orderId,
      verificationKey: verificationKey,
    );
    if (!_host.isActive()) {
      return;
    }
    await _host.reloadWallet();
    _host.onStateChange(
      WalletStorePurchaseStateChange(
        WalletStorePurchasePhase.succeeded,
        grantedSpark: verified.sparkToGrant,
        orderId: verified.orderId,
      ),
    );
  }

  Future<void> _validateRecoveredPurchase({
    required StorePurchaseDetails purchase,
    required String provider,
    required String? pendingOrderId,
    required String? verificationKey,
  }) async {
    final validation = await _host.repository.validateStorePurchase(
      provider: provider,
      purchase: purchase,
    );
    if (!_host.isActive()) {
      return;
    }
    if (!validation.isSettledTokenPack) {
      _host.onStateChange(
        const WalletStorePurchaseStateChange(WalletStorePurchasePhase.pending),
      );
      return;
    }

    await _settlePurchase(
      purchase: purchase,
      orderId: pendingOrderId,
      verificationKey: verificationKey,
    );
    if (!_host.isActive()) {
      return;
    }
    await _host.reloadWallet();
    _host.onStateChange(
      WalletStorePurchaseStateChange(
        WalletStorePurchasePhase.succeeded,
        grantedSpark: validation.tokenAmount,
        orderId: pendingOrderId,
      ),
    );
  }

  Future<void> _settlePurchase({
    required StorePurchaseDetails purchase,
    required String? orderId,
    required String? verificationKey,
  }) async {
    if (verificationKey != null) {
      _rememberVerifiedKey(verificationKey);
    }
    if (purchase.pendingCompletePurchase) {
      await _host.repository.consumeVerifiedPurchase(purchase);
      if (!_host.isActive()) {
        return;
      }
    }
    await _host.repository.clearPendingStorePurchase(orderId: orderId);
  }

  Future<void> _performRecovery({required bool requestStoreRestore}) async {
    if (!_host.hasAuthenticatedSession() || !_host.hasInternet()) {
      return;
    }

    final pending = await _host.repository.readPendingStorePurchase();
    if (!_host.isActive() || pending == null) {
      return;
    }
    _host.onStateChange(
      WalletStorePurchaseStateChange(
        WalletStorePurchasePhase.recoveredPending,
        pendingPurchase: pending,
      ),
    );

    if (!requestStoreRestore || _restoreRequestedThisSession) {
      return;
    }
    try {
      await _host.repository.restoreStorePurchases();
      _restoreRequestedThisSession = true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Wallet.Checkout',
        operation: 'store_purchase_restore_failed',
        message: 'Store purchase restore failed during wallet recovery',
        context: {
          'provider': pending.provider,
          'order_id': pending.orderId,
          'product_id': pending.productId,
        },
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _completeFailedPurchaseIfRequired(
    StorePurchaseDetails purchase,
  ) async {
    if (purchase.pendingCompletePurchase) {
      await _host.repository.completePurchase(purchase);
    }
  }

  void _rememberVerifiedKey(String verificationKey) {
    _verifiedKeys.add(verificationKey);
    while (_verifiedKeys.length > _maxVerificationKeys) {
      _verifiedKeys.remove(_verifiedKeys.first);
    }
  }
}
