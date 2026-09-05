import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_realtime.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

void main() {
  late _Repository repository;
  late _Realtime realtime;
  late ProviderContainer container;
  late TemplateDiscoveryController controller;

  void initialize() {
    repository = _Repository();
    realtime = _Realtime();
    container = ProviderContainer(
      overrides: [
        templateDiscoveryRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(realtime),
      ],
    );
    controller = container.read(templateDiscoveryControllerProvider.notifier);
    container.listen(templateDiscoveryRealtimeProvider, (_, _) {});
  }

  tearDown(() async {
    container.dispose();
    expect(realtime.connectCalls, 1);
    expect(realtime.disconnectCalls, 1);
    await realtime.stream.close();
  });

  testWidgets(
    'offline launch restores the complete cached revision without HTTP',
    (tester) async {
      initialize();
      repository.cached = _discovery(42);
      controller.handleNetworkUnavailable();
      await controller.loadInitial();
      final state = container.read(templateDiscoveryControllerProvider);
      expect(repository.fetchCalls, 0);
      expect(state.loadedFromCache, isTrue);
      expect(state.revision, 42);
      expect(state.page?.title, 'Revision 42');
      expect(state.sections.single.displayTitle, 'Collection 42');
      controller.handleNetworkAvailable();
      await tester.pump();
      expect(repository.fetchCalls, 1);
      expect(
        container.read(templateDiscoveryControllerProvider).loadedFromCache,
        isFalse,
      );
    },
  );

  testWidgets('publication events coalesce and bypass the freshness TTL', (
    tester,
  ) async {
    initialize();
    await controller.loadInitial();
    expect(container.read(templateDiscoveryControllerProvider).revision, 1);
    realtime.publish();
    realtime.publish();
    realtime.publish();
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.fetchCalls, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.fetchCalls, 2);
    expect(container.read(templateDiscoveryControllerProvider).revision, 2);
  });

  testWidgets('hidden screen remembers publication without issuing HTTP', (
    tester,
  ) async {
    initialize();
    await controller.loadInitial();
    controller.setScreenVisible(false);
    realtime.publish();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.fetchCalls, 1);
    controller.setScreenVisible(true);
    await tester.pump();
    expect(repository.fetchCalls, 2);
  });

  testWidgets('offline screen defers publication until reconnect', (
    tester,
  ) async {
    initialize();
    await controller.loadInitial();
    controller.handleNetworkUnavailable();
    realtime.publish();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.fetchCalls, 1);
    controller.handleNetworkAvailable();
    await tester.pump();
    expect(repository.fetchCalls, 2);
  });

  for (final localeChange in [false, true]) {
    testWidgets(
      'stale response cannot undo ${localeChange ? 'locale reset' : 'publication'}',
      (tester) async {
        initialize();
        final stale = Completer<TemplateDiscovery>();
        repository.pending = stale;
        final oldLoad = controller.loadInitial(forceRefresh: true);
        expect(repository.fetchCalls, 1);
        repository.pending = null;
        if (localeChange) {
          controller.resetForLocale();
        } else {
          realtime.publish();
        }
        await tester.pump(const Duration(milliseconds: 350));
        expect(repository.fetchCalls, 2);
        expect(repository.cancelCalls, 1);
        stale.complete(_discovery(1));
        await oldLoad;
        final state = container.read(templateDiscoveryControllerProvider);
        expect(state.revision, 2);
        expect(state.page?.title, 'Revision 2');
        expect(state.sections.single.displayTitle, 'Collection 2');
      },
    );
  }

  testWidgets('unrelated or malformed events do not refresh discovery', (
    tester,
  ) async {
    initialize();
    await controller.loadInitial();
    realtime.stream.add(const RealtimeEvent(topic: 'other'));
    realtime.stream.add(
      const RealtimeEvent(
        topic: RealtimeTopics.templatesFeedInvalidated,
        payload: {'scope': 42},
      ),
    );
    realtime.stream.add(
      const RealtimeEvent(
        topic: RealtimeTopics.templatesFeedInvalidated,
        payload: {'scope': 'templateOfTheDay'},
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(repository.fetchCalls, 1);
  });
}

TemplateDiscovery _discovery(int revision) => TemplateDiscovery(
  generatedAtUtc: DateTime.utc(2026, 9, 5),
  schemaVersion: 2,
  revision: revision,
  page: TemplateDiscoveryPageSettings(title: 'Revision $revision'),
  sections: [
    TemplateDiscoverySection(
      category: 'Funny',
      title: 'Collection $revision',
      items: const [],
    ),
  ],
);

class _Repository implements TemplateDiscoveryRepository {
  int fetchCalls = 0;
  int cancelCalls = 0;
  Completer<TemplateDiscovery>? pending;
  TemplateDiscovery? cached;

  @override
  Future<TemplateDiscovery?> readCached() async => cached;
  @override
  Future<TemplateDiscovery> fetch() {
    fetchCalls++;
    return pending?.future ?? Future.value(_discovery(fetchCalls));
  }

  @override
  void cancelPendingRequest() => cancelCalls++;
}

class _Realtime implements RealtimeClient {
  final stream = StreamController<RealtimeEvent>.broadcast(sync: true);
  int connectCalls = 0;
  int disconnectCalls = 0;
  @override
  Stream<RealtimeEvent> get events => stream.stream;
  @override
  Future<void> connect() async => connectCalls++;
  @override
  Future<void> disconnect() async => disconnectCalls++;

  void publish() => stream.add(
    const RealtimeEvent(
      topic: RealtimeTopics.templatesFeedInvalidated,
      payload: {
        'scope': 'full',
        'isCritical': true,
        'reason': 'discovery_published',
      },
    ),
  );
}
