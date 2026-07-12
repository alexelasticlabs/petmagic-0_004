import 'dart:io';

const _premiumControllerLibraryPaths = [
  'lib/features/premium/application/premium_controller.dart',
  'lib/features/premium/application/premium_controller_lifecycle.part.dart',
  'lib/features/premium/application/premium_controller_loading.part.dart',
  'lib/features/premium/application/premium_controller_checkout.part.dart',
  'lib/features/premium/application/premium_controller_errors.part.dart',
];

String readPremiumControllerLibrarySource() {
  return _premiumControllerLibraryPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
