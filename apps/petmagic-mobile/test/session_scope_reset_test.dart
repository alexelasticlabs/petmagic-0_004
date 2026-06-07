import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/startup/session_scope_reset.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
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

      await repository.rememberActiveGeneration(
        generationId: 'previous-user-generation',
        correlationId: 'previous-user-flow',
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
      expect(await repository.readActiveGeneration(), isNotNull);

      await _waitForLaunchState(
        container,
        (state) => !state.isLoading && !state.isAuthenticated,
      );
      await _flushMicrotasks();

      expect(await repository.readActiveGeneration(), isNull);
      expect(mediaCleanupCalls, 1);
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
