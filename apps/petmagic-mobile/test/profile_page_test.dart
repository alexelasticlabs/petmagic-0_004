import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';

void main() {
  testWidgets('profile legal shortcut opens legal detail route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: ProfileSettingsPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Settings route')),
          ),
        ),
        GoRoute(
          path: ProfileSettingsDetailPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Legal detail route')),
          ),
        ),
        GoRoute(
          path: SupportChatPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Support route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(_FakeProfileController.new),
          walletControllerProvider.overrideWith(_FakeWalletController.new),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: false,
              canManageSubscription: false,
              status: 'inactive',
              manageSubscriptionAction: '',
              provider: PremiumSubscriptionProviderView.unknown,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('ru'),
            Locale('en'),
            Locale('en', 'US'),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final profileContext = tester.element(find.byType(ProfilePage));
    final text = AppLocalizations.of(profileContext);

    await tester.tap(find.text(text.profileLegalShortcutTitle));
    await tester.pumpAndSettle();

    expect(find.text('Legal detail route'), findsOneWidget);
    expect(find.text('Settings route'), findsNothing);
  });
}

class _FakeProfileController extends ProfileController {
  @override
  ProfileState build() {
    final profile = _profile;
    return ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: profile.displayName ?? '',
      email: profile.email,
      password: '',
      confirmPassword: '',
      session: AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAtUtc: DateTime.utc(2099, 1, 1),
        user: profile,
      ),
      profile: profile,
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {}

  @override
  Future<void> logout() async {}
}

class _FakeWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 130,
        adRewardsRemainingToday: 3,
        isPremium: false,
        updatedAtUtc: null,
        nextWeeklyGrantAtUtc: null,
      ),
      isLoading: false,
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

const _profile = MobileUserProfile(
  userId: 'user-1',
  email: 'user@example.com',
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
);
