import 'dart:io';

const _profilePageLibraryPaths = [
  'lib/features/profile/presentation/profile_page.dart',
  'lib/features/profile/presentation/profile_page_cards.part.dart',
  'lib/features/profile/presentation/profile_page_premium.part.dart',
  'lib/features/profile/presentation/profile_page_subscription_summary.part.dart',
  'lib/features/profile/presentation/profile_page_gamification.part.dart',
  'lib/features/profile/presentation/profile_page_view.part.dart',
];

String readProfilePageLibrarySource() {
  return _profilePageLibraryPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
