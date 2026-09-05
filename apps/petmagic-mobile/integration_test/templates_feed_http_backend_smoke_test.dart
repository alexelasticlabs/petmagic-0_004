import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

final List<int> _validTemplatePreviewMp4Bytes = base64Decode(
  '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'
  '4PT+qi/g',
);

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
    'template feed uses real HTTP pagination filters and stale search guards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final backend = _HttpTemplatesBackend(totalTemplates: 1005);
      await backend.start();
      await TemplateMediaCache.clearAll();
      addTearDown(() async {
        await TemplateMediaCache.clearAll();
        await backend.close();
      });

      final dio = Dio(
        BaseOptions(
          baseUrl: backend.baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      addTearDown(() => dio.close(force: true));

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
        description: 'initial real HTTP feed loads first cursor page',
        debugState: () => _backendDebug(tester, backend),
      );
      final firstFrameCardCount = find.byType(TemplateCard).evaluate().length;
      expect(firstFrameCardCount, greaterThan(0));
      expect(firstFrameCardCount, lessThan(40));
      expect(backend.feedQueries.first['take'], '20');
      expect(backend.feedQueries.first.containsKey('page'), isFalse);
      await _pumpUntil(
        tester,
        () =>
            backend.mediaRequestCountsByPath['/media/template-thumb.png'] == 1,
        description: 'first visible cards request shared thumbnail once',
        debugState: () => _backendDebug(tester, backend),
      );

      _recordHttpWorkflowData(
        binding,
        tester,
        backend,
        stage: 'first_page_loaded',
        firstFrameCardCount: firstFrameCardCount,
      );

      late final int afterWorkflowCardCount;
      await binding.watchPerformance(() async {
        await _runHttpBackendWorkflow(tester, backend);
        afterWorkflowCardCount = find.byType(TemplateCard).evaluate().length;
      }, reportKey: 'templates_feed_http_backend_perf');

      final state = _state(tester);
      expect(afterWorkflowCardCount, greaterThan(0));
      expect(afterWorkflowCardCount, lessThan(60));
      expect(state.query.type, TemplateType.video);
      expect(state.query.category, 'Search');
      expect(state.query.search, 'dog');
      expect(state.items.map((item) => item.templateId), [
        'dog-template-000',
        'dog-template-001',
        'dog-template-002',
      ]);
      expect(backend.startedSearches, containsAll(['cat', 'dog']));
      expect(
        backend.feedQueries.any((query) => query['cursor'] == 'cursor-20'),
        isTrue,
      );
      expect(
        backend.feedQueries.where((query) => query.containsKey('page')),
        isEmpty,
      );
      expect(backend.mediaRequestCountsByPath['/media/template-thumb.png'], 1);
      expect(_duplicateTemplateIdCount(state), 0);

      final randomAnyTemplate = await repository.fetchRandomTemplate(
        mode: TemplateRandomMode.any,
        category: state.query.category,
        includePremium: true,
      );
      expect(randomAnyTemplate, isNotNull);
      expect(randomAnyTemplate!.templateId, 'random-any-search-template');
      expect(randomAnyTemplate.category, 'Search');
      expect(
        state.items.map((item) => item.templateId),
        isNot(contains(randomAnyTemplate.templateId)),
      );

      final randomImageTemplate = await repository.fetchRandomTemplate(
        mode: TemplateRandomMode.image,
        category: state.query.category,
        includePremium: false,
      );
      expect(randomImageTemplate, isNotNull);
      expect(randomImageTemplate!.templateId, 'random-image-search-template');
      expect(randomImageTemplate.templateType, TemplateType.image);
      expect(randomImageTemplate.category, 'Search');
      expect(
        state.items.map((item) => item.templateId),
        isNot(contains(randomImageTemplate.templateId)),
      );

      final randomVideoTemplate = await repository.fetchRandomTemplate(
        mode: TemplateRandomMode.video,
        category: state.query.category,
        includePremium: false,
      );
      expect(randomVideoTemplate, isNotNull);
      expect(randomVideoTemplate!.templateId, 'random-video-search-template');
      expect(randomVideoTemplate.templateType, TemplateType.video);
      expect(randomVideoTemplate.category, 'Search');
      expect(
        state.items.map((item) => item.templateId),
        isNot(contains(randomVideoTemplate.templateId)),
      );
      expect(backend.randomQueries, hasLength(3));
      expect(backend.randomQueries[0].containsKey('type'), isFalse);
      expect(backend.randomQueries[0]['category'], 'Search');
      expect(backend.randomQueries[0]['includePremium'], 'true');
      expect(backend.randomQueries[1]['type'], 'Image');
      expect(backend.randomQueries[1]['category'], 'Search');
      expect(backend.randomQueries[1]['includePremium'], 'false');
      expect(backend.randomQueries[2]['type'], 'Video');
      expect(backend.randomQueries[2]['category'], 'Search');
      expect(backend.randomQueries[2]['includePremium'], 'false');
      expect(backend.randomTemplateIds, [
        'random-any-search-template',
        'random-image-search-template',
        'random-video-search-template',
      ]);
      expect(tester.takeException(), isNull);

      _recordHttpWorkflowData(
        binding,
        tester,
        backend,
        stage: 'completed',
        firstFrameCardCount: firstFrameCardCount,
        afterWorkflowCardCount: afterWorkflowCardCount,
      );
    },
  );
}

Future<void> _runHttpBackendWorkflow(
  WidgetTester tester,
  _HttpTemplatesBackend backend,
) async {
  final scrollable = find.byType(CustomScrollView);
  for (var i = 0; i < 5; i++) {
    await tester.fling(scrollable, const Offset(0, -1300), 8500);
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
    description: 'real HTTP cursor loadMore fetches cursor-20',
    debugState: () => _backendDebug(tester, backend),
  );

  scrollController.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 250));

  final controller = _templatesController(tester);
  controller.setType(TemplateType.video);
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        _state(tester).query.type == TemplateType.video &&
        _state(
          tester,
        ).items.any((item) => item.templateId == 'video-template-0000'),
    description: 'video filter loads through real HTTP',
    debugState: () => _backendDebug(tester, backend),
  );
  await _pumpUntil(
    tester,
    () => find.text('video-template-0000').evaluate().isNotEmpty,
    description: 'video template cards are rebuilt into the visible tree',
    debugState: () => _backendDebug(tester, backend),
  );
  await _activateVisibleTemplateCards(tester);
  await _pumpUntil(
    tester,
    () =>
        backend.mediaRequestCountsByPath['/media/template-video-preview.mp4'] ==
        1,
    description:
        'visible real HTTP video cards share one preview download after video filter',
    debugState: () => _backendDebug(tester, backend),
  );

  final feedQueryCountBeforeAllType = backend.feedQueries.length;
  controller.setType(null);
  await tester.pump();
  await _pumpUntil(
    tester,
    () {
      final state = _state(tester);
      return state.query.type == null &&
          state.loadedFromCache &&
          state.items.isNotEmpty &&
          state.items.every(
            (item) => item.templateId.startsWith('template-'),
          ) &&
          backend.feedQueries.length == feedQueryCountBeforeAllType;
    },
    description:
        'all type restores cached HTTP feed without stale video cards or extra request',
    debugState: () => _backendDebug(tester, backend),
  );

  final feedQueryCountBeforeImageType = backend.feedQueries.length;
  controller.setType(TemplateType.image);
  await tester.pump();
  await _pumpUntil(
    tester,
    () {
      final state = _state(tester);
      final imageQueryWasRequested =
          backend.feedQueries.length == feedQueryCountBeforeImageType + 1 &&
          backend.feedQueries.last['type'] == 'Image' &&
          backend.feedQueries.last['cursor'] == null &&
          backend.feedQueries.last['category'] == null &&
          backend.feedQueries.last['search'] == null;

      return state.query.type == TemplateType.image &&
          !state.loadedFromCache &&
          state.items.isNotEmpty &&
          state.items.every(
            (item) =>
                item.templateType == TemplateType.image &&
                item.templateId.startsWith('image-template-'),
          ) &&
          imageQueryWasRequested;
    },
    description:
        'image type reloads through real HTTP without stale video cards',
    debugState: () => _backendDebug(tester, backend),
  );

  final feedQueryCountBeforeVideoRestore = backend.feedQueries.length;
  controller.setType(TemplateType.video);
  await tester.pump();
  await _pumpUntil(
    tester,
    () {
      final state = _state(tester);
      return state.query.type == TemplateType.video &&
          state.loadedFromCache &&
          state.items.every(
            (item) => item.templateType == TemplateType.video,
          ) &&
          state.items.any((item) => item.templateId == 'video-template-0000') &&
          backend.feedQueries.length == feedQueryCountBeforeVideoRestore;
    },
    description:
        'video type restores cached HTTP feed after all and image transitions',
    debugState: () => _backendDebug(tester, backend),
  );

  controller.setCategory('Search');
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        _state(tester).query.category == 'Search' &&
        _state(
          tester,
        ).items.any((item) => item.templateId == 'search-video-template-0000'),
    description: 'category filter loads through real HTTP',
    debugState: () => _backendDebug(tester, backend),
  );
  await _pumpUntil(
    tester,
    () => find.text('search-video-template-0000').evaluate().isNotEmpty,
    description:
        'search category video template cards are rebuilt into the visible tree',
    debugState: () => _backendDebug(tester, backend),
  );
  await _activateVisibleTemplateCards(tester);
  await tester.pump(const Duration(milliseconds: 500));
  expect(
    backend.mediaRequestCountsByPath['/media/template-video-preview.mp4'],
    1,
  );

  controller.setSearch('cat');
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        backend.startedSearches.contains('cat') &&
        _state(tester).query.search == 'cat' &&
        _state(tester).items.isEmpty,
    description: 'slow cat search starts and clears stale items',
    debugState: () => _backendDebug(tester, backend),
  );

  controller.setSearch('dog');
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        _state(tester).query.search == 'dog' &&
        _state(
          tester,
        ).items.any((item) => item.templateId == 'dog-template-000'),
    description: 'newer dog search wins after slow cat request',
    debugState: () => _backendDebug(tester, backend),
  );

  await tester.pump(const Duration(milliseconds: 1000));
  await _pumpUntil(
    tester,
    () => find.text('dog-template-000').evaluate().isNotEmpty,
    description: 'dog search video template cards are visible',
    debugState: () => _backendDebug(tester, backend),
  );
  await _activateVisibleTemplateCards(tester);
  await tester.pump(const Duration(milliseconds: 500));
  final state = _state(tester);
  expect(state.query.search, 'dog');
  expect(
    state.items.map((item) => item.templateId),
    everyElement(startsWith('dog-template-')),
  );
  expect(
    backend.mediaRequestCountsByPath['/media/template-video-preview.mp4'],
    1,
  );
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

void _recordHttpWorkflowData(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  _HttpTemplatesBackend backend, {
  required String stage,
  int? firstFrameCardCount,
  int? afterWorkflowCardCount,
}) {
  final hasPage = find.byType(TemplatesPage).evaluate().isNotEmpty;
  final state = hasPage ? _state(tester) : const TemplatesState();
  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['templates_feed_http_backend_workflow'] = {
    'stage': stage,
    ...?firstFrameCardCount == null
        ? null
        : {'first_frame_card_count': firstFrameCardCount},
    ...?afterWorkflowCardCount == null
        ? null
        : {'after_workflow_card_count': afterWorkflowCardCount},
    'base_url': backend.baseUrl,
    'visible_card_count': find.byType(TemplateCard).evaluate().length,
    'loaded_item_count': state.items.length,
    'duplicate_item_count': _duplicateTemplateIdCount(state),
    'query_type': state.query.type?.apiValue,
    'query_category': state.query.category,
    'query_search': state.query.search,
    'next_cursor': state.nextCursor,
    'has_more': state.hasMore,
    'is_loading': state.isLoading,
    'is_refreshing': state.isRefreshing,
    'is_loading_more': state.isLoadingMore,
    'request_count': backend.feedQueries.length,
    'media_request_counts': backend.mediaRequestCountsByPath,
    'thumbnail_request_count':
        backend.mediaRequestCountsByPath['/media/template-thumb.png'] ?? 0,
    'video_preview_request_count':
        backend.mediaRequestCountsByPath['/media/template-video-preview.mp4'] ??
        0,
    'started_searches': backend.startedSearches,
    'completed_searches': backend.completedSearches,
    'used_cursor_page': backend.feedQueries.any(
      (query) => query['cursor'] == 'cursor-20',
    ),
    'page_query_count': backend.feedQueries
        .where((query) => query.containsKey('page'))
        .length,
    'cursor_query_count': backend.feedQueries
        .where((query) => query['cursor'] != null)
        .length,
    'random_request_count': backend.randomQueries.length,
    'random_queries': backend.randomQueries
        .map((query) => Map<String, Object?>.from(query))
        .toList(growable: false),
    'random_template_ids': backend.randomTemplateIds,
    'search_requests': backend.feedQueries
        .where((query) => query['search'] != null)
        .map((query) => query['search'])
        .toList(growable: false),
    'last_query': backend.feedQueries.isEmpty
        ? null
        : Map<String, Object?>.from(backend.feedQueries.last),
    'request_paths': backend.requestPaths,
    'final_item_ids': state.items
        .map((item) => item.templateId)
        .toList(growable: false),
  };
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

String _backendDebug(WidgetTester tester, _HttpTemplatesBackend backend) {
  final hasPage = find.byType(TemplatesPage).evaluate().isNotEmpty;
  final state = hasPage ? _state(tester) : const TemplatesState();
  final firstItem = state.items.isEmpty ? null : state.items.first;
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
    'completedSearches=${backend.completedSearches}',
    'mediaRequests=${backend.mediaRequestCountsByPath}',
    'visibleCards=${find.byType(TemplateCard).evaluate().length}',
    'visibilityDetectors=${find.byType(VisibilityDetector).evaluate().length}',
    'visibilityKeys=${_visibilityDetectorKeys()}',
    'activeVideoPreviews=${MediaLifecyclePolicy.activeVideoPreviews}',
    'firstItem=${firstItem?.templateId}',
    'firstItemType=${firstItem?.templateType.apiValue}',
    'firstItemPreviewContentType=${firstItem?.previewAsset?.contentType}',
    'firstItemPreviewUrl=${firstItem?.previewAsset?.url}',
  ].join('; ');
}

String _visibilityDetectorKeys() {
  return find
      .byType(VisibilityDetector)
      .evaluate()
      .map((element) => element.widget.key.toString())
      .take(8)
      .join('|');
}

int _duplicateTemplateIdCount(TemplatesState state) {
  final ids = state.items.map((item) => item.templateId).toList();
  return ids.length - ids.toSet().length;
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
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return null;
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    return (await _dataSource.fetchFeed(query)).toDomain();
  }

  @override
  void cancelPendingFeedRequest() {
    _dataSource.cancelPendingFeedRequest();
  }

  @override
  void cancelPendingRandomTemplateRequest() {
    _dataSource.cancelPendingRandomTemplateRequest();
  }

  @override
  void cancelPendingMetadataRequests() {
    _dataSource.cancelPendingMetadataRequests();
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

class _HttpTemplatesBackend {
  _HttpTemplatesBackend({required this.totalTemplates});

  final int totalTemplates;
  final List<Map<String, Object?>> feedQueries = [];
  final List<String> requestPaths = [];
  final Map<String, int> mediaRequestCountsByPath = <String, int>{};
  final List<String> startedSearches = [];
  final List<String> completedSearches = [];
  final List<Map<String, Object?>> randomQueries = [];
  final List<String> randomTemplateIds = [];
  late final HttpServer _server;

  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_serve());
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    requestPaths.add(request.uri.toString());
    try {
      switch (request.uri.path) {
        case '/api/templates/feed':
          await _handleFeed(request);
        case '/api/templates/random':
          await _handleRandom(request);
        case final path when path.startsWith('/media/'):
          await _handleMedia(request);
        case '/api/templates/categories':
          await _sendJson(request.response, [
            {'name': 'Portrait'},
            {'name': 'Search'},
          ]);
        case '/api/templates/catalog-version':
          await _sendJson(request.response, {'version': 1});
        case '/api/templates/template-of-the-day':
          await _sendJson(request.response, {'template': null});
        default:
          await _sendJson(request.response, {'template': null});
      }
    } on Object {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } on Object {
        // The client may already have cancelled the request.
      }
    }
  }

  Future<void> _handleMedia(HttpRequest request) async {
    final path = request.uri.path;
    mediaRequestCountsByPath[path] = (mediaRequestCountsByPath[path] ?? 0) + 1;
    if (path.endsWith('.mp4')) {
      await _sendBytes(
        request.response,
        _validTemplatePreviewMp4Bytes,
        contentType: ContentType('video', 'mp4'),
      );
      return;
    }

    await _sendBytes(
      request.response,
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
      ),
      contentType: ContentType('image', 'png'),
    );
  }

  Future<void> _handleFeed(HttpRequest request) async {
    final query = Map<String, Object?>.from(request.uri.queryParameters);
    feedQueries.add(query);

    final search = query['search'] as String?;
    if (search != null) {
      startedSearches.add(search);
    }

    await Future<void>.delayed(
      search == 'cat'
          ? const Duration(milliseconds: 850)
          : const Duration(milliseconds: 35),
    );

    if (search != null) {
      completedSearches.add(search);
    }

    final type = query['type'] as String?;
    final category = query['category'] as String?;
    final isVideo = type == 'Video';
    final isImage = type == 'Image';
    final templateType = isVideo ? 'Video' : 'Image';

    if (search == 'dog') {
      await _sendJson(request.response, {
        'items': List<Map<String, Object?>>.generate(
          3,
          (index) => _templateJson(
            'dog-template-${index.toString().padLeft(3, '0')}',
            templateType: templateType,
            category: category ?? 'Search',
            mediaBaseUrl: baseUrl,
          ),
        ),
        'nextCursor': null,
        'hasMore': false,
        'page': 1,
      });
      return;
    }

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
    final take = int.tryParse(query['take'] as String? ?? '') ?? 20;
    final cursor = query['cursor'] as String?;
    final start = cursor == null
        ? 0
        : int.tryParse(cursor.replaceFirst('cursor-', '')) ?? 0;
    final end = (start + take).clamp(0, totalTemplates);
    final nextCursor = end < totalTemplates ? 'cursor-$end' : null;

    await _sendJson(request.response, {
      'items': List<Map<String, Object?>>.generate(
        end - start,
        (index) => _templateJson(
          '$idPrefix-${(start + index).toString().padLeft(4, '0')}',
          templateType: templateType,
          category: category ?? 'Portrait',
          mediaBaseUrl: baseUrl,
        ),
      ),
      'nextCursor': nextCursor,
      'hasMore': nextCursor != null,
      'page': (start ~/ take) + 1,
    });
  }

  Future<void> _handleRandom(HttpRequest request) async {
    final query = Map<String, Object?>.from(request.uri.queryParameters);
    randomQueries.add(query);

    final type = query['type'] as String?;
    final category = query['category'] as String?;
    final templateType = type == 'Video' ? 'Video' : 'Image';
    final categorySlug = (category ?? 'Portrait').toLowerCase();
    final typeSlug = type == null ? 'any' : templateType.toLowerCase();
    final templateId = 'random-$typeSlug-$categorySlug-template';
    randomTemplateIds.add(templateId);

    await _sendJson(request.response, {
      'template': _templateJson(
        templateId,
        templateType: templateType,
        category: category ?? 'Portrait',
        mediaBaseUrl: baseUrl,
      ),
    });
  }
}

Future<void> _sendJson(HttpResponse response, Object? payload) async {
  response.statusCode = HttpStatus.ok;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(payload));
  await response.close();
}

Future<void> _sendBytes(
  HttpResponse response,
  List<int> bytes, {
  required ContentType contentType,
}) async {
  response.statusCode = HttpStatus.ok;
  response.headers
    ..contentType = contentType
    ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
  response.contentLength = bytes.length;
  response.add(bytes);
  await response.close();
}

Map<String, Object?> _templateJson(
  String templateId, {
  String templateType = 'Image',
  String category = 'Portrait',
  String? mediaBaseUrl,
}) {
  final isVideo = templateType == 'Video';
  return {
    'templateId': templateId,
    'templateType': templateType,
    'title': templateId,
    'shortDescription': templateId,
    'category': category,
    'tags': ['pet', 'portrait'],
    'isPremium': false,
    'tokenCost': 1,
    if (mediaBaseUrl != null)
      'thumbnailUrl': '$mediaBaseUrl/media/template-thumb.png',
    if (mediaBaseUrl != null)
      'previewAsset': {
        'url': isVideo
            ? '$mediaBaseUrl/media/template-video-preview.mp4'
            : '$mediaBaseUrl/media/template-image-preview.png',
        'fileName': isVideo
            ? 'template-video-preview.mp4'
            : 'template-image-preview.png',
        'contentType': isVideo ? 'video/mp4' : 'image/png',
        if (isVideo) 'durationSeconds': 6,
      },
  };
}
