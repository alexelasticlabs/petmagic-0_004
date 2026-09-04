import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

void main() {
  test(
    'discovery controller renders cache before replacing it with remote',
    () async {
      final repository = _ControlledDiscoveryRepository(
        cached: _discovery('Cached category'),
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      final controller = container.read(
        templateDiscoveryControllerProvider.notifier,
      );
      final load = controller.loadInitial();
      await repository.fetchStarted.future;

      final cachedState = container.read(templateDiscoveryControllerProvider);
      expect(cachedState.sections.single.category, 'Cached category');
      expect(cachedState.loadedFromCache, isTrue);
      expect(cachedState.isLoading, isFalse);
      expect(cachedState.isRefreshing, isTrue);

      repository.completeFetch(_discovery('Remote category'));
      await load;

      final remoteState = container.read(templateDiscoveryControllerProvider);
      expect(remoteState.sections.single.category, 'Remote category');
      expect(remoteState.loadedFromCache, isFalse);
      expect(remoteState.hasLoaded, isTrue);
      expect(remoteState.isRefreshing, isFalse);
      expect(remoteState.errorMessage, isNull);
    },
  );

  test('discovery controller retains cache when refresh fails', () async {
    final repository = _ControlledDiscoveryRepository(
      cached: _discovery('Cached category'),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final load = container
        .read(templateDiscoveryControllerProvider.notifier)
        .loadInitial();
    await repository.fetchStarted.future;
    repository.failFetch(const AppException('templates.discovery_failed'));
    await load;

    final state = container.read(templateDiscoveryControllerProvider);
    expect(state.sections.single.category, 'Cached category');
    expect(state.loadedFromCache, isTrue);
    expect(state.hasLoaded, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.isRefreshing, isFalse);
    expect(state.errorMessage, 'templates.discovery_failed');
  });

  test(
    'hiding discovery cancels an active load without surfacing an error',
    () async {
      final repository = _ControlledDiscoveryRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final controller = container.read(
        templateDiscoveryControllerProvider.notifier,
      );
      final load = controller.loadInitial();
      await repository.fetchStarted.future;
      expect(
        container.read(templateDiscoveryControllerProvider).isLoading,
        isTrue,
      );

      controller.setScreenVisible(false);

      expect(repository.cancelCalls, 1);
      await load;
      final state = container.read(templateDiscoveryControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.hasLoaded, isFalse);
    },
  );

  test('showing discovery retries an initial uncached fetch error', () async {
    final repository = _RetryDiscoveryRepository();
    final container = ProviderContainer(
      overrides: [
        templateDiscoveryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      templateDiscoveryControllerProvider.notifier,
    );

    final firstLoad = controller.loadInitial();
    await repository.firstFetchStarted.future;
    repository.failFirstFetch(const AppException('templates.discovery_failed'));
    await firstLoad;

    final failedState = container.read(templateDiscoveryControllerProvider);
    expect(failedState.sections, isEmpty);
    expect(failedState.hasLoaded, isTrue);
    expect(failedState.errorMessage, 'templates.discovery_failed');

    controller.setScreenVisible(false);
    controller.setScreenVisible(true);
    await repository.secondFetchStarted.future;
    repository.completeSecondFetch(_discovery('Recovered category'));
    await _waitUntil(() {
      final state = container.read(templateDiscoveryControllerProvider);
      return state.sections.length == 1 &&
          state.sections.single.category == 'Recovered category';
    });

    final recoveredState = container.read(templateDiscoveryControllerProvider);
    expect(repository.fetchCalls, 2);
    expect(recoveredState.hasLoaded, isTrue);
    expect(recoveredState.errorMessage, isNull);
    expect(recoveredState.sections.single.category, 'Recovered category');
  });

  test(
    'visibility refresh respects the 45 second freshness interval',
    () async {
      var now = DateTime.utc(2026, 9, 4, 8);
      final repository = _SequencedDiscoveryRepository([
        _discovery('Fresh category'),
        _discovery('Refreshed category'),
      ]);
      final container = ProviderContainer(
        overrides: [
          templateDiscoveryRepositoryProvider.overrideWithValue(repository),
          templateDiscoveryClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        templateDiscoveryControllerProvider.notifier,
      );

      await controller.loadInitial();
      expect(repository.fetchCalls, 1);
      expect(
        container
            .read(templateDiscoveryControllerProvider)
            .sections
            .single
            .category,
        'Fresh category',
      );

      controller.setScreenVisible(false);
      now = now.add(const Duration(seconds: 44));
      controller.setScreenVisible(true);
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchCalls, 1);
      expect(
        container
            .read(templateDiscoveryControllerProvider)
            .sections
            .single
            .category,
        'Fresh category',
      );

      controller.setScreenVisible(false);
      now = now.add(const Duration(seconds: 1));
      controller.setScreenVisible(true);
      await _waitUntil(() => repository.fetchCalls == 2);
      await _waitUntil(
        () =>
            container
                .read(templateDiscoveryControllerProvider)
                .sections
                .single
                .category ==
            'Refreshed category',
      );

      final refreshedState = container.read(
        templateDiscoveryControllerProvider,
      );
      expect(repository.fetchCalls, 2);
      expect(refreshedState.loadedFromCache, isFalse);
      expect(refreshedState.errorMessage, isNull);
    },
  );

  test(
    'offline cancellation allows a fresh retry and ignores the old failure',
    () async {
      final repository = _NetworkRaceDiscoveryRepository();
      final container = ProviderContainer(
        overrides: [
          templateDiscoveryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        templateDiscoveryControllerProvider.notifier,
      );

      final oldLoad = controller.loadInitial();
      await repository.firstFetchStarted.future;

      controller.handleNetworkUnavailable();

      expect(repository.cancelCalls, 1);
      final offlineState = container.read(templateDiscoveryControllerProvider);
      expect(offlineState.isLoading, isFalse);
      expect(offlineState.errorMessage, 'templates.request_failed');

      final freshLoad = controller.refreshIfNeeded();
      await repository.secondFetchStarted.future;
      repository.completeSecondFetch(_discovery('Fresh category'));
      await freshLoad;

      repository.failFirstFetch(
        const AppException('templates.stale_request_failed'),
      );
      await oldLoad;

      final state = container.read(templateDiscoveryControllerProvider);
      expect(repository.fetchCalls, 2);
      expect(state.sections.single.category, 'Fresh category');
      expect(state.errorMessage, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
    },
  );
}

ProviderContainer _container(_ControlledDiscoveryRepository repository) {
  return ProviderContainer(
    overrides: [
      templateDiscoveryRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

TemplateDiscovery _discovery(String category) {
  return TemplateDiscovery(
    sections: [TemplateDiscoverySection(category: category, items: const [])],
    generatedAtUtc: DateTime.utc(2026, 9, 4),
  );
}

final class _ControlledDiscoveryRepository
    implements TemplateDiscoveryRepository {
  _ControlledDiscoveryRepository({this.cached});

  final TemplateDiscovery? cached;
  final Completer<void> fetchStarted = Completer<void>();
  final Completer<TemplateDiscovery> _fetchResult =
      Completer<TemplateDiscovery>();
  int cancelCalls = 0;

  @override
  Future<TemplateDiscovery?> readCached() async => cached;

  @override
  Future<TemplateDiscovery> fetch() {
    if (!fetchStarted.isCompleted) {
      fetchStarted.complete();
    }
    return _fetchResult.future;
  }

  void completeFetch(TemplateDiscovery discovery) {
    _fetchResult.complete(discovery);
  }

  void failFetch(Object error) {
    _fetchResult.completeError(error);
  }

  @override
  void cancelPendingRequest() {
    cancelCalls++;
    if (!_fetchResult.isCompleted) {
      _fetchResult.completeError(const RequestCancelledException());
    }
  }
}

final class _RetryDiscoveryRepository implements TemplateDiscoveryRepository {
  final Completer<void> firstFetchStarted = Completer<void>();
  final Completer<void> secondFetchStarted = Completer<void>();
  final Completer<TemplateDiscovery> _firstFetch =
      Completer<TemplateDiscovery>();
  final Completer<TemplateDiscovery> _secondFetch =
      Completer<TemplateDiscovery>();
  int fetchCalls = 0;

  @override
  Future<TemplateDiscovery?> readCached() async => null;

  @override
  Future<TemplateDiscovery> fetch() {
    fetchCalls++;
    if (fetchCalls == 1) {
      firstFetchStarted.complete();
      return _firstFetch.future;
    }
    secondFetchStarted.complete();
    return _secondFetch.future;
  }

  void failFirstFetch(Object error) => _firstFetch.completeError(error);

  void completeSecondFetch(TemplateDiscovery discovery) {
    _secondFetch.complete(discovery);
  }

  @override
  void cancelPendingRequest() {}
}

final class _SequencedDiscoveryRepository
    implements TemplateDiscoveryRepository {
  _SequencedDiscoveryRepository(this.responses);

  final List<TemplateDiscovery> responses;
  int fetchCalls = 0;

  @override
  Future<TemplateDiscovery?> readCached() async => null;

  @override
  Future<TemplateDiscovery> fetch() async {
    final index = fetchCalls++;
    return responses[index];
  }

  @override
  void cancelPendingRequest() {}
}

final class _NetworkRaceDiscoveryRepository
    implements TemplateDiscoveryRepository {
  final Completer<void> firstFetchStarted = Completer<void>();
  final Completer<void> secondFetchStarted = Completer<void>();
  final Completer<TemplateDiscovery> _firstFetch =
      Completer<TemplateDiscovery>();
  final Completer<TemplateDiscovery> _secondFetch =
      Completer<TemplateDiscovery>();
  int fetchCalls = 0;
  int cancelCalls = 0;

  @override
  Future<TemplateDiscovery?> readCached() async => null;

  @override
  Future<TemplateDiscovery> fetch() {
    fetchCalls++;
    if (fetchCalls == 1) {
      firstFetchStarted.complete();
      return _firstFetch.future;
    }
    secondFetchStarted.complete();
    return _secondFetch.future;
  }

  void failFirstFetch(Object error) => _firstFetch.completeError(error);

  void completeSecondFetch(TemplateDiscovery discovery) {
    _secondFetch.complete(discovery);
  }

  @override
  void cancelPendingRequest() {
    cancelCalls++;
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for discovery controller state.');
}
