import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_cache.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/startup/session_scope_reset.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_repository.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/pets/presentation/pet_profile_providers.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'my_pets_page_test_support.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    sharedStoreProductAvailabilityCache.clear();
  });

  test(
    'clears user generation cache when startup resolves signed out',
    () async {
      final preferences = SharedPreferencesAsync();
      final sessionStorage = _SignedOutAuthSessionStorage();
      final repository = TemplateGenerationRepository(
        dio: Dio(),
        sessionStorage: sessionStorage,
        preferences: preferences,
        authSessionCoordinator: AuthSessionCoordinator(
          dio: Dio(),
          sessionStorage: sessionStorage,
        ),
      );
      var mediaCleanupCalls = 0;

      await preferences.setString(
        'templates_active_generation_id_v1:user-1',
        'previous-user-generation',
      );
      await preferences.setString(
        'templates_active_generation_correlation_id_v1:user-1',
        'previous-user-flow',
      );

      final container = ProviderContainer(
        overrides: [
          authSessionStorageProvider.overrideWithValue(sessionStorage),
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          sessionMediaCacheCleanerProvider.overrideWithValue(() async {
            mediaCleanupCalls++;
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(sessionScopeResetProvider);
      expect(
        await preferences.getString('templates_active_generation_id_v1:user-1'),
        'previous-user-generation',
      );

      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      expect(
        await preferences.getString('templates_active_generation_id_v1:user-1'),
        isNull,
      );
      expect(
        await preferences.getString(
          'templates_active_generation_correlation_id_v1:user-1',
        ),
        isNull,
      );
      expect(mediaCleanupCalls, 1);
    },
  );

  test(
    'invalidates pet gallery providers when startup resolves signed out',
    () async {
      final repository = FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
            name: 'Milo',
            type: 'dog',
            photosCount: 1,
            generationsCount: 1,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
        ],
        photos: [
          PetPhoto(
            id: 'photo-1',
            petId: 'pet-1',
            mediaAssetId: 'media-1',
            url: 'https://cdn.petmagic.test/photo.jpg',
            fileName: 'photo.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: true,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
        generations: [
          TemplateGenerationResult(
            generationId: 'generation-1',
            userId: 'user-1',
            templateId: 'template-1',
            status: TemplateGenerationStatus.completed,
            tokenCost: 1,
            attemptCount: 1,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
            userMediaExpired: false,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authSessionStorageProvider.overrideWithValue(
            _SignedOutAuthSessionStorage(),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          sessionMediaCacheCleanerProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      await Future.wait([
        container.read(petsProvider.future),
        container.read(petPhotosProvider('pet-1').future),
        container.read(petGenerationsProvider('pet-1').future),
      ]);
      expect(repository.petsFetchCount, 1);
      expect(repository.petPhotoFetchCount, 1);
      expect(repository.petGenerationFetchCount, 1);

      container.read(sessionScopeResetProvider);
      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      await Future.wait([
        container.read(petsProvider.future),
        container.read(petPhotosProvider('pet-1').future),
        container.read(petGenerationsProvider('pet-1').future),
      ]);
      expect(repository.petsFetchCount, 2);
      expect(repository.petPhotoFetchCount, 2);
      expect(repository.petGenerationFetchCount, 2);
    },
  );

  test(
    'invalidates gamification providers when startup resolves signed out',
    () async {
      final repository = FakeGamificationRepository();

      final container = ProviderContainer(
        overrides: [
          authSessionStorageProvider.overrideWithValue(
            _SignedOutAuthSessionStorage(),
          ),
          gamificationRepositoryProvider.overrideWithValue(repository),
          sessionMediaCacheCleanerProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      await Future.wait([
        container.read(gamificationSummaryProvider.future),
        container.read(achievementsProvider.future),
      ]);
      expect(repository.summaryFetchCount, 1);
      expect(repository.achievementsFetchCount, 1);

      container.read(sessionScopeResetProvider);
      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      await Future.wait([
        container.read(gamificationSummaryProvider.future),
        container.read(achievementsProvider.future),
      ]);
      expect(repository.summaryFetchCount, 2);
      expect(repository.achievementsFetchCount, 2);
    },
  );

  test(
    'recreates support realtime client when startup resolves signed out',
    () async {
      final container = ProviderContainer(
        overrides: [
          authSessionStorageProvider.overrideWithValue(
            _SignedOutAuthSessionStorage(),
          ),
          sessionMediaCacheCleanerProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      final firstClient = container.read(supportChatRealtimeClientProvider);

      container.read(sessionScopeResetProvider);
      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      final secondClient = container.read(supportChatRealtimeClientProvider);
      expect(identical(firstClient, secondClient), isFalse);
    },
  );

  test(
    'clears push token registration cache when startup resolves signed out',
    () async {
      final registrationCache = SharedPreferencesPushTokenRegistrationCache(
        preferences: SharedPreferencesAsync(),
      );
      await registrationCache.writeLastCompletedRegistrationKey(
        'push-token|user-1|android|en_US|1.0.0|device-1',
      );

      final container = ProviderContainer(
        overrides: [
          authSessionStorageProvider.overrideWithValue(
            _SignedOutAuthSessionStorage(),
          ),
          sessionMediaCacheCleanerProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      container.read(sessionScopeResetProvider);
      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      expect(
        await registrationCache.readLastCompletedRegistrationKey(),
        isNull,
      );
    },
  );

  test(
    'clears store product availability cache when startup resolves signed out',
    () async {
      var loadCalls = 0;

      Future<StoreProductAvailabilitySnapshot> loader(
        Set<String> productIds,
      ) async {
        loadCalls++;
        return StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: productIds,
          productPrices: {
            for (final productId in productIds) productId: '\$3.99',
          },
        );
      }

      await sharedStoreProductAvailabilityCache.read(
        {'pack.small'},
        scopeKey: 'google_play',
        loader: loader,
      );
      await sharedStoreProductAvailabilityCache.read(
        {'pack.small'},
        scopeKey: 'google_play',
        loader: loader,
      );
      expect(loadCalls, 1);

      final container = ProviderContainer(
        overrides: [
          authSessionStorageProvider.overrideWithValue(
            _SignedOutAuthSessionStorage(),
          ),
          sessionMediaCacheCleanerProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      container.read(sessionScopeResetProvider);
      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      await sharedStoreProductAvailabilityCache.read(
        {'pack.small'},
        scopeKey: 'google_play',
        loader: loader,
      );
      expect(loadCalls, 2);
    },
  );
}

Future<void> _waitForLaunchState(
  ProviderContainer container,
  bool Function(AppLaunchState state) predicate,
) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final state = container.read(appLaunchControllerProvider);
    if (predicate(state)) {
      return;
    }

    await Future<void>.delayed(Duration.zero);
  }

  fail('App launch state did not satisfy predicate.');
}

Future<void> _flushMicrotasks() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _SignedOutAuthSessionStorage extends AuthSessionStorage {
  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> save(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

class FakeGamificationRepository extends GamificationRepository {
  FakeGamificationRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int summaryFetchCount = 0;
  int achievementsFetchCount = 0;

  @override
  Future<GamificationSummaryModel> fetchSummary({
    CancelToken? cancelToken,
  }) async {
    summaryFetchCount++;
    return GamificationSummaryModel(
      streak: const StreakModel(
        currentStreak: 4,
        longestStreak: 7,
        freezesAvailable: 1,
        freezesPerWeek: 2,
        lastActiveDate: '2026-06-30',
        activeDaysThisWeek: ['2026-06-30'],
      ),
      recentAchievements: const [
        AchievementModel(
          key: 'achievement-1',
          category: 'care',
          rarity: 'common',
          titleKey: 'achievement.title',
          descriptionKey: 'achievement.description',
          requirementValue: 1,
          currentProgress: 1,
          rewardSpark: 5,
          isSecret: false,
          isUnlocked: true,
        ),
      ],
      activeChallenges: const [
        WeeklyChallengeModel(
          id: 'challenge-1',
          challengeType: 'generations',
          targetValue: 3,
          currentValue: 1,
          titleKey: 'challenge.title',
          descriptionKey: 'challenge.description',
          rewardSpark: 10,
          isCompleted: false,
          rewardClaimed: false,
        ),
      ],
      topPets: const [
        PetProgressModel(
          petId: 'pet-1',
          xp: 120,
          level: 3,
          evolutionStage: 'juvenile',
          totalGenerations: 4,
          xpForNextLevel: 200,
          xpForCurrentLevel: 100,
          daysActive: 6,
        ),
      ],
    );
  }

  @override
  Future<List<AchievementModel>> fetchAchievements({
    CancelToken? cancelToken,
  }) async {
    achievementsFetchCount++;
    return const [
      AchievementModel(
        key: 'achievement-1',
        category: 'care',
        rarity: 'common',
        titleKey: 'achievement.title',
        descriptionKey: 'achievement.description',
        requirementValue: 1,
        currentProgress: 1,
        rewardSpark: 5,
        isSecret: false,
        isUnlocked: true,
      ),
    ];
  }
}
