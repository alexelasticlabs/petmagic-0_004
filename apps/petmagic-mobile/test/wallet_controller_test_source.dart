import 'dart:io';

const _walletControllerLibraryPaths = [
  'lib/features/wallet/application/wallet_controller.dart',
  'lib/features/wallet/application/wallet_controller_errors.part.dart',
  'lib/features/wallet/application/wallet_controller_lifecycle.part.dart',
  'lib/features/wallet/application/wallet_controller_loading.part.dart',
  'lib/features/wallet/application/wallet_controller_checkout.part.dart',
  'lib/features/wallet/application/wallet_checkout_verification_coordinator.dart',
  'lib/features/wallet/application/wallet_store_purchase_coordinator.dart',
  'lib/features/wallet/application/wallet_store_purchase_resolver.dart',
  'lib/features/wallet/application/wallet_store_purchase_state_change.dart',
];

String readWalletControllerLibrarySource() {
  return _walletControllerLibraryPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
