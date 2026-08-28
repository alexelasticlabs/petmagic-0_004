import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  testWidgets('linked accounts screen hides Apple on Android', (tester) async {
    await _pumpLinkedAccountsPage(
      tester,
      linkedAccounts: const <MobileLinkedAccount>[],
    );

    expect(find.text('Linked accounts'), findsOneWidget);
    expect(
      find.text(
        'Connect Google to keep access to your generations, purchases, and PawSpark on any device.',
      ),
      findsOneWidget,
    );

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('pet@example.com'), findsOneWidget);

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('linked accounts screen shows Apple on iOS', (tester) async {
    await _pumpLinkedAccountsPage(
      tester,
      linkedAccounts: const <MobileLinkedAccount>[],
      runtimeInfo: const DefaultAppRuntimeInfo(
        platform: AppRuntimePlatform.ios,
      ),
    );

    expect(
      find.text(
        'Connect Google or Apple to keep access to your generations, purchases, and PawSpark on any device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Connect'), findsNWidgets(2));
  });

  test(
    'linked accounts provider labels use localized short labels instead of api values',
    () async {
      final source = await File(
        'lib/features/profile/presentation/widgets/profile_linked_accounts_settings_section.dart',
      ).readAsString();

      expect(source, contains('providerLabel: text.authGoogleShortLabel'));
      expect(source, contains('providerLabel: text.authAppleShortLabel'));
      expect(
        source,
        isNot(contains('providerLabel: ExternalAuthProvider.google.apiValue')),
      );
      expect(
        source,
        isNot(contains('providerLabel: ExternalAuthProvider.apple.apiValue')),
      );
    },
  );

  testWidgets('linked accounts email row opens password setup flow', (
    tester,
  ) async {
    await _pumpLinkedAccountsPage(
      tester,
      linkedAccounts: const <MobileLinkedAccount>[],
    );

    await tester.ensureVisible(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('password-change-screen'), findsOneWidget);
  });

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
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
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

  testWidgets(
    'linked accounts stays offline without loading and retries on reconnect',
    (tester) async {
      var linkedAccountsReads = 0;
      final networkController = _TestLinkedAccountsNetworkStatusController(
        initialHasInternet: false,
      );
      final container = ProviderContainer(
        retry: (attempt, error) => null,
        overrides: [
          profileControllerProvider.overrideWith(_FakeProfileController.new),
          networkStatusControllerProvider.overrideWith(() => networkController),
          linkedAccountsProvider.overrideWith((ref) async {
            linkedAccountsReads++;
            return const <MobileLinkedAccount>[];
          }),
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

      await tester.pump();
      expect(linkedAccountsReads, 0);
      expect(find.text("You're offline"), findsOneWidget);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(linkedAccountsReads, 1);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text("You're offline"), findsNothing);
    },
  );

  testWidgets(
    'linked accounts detail shows auth gate for guests without loading provider',
    (tester) async {
      var linkedAccountsReads = 0;
      final container = ProviderContainer(
        retry: (attempt, error) => null,
        overrides: [
          profileControllerProvider.overrideWith(_GuestProfileController.new),
          linkedAccountsProvider.overrideWith((ref) async {
            linkedAccountsReads++;
            return const <MobileLinkedAccount>[];
          }),
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(linkedAccountsReads, 0);
    },
  );
}

Future<void> _pumpLinkedAccountsPage(
  WidgetTester tester, {
  required List<MobileLinkedAccount> linkedAccounts,
  AppRuntimeInfo runtimeInfo = const DefaultAppRuntimeInfo(
    platform: AppRuntimePlatform.android,
  ),
}) async {
  final container = ProviderContainer(
    retry: (attempt, error) => null,
    overrides: [
      profileControllerProvider.overrideWith(_FakeProfileController.new),
      appRuntimeInfoProvider.overrideWithValue(runtimeInfo),
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
  late final GoRouter router;
  Widget withNavigation(Widget child) =>
      AppNavigationScope(navigator: GoRouterAppNavigator(router), child: child);

  router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => withNavigation(home)),
      GoRoute(
        path: '/profile/settings/password-change',
        builder: (context, state) => withNavigation(
          const Scaffold(body: Text('password-change-screen')),
        ),
      ),
    ],
  );
  return router;
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

class _GuestProfileController extends ProfileController {
  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: '',
      email: '',
      password: '',
      confirmPassword: '',
    );
  }
}

class _TestLinkedAccountsNetworkStatusController
    extends NetworkStatusController {
  _TestLinkedAccountsNetworkStatusController({
    required this.initialHasInternet,
  });

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}
