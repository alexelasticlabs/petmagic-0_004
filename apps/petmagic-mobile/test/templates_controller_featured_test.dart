import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';

import 'templates_controller_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads template of the day without blocking feed state', () async {
    final today = DateTime.utc(2026, 6, 14);
    final repository = FakeTemplatesControllerRepository(
      templateOfTheDay: TemplateOfTheDayItem(
        templateId: 'featured-1',
        title: 'Featured pet',
        subtitle: 'Daily idea',
        badgeText: 'Template of the Day',
        templateType: TemplateType.image,
        isPremium: false,
        requiredPlan: 'free',
        date: today,
        source: 'auto',
      ),
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [templateFixture('featured-1', TemplateType.image)],
          hasMore: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(templatesControllerProvider.notifier)
        .loadInitial(forceRefresh: true);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(templatesControllerProvider);
    expect(state.items.map((item) => item.templateId), ['featured-1']);
    expect(state.templateOfTheDay?.templateId, 'featured-1');
    expect(state.templateOfTheDay?.source, 'auto');
    expect(state.isTemplateOfTheDayLoading, isFalse);
    expect(state.templateOfTheDayError, isNull);
    expect(repository.fetchTemplateOfTheDayCalls, 1);
  });

  test(
    'keeps template of the day visible when thumbnail warmup fails',
    () async {
      const featuredThumbnailUrl =
          'https://cdn.petmagic.test/featured-thumb.jpg';
      final today = DateTime.utc(2026, 6, 14);
      final warmedUrls = <String>[];
      final repository = FakeTemplatesControllerRepository(
        templateOfTheDay: TemplateOfTheDayItem(
          templateId: 'featured-warmup-failure',
          title: 'Featured pet',
          subtitle: 'Daily idea',
          badgeText: 'Template of the Day',
          templateType: TemplateType.image,
          thumbnailUrl: featuredThumbnailUrl,
          isPremium: false,
          requiredPlan: 'free',
          date: today,
          source: 'auto',
        ),
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('feed-1', TemplateType.image)],
            hasMore: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
          templateThumbnailWarmupProvider.overrideWithValue((
            url, {
            mediaVersion,
          }) async {
            warmedUrls.add(url);
            throw StateError('warmup failed');
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(templatesControllerProvider.notifier)
          .loadInitial(forceRefresh: true);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(templatesControllerProvider);
      expect(warmedUrls, [featuredThumbnailUrl]);
      expect(state.items.map((item) => item.templateId), ['feed-1']);
      expect(state.templateOfTheDay?.templateId, 'featured-warmup-failure');
      expect(state.isTemplateOfTheDayLoading, isFalse);
      expect(state.templateOfTheDayError, isNull);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'skips template of the day thumbnail warmup after screen hides',
    () async {
      const featuredThumbnailUrl =
          'https://cdn.petmagic.test/featured-thumb.jpg';
      final today = DateTime.utc(2026, 6, 14);
      final featuredCompleter = Completer<TemplateOfTheDayItem?>();
      final warmedUrls = <String>[];
      final repository = FakeTemplatesControllerRepository(
        templateOfTheDayCompleter: featuredCompleter,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('feed-1', TemplateType.image)],
            hasMore: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
          templateThumbnailWarmupProvider.overrideWithValue((
            url, {
            mediaVersion,
          }) async {
            warmedUrls.add(url);
          }),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(templatesControllerProvider.notifier);
      await controller.loadInitial(forceRefresh: true);
      controller.setScreenVisible(false);
      featuredCompleter.complete(
        TemplateOfTheDayItem(
          templateId: 'featured-hidden',
          title: 'Featured pet',
          subtitle: 'Daily idea',
          badgeText: 'Template of the Day',
          templateType: TemplateType.image,
          thumbnailUrl: featuredThumbnailUrl,
          isPremium: false,
          requiredPlan: 'free',
          date: today,
          source: 'auto',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(templatesControllerProvider);
      expect(state.templateOfTheDay, isNull);
      expect(state.isTemplateOfTheDayLoading, isFalse);
      expect(warmedUrls, isEmpty);
    },
  );

  test(
    'does not refetch template of the day on filter changes after it is loaded',
    () async {
      final today = DateTime.utc(2026, 6, 14);
      final repository = FakeTemplatesControllerRepository(
        templateOfTheDay: TemplateOfTheDayItem(
          templateId: 'featured-1',
          title: 'Featured pet',
          subtitle: 'Daily idea',
          badgeText: 'Template of the Day',
          templateType: TemplateType.image,
          isPremium: false,
          requiredPlan: 'free',
          date: today,
          source: 'auto',
        ),
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('image-1', TemplateType.image)],
            hasMore: false,
          ),
          const TemplatesQuery(
            type: TemplateType.video,
          ).cacheKey: TemplatesFeedPage(
            items: [templateFixture('video-1', TemplateType.video)],
            hasMore: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(templatesControllerProvider.notifier);
      await controller.loadInitial(forceRefresh: true);
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchTemplateOfTheDayCalls, 1);
      expect(
        container
            .read(templatesControllerProvider)
            .templateOfTheDay
            ?.templateId,
        'featured-1',
      );

      controller.setType(TemplateType.video);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var state = container.read(templatesControllerProvider);
      expect(state.query.type, TemplateType.video);
      expect(state.items.map((item) => item.templateId), ['video-1']);
      expect(repository.fetchTemplateOfTheDayCalls, 1);

      await controller.refresh();
      await Future<void>.delayed(Duration.zero);

      state = container.read(templatesControllerProvider);
      expect(state.query.type, TemplateType.video);
      expect(state.templateOfTheDay?.templateId, 'featured-1');
      expect(repository.fetchTemplateOfTheDayCalls, 2);
    },
  );

  test(
    'hides template of the day and keeps feed usable when feature load fails',
    () async {
      final repository = FakeTemplatesControllerRepository(
        throwOnTemplateOfTheDay: true,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('feed-1', TemplateType.image)],
            hasMore: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(templatesControllerProvider.notifier)
          .loadInitial(forceRefresh: true);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(templatesControllerProvider);
      expect(state.items.map((item) => item.templateId), ['feed-1']);
      expect(state.templateOfTheDay, isNull);
      expect(state.isTemplateOfTheDayLoading, isFalse);
      expect(
        state.templateOfTheDayError,
        'templates.template_of_the_day_load_failed',
      );
      expect(state.errorMessage, isNull);
      expect(repository.fetchTemplateOfTheDayCalls, 1);
    },
  );
}
