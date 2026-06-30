import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'generation_status_page_test_support.dart';

void main() {
  final generationStatusPageSource = File(
    'lib/features/templates/presentation/generation_status_page.dart',
  ).readAsStringSync();
  final generationStatusLibrarySource = readGenerationStatusLibrarySource();
  final generationStatusSectionsLibrarySource =
      readGenerationStatusSectionsLibrarySource();

  configureGenerationStatusPageTestHarness();

  test('generation status load errors are mapped before reaching UI state', () {
    final source = generationStatusLibrarySource;
    final loadBody = methodBody(source, 'Future<void> _load');
    final errorBody = methodBody(
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

  test('generation status feedback UI stays in a dedicated part file', () {
    final pageSource = generationStatusPageSource;
    final sectionsSource = File(
      'lib/features/templates/presentation/generation_status_page_sections.dart',
    ).readAsStringSync();
    final feedbackSource = File(
      'lib/features/templates/presentation/generation_status_page_feedback.part.dart',
    ).readAsStringSync();

    expect(
      pageSource,
      contains("part 'generation_status_page_feedback.part.dart';"),
    );
    expect(sectionsSource, isNot(contains('class _FeedbackCard')));
    expect(sectionsSource, isNot(contains('class _ProblemFeedbackSheet')));
    expect(sectionsSource, isNot(contains('class _NegativeFeedbackSheet')));
    expect(feedbackSource, contains("part of 'generation_status_page.dart';"));
    expect(feedbackSource, contains('class _FeedbackCard'));
    expect(feedbackSource, contains('class _ProblemFeedbackSheet'));
    expect(feedbackSource, contains('class _NegativeFeedbackSheet'));
  });

  test('generation status compare viewer stays in a dedicated part file', () {
    final pageSource = generationStatusPageSource;
    final sectionsSource = File(
      'lib/features/templates/presentation/generation_status_page_sections.dart',
    ).readAsStringSync();
    final compareSource = File(
      'lib/features/templates/presentation/generation_status_page_compare_viewer.part.dart',
    ).readAsStringSync();

    expect(
      pageSource,
      contains("part 'generation_status_page_compare_viewer.part.dart';"),
    );
    expect(sectionsSource, isNot(contains('class _BeforeAfterCompareViewer')));
    expect(sectionsSource, isNot(contains('class _CompareImageLayer')));
    expect(sectionsSource, isNot(contains('class _CompareViewerSkeleton')));
    expect(compareSource, contains("part of 'generation_status_page.dart';"));
    expect(compareSource, contains('class _BeforeAfterCompareViewer'));
    expect(compareSource, contains('class _CompareImageLayer'));
    expect(compareSource, contains('class _CompareViewerSkeleton'));
  });

  test('generation status fullscreen viewer stays in a dedicated part file', () {
    final pageSource = generationStatusPageSource;
    final sectionsSource = File(
      'lib/features/templates/presentation/generation_status_page_sections.dart',
    ).readAsStringSync();
    final fullscreenSource = File(
      'lib/features/templates/presentation/generation_status_page_fullscreen_viewer.part.dart',
    ).readAsStringSync();

    expect(
      pageSource,
      contains("part 'generation_status_page_fullscreen_viewer.part.dart';"),
    );
    expect(sectionsSource, isNot(contains('class _FullscreenResultViewer')));
    expect(sectionsSource, isNot(contains('class _FullscreenVideoControls')));
    expect(
      fullscreenSource,
      contains("part of 'generation_status_page.dart';"),
    );
    expect(fullscreenSource, contains('class _FullscreenResultViewer'));
    expect(fullscreenSource, contains('class _FullscreenVideoControls'));
    expect(fullscreenSource, contains('parseSafeGenerationMediaUri(mediaUrl)'));
    expect(fullscreenSource, contains('_resultFullscreenImageCacheWidth'));
  });

  test(
    'generation status async feedback and toast paths guard mounted state',
    () {
      final source = generationStatusLibrarySource;

      final ratingBody = methodBody(
        source,
        'Future<void> _handleRatingSelected',
      );
      expect(ratingBody, contains('if (!mounted || result == null)'));

      final submitBody = methodBody(source, 'Future<void> _submitFeedback');
      expect(submitBody, contains('if (!mounted)'));
      expect(
        submitBody.indexOf('if (!mounted)'),
        lessThan(submitBody.indexOf('_setPageState(')),
      );

      final showInfoBody = methodBody(source, 'void _showInfo');
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
      final source = generationStatusLibrarySource;
      final buildBody = methodBody(source, 'Widget build');
      final backBody = methodBody(source, 'void _handleBackNavigation');

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
              FakeGenerationStatusTemplateGenerationRepository(
                generationStatusFixture(),
              ),
            ),
            generationHistoryControllerProvider.overrideWith(
              IdleGenerationStatusHistoryController.new,
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

  testWidgets(
    'active generation status exposes gallery continuation without cancel',
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
              FakeGenerationStatusTemplateGenerationRepository(
                generationStatusFixture(
                  status: TemplateGenerationStatus.processing,
                ),
              ),
            ),
            generationHistoryControllerProvider.overrideWith(
              IdleGenerationStatusHistoryController.new,
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

      expect(find.text(text.generationStatusBackgroundHint), findsOneWidget);
      expect(find.text('Cancel generation'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text(text.generationStatusOpenGalleryAction), findsOneWidget);
      expect(find.text('Cancel generation'), findsNothing);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.tap(find.text(text.generationStatusContinueInAppAction));
      await tester.pumpAndSettle();
      expect(find.text('creations-route'), findsOneWidget);
    },
  );

  testWidgets('generation status failed action preserves pet context', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeGenerationStatusTemplateGenerationRepository(
      generationStatusFixture(
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
            IdleGenerationStatusHistoryController.new,
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
    final source = generationStatusLibrarySource;
    final buildBody = methodBody(source, 'Widget build');
    final sheetBody = methodBody(source, 'Future<void> _openActionsSheet');
    final retryBody = methodBody(source, 'void _retrySoon');

    expect(buildBody, contains('onRetry: () => _retrySoon(generation)'));
    expect(
      RegExp(
        r'_templatesLocationForGeneration\(generation\)',
      ).allMatches(buildBody).length,
      greaterThanOrEqualTo(1),
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
      final source = generationStatusLibrarySource;
      final saveBody = methodBody(source, 'Future<void> _saveToGallery');
      final shareBody = methodBody(source, 'Future<void> _shareResult');

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
    final source = generationStatusSectionsLibrarySource.replaceAll(
      '\r\n',
      '\n',
    );

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
    final pageSource = generationStatusLibrarySource;
    final sectionsSource = generationStatusSectionsLibrarySource;
    final compareSource = File(
      'lib/features/templates/presentation/generation_status_page_compare_viewer.part.dart',
    ).readAsStringSync();
    final fullscreenSource = File(
      'lib/features/templates/presentation/generation_status_page_fullscreen_viewer.part.dart',
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
    expect(fullscreenSource, contains('parseSafeGenerationMediaUri(mediaUrl)'));
    expect(
      fullscreenSource,
      contains('VideoPlayerController.networkUrl(safeUri)'),
    );
    expect(fullscreenSource, contains('imageUrl: safeMediaUrl'));
    expect(
      fullscreenSource,
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
    expect(compareSource, contains('class _BeforeAfterCompareViewer'));
  });

  test(
    'generation status local media sync checks page lifecycle before apply',
    () {
      final source = generationStatusLibrarySource;
      final materializeBody = methodBody(
        source,
        'Future<void> _materializeLocalMediaAndRefresh',
      );
      final lifecycleGuardBody = methodBody(
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
              FakeGenerationStatusTemplateGenerationRepository(
                generationStatusFixture(
                  canCompareBeforeAfter: true,
                  inputPreviewUrl:
                      'https://cdn.petmagic.test/before.jpg?signature=secret',
                  resultPreviewUrl:
                      'https://cdn.petmagic.test/after.jpg?signature=secret',
                ),
              ),
            ),
            generationHistoryControllerProvider.overrideWith(
              IdleGenerationStatusHistoryController.new,
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
              FakeGenerationStatusTemplateGenerationRepository(
                generationStatusFixture(),
              ),
            ),
            generationHistoryControllerProvider.overrideWith(
              IdleGenerationStatusHistoryController.new,
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
    final repository =
        DelayedLoadGenerationStatusTemplateGenerationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          generationHistoryControllerProvider.overrideWith(
            IdleGenerationStatusHistoryController.new,
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
}
