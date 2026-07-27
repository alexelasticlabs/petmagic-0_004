import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';

import '../test/widget_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Welcome/Auth to Discover/Create/Creations/Rewards/Profile/Support',
    (tester) async {
      resetInMemoryAsyncPreferences();
      final profileRepository = FakeProfileRepository();

      await pumpTestApp(
        tester,
        repository: const FakeTemplatesRepository(items: [sampleTemplate]),
        profileRepository: profileRepository,
        externalAuthRepository: FakeExternalAuthRepository(),
        networkStatusController: OnlineWidgetNetworkStatusController.new,
        surfaceSize: const Size(390, 844),
      );

      await _pumpUntilVisible(tester, find.byType(GuestWelcomePage));
      expect(find.byType(GuestWelcomePage), findsOneWidget);
      final text = AppLocalizations.of(
        tester.element(find.byType(GuestWelcomePage)),
      );

      await tester.tap(find.bySemanticsLabel(text.profileSignInAction));
      await _pumpUntilVisible(tester, find.byType(AuthEntryPage));
      expect(find.byType(AuthEntryPage), findsOneWidget);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'journey@petmagic.test');
      await tester.enterText(fields.at(1), 'PetMagic-2026!');
      final signIn = find.widgetWithText(
        FilledButton,
        text.profileSignInAction,
      );
      await tester.ensureVisible(signIn);
      await tester.tap(signIn);

      await _pumpUntilVisible(tester, find.byType(TemplatesPage));
      expect(find.byType(TemplatesPage), findsOneWidget);
      expect(
        profileRepository.storedSession?.user.email,
        'journey@petmagic.test',
      );

      await _openDestination(
        tester,
        semanticsLabel: text.navCreations,
        page: find.byType(GenerationsGalleryPage),
      );
      await _openDestination(
        tester,
        semanticsLabel: text.navRewards,
        page: find.byType(RewardsPage),
      );
      await _openDestination(
        tester,
        semanticsLabel: text.navProfile,
        page: find.byType(ProfilePage),
      );

      tester
          .element(find.byType(ProfilePage))
          .appNavigator
          .go(const SupportChatDestination());
      await _pumpUntilVisible(tester, find.byType(SupportChatPage));

      expect(find.byType(SupportChatPage), findsOneWidget);
      expect(find.text('How can we help today?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openDestination(
  WidgetTester tester, {
  required String semanticsLabel,
  required Finder page,
}) async {
  final destination = find.bySemanticsLabel(semanticsLabel);
  expect(destination, findsOneWidget);
  await tester.tap(destination);
  await _pumpUntilVisible(tester, page);
  expect(page, findsOneWidget);
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (finder.evaluate().isEmpty &&
      tester.binding.clock.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
