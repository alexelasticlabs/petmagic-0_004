import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_type_filters.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  testWidgets(
    'template filters hide category row when backend has no categories',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TemplateTypeFilters(
              selectedType: null,
              categories: const [],
              selectedCategory: null,
              onTypeSelected: (_) {},
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(TemplateTypeFilters));
      final text = AppLocalizations.of(context);

      expect(find.text(text.allFilter), findsOneWidget);
      expect(find.text(text.videosFilter), findsOneWidget);
      expect(find.text(text.imagesFilter), findsOneWidget);
    },
  );

  testWidgets('template filters use theme contrast for selected pills', (
    tester,
  ) async {
    Future<AppLocalizations> pumpFilters({
      required Brightness brightness,
      required TemplateType? selectedType,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TemplateTypeFilters(
              selectedType: selectedType,
              categories: const [],
              selectedCategory: null,
              onTypeSelected: (_) {},
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      return AppLocalizations.of(
        tester.element(find.byType(TemplateTypeFilters)),
      );
    }

    var text = await pumpFilters(
      brightness: Brightness.light,
      selectedType: null,
    );
    var context = tester.element(find.byType(TemplateTypeFilters));
    var selectedText = tester.widget<Text>(find.text(text.allFilter));

    expect(selectedText.style?.color, Theme.of(context).colorScheme.onPrimary);

    text = await pumpFilters(
      brightness: Brightness.dark,
      selectedType: TemplateType.video,
    );
    context = tester.element(find.byType(TemplateTypeFilters));
    selectedText = tester.widget<Text>(find.text(text.videosFilter));
    final selectedIcon = tester.widget<Icon>(
      find.byIcon(Icons.play_circle_outline_rounded),
    );

    expect(selectedText.style?.color, Theme.of(context).colorScheme.onPrimary);
    expect(selectedIcon.color, Theme.of(context).colorScheme.onPrimary);
  });

  test(
    'templates top bar alert badge uses theme contrast for danger token',
    () {
      final source = File(
        'lib/features/templates/presentation/widgets/templates_top_bar.dart',
      ).readAsStringSync();

      expect(source, contains('color: colors.on(colors.danger)'));
      expect(
        source,
        isNot(
          contains('color: Colors.white,\n                    fontSize: 9'),
        ),
      );
    },
  );

  testWidgets(
    'templates page uses backend cursor pages and drops stale search results',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final backend = _SlowTemplateFeedBackend(totalTemplates: 1005);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = _RemoteBackedTemplatesRepository(
        TemplatesRemoteDataSource(dio),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
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
        () =>
            _templatesState(tester).items.length == 20 &&
            find.text('template-0000').evaluate().isNotEmpty,
      );

      expect(backend.feedQueries.single, {'take': 20});
      expect(find.byType(TemplateCard).evaluate().length, lessThan(40));
      expect(_templatesState(tester).nextCursor, 'cursor-20');

      final scrollableState = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
      await tester.pump();

      await _pumpUntil(
        tester,
        () =>
            _templatesState(tester).items.length == 40 &&
            backend.feedQueries.any((query) => query['cursor'] == 'cursor-20'),
      );

      expect(_templatesState(tester).items.last.templateId, 'template-0039');
      expect(
        backend.feedQueries.map((query) => query['page']).whereType<Object>(),
        isEmpty,
      );

      scrollableState.position.jumpTo(0);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pump(const Duration(milliseconds: 359));
      expect(backend.startedSearches, isEmpty);

      await tester.pump(const Duration(milliseconds: 2));
      await _pumpUntil(
        tester,
        () =>
            backend.startedSearches.contains('cat') &&
            _templatesState(tester).query.search == 'cat' &&
            _templatesState(tester).items.isEmpty &&
            _templatesState(tester).isInitialLoading &&
            find.byType(MagicLoadingScreen).evaluate().isNotEmpty,
      );
      expect(find.text('template-0000'), findsNothing);

      await tester.enterText(find.byType(TextField), 'dog');
      await tester.pump(const Duration(milliseconds: 361));
      await _pumpUntil(
        tester,
        () =>
            _templatesState(tester).query.search == 'dog' &&
            _templatesState(
              tester,
            ).items.map((item) => item.templateId).contains('dog-template-000'),
      );

      final state = _templatesState(tester);
      expect(backend.cancelledSearches, contains('cat'));
      expect(state.items.map((item) => item.templateId), [
        'dog-template-000',
        'dog-template-001',
        'dog-template-002',
      ]);
      expect(
        backend.feedQueries
            .where((query) => query['search'] != null)
            .map((query) => query['search'])
            .toList(),
        ['cat', 'dog'],
      );
      expect(find.text('dog-template-000'), findsOneWidget);
      expect(find.text('template-0000'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'templates page sends type and category filters through backend feed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final backend = _SlowTemplateFeedBackend(totalTemplates: 1005);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = _RemoteBackedTemplatesRepository(
        TemplatesRemoteDataSource(dio),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
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
        () => _templatesState(tester).items.length == 20,
      );

      final context = tester.element(find.byType(TemplatesPage));
      final text = AppLocalizations.of(context);

      await tester.tap(find.text(text.videosFilter));
      await _pumpUntil(
        tester,
        () =>
            _templatesState(tester).query.type == TemplateType.video &&
            _templatesState(
              tester,
            ).items.any((item) => item.templateId == 'video-template-0000'),
      );

      var state = _templatesState(tester);
      expect(state.items.map((item) => item.templateId).take(3), [
        'video-template-0000',
        'video-template-0001',
        'video-template-0002',
      ]);
      expect(
        state.items.any((item) => item.templateId.startsWith('template-')),
        isFalse,
      );
      expect(backend.feedQueries.last['type'], 'Video');

      await tester.tap(find.text('Search'));
      await _pumpUntil(
        tester,
        () =>
            _templatesState(tester).query.category == 'Search' &&
            _templatesState(tester).items.any(
              (item) => item.templateId == 'search-video-template-0000',
            ),
      );

      state = _templatesState(tester);
      expect(state.query.type, TemplateType.video);
      expect(state.items.map((item) => item.templateId).take(3), [
        'search-video-template-0000',
        'search-video-template-0001',
        'search-video-template-0002',
      ]);
      expect(
        state.items.any(
          (item) => item.templateId.startsWith('video-template-'),
        ),
        isFalse,
      );
      expect(backend.feedQueries.last['type'], 'Video');
      expect(backend.feedQueries.last['category'], 'Search');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('repeated feed changes stay paged bounded and unmixed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final backend = _SlowTemplateFeedBackend(totalTemplates: 1005);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = backend;
    final repository = _RemoteBackedTemplatesRepository(
      TemplatesRemoteDataSource(dio),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
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

    await _expectBackendFeed(
      tester,
      type: null,
      category: null,
      search: null,
      expectedPrefix: 'template-',
    );

    final controller = _templatesController(tester);
    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );

    await _loadNextCursorPage(
      tester,
      backend,
      scrollableState,
      expectedPrefix: 'template-',
    );

    controller.setType(TemplateType.video);
    await _expectBackendFeed(
      tester,
      type: TemplateType.video,
      category: null,
      search: null,
      expectedPrefix: 'video-template-',
    );

    controller.setCategory('Search');
    await _expectBackendFeed(
      tester,
      type: TemplateType.video,
      category: 'Search',
      search: null,
      expectedPrefix: 'search-video-template-',
    );
    await _loadNextCursorPage(
      tester,
      backend,
      scrollableState,
      expectedPrefix: 'search-video-template-',
    );

    controller.setType(TemplateType.image);
    await _expectBackendFeed(
      tester,
      type: TemplateType.image,
      category: 'Search',
      search: null,
      expectedPrefix: 'search-image-template-',
    );

    controller.setSearch('spark');
    await _expectBackendFeed(
      tester,
      type: TemplateType.image,
      category: 'Search',
      search: 'spark',
      expectedPrefix: 'spark-search-image-template-',
    );

    controller.setCategory(null);
    await _expectBackendFeed(
      tester,
      type: TemplateType.image,
      category: null,
      search: 'spark',
      expectedPrefix: 'spark-image-template-',
    );
    await _loadNextCursorPage(
      tester,
      backend,
      scrollableState,
      expectedPrefix: 'spark-image-template-',
    );

    controller.setType(null);
    await _expectBackendFeed(
      tester,
      type: null,
      category: null,
      search: 'spark',
      expectedPrefix: 'spark-template-',
    );

    controller.setSearch('');
    await _expectBackendFeed(
      tester,
      type: null,
      category: null,
      search: null,
      expectedPrefix: 'template-',
    );

    controller.setType(TemplateType.video);
    await _expectBackendFeed(
      tester,
      type: TemplateType.video,
      category: null,
      search: null,
      expectedPrefix: 'video-template-',
    );

    final signatures = backend.feedQueries.map(_querySignature).toList();
    for (var i = 1; i < signatures.length; i++) {
      expect(signatures[i], isNot(signatures[i - 1]));
    }
    expect(
      backend.feedQueries.map((query) => query['page']).whereType<Object>(),
      isEmpty,
    );
    expect(_templatesState(tester).cachedPagesByQueryKey.length, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'templates page shows backend empty and error states without stale cards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final backend = _SlowTemplateFeedBackend(
        totalTemplates: 1005,
        emptySearches: const {'missing'},
        errorSearches: const {'timeout'},
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = _RemoteBackedTemplatesRepository(
        TemplatesRemoteDataSource(dio),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
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

      await _expectBackendFeed(
        tester,
        type: null,
        category: null,
        search: null,
        expectedPrefix: 'template-',
      );
      expect(find.text('template-0000'), findsOneWidget);

      final context = tester.element(find.byType(TemplatesPage));
      final text = AppLocalizations.of(context);

      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump(const Duration(milliseconds: 361));
      await _pumpUntil(
        tester,
        () =>
            _templatesState(tester).query.search == 'missing' &&
            _templatesState(tester).isEmpty &&
            find.text(text.emptyTemplatesTitle).evaluate().isNotEmpty,
        maxPumps: 200,
      );

      var state = _templatesState(tester);
      expect(state.items, isEmpty);
      expect(state.errorMessage, isNull);
      expect(find.text(text.emptyTemplatesMessage), findsOneWidget);
      expect(find.text('template-0000'), findsNothing);
      expect(
        backend.feedQueries.where((query) => query['search'] == 'missing'),
        hasLength(1),
      );

      await tester.enterText(find.byType(TextField), 'timeout');
      await tester.pump(const Duration(milliseconds: 361));
      await _pumpUntil(
        tester,
        () =>
            _templatesState(tester).query.search == 'timeout' &&
            _templatesState(tester).errorMessage ==
                'templates.server_timeout' &&
            find.text(text.appUnavailableServerTitle).evaluate().isNotEmpty,
        maxPumps: 200,
      );

      state = _templatesState(tester);
      expect(state.items, isEmpty);
      expect(state.isEmpty, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(find.text(text.appUnavailableServerTitle), findsOneWidget);
      expect(find.text('template-0000'), findsNothing);
      expect(
        backend.feedQueries.where((query) => query['search'] == 'timeout'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

TemplatesState _templatesState(WidgetTester tester) {
  final context = tester.element(find.byType(TemplatesPage));
  return ProviderScope.containerOf(context).read(templatesControllerProvider);
}

TemplatesController _templatesController(WidgetTester tester) {
  final context = tester.element(find.byType(TemplatesPage));
  return ProviderScope.containerOf(
    context,
  ).read(templatesControllerProvider.notifier);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration step = const Duration(milliseconds: 20),
  int maxPumps = 150,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (condition()) {
      return;
    }
    await tester.pump(step);
  }

  fail('Timed out waiting for condition.');
}

Future<void> _expectBackendFeed(
  WidgetTester tester, {
  required TemplateType? type,
  required String? category,
  required String? search,
  required String expectedPrefix,
  int expectedCount = 20,
}) async {
  await _pumpUntil(tester, () {
    final state = _templatesState(tester);
    return state.query.type == type &&
        state.query.category == category &&
        state.query.search == search &&
        state.items.length == expectedCount &&
        state.items.every(
          (item) => item.templateId.startsWith(expectedPrefix),
        ) &&
        !state.isLoading &&
        !state.isRefreshing &&
        !state.isLoadingMore &&
        state.errorMessage == null;
  }, maxPumps: 200);

  final state = _templatesState(tester);
  expect(
    state.items.map((item) => item.templateId).toSet(),
    hasLength(state.items.length),
  );
  expect(find.byType(TemplateCard).evaluate().length, lessThan(60));
  expect(state.cachedPagesByQueryKey.length, lessThanOrEqualTo(6));
}

Future<void> _loadNextCursorPage(
  WidgetTester tester,
  _SlowTemplateFeedBackend backend,
  ScrollableState scrollableState, {
  required String expectedPrefix,
}) async {
  final requestCountBefore = backend.feedQueries.length;
  scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
  await tester.pump();
  await _pumpUntil(
    tester,
    () =>
        _templatesState(tester).items.length == 40 &&
        _templatesState(
          tester,
        ).items.every((item) => item.templateId.startsWith(expectedPrefix)) &&
        backend.feedQueries.length > requestCountBefore &&
        backend.feedQueries.last['cursor'] == 'cursor-20',
    maxPumps: 200,
  );
  scrollableState.position.jumpTo(0);
  await tester.pump();
}

String _querySignature(Map<String, Object?> query) {
  final entries = query.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return jsonEncode({for (final entry in entries) entry.key: entry.value});
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
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

class _SlowTemplateFeedBackend implements HttpClientAdapter {
  _SlowTemplateFeedBackend({
    required this.totalTemplates,
    this.emptySearches = const {},
    this.errorSearches = const {},
  });

  final int totalTemplates;
  final Set<String> emptySearches;
  final Set<String> errorSearches;
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

    if (search != null && errorSearches.contains(search)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }

    if (search != null && emptySearches.contains(search)) {
      return _jsonResponse({
        'items': const <Map<String, Object?>>[],
        'nextCursor': null,
        'hasMore': false,
        'page': 1,
      });
    }

    final type = query['type'] as String?;
    final category = query['category'] as String?;
    final isVideo = type == 'Video';
    final isImage = type == 'Image';
    final templateType = isVideo ? 'Video' : 'Image';
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
      'items': List<Map<String, Object?>>.generate(
        end - start,
        (index) => _templateJson(
          '$idPrefix-${(start + index).toString().padLeft(4, '0')}',
          templateType: templateType,
          category: category ?? 'Portrait',
        ),
      ),
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
  return {
    'templateId': templateId,
    'templateType': templateType,
    'title': templateId,
    'shortDescription': templateId,
    'category': category,
    'tags': ['pet', 'portrait'],
    'isPremium': false,
    'tokenCost': 1,
  };
}
