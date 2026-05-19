import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';

void main() {
  test(
    'coalesces burst realtime invalidations into a single refresh',
    () async {
      final repository = _FakeTemplatesRepository();
      final realtimeClient = _FakeRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(templatesControllerProvider);

      realtimeClient.emitTemplatesFeedInvalidated();
      realtimeClient.emitTemplatesFeedInvalidated();
      realtimeClient.emitTemplatesFeedInvalidated();

      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(repository.fetchFeedCalls, 1);
      expect(repository.fetchCategoriesCalls, 1);
    },
  );

  test(
    'replays one deferred refresh after an in-flight realtime refresh',
    () async {
      final repository = _FakeTemplatesRepository(
        firstFetchCompleter: Completer<void>(),
      );
      final realtimeClient = _FakeRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(templatesControllerProvider);

      realtimeClient.emitTemplatesFeedInvalidated();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(repository.fetchFeedCalls, 1);

      realtimeClient.emitTemplatesFeedInvalidated();
      realtimeClient.emitTemplatesFeedInvalidated();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repository.fetchFeedCalls, 1);

      repository.completeFirstFetch();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(repository.fetchFeedCalls, 2);
      expect(repository.fetchCategoriesCalls, 2);
    },
  );
}

class _FakeTemplatesRepository implements TemplatesRepository {
  _FakeTemplatesRepository({this.firstFetchCompleter});

  final Completer<void>? firstFetchCompleter;
  int fetchFeedCalls = 0;
  int fetchCategoriesCalls = 0;

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return null;
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    fetchFeedCalls++;
    if (fetchFeedCalls == 1 && firstFetchCompleter != null) {
      await firstFetchCompleter!.future;
    }

    return const TemplatesFeedPage(items: [], hasMore: false);
  }

  @override
  Future<List<String>> fetchCategories() async {
    fetchCategoriesCalls++;
    return const ['Portrait'];
  }

  void completeFirstFetch() {
    if (firstFetchCompleter != null && !firstFetchCompleter!.isCompleted) {
      firstFetchCompleter!.complete();
    }
  }
}

class _FakeRealtimeClient implements RealtimeClient {
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await _controller.close();
  }

  void emitTemplatesFeedInvalidated() {
    _controller.add(
      const RealtimeEvent(topic: RealtimeTopics.templatesFeedInvalidated),
    );
  }
}
