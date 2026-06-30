import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_repository.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';

void main() {
  testWidgets('achievements page reloads on open after a transient failure', (
    tester,
  ) async {
    final repository = _ControlledAchievementsRepository(failUntilCall: 1);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AchievementsPage));
    final text = AppLocalizations.of(context);

    expect(repository.fetchCalls, greaterThanOrEqualTo(2));
    expect(find.text(text.gamificationLoadFailed), findsNothing);
    expect(find.text(text.achievementFirstMagic), findsOneWidget);
  });

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
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AchievementsPage));
      final text = AppLocalizations.of(context);

      expect(find.text(text.appUnavailableServerTitle), findsNothing);
      expect(find.text(text.profileLegalAcceptanceRequired), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, text.profileLegalAcceptAction),
        findsOneWidget,
      );
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
      final initialFetchCalls = repository.fetchCalls;
      expect(initialFetchCalls, greaterThan(0));

      repository.failUntilCall = initialFetchCalls;
      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, greaterThan(initialFetchCalls));
      expect(find.text(text.appUnavailableOfflineTitle), findsNothing);
      expect(find.text(text.achievementFirstMagic), findsOneWidget);
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
}

Future<void> _pumpPage(
  WidgetTester tester,
  _ControlledAchievementsRepository repository, {
  _TestNetworkStatusController? networkOverride,
  GamificationSummaryModel? summaryOverride,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
  })
    : super(dio: Dio(), sessionStorage: _NoopAuthSessionStorage());

  int fetchCalls = 0;
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
    return const GamificationSummaryModel();
  }
}

class _NoopAuthSessionStorage extends AuthSessionStorage {}

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
