import 'package:petmagic_mobile/features/wallet/domain/pending_store_wallet_purchase.dart';

enum WalletStorePurchasePhase {
  purchasePending,
  recoveredPending,
  pendingWithoutOrder,
  checking,
  succeeded,
  pending,
  error,
  cancelled,
}

class WalletStorePurchaseStateChange {
  const WalletStorePurchaseStateChange(
    this.phase, {
    this.pendingPurchase,
    this.grantedSpark,
    this.orderId,
    this.errorMessage,
  });

  final WalletStorePurchasePhase phase;
  final PendingStoreWalletPurchase? pendingPurchase;
  final int? grantedSpark;
  final String? orderId;
  final String? errorMessage;
}
