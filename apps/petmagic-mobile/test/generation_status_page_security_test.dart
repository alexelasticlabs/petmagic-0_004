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
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
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

    final shareAction = find.text(text.supportChatShareAction);
    await tester.scrollUntilVisible(
      shareAction,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(shareAction);
    await mediaActions.shareStarted.future;
    expect(mediaActions.shareCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(mediaActions.shareCancelToken?.isCancelled, isTrue);
  });
}

class _FakeTemplateGenerationRepository extends TemplateGenerationRepository {
  _FakeTemplateGenerationRepository(this.generation)
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final TemplateGenerationResult generation;

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

TemplateGenerationResult _generation() {
  final now = DateTime.utc(2026, 5, 25, 14, 30);
  return TemplateGenerationResult(
    generationId: 'generation-1',
    userId: 'user-1',
    templateId: 'template-1',
    status: TemplateGenerationStatus.completed,
    tokenCost: 6,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    completedAtUtc: now,
    userMediaExpired: false,
    templateTitle: 'Movie Star Pet Poster',
    templateType: 'image',
    outputUrl: 'https://cdn.petmagic.test/result.jpg?signature=secret',
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
