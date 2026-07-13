import 'dart:async';

import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';

typedef WalletCheckoutSucceeded =
    Future<void> Function(PurchaseHistoryItem purchase);

class WalletCheckoutVerificationHost {
  const WalletCheckoutVerificationHost({
    required this.repository,
    required this.isActive,
    required this.pendingOrderId,
    required this.startCancellation,
    required this.clearCancellation,
    required this.errorMessage,
    required this.onChecking,
    required this.onSucceeded,
    required this.onError,
    required this.onPending,
  });

  final WalletRepositoryPort repository;
  final bool Function() isActive;
  final String? Function() pendingOrderId;
  final RequestCancellation Function() startCancellation;
  final void Function(RequestCancellation cancellation) clearCancellation;
  final String Function(Object error) errorMessage;
  final void Function() onChecking;
  final WalletCheckoutSucceeded onSucceeded;
  final void Function(String message) onError;
  final void Function() onPending;
}

class WalletCheckoutVerificationCoordinator {
  WalletCheckoutVerificationCoordinator(this._host);

  final WalletCheckoutVerificationHost _host;
  Future<void>? _inFlight;

  Future<void> verifyCheckoutStatus() {
    return _runSingleFlight(_performCheckoutStatusVerification);
  }

  Future<void> verifyStripeCheckout(String? stripeReferenceId) {
    return _runSingleFlight(
      () => _performStripeCheckoutVerification(stripeReferenceId),
    );
  }

  Future<void> _runSingleFlight(
    Future<void> Function() operationFactory,
  ) async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = operationFactory();
    _inFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_inFlight, operation)) {
        _inFlight = null;
      }
    }
  }

  Future<void> _performCheckoutStatusVerification() async {
    final pendingOrderId = _normalizedPendingOrderId();
    if (pendingOrderId == null) {
      return;
    }

    _host.onChecking();
    final cancellation = _host.startCancellation();
    const maxAttempts = 6;
    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!_canContinue(cancellation)) {
          return;
        }

        try {
          final purchase = await _host.repository.fetchPurchase(
            pendingOrderId,
            cancelToken: cancellation,
          );
          if (!_canContinue(cancellation)) {
            return;
          }
          if (purchase.status == 'succeeded') {
            await _host.onSucceeded(purchase);
            return;
          }
        } on RequestCancelledException {
          return;
        } catch (error) {
          _host.onError(_host.errorMessage(error));
          return;
        }

        if (attempt < maxAttempts - 1 &&
            !await _waitBeforeRetry(cancellation)) {
          return;
        }
      }
    } finally {
      _host.clearCancellation(cancellation);
    }

    _host.onPending();
  }

  Future<void> _performStripeCheckoutVerification(
    String? stripeReferenceId,
  ) async {
    final pendingOrderId = _normalizedPendingOrderId();
    if (pendingOrderId == null) {
      return;
    }

    _host.onChecking();
    final cancellation = _host.startCancellation();
    const maxAttempts = 5;
    final normalizedReference = normalizeStripeCheckoutReferenceId(
      stripeReferenceId,
    );

    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!_canContinue(cancellation)) {
          return;
        }

        try {
          final purchase = await _host.repository.verifyStripeCheckoutSession(
            orderId: pendingOrderId,
            stripeReferenceId: normalizedReference,
            cancelToken: cancellation,
          );
          if (!_canContinue(cancellation)) {
            return;
          }
          if (purchase.status == 'succeeded') {
            await _host.onSucceeded(purchase);
            return;
          }
        } on RequestCancelledException {
          return;
        } catch (error) {
          AppLogger.warn(
            feature: 'Wallet.Checkout',
            operation: 'stripe_verify_attempt_failed',
            message: 'Stripe verify attempt failed',
            context: {
              'order_id': pendingOrderId,
              'attempt': attempt + 1,
              'reference_type': stripeCheckoutReferenceType(
                normalizedReference,
              ),
            },
            error: error,
          );
        }

        final settled = await _fetchSettledPurchase(
          pendingOrderId,
          cancellation,
        );
        if (settled != null) {
          await _host.onSucceeded(settled);
          return;
        }
        if (!_canContinue(cancellation)) {
          return;
        }

        if (attempt < maxAttempts - 1 &&
            !await _waitBeforeRetry(cancellation)) {
          return;
        }
      }
    } finally {
      _host.clearCancellation(cancellation);
    }

    await _performCheckoutStatusVerification();
  }

  Future<PurchaseHistoryItem?> _fetchSettledPurchase(
    String orderId,
    RequestCancellation cancellation,
  ) async {
    try {
      final purchase = await _host.repository.fetchPurchase(
        orderId,
        cancelToken: cancellation,
      );
      if (!_canContinue(cancellation)) {
        return null;
      }
      return purchase.status == 'succeeded' ? purchase : null;
    } on RequestCancelledException {
      return null;
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'Wallet.Load',
        operation: 'fetch_purchase_for_verification',
        message: 'Wallet load stage failed',
        error: error,
        stackTrace: stackTrace,
        context: {'stage': 'fetch_purchase_for_verification'},
      );
      return null;
    }
  }

  String? _normalizedPendingOrderId() {
    final orderId = _host.pendingOrderId()?.trim();
    return orderId == null || orderId.isEmpty ? null : orderId;
  }

  bool _canContinue(RequestCancellation cancellation) {
    return _host.isActive() && !cancellation.isCancelled;
  }

  Future<bool> _waitBeforeRetry(RequestCancellation cancellation) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return _canContinue(cancellation);
  }
}

final RegExp _stripeCheckoutSessionReferencePattern = RegExp(
  r'^cs_(test|live)_[A-Za-z0-9_]{8,255}$',
);
final RegExp _stripePaymentIntentReferencePattern = RegExp(
  r'^pi_[A-Za-z0-9_]{8,255}$',
);

String? normalizeStripeCheckoutReferenceId(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  if (_stripeCheckoutSessionReferencePattern.hasMatch(trimmed) ||
      _stripePaymentIntentReferencePattern.hasMatch(trimmed)) {
    return trimmed;
  }
  return null;
}

String stripeCheckoutReferenceType(String? value) {
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
