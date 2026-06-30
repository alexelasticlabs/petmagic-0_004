import 'dart:io';

const _walletPageLibraryPaths = [
  'lib/features/wallet/presentation/wallet_page.dart',
  'lib/features/wallet/presentation/wallet_page_checkout.part.dart',
  'lib/features/wallet/presentation/wallet_page_helpers.part.dart',
  'lib/features/wallet/presentation/widgets/wallet_page_activity_widgets.dart',
  'lib/features/wallet/presentation/widgets/wallet_page_overview_chrome.part.dart',
];

String readWalletPageLibrarySource() {
  return _walletPageLibraryPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
