import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  testWidgets(
    'backend-backed 1000+ templates feed survives scroll filters and search',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final backend = _BackendStressAdapter(totalTemplates: 1005);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = _RemoteBackedTemplatesRepository(
        TemplatesRemoteDataSource(dio),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(_AuthenticatedLaunch.new),
            walletControllerProvider.overrideWith(_IdleWalletController.new),
            templatesRepositoryProvider.overrideWithValue(repository),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => _state(tester).items.length == 20,
        description: 'initial backend feed loads 20 items',
        debugState: () => _backendDebug(tester, backend),
      );
      final firstFrameCardCount = find.byType(TemplateCard).evaluate().length;
      expect(firstFrameCardCount, greaterThan(0));
      expect(firstFrameCardCount, lessThan(40));
      _recordBackendWorkflowData(
        binding,
        tester,
        backend,
        stage: 'first_page_loaded',
        firstFrameCardCount: firstFrameCardCount,
      );

      var afterScrollCardCount = 0;
      var afterSecondPageCount = 0;
      await binding.watchPerformance(() async {
        await _runBackendFeedWorkflow(tester, backend, binding);
        afterScrollCardCount = find.byType(TemplateCard).evaluate().length;
        afterSecondPageCount = _state(tester).items.length;
      }, reportKey: 'templates_feed_backend_filter_search');

      final state = _state(tester);
      expect(afterScrollCardCount, greaterThan(0));
      expect(afterScrollCardCount, lessThan(60));
      expect(afterSecondPageCount, 3);
      expect(state.query.type, TemplateType.video);
      expect(state.query.category, 'Search');
      expect(state.query.search, 'dog');
      expect(state.items.map((item) => item.templateId), [
        'dog-template-000',
        'dog-template-001',
        'dog-template-002',
      ]);
      expect(backend.cancelledSearches, contains('cat'));
      expect(
        backend.feedQueries.any((query) => query['cursor'] == 'cursor-20'),
        isTrue,
      );
      expect(
        backend.feedQueries.map((query) => query['page']).whereType<Object>(),
        isEmpty,
      );

      _recordBackendWorkflowData(
        binding,
        tester,
        backend,
        stage: 'completed',
        firstFrameCardCount: firstFrameCardCount,
        afterScrollCardCount: afterScrollCardCount,
      );

      late final Map<String, Object?> longSessionData;
      await binding.watchPerformance(() async {
        longSessionData = await _runBackendLongSessionWorkflow(tester, backend);
      }, reportKey: 'templates_feed_backend_long_session_perf');
      _recordBackendLongSessionData(binding, longSessionData);

      expect(longSessionData['cycles'], 12);
      expect(longSessionData['duplicate_adjacent_query_count'], 0);
      expect(longSessionData['page_query_count'], 0);
      expect(longSessionData['max_cache_query_key_count'], 6);
      expect(
        longSessionData['max_visible_card_count'],
        isA<int>().having((value) => value, 'value', lessThan(60)),
      );

      final longScrollMemoryData = await _runBackendLongScrollMemoryProfile(
        tester,
        backend,
      );
      _recordBackendLongScrollMemoryData(binding, longScrollMemoryData);

      final mixedData = longScrollMemoryData['mixed']! as Map<String, Object?>;
      final videoOnlyData =
          longScrollMemoryData['video_only']! as Map<String, Object?>;
      expect(mixedData['target_reached'], isTrue);
      expect(videoOnlyData['target_reached'], isTrue);
      expect(
        videoOnlyData['active_video_preview_average'],
        greaterThan(mixedData['active_video_preview_average'] as double),
      );

      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _runBackendFeedWorkflow(
  WidgetTester tester,
  _BackendStressAdapter backend,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  final scrollable = find.byType(CustomScrollView);
  for (var i = 0; i < 8; i++) {
    await tester.fling(scrollable, const Offset(0, -1400), 9000);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 120));

  final scrollView = tester.widget<CustomScrollView>(scrollable);
  final scrollController = scrollView.controller;
  expect(scrollController, isNotNull);
  scrollController!.jumpTo(scrollController.position.maxScrollExtent);
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        _state(tester).items.length >= 40 &&
        backend.feedQueries.any((query) => query['cursor'] == 'cursor-20'),
    description:
        'cursor loadMore fetches cursor-20 and loads at least 40 items',
    debugState: () => _backendDebug(tester, backend),
  );
  _recordBackendWorkflowData(
    binding,
    tester,
    backend,
    stage: 'cursor_page_loaded',
    afterScrollCardCount: find.byType(TemplateCard).evaluate().length,
  );

  scrollController.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 300));

  final context = tester.element(find.byType(TemplatesPage));
  final text = AppLocalizations.of(context);
  final videosFilter = find.text(text.videosFilter).first;
  await tester.ensureVisible(videosFilter);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(videosFilter);
  await tester.pump(const Duration(milliseconds: 80));
  await _pumpUntil(
    tester,
    () =>
        _state(tester).query.type == TemplateType.video &&
        _state(
          tester,
        ).items.any((item) => item.templateId == 'video-template-0000'),
    description: 'video filter loads backend video templates',
    debugState: () => _backendDebug(tester, backend),
  );
  _recordBackendWorkflowData(
    binding,
    tester,
    backend,
    stage: 'video_filter_loaded',
  );

  final searchCategory = find.text('Search').last;
  await tester.ensureVisible(searchCategory);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(searchCategory);
  await tester.pump(const Duration(milliseconds: 80));
  await _pumpUntil(
    tester,
    () =>
        _state(tester).query.category == 'Search' &&
        _state(
          tester,
        ).items.any((item) => item.templateId == 'search-video-template-0000'),
    description: 'Search category filter loads backend search video templates',
    debugState: () => _backendDebug(tester, backend),
  );
  _recordBackendWorkflowData(
    binding,
    tester,
    backend,
    stage: 'category_filter_loaded',
  );

  _templatesController(tester).setSearch('cat');
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        backend.startedSearches.contains('cat') &&
        _state(tester).query.search == 'cat' &&
        _state(tester).items.isEmpty,
    description: 'slow cat search starts and clears stale visible items',
    debugState: () => _backendDebug(tester, backend),
  );
  _recordBackendWorkflowData(
    binding,
    tester,
    backend,
    stage: 'cat_search_started',
  );

  _templatesController(tester).setSearch('dog');
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        _state(tester).query.search == 'dog' &&
        _state(
          tester,
        ).items.any((item) => item.templateId == 'dog-template-000'),
    description:
        'newer dog search cancels cat and renders latest backend result',
    debugState: () => _backendDebug(tester, backend),
  );
  _recordBackendWorkflowData(
    binding,
    tester,
    backend,
    stage: 'dog_search_loaded',
  );
}

Future<Map<String, Object?>> _runBackendLongSessionWorkflow(
  WidgetTester tester,
  _BackendStressAdapter backend,
) async {
  final scrollView = tester.widget<CustomScrollView>(
    find.byType(CustomScrollView),
  );
  final scrollController = scrollView.controller;
  expect(scrollController, isNotNull);

  final requestStartIndex = backend.feedQueries.length;
  var maxLoadedItemCount = 0;
  var maxVisibleCardCount = 0;
  var maxCacheQueryKeyCount = 0;
  var maxDuplicateItemCount = 0;
  final mixedActiveVideoPreviewSamples = <int>[];
  final videoOnlyActiveVideoPreviewSamples = <int>[];

  for (var cycle = 0; cycle < 12; cycle++) {
    final type = switch (cycle % 3) {
      0 => null,
      1 => TemplateType.video,
      _ => TemplateType.image,
    };
    final category = cycle.isEven ? null : 'Search';
    final search = 'loop$cycle';
    final expectedPrefix = _expectedLongSessionPrefix(
      type: type,
      category: category,
      search: search,
    );

    final controller = _templatesController(tester);
    controller.setSearch('');
    controller.setCategory(category);
    controller.setType(type);
    controller.setSearch(search);
    await tester.pump();

    await _pumpUntil(
      tester,
      () => _stateMatchesLongSessionQuery(
        tester,
        type: type,
        category: category,
        search: search,
        expectedPrefix: expectedPrefix,
        expectedItemCount: 20,
      ),
      description: 'long-session cycle $cycle loads first backend page',
      debugState: () => _backendDebug(tester, backend),
      maxPumps: 250,
    );
    await _settlePlaybackBudget(tester);
    await _activateVisibleTemplateCards(tester);
    _recordLongSessionExtremes(
      tester,
      onLoaded: (value) => maxLoadedItemCount = value > maxLoadedItemCount
          ? value
          : maxLoadedItemCount,
      onVisible: (value) => maxVisibleCardCount = value > maxVisibleCardCount
          ? value
          : maxVisibleCardCount,
      onCache: (value) => maxCacheQueryKeyCount = value > maxCacheQueryKeyCount
          ? value
          : maxCacheQueryKeyCount,
      onDuplicates: (value) => maxDuplicateItemCount =
          value > maxDuplicateItemCount ? value : maxDuplicateItemCount,
    );
    _recordActiveVideoPreviewSample(
      type,
      mixedActiveVideoPreviewSamples,
      videoOnlyActiveVideoPreviewSamples,
    );

    scrollController!.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();
    await _pumpUntil(
      tester,
      () => _stateMatchesLongSessionQuery(
        tester,
        type: type,
        category: category,
        search: search,
        expectedPrefix: expectedPrefix,
        expectedItemCount: 40,
      ),
      description: 'long-session cycle $cycle loads cursor page',
      debugState: () => _backendDebug(tester, backend),
      maxPumps: 250,
    );
    await _settlePlaybackBudget(tester);
    await _activateVisibleTemplateCards(tester);
    _recordLongSessionExtremes(
      tester,
      onLoaded: (value) => maxLoadedItemCount = value > maxLoadedItemCount
          ? value
          : maxLoadedItemCount,
      onVisible: (value) => maxVisibleCardCount = value > maxVisibleCardCount
          ? value
          : maxVisibleCardCount,
      onCache: (value) => maxCacheQueryKeyCount = value > maxCacheQueryKeyCount
          ? value
          : maxCacheQueryKeyCount,
      onDuplicates: (value) => maxDuplicateItemCount =
          value > maxDuplicateItemCount ? value : maxDuplicateItemCount,
    );
    _recordActiveVideoPreviewSample(
      type,
      mixedActiveVideoPreviewSamples,
      videoOnlyActiveVideoPreviewSamples,
    );

    scrollController.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 20));
  }

  final newQueries = backend.feedQueries.skip(requestStartIndex).toList();
  final state = _state(tester);
  return {
    'stage': 'completed',
    'cycles': 12,
    'request_count_delta': newQueries.length,
    'feed_request_count': backend.feedQueries.length,
    'duplicate_adjacent_query_count': _duplicateAdjacentQueryCount(newQueries),
    'page_query_count': newQueries
        .where((query) => query['page'] != null)
        .length,
    'cursor_query_count': newQueries
        .where((query) => query['cursor'] != null)
        .length,
    'search_query_count': newQueries
        .where((query) => query['search'] != null)
        .length,
    'max_loaded_item_count': maxLoadedItemCount,
    'max_visible_card_count': maxVisibleCardCount,
    'max_cache_query_key_count': maxCacheQueryKeyCount,
    'max_duplicate_item_count': maxDuplicateItemCount,
    'final_cache_query_key_count': state.cachedPagesByQueryKey.length,
    'final_loaded_item_count': state.items.length,
    'final_visible_card_count': _visibleCardCount(),
    'mixed_active_video_preview_average': _average(
      mixedActiveVideoPreviewSamples,
    ),
    'mixed_active_video_preview_max': mixedActiveVideoPreviewSamples.isEmpty
        ? 0
        : mixedActiveVideoPreviewSamples.reduce((a, b) => a > b ? a : b),
    'mixed_active_video_preview_samples': mixedActiveVideoPreviewSamples,
    'video_only_active_video_preview_average': _average(
      videoOnlyActiveVideoPreviewSamples,
    ),
    'video_only_active_video_preview_max':
        videoOnlyActiveVideoPreviewSamples.isEmpty
        ? 0
        : videoOnlyActiveVideoPreviewSamples.reduce((a, b) => a > b ? a : b),
    'video_only_active_video_preview_samples':
        videoOnlyActiveVideoPreviewSamples,
    'final_query': {
      'type': state.query.type?.apiValue,
      'category': state.query.category,
      'search': state.query.search,
    },
  };
}

Future<Map<String, Object?>> _runBackendLongScrollMemoryProfile(
  WidgetTester tester,
  _BackendStressAdapter backend,
) async {
  final mixed = await _runLongScrollMode(tester, backend, type: null);
  final videoOnly = await _runLongScrollMode(
    tester,
    backend,
    type: TemplateType.video,
  );

  return {
    'stage': 'completed',
    'target_item_count': 520,
    'mixed': mixed,
    'video_only': videoOnly,
  };
}

Future<Map<String, Object?>> _runLongScrollMode(
  WidgetTester tester,
  _BackendStressAdapter backend, {
  required TemplateType? type,
}) async {
  const targetItemCount = 520;
  final label = type == TemplateType.video ? 'video_only' : 'mixed';
  final requestStartIndex = backend.feedQueries.length;
  final controller = _templatesController(tester);
  controller.setSearch('');
  await tester.pump();
  controller.setCategory(null);
  await tester.pump();
  controller.setType(type);
  await tester.pump();

  final expectedPrefix = _expectedLongScrollPrefix(type: type);
  await _pumpUntil(
    tester,
    () => _stateMatchesLongScrollQuery(
      tester,
      type: type,
      expectedPrefix: expectedPrefix,
      minimumItemCount: 20,
    ),
    description: '$label long-scroll first page loads',
    debugState: () => _backendDebug(tester, backend),
    maxPumps: 300,
  );

  final loadedItemSamples = <int>[];
  final activeVideoPreviewSamples = <int>[];
  var maxVisibleCardCount = 0;
  var maxDuplicateItemCount = 0;

  await _sampleLongScrollState(
    tester,
    activeVideoPreviewSamples,
    loadedItemSamples,
    onVisible: (value) => maxVisibleCardCount = value > maxVisibleCardCount
        ? value
        : maxVisibleCardCount,
    onDuplicates: (value) => maxDuplicateItemCount =
        value > maxDuplicateItemCount ? value : maxDuplicateItemCount,
  );

  while (_state(tester).items.length < targetItemCount &&
      _state(tester).hasMore) {
    final beforeCount = _state(tester).items.length;
    await controller.loadMore();
    await _pumpUntil(
      tester,
      () =>
          _state(tester).items.length > beforeCount || !_state(tester).hasMore,
      description: '$label long-scroll cursor advances past $beforeCount',
      debugState: () => _backendDebug(tester, backend),
      maxPumps: 300,
    );

    final loadedCount = _state(tester).items.length;
    if (loadedCount % 100 == 0 || loadedCount >= targetItemCount) {
      await tester.pump(const Duration(seconds: 2));
    }
    await _sampleLongScrollState(
      tester,
      activeVideoPreviewSamples,
      loadedItemSamples,
      onVisible: (value) => maxVisibleCardCount = value > maxVisibleCardCount
          ? value
          : maxVisibleCardCount,
      onDuplicates: (value) => maxDuplicateItemCount =
          value > maxDuplicateItemCount ? value : maxDuplicateItemCount,
    );
  }

  await tester.pump(const Duration(seconds: 12));
  await _sampleLongScrollState(
    tester,
    activeVideoPreviewSamples,
    loadedItemSamples,
    onVisible: (value) => maxVisibleCardCount = value > maxVisibleCardCount
        ? value
        : maxVisibleCardCount,
    onDuplicates: (value) => maxDuplicateItemCount =
        value > maxDuplicateItemCount ? value : maxDuplicateItemCount,
  );

  final newQueries = backend.feedQueries.skip(requestStartIndex).toList();
  final state = _state(tester);
  return {
    'label': label,
    'type': type?.apiValue,
    'loaded_item_count': state.items.length,
    'target_reached': state.items.length >= targetItemCount,
    'has_more': state.hasMore,
    'request_count_delta': newQueries.length,
    'cursor_query_count': newQueries
        .where((query) => query['cursor'] != null)
        .length,
    'duplicate_adjacent_query_count': _duplicateAdjacentQueryCount(newQueries),
    'max_visible_card_count': maxVisibleCardCount,
    'max_duplicate_item_count': maxDuplicateItemCount,
    'active_video_preview_average': _average(activeVideoPreviewSamples),
    'active_video_preview_max': activeVideoPreviewSamples.isEmpty
        ? 0
        : activeVideoPreviewSamples.reduce((a, b) => a > b ? a : b),
    'active_video_preview_samples': activeVideoPreviewSamples,
    'loaded_item_samples': loadedItemSamples,
  };
}

Future<void> _sampleLongScrollState(
  WidgetTester tester,
  List<int> activeVideoPreviewSamples,
  List<int> loadedItemSamples, {
  required ValueChanged<int> onVisible,
  required ValueChanged<int> onDuplicates,
}) async {
  await _settlePlaybackBudget(tester);
  await _activateVisibleTemplateCards(tester);
  activeVideoPreviewSamples.add(MediaLifecyclePolicy.activeVideoPreviews);
  final state = _state(tester);
  loadedItemSamples.add(state.items.length);
  onVisible(_visibleCardCount());
  onDuplicates(_duplicateTemplateIdCount(state));
}

Future<void> _settlePlaybackBudget(WidgetTester tester) async {
  final manager = ProviderScope.containerOf(
    tester.element(find.byType(TemplatesPage)),
  ).read(templateFeedPlaybackManagerProvider);
  manager.updateScrollVelocity(0);
  await tester.pump(const Duration(milliseconds: 120));
}

void _recordActiveVideoPreviewSample(
  TemplateType? type,
  List<int> mixedActiveVideoPreviewSamples,
  List<int> videoOnlyActiveVideoPreviewSamples,
) {
  final active = MediaLifecyclePolicy.activeVideoPreviews;
  if (type == null) {
    mixedActiveVideoPreviewSamples.add(active);
  } else if (type == TemplateType.video) {
    videoOnlyActiveVideoPreviewSamples.add(active);
  }
}

double _average(List<int> values) {
  if (values.isEmpty) {
    return 0;
  }

  return values.reduce((a, b) => a + b) / values.length;
}

TemplatesState _state(WidgetTester tester) {
  final context = tester.element(find.byType(TemplatesPage));
  return ProviderScope.containerOf(context).read(templatesControllerProvider);
}

TemplatesController _templatesController(WidgetTester tester) {
  final context = tester.element(find.byType(TemplatesPage));
  return ProviderScope.containerOf(
    context,
  ).read(templatesControllerProvider.notifier);
}

void _recordBackendWorkflowData(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  _BackendStressAdapter backend, {
  required String stage,
  int? firstFrameCardCount,
  int? afterScrollCardCount,
}) {
  final hasPage = find.byType(TemplatesPage).evaluate().isNotEmpty;
  final state = hasPage ? _state(tester) : const TemplatesState();
  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['templates_feed_backend_workflow'] = {
    'stage': stage,
    ...?firstFrameCardCount == null
        ? null
        : {'first_frame_card_count': firstFrameCardCount},
    ...?afterScrollCardCount == null
        ? null
        : {'after_scroll_card_count': afterScrollCardCount},
    'visible_card_count': find.byType(TemplateCard).evaluate().length,
    'loaded_item_count': state.items.length,
    'query_type': state.query.type?.apiValue,
    'query_category': state.query.category,
    'query_search': state.query.search,
    'next_cursor': state.nextCursor,
    'has_more': state.hasMore,
    'is_loading': state.isLoading,
    'is_refreshing': state.isRefreshing,
    'is_loading_more': state.isLoadingMore,
    'feed_request_count': backend.feedQueries.length,
    'used_cursor_page': backend.feedQueries.any(
      (query) => query['cursor'] == 'cursor-20',
    ),
    'page_query_count': backend.feedQueries
        .where((query) => query['page'] != null)
        .length,
    'search_requests': backend.feedQueries
        .where((query) => query['search'] != null)
        .map((query) => query['search'])
        .toList(growable: false),
    'cancelled_searches': backend.cancelledSearches,
    'last_query': backend.feedQueries.isEmpty
        ? null
        : Map<String, Object?>.from(backend.feedQueries.last),
    'final_item_ids': state.items
        .map((item) => item.templateId)
        .toList(growable: false),
  };
}

void _recordBackendLongSessionData(
  IntegrationTestWidgetsFlutterBinding binding,
  Map<String, Object?> data,
) {
  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['templates_feed_backend_long_session'] = data;
}

void _recordBackendLongScrollMemoryData(
  IntegrationTestWidgetsFlutterBinding binding,
  Map<String, Object?> data,
) {
  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['templates_feed_backend_long_scroll_memory_profile'] =
      data;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  String Function()? debugState,
  Duration step = const Duration(milliseconds: 20),
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (condition()) {
      return;
    }
    await tester.pump(step);
  }

  final details = debugState == null ? '' : '\n${debugState()}';
  fail('Timed out waiting for condition: $description$details');
}

Future<void> _activateVisibleTemplateCards(WidgetTester tester) async {
  final templateDetectors = tester
      .widgetList<VisibilityDetector>(find.byType(VisibilityDetector))
      .where((detector) => detector.key.toString().contains('template-card-'))
      .toList(growable: false);

  expect(templateDetectors, isNotEmpty);
  var invokedCallbacks = 0;
  for (final detector in templateDetectors) {
    final callback = detector.onVisibilityChanged;
    if (callback == null) {
      continue;
    }

    invokedCallbacks += 1;
    callback(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(180, 250),
        visibleBounds: const Rect.fromLTWH(0, 0, 180, 250),
      ),
    );
  }
  expect(invokedCallbacks, greaterThan(0));
  await tester.pump();
}

String _backendDebug(WidgetTester tester, _BackendStressAdapter backend) {
  final hasPage = find.byType(TemplatesPage).evaluate().isNotEmpty;
  final state = hasPage ? _state(tester) : const TemplatesState();
  final lastQuery = backend.feedQueries.isEmpty
      ? null
      : backend.feedQueries.last;
  return [
    'items=${state.items.length}',
    'query(type=${state.query.type?.apiValue}, category=${state.query.category}, search=${state.query.search})',
    'nextCursor=${state.nextCursor}',
    'hasMore=${state.hasMore}',
    'loading=${state.isLoading}',
    'refreshing=${state.isRefreshing}',
    'loadingMore=${state.isLoadingMore}',
    'requests=${backend.feedQueries.length}',
    'lastQuery=$lastQuery',
    'startedSearches=${backend.startedSearches}',
    'cancelledSearches=${backend.cancelledSearches}',
    'visibleCards=${find.byType(TemplateCard).evaluate().length}',
  ].join('; ');
}

void _recordLongSessionExtremes(
  WidgetTester tester, {
  required ValueChanged<int> onLoaded,
  required ValueChanged<int> onVisible,
  required ValueChanged<int> onCache,
  required ValueChanged<int> onDuplicates,
}) {
  final state = _state(tester);
  onLoaded(state.items.length);
  onVisible(_visibleCardCount());
  onCache(state.cachedPagesByQueryKey.length);
  onDuplicates(_duplicateTemplateIdCount(state));
}

bool _stateMatchesLongSessionQuery(
  WidgetTester tester, {
  required TemplateType? type,
  required String? category,
  required String search,
  required String expectedPrefix,
  required int expectedItemCount,
}) {
  final state = _state(tester);
  return state.query.type == type &&
      state.query.category == category &&
      state.query.search == search &&
      state.items.length == expectedItemCount &&
      state.items.every((item) => item.templateId.startsWith(expectedPrefix)) &&
      _duplicateTemplateIdCount(state) == 0 &&
      !state.isLoading &&
      !state.isRefreshing &&
      !state.isLoadingMore &&
      state.errorMessage == null;
}

bool _stateMatchesLongScrollQuery(
  WidgetTester tester, {
  required TemplateType? type,
  required String expectedPrefix,
  required int minimumItemCount,
}) {
  final state = _state(tester);
  return state.query.type == type &&
      state.query.category == null &&
      state.query.search == null &&
      state.items.length >= minimumItemCount &&
      state.items.every((item) => item.templateId.startsWith(expectedPrefix)) &&
      _duplicateTemplateIdCount(state) == 0 &&
      !state.isLoading &&
      !state.isRefreshing &&
      !state.isLoadingMore &&
      state.errorMessage == null;
}

int _visibleCardCount() => find.byType(TemplateCard).evaluate().length;

int _duplicateTemplateIdCount(TemplatesState state) {
  final ids = state.items.map((item) => item.templateId).toList();
  return ids.length - ids.toSet().length;
}

String _expectedLongSessionPrefix({
  required TemplateType? type,
  required String? category,
  required String search,
}) {
  final basePrefix = category == 'Search'
      ? type == TemplateType.video
            ? 'search-video-template'
            : type == TemplateType.image
            ? 'search-image-template'
            : 'search-template'
      : type == TemplateType.video
      ? 'video-template'
      : type == TemplateType.image
      ? 'image-template'
      : 'template';
  return '${search.toLowerCase()}-$basePrefix-';
}

String _expectedLongScrollPrefix({required TemplateType? type}) {
  final basePrefix = type == TemplateType.video
      ? 'video-template'
      : type == TemplateType.image
      ? 'image-template'
      : 'template';
  return '$basePrefix-';
}

int _duplicateAdjacentQueryCount(List<Map<String, Object?>> queries) {
  var duplicates = 0;
  String? previous;
  for (final query in queries) {
    final current = _querySignature(query);
    if (current == previous) {
      duplicates += 1;
    }
    previous = current;
  }
  return duplicates;
}

String _querySignature(Map<String, Object?> query) {
  final entries = query.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return jsonEncode({for (final entry in entries) entry.key: entry.value});
}

class _AuthenticatedLaunch extends AppLaunchController {
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

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _RemoteBackedTemplatesRepository implements TemplatesRepository {
  const _RemoteBackedTemplatesRepository(this._dataSource);

  final TemplatesRemoteDataSource _dataSource;

  @override
  void cancelPendingFeedRequest() {}

  @override
  void cancelPendingRandomTemplateRequest() {
    _dataSource.cancelPendingRandomTemplateRequest();
  }

  @override
  void cancelPendingMetadataRequests() {
    _dataSource.cancelPendingMetadataRequests();
  }

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return null;
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    return (await _dataSource.fetchFeed(query)).toDomain();
  }

  @override
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
    String? analyticsSource,
  }) async {
    return (await _dataSource.fetchTemplate(templateId)).toDomain();
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    return (await _dataSource.fetchRandomTemplate(
      mode: mode,
      category: category,
      includePremium: includePremium,
      access: access,
    )).toDomain();
  }

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async {
    return const [];
  }

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async {
    return null;
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) async {}

  @override
  Future<List<String>> fetchCategories() async {
    return const ['Portrait', 'Search'];
  }

  @override
  Future<int> readLocalCatalogVersion() async {
    return 0;
  }

  @override
  Future<int> fetchCatalogVersion() async {
    return 1;
  }

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    return TemplatesCatalogChanges(
      fromVersion: sinceVersion,
      toVersion: 1,
      upserts: const [],
      deletedIds: const [],
      needsFullResync: false,
    );
  }

  @override
  Future<int> syncCatalog({int? knownRemoteVersion}) async {
    return knownRemoteVersion ?? 1;
  }
}

class _BackendStressAdapter implements HttpClientAdapter {
  _BackendStressAdapter({required this.totalTemplates});

  final int totalTemplates;
  final List<Map<String, Object?>> feedQueries = [];
  final List<String> startedSearches = [];
  final List<String> cancelledSearches = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path != '/api/templates/feed') {
      return _jsonResponse({'template': null});
    }

    final query = Map<String, Object?>.from(options.queryParameters);
    feedQueries.add(query);
    final search = query['search'] as String?;
    if (search != null) {
      startedSearches.add(search);
    }

    if (search == 'cat') {
      await (cancelFuture ?? Completer<void>().future);
      cancelledSearches.add(search!);
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'superseded slow search',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 30));

    if (search == 'dog') {
      return _jsonResponse({
        'items': List<Map<String, Object?>>.generate(
          3,
          (index) =>
              _templateJson('dog-template-${index.toString().padLeft(3, '0')}'),
        ),
        'nextCursor': null,
        'hasMore': false,
        'page': 1,
      });
    }

    final type = query['type'] as String?;
    final category = query['category'] as String?;
    final isVideo = type == 'Video';
    final isImage = type == 'Image';
    final basePrefix = category == 'Search'
        ? isVideo
              ? 'search-video-template'
              : isImage
              ? 'search-image-template'
              : 'search-template'
        : isVideo
        ? 'video-template'
        : isImage
        ? 'image-template'
        : 'template';
    final idPrefix = search == null
        ? basePrefix
        : '${search.toLowerCase()}-$basePrefix';
    final take = (query['take'] as int?) ?? 20;
    final cursor = query['cursor'] as String?;
    final start = cursor == null
        ? 0
        : int.tryParse(cursor.replaceFirst('cursor-', '')) ?? 0;
    final end = (start + take).clamp(0, totalTemplates);
    final nextCursor = end < totalTemplates ? 'cursor-$end' : null;

    return _jsonResponse({
      'items': List<Map<String, Object?>>.generate(end - start, (index) {
        final itemIndex = start + index;
        final itemTemplateType = isVideo
            ? 'Video'
            : isImage
            ? 'Image'
            : itemIndex.isEven
            ? 'Video'
            : 'Image';
        return _templateJson(
          '$idPrefix-${itemIndex.toString().padLeft(4, '0')}',
          templateType: itemTemplateType,
          category: category ?? 'Portrait',
        );
      }),
      'nextCursor': nextCursor,
      'hasMore': nextCursor != null,
      'page': (start ~/ take) + 1,
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, Object?> json) {
  return ResponseBody.fromString(
    jsonEncode(json),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, Object?> _templateJson(
  String templateId, {
  String templateType = 'Image',
  String category = 'Portrait',
}) {
  final isVideo = templateType == 'Video';
  final mediaUrl = isVideo
      ? 'https://cdn.petmagic.ai/media/template-video-preview.mp4'
      : 'https://cdn.petmagic.ai/media/template-preview.png';
  return {
    'templateId': templateId,
    'templateType': templateType,
    'title': templateId,
    'shortDescription': templateId,
    'category': category,
    'tags': ['pet', 'portrait'],
    'isPremium': false,
    'tokenCost': 1,
    'thumbnailUrl': 'https://cdn.petmagic.ai/media/template-thumb.png',
    'mediaKind': isVideo ? 'video' : 'image',
    'durationMs': isVideo ? 4500 : null,
    'sizeBytes': isVideo ? 384000 : 48000,
    'mediaVersion': 1,
    'media': {
      'thumbnailUrl': 'https://cdn.petmagic.ai/media/template-thumb.png',
      'animatedPreviewUrl': isVideo
          ? 'https://cdn.petmagic.ai/media/template-preview.gif'
          : null,
      'feedLoopLowUrl': isVideo ? mediaUrl : null,
      'feedLoopMediumUrl': isVideo ? mediaUrl : null,
      'mediaKind': isVideo ? 'video' : 'image',
      'durationMs': isVideo ? 4500 : null,
      'sizeBytes': isVideo ? 384000 : 48000,
      'mediaVersion': 1,
    },
    'previewAsset': {
      'url': mediaUrl,
      'fileName': isVideo
          ? 'template-video-preview.mp4'
          : 'template-preview.png',
      'contentType': isVideo ? 'video/mp4' : 'image/png',
      'fileSizeBytes': isVideo ? 384000 : 48000,
      'durationSeconds': isVideo ? 4.5 : null,
    },
  };
}
