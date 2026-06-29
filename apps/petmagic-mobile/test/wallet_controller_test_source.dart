import 'dart:io';

const _walletControllerLibraryPaths = [
  'lib/features/wallet/presentation/wallet_controller.dart',
  'lib/features/wallet/presentation/wallet_controller_errors.part.dart',
  'lib/features/wallet/presentation/wallet_controller_lifecycle.part.dart',
  'lib/features/wallet/presentation/wallet_controller_loading.part.dart',
  'lib/features/wallet/presentation/wallet_controller_checkout.part.dart',
];

String readWalletControllerLibrarySource() {
  return _walletControllerLibraryPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
