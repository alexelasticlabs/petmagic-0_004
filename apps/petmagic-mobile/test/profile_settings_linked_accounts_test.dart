import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';

void main() {
  testWidgets(
    'linked accounts screen shows value proposition and provider rows',
    (tester) async {
      await _pumpLinkedAccountsPage(
        tester,
        linkedAccounts: const <MobileLinkedAccount>[],
      );

      expect(find.text('Linked accounts'), findsOneWidget);
      expect(
        find.text(
          'Connect Google or Apple to keep access to your generations, purchases, and PawSpark on any device.',
        ),
        findsOneWidget,
      );

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('pet@example.com'), findsOneWidget);

      expect(find.text('Connect'), findsNWidgets(2));
      expect(find.text('Disconnect'), findsOneWidget);
    },
  );

  testWidgets('linked accounts screen reflects connected provider state', (
    tester,
  ) async {
    await _pumpLinkedAccountsPage(
      tester,
      linkedAccounts: const <MobileLinkedAccount>[
        MobileLinkedAccount(
          provider: 'Google',
          displayName: 'alex@gmail.com',
          canDisconnect: true,
        ),
      ],
    );

    expect(find.text('alex@gmail.com'), findsOneWidget);
    expect(find.text('Connected and ready to sign in.'), findsNWidgets(2));
    expect(find.text('Disconnect'), findsNWidgets(2));
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('linked accounts screen shows retry on load failure', (
    tester,
  ) async {
    await _pumpLinkedAccountsPageWithError(tester);

    expect(
      find.text('Linked accounts are temporarily unavailable.'),
      findsWidgets,
    );
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });
}

Future<void> _pumpLinkedAccountsPage(
  WidgetTester tester, {
  required List<MobileLinkedAccount> linkedAccounts,
}) async {
  final container = ProviderContainer(
    retry: (attempt, error) => null,
    overrides: [
      profileControllerProvider.overrideWith(_FakeProfileController.new),
      linkedAccountsProvider.overrideWith((ref) async => linkedAccounts),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: _testRouter(
          const ProfileSettingsDetailPage(
            kind: ProfileSettingsDetailKind.linkedAccounts,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _pumpLinkedAccountsPageWithError(WidgetTester tester) async {
  final container = ProviderContainer(
    retry: (attempt, error) => null,
    overrides: [
      profileControllerProvider.overrideWith(_FakeProfileController.new),
      linkedAccountsProvider.overrideWith(
        (ref) async => throw Exception('auth.request_failed'),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: _testRouter(
          const ProfileSettingsDetailPage(
            kind: ProfileSettingsDetailKind.linkedAccounts,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

GoRouter _testRouter(Widget home) {
  return GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
}

class _FakeProfileController extends ProfileController {
  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: 'Pet User',
      email: 'pet@example.com',
      password: '',
      confirmPassword: '',
      profile: MobileUserProfile(
        userId: 'user-1',
        email: 'pet@example.com',
        displayName: 'Pet User',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: true,
        legalAcceptance: MobileLegalAcceptanceStatus(
          termsOfUseAccepted: true,
          termsOfUseAcceptedVersion: '1.0',
          termsOfUseAcceptedAtUtc: null,
          privacyPolicyAccepted: true,
          privacyPolicyAcceptedVersion: '1.0',
          privacyPolicyAcceptedAtUtc: null,
          currentTermsOfUseVersion: '1.0',
          currentPrivacyPolicyVersion: '1.0',
          requiresAcceptance: false,
        ),
        roles: ['user'],
        avatar: null,
      ),
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {}

  @override
  Future<void> logout() async {}
}
