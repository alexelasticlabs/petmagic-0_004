import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() async {
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  test('generation status load errors are mapped before reaching UI state', () {
    final source = File(
      'lib/features/templates/presentation/generation_status_page.dart',
    ).readAsStringSync();
    final loadBody = _methodBody(source, 'Future<void> _load');
    final errorBody = _methodBody(
      source,
      'Future<void> _showCachedOrMappedLoadError',
    );

    expect(loadBody, isNot(contains('error.toString()')));
    expect(loadBody, contains('CancelToken.isCancel(error)'));
    expect(
      loadBody,
      contains('_showCachedOrMappedLoadError(repository, error)'),
    );
    expect(errorBody, contains('_mapStatusLoadError(error)'));
    expect(source, contains('String _mapStatusLoadError(Object error)'));
    expect(source, contains('_statusLoadErrorText(text, _errorMessage!)'));
  });

  test(
    'generation status async feedback and toast paths guard mounted state',
    () {
      final source = File(
        'lib/features/templates/presentation/generation_status_page.dart',
      ).readAsStringSync();

      final ratingBody = _methodBody(
        source,
        'Future<void> _handleRatingSelected',
      );
      expect(ratingBody, contains('if (!mounted || result == null)'));

      final submitBody = _methodBody(source, 'Future<void> _submitFeedback');
      expect(submitBody, contains('if (!mounted)'));
      expect(
        submitBody.indexOf('if (!mounted)'),
        lessThan(submitBody.indexOf('setState(')),
      );

      final showInfoBody = _methodBody(source, 'void _showInfo');
      expect(showInfoBody, contains('if (!mounted)'));
      expect(
        showInfoBody.indexOf('if (!mounted)'),
        lessThan(showInfoBody.indexOf('PetMagicToast.show')),
      );
    },
  );

  test(
    'generation status back button preserves existing navigation stack first',
    () {
      final source = File(
        'lib/features/templates/presentation/generation_status_page.dart',
      ).readAsStringSync();
      final buildBody = _methodBody(source, 'Widget build');
      final backBody = _methodBody(source, 'void _handleBackNavigation');

      expect(buildBody, contains('onBack: _handleBackNavigation'));
      expect(backBody, contains('final navigator = Navigator.of(context);'));
      expect(backBody, contains('if (navigator.canPop())'));
      expect(backBody, contains('navigator.pop();'));
      expect(backBody, contains("context.go('/creations');"));
      expect(
        backBody.indexOf('navigator.pop();'),
        lessThan(backBody.indexOf("context.go('/creations');")),
      );
    },
  );

  testWidgets(
    'generation status back button opens Creations for direct status entries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: GenerationStatusPage.routeFor('generation-1'),
        routes: [
          GoRoute(
            path: '/creations',
            builder: (context, state) =>
                const Scaffold(body: Text('creations-route')),
          ),
          GoRoute(
            path: '${GenerationStatusPage.routePrefix}/:generationId',
            builder: (context, state) => GenerationStatusPage(
              generationId: state.pathParameters['generationId'] ?? '',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(
              _FakeTemplateGenerationRepository(_generation()),
            ),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GenerationStatusPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('creations-route'), findsOneWidget);
      expect(find.byType(GenerationStatusPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation status failed action preserves pet context', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _FakeTemplateGenerationRepository(
      _generation(
        status: TemplateGenerationStatus.failed,
        petId: 'pet/route',
        petPhotoId: 'photo route',
      ),
    );
    final router = GoRouter(
      initialLocation: GenerationStatusPage.routeFor('generation-1'),
      routes: [
        GoRoute(
          path: '${GenerationStatusPage.routePrefix}/:generationId',
          builder: (context, state) => GenerationStatusPage(
            generationId: state.pathParameters['generationId'] ?? '',
          ),
        ),
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) {
            final query = state.uri.queryParameters;
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('templates-route'),
                    Text('templates-pet:${query['petId'] ?? ''}'),
                    Text('templates-photo:${query['petPhotoId'] ?? ''}'),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    final text = AppLocalizations.of(
      tester.element(find.byType(GenerationStatusPage)),
    );

    await tester.tap(find.text(text.generationStatusPickAnotherPhotoAction));
    await tester.pumpAndSettle();

    expect(find.text('templates-route'), findsOneWidget);
    expect(find.text('templates-pet:pet/route'), findsOneWidget);
    expect(find.text('templates-photo:photo route'), findsOneWidget);
  });

  test('generation status failed retry and sheet keep pet context helper', () {
    final source = File(
      'lib/features/templates/presentation/generation_status_page.dart',
    ).readAsStringSync();
    final buildBody = _methodBody(source, 'Widget build');
    final sheetBody = _methodBody(source, 'Future<void> _openActionsSheet');
    final retryBody = _methodBody(source, 'void _retrySoon');

    expect(buildBody, contains('onRetry: () => _retrySoon(generation)'));
    expect(
      RegExp(
        r'_templatesLocationForGeneration\(generation\)',
      ).allMatches(buildBody).length,
      greaterThanOrEqualTo(2),
    );
    expect(sheetBody, contains('_templatesLocationForGeneration(generation)'));
    expect(
      retryBody,
      contains('context.go(_templatesLocationForGeneration(generation))'),
    );
  });

  test(
    'generation status media actions stop after local-media lookup if unmounted',
    () {
      final source = File(
        'lib/features/templates/presentation/generation_status_page.dart',
      ).readAsStringSync();
      final saveBody = _methodBody(source, 'Future<void> _saveToGallery');
      final shareBody = _methodBody(source, 'Future<void> _shareResult');

      void expectMountedGuardBeforeRemoteAccess(String body) {
        final localLookupIndex = body.indexOf('await usableLocalMediaPath');
        final mountedGuardIndex = body.indexOf('if (!mounted)');
        final fetchAccessIndex = body.indexOf('fetch');
        expect(localLookupIndex, isNonNegative);
        expect(mountedGuardIndex, isNonNegative);
        expect(fetchAccessIndex, isNonNegative);
        expect(localLookupIndex, lessThan(mountedGuardIndex));
        expect(mountedGuardIndex, lessThan(fetchAccessIndex));
      }

      expectMountedGuardBeforeRemoteAccess(saveBody);
      expectMountedGuardBeforeRemoteAccess(shareBody);
    },
  );

  test('generation result aspect ratio probe is cached and detached', () {
    final source = File(
      'lib/features/templates/presentation/generation_status_page_sections.dart',
    ).readAsStringSync();

    expect(source, contains('CachedNetworkImageProvider('));
    expect(
      source,
      contains('ResizeImage(\n        FileImage(localOutputFile)'),
    );
    expect(source, contains('maxWidth: _aspectRatioProbeCacheWidth'));
    expect(source, contains('void _detachAspectRatioListener()'));
    expect(source, contains('stream.removeListener(listener)'));
    expect(source, isNot(contains('NetworkImage(url)')));
  });

  test('generation result media URLs are checked before network use', () {
    final pageSource = File(
      'lib/features/templates/presentation/generation_status_page.dart',
    ).readAsStringSync();
    final sectionsSource = File(
      'lib/features/templates/presentation/generation_status_page_sections.dart',
    ).readAsStringSync();

    expect(
      pageSource,
      contains(
        "import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';",
      ),
    );
    expect(pageSource, contains('parseSafeGenerationMediaUri(mediaUrl)'));
    expect(pageSource, contains('parseSafeGenerationMediaUri(outputUrl)'));
    expect(pageSource, contains('ClipboardData(text: safeUri.toString())'));
    expect(sectionsSource, contains('parseSafeGenerationMediaUri(url)'));
    expect(sectionsSource, contains('parseSafeGenerationMediaUri(outputUrl)'));
    expect(sectionsSource, contains('parseSafeGenerationMediaUri(mediaUrl)'));
    expect(
      sectionsSource,
      contains('VideoPlayerController.networkUrl(safeUri)'),
    );
    expect(sectionsSource, contains('imageUrl: safeMediaUrl'));
    expect(
      sectionsSource,
      isNot(contains('VideoPlayerController.networkUrl(Uri.parse(mediaUrl))')),
    );
    expect(
      sectionsSource,
      isNot(contains('VideoPlayerController.networkUrl(Uri.parse(url))')),
    );
    expect(
      pageSource,
      contains("_recordCompareAnalytics(generation, 'compare_clicked')"),
    );
    expect(sectionsSource, contains('class _BeforeAfterCompareViewer'));
  });

  test(
    'generation status local media sync checks page lifecycle before apply',
    () {
      final source = File(
        'lib/features/templates/presentation/generation_status_page.dart',
      ).readAsStringSync();
      final materializeBody = _methodBody(
        source,
        'Future<void> _materializeLocalMediaAndRefresh',
      );
      final lifecycleGuardBody = _methodBody(
        source,
        'bool _canApplyLocalMediaSync',
      );

      expect(materializeBody, contains('if (!_canApplyLocalMediaSync() ||'));
      expect(
        materializeBody,
        contains('mergeFetchedGeneration(localizedGeneration)'),
      );
      expect(lifecycleGuardBody, contains('!mounted || !_isPageActive'));
      expect(lifecycleGuardBody, contains('AppLifecycleState.resumed'));
      expect(source, contains('_isPageActive = false;'));
      expect(source, contains('_cancelActiveLocalMediaDownloads();'));
    },
  );

  testWidgets(
    'generation status shows compare action only for eligible image result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(
              _FakeTemplateGenerationRepository(
                _generation(
                  canCompareBeforeAfter: true,
                  inputPreviewUrl:
                      'https://cdn.petmagic.test/before.jpg?signature=secret',
                  resultPreviewUrl:
                      'https://cdn.petmagic.test/after.jpg?signature=secret',
                ),
              ),
            ),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Compare'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(
              _FakeTemplateGenerationRepository(_generation()),
            ),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Compare'), findsNothing);
    },
  );

  testWidgets('generation status cancels active status load on disposal', (
    tester,
  ) async {
    final repository = _DelayedLoadTemplateGenerationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GenerationStatusPage(generationId: 'generation-1'),
        ),
      ),
    );

    final cancelToken = await repository.fetchStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancelToken.isCancelled, isTrue);
    await tester.pump();
  });

  testWidgets('generation status cancels active media share on disposal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = _DelayedGenerationStatusMediaActions();
    final generation = _generation();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(
            _FakeTemplateGenerationRepository(generation),
          ),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
          generationStatusMediaActionsProvider.overrideWithValue(mediaActions),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GenerationStatusPage(generationId: 'generation-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final text = AppLocalizations.of(
      tester.element(find.byType(GenerationStatusPage)),
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    final shareAction = find.text(text.supportChatShareAction);
    expect(shareAction, findsOneWidget);
    await tester.tap(shareAction);
    await mediaActions.shareStarted.future;
    expect(mediaActions.shareCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(mediaActions.shareCancelToken?.isCancelled, isTrue);
  });

  testWidgets(
    'generation status rejects unsafe media access URLs before save and share',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeTemplateGenerationRepository(
        _generation(),
        mediaAccessUrl: 'javascript:alert(1)',
      );
      final mediaActions = _RecordingGenerationStatusMediaActions();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
            generationStatusMediaActionsProvider.overrideWithValue(
              mediaActions,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.generationStatusSaveAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.fetchDownloadCalls, 1);
      expect(mediaActions.saveCalls, 0);
      await PetMagicNotificationCenter.instance.clearQueue();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.supportChatShareAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.fetchShareCalls, 1);
      expect(mediaActions.shareCalls, 0);
      await PetMagicNotificationCenter.instance.clearQueue();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generation status fallback media file names sanitize title and id',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tempDir = Directory.systemTemp.createTempSync(
        'petmagic-status-local-output-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final localOutput = File(
        '${tempDir.path}${Platform.pathSeparator}status-local.jpg',
      );
      localOutput.writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);

      final repository = _FakeTemplateGenerationRepository(
        _generation(
          generationId: 'g/ready #1?x=2',
          templateTitle: 'Movie *Star* / Pet?',
          localOutputPath: localOutput.path,
        ),
        mediaAccessFileName: '',
      );
      final mediaActions = _RecordingGenerationStatusMediaActions();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
            generationStatusMediaActionsProvider.overrideWithValue(
              mediaActions,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'g/ready #1?x=2'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.generationStatusSaveAction));
      await tester.pump();

      expect(repository.fetchDownloadCalls, 0);
      expect(mediaActions.savedFileNames, ['Movie_Star_Pet_g_ready_1_x_2.jpg']);
      expect(mediaActions.savedLocalPaths, [localOutput.path]);
      await PetMagicNotificationCenter.instance.clearQueue();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.supportChatShareAction));
      await tester.pump();

      expect(mediaActions.sharedFileNames, [
        'Movie_Star_Pet_g_ready_1_x_2.jpg',
      ]);
      expect(mediaActions.sharedLocalPaths, [localOutput.path]);
      expect(repository.fetchShareCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generation status ignores corrupted local output and falls back to remote access',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tempDir = Directory.systemTemp.createTempSync(
        'petmagic-status-corrupt-local-output-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final localOutput = File(
        '${tempDir.path}${Platform.pathSeparator}status-corrupt.jpg',
      );
      localOutput.writeAsBytesSync('not-media'.codeUnits);

      final repository = _FakeTemplateGenerationRepository(
        _generation(localOutputPath: localOutput.path),
        mediaAccessUrl: 'https://cdn.petmagic.test/result-fallback.jpg',
        mediaAccessFileName: '',
      );
      final mediaActions = _RecordingGenerationStatusMediaActions();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
            generationStatusMediaActionsProvider.overrideWithValue(
              mediaActions,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.generationStatusSaveAction));
      await tester.pump();

      expect(repository.fetchDownloadCalls, 1);
      expect(mediaActions.savedLocalPaths, [null]);
      expect(mediaActions.savedFileNames, [
        'Movie_Star_Pet_Poster_generation-1.jpg',
      ]);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.supportChatShareAction));
      await tester.pump();

      expect(repository.fetchShareCalls, 1);
      expect(mediaActions.sharedLocalPaths, [null]);
      expect(mediaActions.sharedFileNames, [
        'Movie_Star_Pet_Poster_generation-1.jpg',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation status cancels active local media sync on disposal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _DelayedGenerationGalleryStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(
            _FakeTemplateGenerationRepository(_generation()),
          ),
          generationGalleryStoreProvider.overrideWithValue(store),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GenerationStatusPage(generationId: 'generation-1'),
        ),
      ),
    );

    await store.materializeStarted.future;
    expect(store.cancelActiveDownloadsCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(store.cancelActiveDownloadsCalls, greaterThanOrEqualTo(1));

    store.materializeCompleter.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'generation status shows free watermark actions and paywall sheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeTemplateGenerationRepository(
        _generation(
          hasWatermark: true,
          canRemoveWatermark: true,
          removeWatermarkCostCredits: 1,
          watermarkMessage: 'Watermark added on the free plan',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      expect(find.text(text.generationStatusWatermarkAddedFreePlan), findsOne);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      final removeAction = find.text(text.generationStatusRemoveWatermark);
      expect(find.text(text.generationStatusShareWithWatermark), findsOne);
      expect(find.text(text.generationStatusSaveWithWatermark), findsOne);
      expect(find.text(text.generationStatusUpgradePremium), findsOne);

      await tester.tap(removeAction);
      await tester.pumpAndSettle();

      expect(
        find.text(text.generationStatusRemoveWatermarkSheetTitle),
        findsWidgets,
      );
      expect(
        find.text(text.generationStatusRemoveWatermarkUseCredit(1)),
        findsOne,
      );
      expect(find.text(text.generationStatusUpgradePremium), findsWidgets);
      expect(repository.analyticsEvents, contains('remove_clicked'));
      expect(repository.analyticsEvents, contains('paywall_viewed'));
      for (final eventType in ['remove_clicked', 'paywall_viewed']) {
        final call = repository.analyticsCalls.singleWhere(
          (item) => item.eventType == eventType,
        );
        expect(call.templateId, 'template-1');
        expect(call.generationId, 'generation-1');
        expect(call.metadata['generationId'], 'generation-1');
        expect(call.metadata['templateId'], 'template-1');
        expect(call.metadata['mediaType'], 'image');
        expect(call.metadata['userPlan'], 'free');
        expect(call.metadata.containsKey('unlockMethod'), isFalse);
        expect(call.metadata.containsKey('creditsSpent'), isFalse);
      }
    },
  );

  testWidgets(
    'generation status records template of the day completion after polling',
    (tester) async {
      final repository = _FakeTemplateGenerationRepository(
        _generation(status: TemplateGenerationStatus.queued),
      );
      final featured = _templateOfTheDay();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: GenerationStatusPage(
              generationId: 'generation-1',
              templateOfTheDay: featured,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(repository.analyticsEvents, isEmpty);

      repository.generation = _generation(
        status: TemplateGenerationStatus.completed,
        userPlan: 'premium',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(repository.analyticsEvents, contains('generation_completed'));
      final completionCall = repository.analyticsCalls.singleWhere(
        (call) => call.eventType == 'generation_completed',
      );
      expect(completionCall.generationId, 'generation-1');
      expect(completionCall.templateId, featured.templateId);
      expect(completionCall.metadata, containsPair('source', 'auto'));
      expect(
        completionCall.metadata,
        containsPair('screen', 'generation_status'),
      );
      expect(completionCall.metadata, containsPair('userPlan', 'premium'));
    },
  );

  testWidgets('generation status records template of the day failure', (
    tester,
  ) async {
    final repository = _FakeTemplateGenerationRepository(
      _generation(
        status: TemplateGenerationStatus.failed,
        failureCode: 'provider_failed',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: GenerationStatusPage(
            generationId: 'generation-1',
            templateOfTheDay: _templateOfTheDay(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(repository.analyticsEvents, ['generation_failed']);
    expect(
      repository.analyticsCalls.single.metadata,
      containsPair('failureCode', 'provider_failed'),
    );
  });

  testWidgets(
    'generation status removes watermark with credit and reloads clean result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeTemplateGenerationRepository(
        _generation(
          hasWatermark: true,
          canRemoveWatermark: true,
          removeWatermarkCostCredits: 1,
          watermarkMessage: 'Watermark added on the free plan',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.generationStatusRemoveWatermark).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(text.generationStatusRemoveWatermarkUseCredit(1)),
      );
      await tester.pumpAndSettle();

      expect(repository.removeWatermarkCalls, equals(['generation-1']));
      expect(find.text(text.generationStatusWatermarkRemoved), findsWidgets);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text(text.generationStatusDownloadWithoutWatermark),
        findsOne,
      );
      expect(find.text(text.generationStatusShareWithWatermark), findsNothing);

      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'generation status shows no credits message when watermark unlock is unpaid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeTemplateGenerationRepository(
        _generation(
          hasWatermark: true,
          canRemoveWatermark: true,
          removeWatermarkCostCredits: 1,
          watermarkMessage: 'Watermark added on the free plan',
        ),
        removeWatermarkStatusCode: 402,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text.generationStatusRemoveWatermark).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(text.generationStatusRemoveWatermarkUseCredit(1)),
      );
      await tester.pumpAndSettle();

      expect(repository.removeWatermarkCalls, equals(['generation-1']));
      expect(
        find.text(text.generationStatusRemoveWatermarkNoCredits),
        findsOne,
      );
      expect(find.text(text.walletBuySparkTitle), findsOne);
      expect(find.text(text.generationStatusUpgradePremium), findsOne);
      expect(find.text(text.generationStatusWatermarkAddedFreePlan), findsOne);

      await PetMagicNotificationCenter.instance.clearQueue();
    },
  );

  testWidgets(
    'generation status shows clean premium actions without watermark controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeTemplateGenerationRepository(
        _generation(userPlan: 'premium', supportsGenerateSimilar: true),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      expect(
        find.text(text.generationStatusWatermarkAddedFreePlan),
        findsNothing,
      );
      expect(find.text(text.generationStatusWatermarkRemoved), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text(text.generationStatusSaveAction), findsOne);
      expect(find.text(text.supportChatShareAction), findsOne);
      expect(find.text('Generate similar'), findsWidgets);
      expect(find.text(text.generationStatusRemoveWatermark), findsNothing);
      expect(find.text(text.generationStatusUpgradePremium), findsNothing);
      expect(find.text(text.generationStatusShareWithWatermark), findsNothing);
      expect(find.text(text.generationStatusSaveWithWatermark), findsNothing);
    },
  );

  testWidgets(
    'generation status syncs fetched generation into Creations history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final generation = _generation(
        generationId: 'generation-fresh',
        templateTitle: 'Fresh Pet Portrait',
      );
      final historyController = _TrackingGenerationHistoryController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(
              _FakeTemplateGenerationRepository(generation),
            ),
            generationHistoryControllerProvider.overrideWith(
              () => historyController,
            ),
            generationGalleryStoreProvider.overrideWithValue(
              _NoopGenerationGalleryStore(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-fresh'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(historyController.mergedGenerationIds, ['generation-fresh']);
      expect(historyController.state.items.map((item) => item.generationId), [
        'generation-fresh',
      ]);
      expect(find.text('Fresh Pet Portrait'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generation status syncs local media paths into Creations history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final generation = _generation(
        generationId: 'generation-local',
        templateTitle: 'Local Pet Portrait',
      );
      final historyController = _TrackingGenerationHistoryController();
      final store = _ImmediateGenerationGalleryStore(
        record: GenerationGalleryMediaRecord(
          generationId: 'generation-local',
          accountScope: 'user-1',
          userId: 'user-1',
          status: TemplateGenerationStatus.completed.name,
          updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
          lastSyncedAtUtc: DateTime.utc(2026, 5, 25, 14, 31),
          version: 1,
          previewLocalPath: '/local/generation-local-preview.jpg',
          outputLocalPath: '/local/generation-local-output.jpg',
          isDownloadComplete: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(
              _FakeTemplateGenerationRepository(generation),
            ),
            generationHistoryControllerProvider.overrideWith(
              () => historyController,
            ),
            generationGalleryStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GenerationStatusPage(generationId: 'generation-local'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(historyController.mergedGenerationIds, [
        'generation-local',
        'generation-local',
      ]);
      expect(
        historyController.mergedGenerations.last.localPreviewPath,
        '/local/generation-local-preview.jpg',
      );
      expect(
        historyController.mergedGenerations.last.localOutputPath,
        '/local/generation-local-output.jpg',
      );
      expect(historyController.state.items.single.isLocalMediaReady, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeTemplateGenerationRepository extends TemplateGenerationRepository {
  _FakeTemplateGenerationRepository(
    this.generation, {
    this.removeWatermarkStatusCode,
    this.mediaAccessUrl = 'https://cdn.petmagic.test/result.jpg',
    this.mediaAccessFileName = 'result.jpg',
  }) : super(
         dio: Dio(),
         sessionStorage: AuthSessionStorage(),
         preferences: SharedPreferencesAsync(),
       );

  TemplateGenerationResult generation;
  final int? removeWatermarkStatusCode;
  final String mediaAccessUrl;
  final String mediaAccessFileName;
  final List<String> analyticsEvents = [];
  final List<_AnalyticsCall> analyticsCalls = [];
  final List<String> removeWatermarkCalls = [];
  int fetchDownloadCalls = 0;
  int fetchShareCalls = 0;

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    return generation;
  }

  @override
  Future<TemplateGenerationResult?> readCachedGeneration(
    String generationId,
  ) async {
    return generation;
  }

  @override
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    fetchDownloadCalls++;
    return GenerationMediaAccessResult(
      mediaUrl: mediaAccessUrl,
      hasWatermark: false,
      fileName: mediaAccessFileName,
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    fetchShareCalls++;
    return GenerationMediaAccessResult(
      mediaUrl: mediaAccessUrl,
      hasWatermark: false,
      fileName: mediaAccessFileName,
    );
  }

  @override
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    CancelToken? cancelToken,
  }) async {
    removeWatermarkCalls.add(generationId);
    if (removeWatermarkStatusCode != null) {
      throw DioException.badResponse(
        statusCode: removeWatermarkStatusCode!,
        requestOptions: RequestOptions(
          path: '/api/generations/$generationId/remove-watermark',
        ),
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(
            path: '/api/generations/$generationId/remove-watermark',
          ),
          statusCode: removeWatermarkStatusCode,
          data: const {'title': 'economy.insufficient_balance'},
        ),
      );
    }

    generation = generation.copyWith(
      outputUrl: 'https://cdn.petmagic.test/result-clean.jpg?signature=secret',
      hasWatermark: false,
      canRemoveWatermark: false,
      isWatermarkRemoved: true,
      watermarkMessage: 'Watermark removed',
    );
    return const RemoveGenerationWatermarkResult(
      watermarkRemoved: true,
      creditsSpent: 1,
      remainingCredits: 2,
      mediaUrl: 'https://cdn.petmagic.test/result-clean.jpg',
    );
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    CancelToken? cancelToken,
  }) async {
    analyticsEvents.add(eventType);
    analyticsCalls.add(
      _AnalyticsCall(
        templateId: templateId,
        eventType: eventType,
        generationId: generationId,
        metadata: metadata,
      ),
    );
  }
}

class _AnalyticsCall {
  const _AnalyticsCall({
    required this.templateId,
    required this.eventType,
    required this.generationId,
    required this.metadata,
  });

  final String templateId;
  final String eventType;
  final String? generationId;
  final Map<String, Object?> metadata;
}

class _DelayedLoadTemplateGenerationRepository
    extends TemplateGenerationRepository {
  _DelayedLoadTemplateGenerationRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final fetchStarted = Completer<CancelToken>();

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    if (!fetchStarted.isCompleted) {
      fetchStarted.complete(token);
    }

    await token.whenCancel;
    throw DioException.requestCancelled(
      requestOptions: RequestOptions(path: ''),
      reason: 'generation_status_load_cancelled',
    );
  }
}

class _IdleGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }

  @override
  Future<void> mergeFetchedGeneration(
    TemplateGenerationResult generation,
  ) async {}

  @override
  Future<void> markRead(String generationId) async {}
}

class _TrackingGenerationHistoryController
    extends _IdleGenerationHistoryController {
  final List<String> mergedGenerationIds = [];
  final List<TemplateGenerationResult> mergedGenerations = [];

  @override
  Future<void> mergeFetchedGeneration(
    TemplateGenerationResult generation,
  ) async {
    mergedGenerationIds.add(generation.generationId);
    mergedGenerations.add(generation);
    state = state.copyWith(items: [generation]);
  }
}

class _DelayedGenerationStatusMediaActions
    extends GenerationStatusMediaActions {
  final shareStarted = Completer<void>();
  CancelToken? shareCancelToken;

  @override
  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required CancelToken cancelToken,
    String? localPath,
  }) {
    shareCancelToken = cancelToken;
    if (!shareStarted.isCompleted) {
      shareStarted.complete();
    }
    return cancelToken.whenCancel.then((_) {});
  }
}

class _RecordingGenerationStatusMediaActions
    extends GenerationStatusMediaActions {
  int saveCalls = 0;
  int shareCalls = 0;
  final savedFileNames = <String>[];
  final sharedFileNames = <String>[];
  final savedLocalPaths = <String?>[];
  final sharedLocalPaths = <String?>[];

  @override
  Future<bool> saveToGallery({
    required String mediaUrl,
    required String fileName,
    required bool isVideo,
    required String albumName,
    required CancelToken cancelToken,
    String? localPath,
  }) async {
    saveCalls++;
    savedFileNames.add(fileName);
    savedLocalPaths.add(localPath);
    return true;
  }

  @override
  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required CancelToken cancelToken,
    String? localPath,
  }) async {
    shareCalls++;
    sharedFileNames.add(fileName);
    sharedLocalPaths.add(localPath);
  }
}

class _DelayedGenerationGalleryStore extends GenerationGalleryStore {
  _DelayedGenerationGalleryStore()
    : super(
        dio: Dio(),
        preferences: SharedPreferencesAsync(),
        sessionStorage: AuthSessionStorage(),
        rootDirectoryResolver: () async => Directory.systemTemp,
      );

  final materializeStarted = Completer<void>();
  final materializeCompleter = Completer<GenerationGalleryMediaRecord?>();
  int cancelActiveDownloadsCalls = 0;

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation,
  ) async {
    if (!materializeStarted.isCompleted) {
      materializeStarted.complete();
    }
    return materializeCompleter.future;
  }

  @override
  Future<void> cancelActiveDownloads() async {
    cancelActiveDownloadsCalls++;
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
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation,
  ) async {
    return null;
  }

  @override
  Future<void> cancelActiveDownloads() async {}
}

class _ImmediateGenerationGalleryStore extends GenerationGalleryStore {
  _ImmediateGenerationGalleryStore({required this.record})
    : super(
        dio: Dio(),
        preferences: SharedPreferencesAsync(),
        sessionStorage: AuthSessionStorage(),
        rootDirectoryResolver: () async => Directory.systemTemp,
      );

  final GenerationGalleryMediaRecord record;

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation,
  ) async {
    return record;
  }

  @override
  Future<void> cancelActiveDownloads() async {}
}

TemplateGenerationResult _generation({
  String generationId = 'generation-1',
  String templateTitle = 'Movie Star Pet Poster',
  TemplateGenerationStatus status = TemplateGenerationStatus.completed,
  bool hasWatermark = false,
  bool canRemoveWatermark = false,
  bool isWatermarkRemoved = false,
  int removeWatermarkCostCredits = 1,
  String userPlan = 'free',
  String? watermarkMessage,
  bool supportsGenerateSimilar = false,
  String? failureCode,
  String? inputPreviewUrl,
  String? resultPreviewUrl,
  bool canCompareBeforeAfter = false,
  String? localOutputPath,
  String? petId,
  String? petPhotoId,
}) {
  final now = DateTime.utc(2026, 5, 25, 14, 30);
  return TemplateGenerationResult(
    generationId: generationId,
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: 6,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    completedAtUtc: now,
    failureCode: failureCode,
    userMediaExpired: false,
    templateTitle: templateTitle,
    templateType: 'image',
    outputUrl: 'https://cdn.petmagic.test/result.jpg?signature=secret',
    hasWatermark: hasWatermark,
    canRemoveWatermark: canRemoveWatermark,
    isWatermarkRemoved: isWatermarkRemoved,
    removeWatermarkCostCredits: removeWatermarkCostCredits,
    userPlan: userPlan,
    watermarkMessage: watermarkMessage,
    supportsGenerateSimilar: supportsGenerateSimilar,
    inputPreviewUrl: inputPreviewUrl,
    resultPreviewUrl: resultPreviewUrl,
    canCompareBeforeAfter: canCompareBeforeAfter,
    localOutputPath: localOutputPath,
    petId: petId,
    petPhotoId: petPhotoId,
  );
}

TemplateOfTheDayItem _templateOfTheDay() {
  return TemplateOfTheDayItem(
    templateId: 'template-1',
    title: 'Movie Star Pet Poster',
    subtitle: 'Today magic idea',
    badgeText: 'Template of the Day',
    templateType: TemplateType.image,
    isPremium: false,
    requiredPlan: 'free',
    date: DateTime.utc(2026, 6, 14),
    source: 'auto',
  );
}

String _methodBody(String source, String methodName) {
  final methodIndex = source.indexOf(methodName);
  if (methodIndex < 0) {
    fail('Method $methodName was not found.');
  }

  final asyncBodyIndex = source.indexOf('async {', methodIndex);
  final syncBodyIndex = source.indexOf(') {', methodIndex);
  final openBraceIndex =
      asyncBodyIndex >= 0 &&
          (syncBodyIndex < 0 || asyncBodyIndex < syncBodyIndex)
      ? source.indexOf('{', asyncBodyIndex)
      : source.indexOf('{', syncBodyIndex);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}
