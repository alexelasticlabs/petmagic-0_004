import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  testWidgets('profile page shows unified auth gate for guests', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: AuthEntryPage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: Scaffold(body: Text('Auth route'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(_GuestProfileController.new),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('ru'),
            Locale('en'),
            Locale('de'),
            Locale('es'),
            Locale('fr'),
            Locale('it'),
            Locale('pl'),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final profileContext = tester.element(find.byType(ProfilePage));
    final text = AppLocalizations.of(profileContext);

    expect(
      router.routeInformationProvider.value.uri.path,
      ProfilePage.routePath,
    );
    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text(text.authSignInRequired), findsOneWidget);
    expect(find.text(text.authRequiredMessage), findsOneWidget);
    expect(find.text('Auth route'), findsNothing);
  });

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
          gamificationSummaryProvider.overrideWith(
            (ref) async => const GamificationSummaryModel(
              streak: StreakModel(
                currentStreak: 4,
                longestStreak: 8,
                freezesAvailable: 1,
                freezesPerWeek: 1,
                lastActiveDate: '2026-06-29',
                activeDaysThisWeek: ['mon', 'tue', 'wed', 'thu'],
              ),
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) async => const [
              AchievementModel(
                key: 'first_magic',
                category: 'generation',
                rarity: 'common',
                titleKey: 'achievementFirstMagic',
                descriptionKey: 'achievementFirstMagicDesc',
                requirementValue: 1,
                currentProgress: 1,
                rewardSpark: 10,
                isSecret: false,
                isUnlocked: true,
                iconEmoji: '✨',
              ),
            ],
          ),
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
            Locale('de'),
            Locale('es'),
            Locale('fr'),
            Locale('it'),
            Locale('pl'),
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

  testWidgets('subscription action returns safely after profile disposal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final profileController = _FakeProfileController();
    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: PremiumPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Premium route')),
          ),
        ),
        GoRoute(
          path: SubscriptionManagementPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Subscription route')),
          ),
        ),
        GoRoute(
          path: '/away',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: Scaffold(body: Text('Away route'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(() => profileController),
          walletControllerProvider.overrideWith(_FakeWalletController.new),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: true,
              canManageSubscription: true,
              status: 'active',
              manageSubscriptionAction: 'manage',
              provider: PremiumSubscriptionProviderView.stripe,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('ru'),
            Locale('en'),
            Locale('de'),
            Locale('es'),
            Locale('fr'),
            Locale('it'),
            Locale('pl'),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final initialInitializeCalls = profileController.initializeCalls;
    final profileContext = tester.element(find.byType(ProfilePage));
    final text = AppLocalizations.of(profileContext);

    await tester.tap(find.text(text.premiumManageAction));
    await tester.pumpAndSettle();
    expect(find.text('Subscription route'), findsOneWidget);

    router.go('/away');
    await tester.pumpAndSettle();

    expect(find.text('Away route'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(profileController.initializeCalls, initialInitializeCalls);
  });

  testWidgets('profile keeps a single achievements entrypoint and opens it', (
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
          path: AchievementsPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Achievements route')),
          ),
        ),
        GoRoute(
          path: ProfileSettingsPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Settings route')),
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
          gamificationSummaryProvider.overrideWith(
            (ref) async => const GamificationSummaryModel(
              streak: StreakModel(
                currentStreak: 4,
                longestStreak: 8,
                freezesAvailable: 1,
                freezesPerWeek: 1,
                lastActiveDate: '2026-06-29',
                activeDaysThisWeek: ['mon', 'tue', 'wed', 'thu'],
              ),
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) async => const [
              AchievementModel(
                key: 'first_magic',
                category: 'generation',
                rarity: 'common',
                titleKey: 'achievementFirstMagic',
                descriptionKey: 'achievementFirstMagicDesc',
                requirementValue: 1,
                currentProgress: 1,
                rewardSpark: 10,
                isSecret: false,
                isUnlocked: true,
                iconEmoji: '✨',
              ),
            ],
          ),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('ru'),
            Locale('en'),
            Locale('de'),
            Locale('es'),
            Locale('fr'),
            Locale('it'),
            Locale('pl'),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final profileContext = tester.element(find.byType(ProfilePage));
    final text = AppLocalizations.of(profileContext);

    await tester.fling(find.byType(ListView), const Offset(0, -900), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(text.gamificationAchievementsTitle), findsOneWidget);

    await tester.tap(find.text(text.gamificationAchievementsTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Achievements route'), findsOneWidget);
  });
}

class _FakeProfileController extends ProfileController {
  int initializeCalls = 0;

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
      profile: profile,
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {
    initializeCalls++;
  }

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
