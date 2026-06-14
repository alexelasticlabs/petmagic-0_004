import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
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

  test('generation result aspect ratio probe is cached and detached', () {
    final source = File(
      'lib/features/templates/presentation/generation_status_page_sections.dart',
    ).readAsStringSync();

    expect(source, contains('CachedNetworkImageProvider('));
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
    expect(pageSource, contains("_recordCompareAnalytics(generation, 'compare_clicked')"));
    expect(sectionsSource, contains('class _BeforeAfterCompareViewer'));
  });

  testWidgets('generation status shows compare action only for eligible image result', (
    tester,
  ) async {
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
  });

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
      expect(
        completionCall.metadata,
        containsPair('source', 'auto'),
      );
      expect(
        completionCall.metadata,
        containsPair('screen', 'generation_status'),
      );
      expect(
        completionCall.metadata,
        containsPair('userPlan', 'premium'),
      );
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
}

class _FakeTemplateGenerationRepository extends TemplateGenerationRepository {
  _FakeTemplateGenerationRepository(
    this.generation, {
    this.removeWatermarkStatusCode,
  }) : super(
         dio: Dio(),
         sessionStorage: AuthSessionStorage(),
         preferences: SharedPreferencesAsync(),
       );

  TemplateGenerationResult generation;
  final int? removeWatermarkStatusCode;
  final List<String> analyticsEvents = [];
  final List<_AnalyticsCall> analyticsCalls = [];
  final List<String> removeWatermarkCalls = [];

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
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    return const GenerationMediaAccessResult(
      mediaUrl: 'https://cdn.petmagic.test/result.jpg',
      hasWatermark: false,
      fileName: 'result.jpg',
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
  Future<void> markRead(String generationId) async {}
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
  }) {
    shareCancelToken = cancelToken;
    if (!shareStarted.isCompleted) {
      shareStarted.complete();
    }
    return cancelToken.whenCancel.then((_) {});
  }
}

TemplateGenerationResult _generation({
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
}) {
  final now = DateTime.utc(2026, 5, 25, 14, 30);
  return TemplateGenerationResult(
    generationId: 'generation-1',
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
    templateTitle: 'Movie Star Pet Poster',
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
