import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
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
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_store_purchase_recovery_store.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'my_pets_page_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

      container.read(sessionScopeResetProvider);
      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      final petsSubscription = container.listen<AsyncValue<List<PetProfile>>>(
        petsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final photosSubscription = container.listen<AsyncValue<List<PetPhoto>>>(
        petPhotosProvider('pet-1'),
        (_, _) {},
        fireImmediately: true,
      );
      final generationsSubscription = container
          .listen<AsyncValue<List<TemplateGenerationResult>>>(
            petGenerationsProvider('pet-1'),
            (_, _) {},
            fireImmediately: true,
          );
      await _flushMicrotasks();

      expect(petsSubscription.read().error, _sessionExpiredExceptionMatcher());
      expect(
        photosSubscription.read().error,
        _sessionExpiredExceptionMatcher(),
      );
      expect(
        generationsSubscription.read().error,
        _sessionExpiredExceptionMatcher(),
      );
      petsSubscription.close();
      photosSubscription.close();
      generationsSubscription.close();
      expect(repository.petsFetchCount, 0);
      expect(repository.petPhotoFetchCount, 0);
      expect(repository.petGenerationFetchCount, 0);
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

      container.read(sessionScopeResetProvider);
      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      final summarySubscription = container
          .listen<AsyncValue<GamificationSummaryModel>>(
            gamificationSummaryProvider,
            (_, _) {},
            fireImmediately: true,
          );
      final achievementsSubscription = container
          .listen<AsyncValue<List<AchievementModel>>>(
            achievementsProvider,
            (_, _) {},
            fireImmediately: true,
          );
      await _flushMicrotasks();

      expect(
        summarySubscription.read().error,
        _sessionExpiredExceptionMatcher(),
      );
      expect(
        achievementsSubscription.read().error,
        _sessionExpiredExceptionMatcher(),
      );
      summarySubscription.close();
      achievementsSubscription.close();
      expect(repository.summaryFetchCount, 0);
      expect(repository.achievementsFetchCount, 0);
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
        '${pushTokenRegistrationFingerprintPrefix}test-registration-fingerprint',
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

  test(
    'clears pending wallet store purchase recovery when startup resolves signed out',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage();
      final recoveryStore = WalletStorePurchaseRecoveryStore(
        preferences: preferences,
        secureStorage: secureStorage,
        clock: () => DateTime.utc(2026, 7, 3, 12),
      );
      await recoveryStore.savePendingPurchase(
        PendingStoreWalletPurchase(
          orderId: 'order-previous-user',
          provider: 'google_play',
          productId: 'com.petmagic.app.tokens.google.pack100',
          packId: 'pack-100',
          packCode: 'pack100',
          createdAtUtc: DateTime.utc(2026, 7, 3, 11),
        ),
      );
      expect(await recoveryStore.readPendingPurchase(), isNotNull);

      final container = ProviderContainer(
        overrides: [
          authSessionStorageProvider.overrideWithValue(
            _SignedOutAuthSessionStorage(),
          ),
          walletStorePurchaseRecoveryPreferencesProvider.overrideWithValue(
            preferences,
          ),
          walletStorePurchaseRecoverySecureStorageProvider.overrideWithValue(
            secureStorage,
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

      expect(await recoveryStore.readPendingPurchase(), isNull);
    },
  );

  test(
    'deferred session invalidation stops quietly after container disposal',
    () async {
      final sessionStorage = _SignedOutAuthSessionStorage();
      final repository = TemplateGenerationRepository(
        dio: Dio(),
        sessionStorage: sessionStorage,
        preferences: SharedPreferencesAsync(),
        authSessionCoordinator: AuthSessionCoordinator(
          dio: Dio(),
          sessionStorage: sessionStorage,
        ),
      );
      final galleryStore = _NoopGenerationGalleryStore();
      final launchController = _MutableSessionScopeLaunchController(true);
      final asyncErrors = <Object>[];

      await runZonedGuarded(
        () async {
          final container = ProviderContainer(
            overrides: [
              appLaunchControllerProvider.overrideWith(() => launchController),
              authSessionStorageProvider.overrideWithValue(sessionStorage),
              templateGenerationRepositoryProvider.overrideWithValue(
                repository,
              ),
              generationGalleryStoreProvider.overrideWithValue(galleryStore),
              sessionMediaCacheCleanerProvider.overrideWithValue(() async {}),
            ],
          );

          container.read(sessionScopeResetProvider);
          launchController.setAuthenticated(false);
          container.dispose();

          await _flushMicrotasks();
        },
        (error, stackTrace) {
          asyncErrors.add(error);
        },
      );

      expect(asyncErrors, isEmpty);
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

Matcher _sessionExpiredExceptionMatcher() {
  return isA<AppException>().having(
    (error) => error.message,
    'message',
    'auth.session_expired',
  );
}

class _SignedOutAuthSessionStorage extends AuthSessionStorage {
  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> save(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

class _MutableSessionScopeLaunchController extends AppLaunchController {
  _MutableSessionScopeLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: _isAuthenticated,
    );
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: value,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: value,
    );
  }
}

class _NoopGenerationGalleryStore extends GenerationGalleryStore {
  _NoopGenerationGalleryStore()
    : super(
        dio: Dio(),
        preferences: SharedPreferencesAsync(),
        sessionStorage: AuthSessionStorage(),
        rootDirectoryResolver: () async => Directory.systemTemp,
      );

  @override
  Future<void> cancelActiveDownloads() async {}

  @override
  Future<void> purgeAllScopes() async {}
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

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? initialValues])
    : values = initialValues ?? <String, String>{};

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
      return;
    }

    values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
