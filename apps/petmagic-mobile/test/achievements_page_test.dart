import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_repository.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  testWidgets(
    'achievements page shows auth gate for guests without loading providers',
    (tester) async {
      final repository = _ControlledAchievementsRepository(failUntilCall: 0);

      await _pumpPage(tester, repository, authenticated: false);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AchievementsPage));
      final text = AppLocalizations.of(context);

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(find.text(text.authSignInRequired), findsOneWidget);
      expect(find.text(text.authRequiredMessage), findsOneWidget);
      expect(repository.fetchCalls, 0);
      expect(repository.summaryFetchCalls, 0);
    },
  );

  testWidgets(
    'achievements page avoids redundant reload on first authenticated open',
    (tester) async {
      final repository = _ControlledAchievementsRepository(failUntilCall: 0);

      await _pumpPage(tester, repository);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AchievementsPage));
      final text = AppLocalizations.of(context);

      expect(repository.fetchCalls, 1);
      expect(repository.summaryFetchCalls, 1);
      expect(find.text(text.achievementFirstMagic), findsOneWidget);
    },
  );

  testWidgets('achievements page shows retry action and retries explicitly', (
    tester,
  ) async {
    final repository = _ControlledAchievementsRepository(failUntilCall: 20);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AchievementsPage));
    final text = AppLocalizations.of(context);

    expect(find.text(text.appUnavailableServerTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, text.retryAction), findsOneWidget);

    repository.failUntilCall = repository.fetchCalls;
    await tester.tap(find.widgetWithText(FilledButton, text.retryAction));
    await tester.pumpAndSettle();

    expect(find.text(text.appUnavailableServerTitle), findsNothing);
    expect(find.text(text.achievementFirstMagic), findsOneWidget);
  });

  testWidgets(
    'achievements page shows legal acceptance action instead of server unavailable for legal gate errors',
    (tester) async {
      final repository = _ControlledAchievementsRepository(
        failUntilCall: 20,
        failureMessage: 'auth.legal_acceptance_required',
      );

      await _pumpPage(tester, repository);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final context = tester.element(find.byType(AchievementsPage));
      final text = AppLocalizations.of(context);

      expect(find.text(text.appUnavailableServerTitle), findsNothing);
      expect(find.text(text.appUnavailableOfflineTitle), findsNothing);
    },
  );

  testWidgets(
    'achievements page shows offline unavailable state and retries on network restore',
    (tester) async {
      final repository = _ControlledAchievementsRepository(failUntilCall: 20);
      final networkController = _TestNetworkStatusController(false);

      await _pumpPage(tester, repository, networkOverride: networkController);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AchievementsPage));
      final text = AppLocalizations.of(context);

      expect(find.text(text.appUnavailableOfflineTitle), findsOneWidget);
      expect(repository.fetchCalls, 0);
      expect(repository.summaryFetchCalls, 0);

      repository.failUntilCall = repository.fetchCalls;
      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 1);
      expect(repository.summaryFetchCalls, 1);
      expect(find.text(text.appUnavailableOfflineTitle), findsNothing);
      expect(find.text(text.achievementFirstMagic), findsOneWidget);
    },
  );

  testWidgets(
    'achievements page does not refetch unavailable state on offline resume',
    (tester) async {
      final repository = _ControlledAchievementsRepository(failUntilCall: 20);
      final networkController = _TestNetworkStatusController(false);

      await _pumpPage(tester, repository, networkOverride: networkController);
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 0);
      expect(repository.summaryFetchCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(repository.fetchCalls, 0);
      expect(repository.summaryFetchCalls, 0);

      repository.failUntilCall = repository.fetchCalls;
      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 1);
      expect(repository.summaryFetchCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'achievements page treats online connection failures as server unavailable',
    (tester) async {
      final repository = _ControlledAchievementsRepository(
        failUntilCall: 20,
        failureMessage: 'gamification.network_unavailable',
      );
      final networkController = _TestNetworkStatusController(true);

      await _pumpPage(tester, repository, networkOverride: networkController);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AchievementsPage));
      final text = AppLocalizations.of(context);

      expect(find.text(text.appUnavailableServerTitle), findsOneWidget);
      expect(find.text(text.appUnavailableOfflineTitle), findsNothing);
      expect(
        find.widgetWithText(FilledButton, text.retryAction),
        findsOneWidget,
      );
    },
  );

  testWidgets('achievements page filters unlocked achievements', (
    tester,
  ) async {
    final repository = _ControlledAchievementsRepository(failUntilCall: 0);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AchievementsPage));
    final text = AppLocalizations.of(context);

    expect(find.text(text.achievementApprentice10), findsOneWidget);
    expect(find.text(text.achievementFirstMagic), findsOneWidget);

    await tester.tap(find.byKey(const Key('achievement_filter_unlocked')));
    await tester.pumpAndSettle();

    expect(find.text(text.achievementFirstMagic), findsOneWidget);
    expect(find.text(text.achievementApprentice10), findsNothing);
  });

  testWidgets('achievements page shows weekly focus and next milestone', (
    tester,
  ) async {
    final repository = _ControlledAchievementsRepository(failUntilCall: 0);

    await _pumpPage(
      tester,
      repository,
      summaryOverride: const GamificationSummaryModel(
        streak: StreakModel(
          currentStreak: 4,
          longestStreak: 9,
          freezesAvailable: 1,
          freezesPerWeek: 1,
          lastActiveDate: '2026-06-29',
          activeDaysThisWeek: ['mon', 'tue', 'wed', 'thu'],
        ),
        activeChallenges: [
          WeeklyChallengeModel(
            id: 'challenge-1',
            challengeType: 'generation',
            targetValue: 10,
            currentValue: 4,
            titleKey: 'gamificationChallengeGenerateImages',
            descriptionKey: 'gamificationChallengeGenerateImagesDesc',
            rewardSpark: 20,
            isCompleted: false,
            rewardClaimed: false,
            iconEmoji: '🪄',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AchievementsPage));
    final text = AppLocalizations.of(context);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text(text.gamificationWeekFocusTitle), findsOneWidget);
    expect(find.text(text.gamificationNextMilestoneTitle), findsOneWidget);
    expect(find.text(text.gamificationChallengeGenerateImages), findsOneWidget);
    expect(find.text(text.gamificationStreakTitle), findsWidgets);
  });

  test(
    'achievements page logs partial summary refresh failures instead of swallowing them',
    () async {
      final pageSource = await File(
        'lib/features/gamification/presentation/achievements_page.dart',
      ).readAsString();

      expect(pageSource, contains('AppLogger.warn('));
      expect(pageSource, contains("feature: 'Gamification.Achievements'"));
      expect(pageSource, contains("operation: 'refresh_summary'"));
      expect(pageSource, isNot(contains('} catch (_) {')));
    },
  );

  test(
    'achievements provider keeps warm cache instead of dropping immediately',
    () async {
      final providersSource = await File(
        'lib/features/gamification/presentation/gamification_providers.dart',
      ).readAsString();

      expect(
        providersSource,
        contains(
          'final achievementsProvider = FutureProvider.autoDispose<List<AchievementModel>>(',
        ),
      );
      expect(providersSource, contains('final link = ref.keepAlive();'));
      expect(
        providersSource,
        contains(
          "disposeTimer = Timer(_gamificationProviderCacheTtl, link.close);",
        ),
      );
      expect(
        providersSource,
        contains("cancelToken.cancel('achievements_provider_disposed');"),
      );
      expect(
        providersSource,
        contains(
          "if (!ref.read(networkStatusControllerProvider).hasInternet) {",
        ),
      );
      expect(
        providersSource,
        contains(
          "throw const AppException('gamification.network_unavailable');",
        ),
      );
    },
  );

  test(
    'achievements page only retries cached unavailable data on open',
    () async {
      final pageSource = await File(
        'lib/features/gamification/presentation/achievements_page.dart',
      ).readAsString();

      expect(
        pageSource,
        contains('_reloadCachedUnavailableAchievementsIfNeeded();'),
      );
      expect(
        pageSource,
        contains('void _reloadCachedUnavailableAchievementsIfNeeded() {'),
      );
      expect(pageSource, contains('if (!ref.exists(achievementsProvider)) {'));
      expect(
        pageSource,
        contains(
          'void initState() {\n'
          '    super.initState();\n'
          '    WidgetsBinding.instance.addObserver(this);\n'
          '    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {\n'
          '      return;\n'
          '    }\n'
          '\n'
          '    _reloadCachedUnavailableAchievementsIfNeeded();\n'
          '  }',
        ),
      );
      expect(
        pageSource,
        isNot(
          contains(
            'void initState() {\n'
            '    super.initState();\n'
            '    WidgetsBinding.instance.addObserver(this);\n'
            '    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {\n'
            '      return;\n'
            '    }\n'
            '\n'
            '    _reloadAll();\n'
            '  }',
          ),
        ),
      );
    },
  );

  test(
    'achievements page keeps dedicated legal acceptance recovery action',
    () async {
      final pageSource = await File(
        'lib/features/gamification/presentation/achievements_page.dart',
      ).readAsString();

      expect(
        pageSource,
        contains('isAchievementsLegalAcceptanceFailure(rawError)'),
      );
      expect(pageSource, contains('LegalAcceptanceGatePage.routePath'));
      expect(pageSource, contains('text.profileLegalAcceptAction'));
    },
  );

  test(
    'profile achievements navigation avoids redundant preview invalidation',
    () async {
      final profileGamificationSource = await File(
        'lib/features/profile/presentation/profile_page_gamification.part.dart',
      ).readAsString();

      expect(
        profileGamificationSource,
        contains(
          'void openAchievements() => context.push(AchievementsPage.routePath);',
        ),
      );
      expect(
        profileGamificationSource,
        isNot(
          contains(
            'void openAchievements() {\n      reloadPreview();\n      context.push(AchievementsPage.routePath);\n    }',
          ),
        ),
      );
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  _ControlledAchievementsRepository repository, {
  _TestNetworkStatusController? networkOverride,
  GamificationSummaryModel? summaryOverride,
  bool authenticated = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? _AuthenticatedAppLaunchController.new
              : _GuestAppLaunchController.new,
        ),
        gamificationRepositoryProvider.overrideWithValue(repository),
        if (summaryOverride != null)
          gamificationSummaryProvider.overrideWith(
            (ref) async => summaryOverride,
          ),
        if (networkOverride != null)
          networkStatusControllerProvider.overrideWith(() => networkOverride),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AchievementsPage(),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _ControlledAchievementsRepository extends GamificationRepository {
  _ControlledAchievementsRepository({
    required this.failUntilCall,
    this.failureMessage = 'gamification.request_failed',
  }) : super(dio: Dio(), sessionStorage: _NoopAuthSessionStorage());

  int fetchCalls = 0;
  int summaryFetchCalls = 0;
  int failUntilCall;
  final String failureMessage;

  @override
  Future<List<AchievementModel>> fetchAchievements({
    CancelToken? cancelToken,
  }) async {
    fetchCalls += 1;
    if (fetchCalls <= failUntilCall) {
      throw AppException(failureMessage);
    }

    return const [
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
      AchievementModel(
        key: 'apprentice_10',
        category: 'generation',
        rarity: 'common',
        titleKey: 'achievementApprentice10',
        descriptionKey: 'achievementApprentice10Desc',
        requirementValue: 10,
        currentProgress: 3,
        rewardSpark: 15,
        isSecret: false,
        isUnlocked: false,
        iconEmoji: '🎯',
      ),
    ];
  }

  @override
  Future<GamificationSummaryModel> fetchSummary({
    CancelToken? cancelToken,
  }) async {
    summaryFetchCalls += 1;
    return const GamificationSummaryModel();
  }
}

class _NoopAuthSessionStorage extends AuthSessionStorage {}

class _AuthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _GuestAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _TestNetworkStatusController extends NetworkStatusController {
  _TestNetworkStatusController(bool hasInternet)
    : _initialState = NetworkStatusState(
        hasInternet: hasInternet,
        bannerPhase: hasInternet
            ? NetworkBannerPhase.hidden
            : NetworkBannerPhase.offline,
      );

  final NetworkStatusState _initialState;

  @override
  NetworkStatusState build() => _initialState;

  void setHasInternet(bool value) {
    state = NetworkStatusState(
      hasInternet: value,
      bannerPhase: value
          ? NetworkBannerPhase.restored
          : NetworkBannerPhase.offline,
    );
  }
}
