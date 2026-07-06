import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_result_input_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('cancels result-input generation start when page is disposed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(const {});
    final repository = _ResultInputRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(_FundedWalletController.new),
        ],
        child: const _ResultInputTestApp(generationId: 'parent/1?source=ready'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Magic motion'), findsOneWidget);

    await tester.tap(find.text('Magic motion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();

    await repository.startStarted.future;
    expect(repository.startCalls, 1);
    expect(repository.startCancelToken, isNotNull);
    expect(repository.startCancelToken!.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.startCancelToken!.isCancelled, isTrue);

    repository.completeStart();
    await tester.pump();

    expect(repository.rememberedGenerationIds, isEmpty);
    expect(repository.analyticsEvents, ['template_selected']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'result-input page stays offline without loading and retries on reconnect',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _ResultInputRepository();
      final networkController = _TestGenerationResultNetworkStatusController(
        false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            walletControllerProvider.overrideWith(_FundedWalletController.new),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
          ],
          child: const _ResultInputTestApp(
            generationId: 'parent/1?source=ready',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(repository.fetchGenerationCalls, 0);
      expect(repository.fetchCompatibleTemplatesCalls, 0);
      expect(find.text("You're offline"), findsOneWidget);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.fetchGenerationCalls, 1);
      expect(repository.fetchCompatibleTemplatesCalls, 1);
      expect(find.text('Magic motion'), findsOneWidget);
    },
  );

  testWidgets('cancels in-flight result-input load when network goes offline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final loadCompleter = Completer<void>();
    final repository = _ResultInputRepository(loadCompleter: loadCompleter);
    final networkController = _TestGenerationResultNetworkStatusController(
      true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(_FundedWalletController.new),
          networkStatusControllerProvider.overrideWith(() => networkController),
        ],
        child: const _ResultInputTestApp(generationId: 'parent/1?source=ready'),
      ),
    );

    await repository.loadStarted.future;
    expect(repository.fetchGenerationCancelToken?.isCancelled, isFalse);
    expect(
      repository.fetchCompatibleTemplatesCancelToken?.isCancelled,
      isFalse,
    );

    networkController.setHasInternet(false);
    await tester.pump();

    expect(repository.fetchGenerationCancelToken?.isCancelled, isTrue);
    expect(repository.fetchCompatibleTemplatesCancelToken?.isCancelled, isTrue);
    expect(find.text("You're offline"), findsOneWidget);

    loadCompleter.complete();
    await tester.pump();

    expect(find.text('Magic motion'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancels result-input generation start when network goes offline',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(const {});
      final repository = _ResultInputRepository();
      final networkController = _TestGenerationResultNetworkStatusController(
        true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            walletControllerProvider.overrideWith(_FundedWalletController.new),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
          ],
          child: const _ResultInputTestApp(
            generationId: 'parent/1?source=ready',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Magic motion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pump();

      await repository.startStarted.future;
      expect(repository.startCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await tester.pump();

      expect(repository.startCancelToken?.isCancelled, isTrue);

      repository.completeStart();
      await tester.pump();

      expect(repository.rememberedGenerationIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test('result-input load ignores generic failures after cancellation', () {
    final source = File(
      'lib/features/templates/presentation/generation_result_input_page.dart',
    ).readAsStringSync();
    final loadBody = _methodBody(source, '_load');
    final genericCatchIndex = loadBody.indexOf('} on Object {');
    final canceledGuardIndex = loadBody.indexOf(
      'if (!mounted || cancelToken.isCancelled)',
      genericCatchIndex,
    );
    final errorStateIndex = loadBody.indexOf(
      '_error = _copy.error;',
      genericCatchIndex,
    );
    final finallyIndex = loadBody.indexOf('} finally {', genericCatchIndex);

    expect(genericCatchIndex, isNonNegative);
    expect(canceledGuardIndex, isNonNegative);
    expect(errorStateIndex, isNonNegative);
    expect(canceledGuardIndex, lessThan(errorStateIndex));
    expect(finallyIndex, isNonNegative);
    expect(loadBody, contains('if (identical(_cancelToken, cancelToken))'));
    expect(loadBody, contains('_cancelToken = null;'));
  });
}

class _ResultInputTestApp extends StatelessWidget {
  const _ResultInputTestApp({required this.generationId});

  final String generationId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: GenerationResultInputPage(generationId: generationId),
    );
  }
}

class _FundedWalletController extends WalletController {
  @override
  WalletState build() {
    return WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 100,
        adRewardsRemainingToday: 0,
        isPremium: false,
        updatedAtUtc: DateTime.utc(2026, 6, 15),
      ),
      isLoading: false,
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _ResultInputRepository extends TemplateGenerationRepository {
  _ResultInputRepository({this.loadCompleter})
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final Completer<void>? loadCompleter;
  final Completer<void> startStarted = Completer<void>();
  final Completer<void> loadStarted = Completer<void>();
  final Completer<void> _startCompleter = Completer<void>();
  final List<String> analyticsEvents = <String>[];
  final List<String> rememberedGenerationIds = <String>[];

  int fetchGenerationCalls = 0;
  int fetchCompatibleTemplatesCalls = 0;
  int startCalls = 0;
  CancelToken? fetchGenerationCancelToken;
  CancelToken? fetchCompatibleTemplatesCancelToken;
  CancelToken? startCancelToken;

  void completeStart() {
    if (!_startCompleter.isCompleted) {
      _startCompleter.complete();
    }
  }

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    fetchGenerationCalls++;
    fetchGenerationCancelToken = cancelToken;
    if (!loadStarted.isCompleted) {
      loadStarted.complete();
    }
    await loadCompleter?.future;
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/templates/generations'),
        type: DioExceptionType.cancel,
      );
    }
    return _generation(
      generationId: generationId,
      status: TemplateGenerationStatus.completed,
    );
  }

  @override
  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    CancelToken? cancelToken,
  }) async {
    fetchCompatibleTemplatesCalls++;
    fetchCompatibleTemplatesCancelToken = cancelToken;
    if (!loadStarted.isCompleted) {
      loadStarted.complete();
    }
    await loadCompleter?.future;
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/api/templates/generations/compatible',
        ),
        type: DioExceptionType.cancel,
      );
    }
    return const CompatibleGenerationTemplates(
      resultId: 'parent/1?source=ready',
      inputMediaType: TemplateType.image,
      templates: [
        CompatibleGenerationTemplate(
          id: 'template/with?reserved=id',
          title: 'Magic motion',
          templateType: TemplateType.video,
          isPremium: false,
          isRecommended: true,
          tokenCost: 3,
          version: 7,
        ),
      ],
    );
  }

  @override
  Future<void> recordTemplateAnalyticsEvent({
    required String templateId,
    required String eventType,
    String source = 'mobile',
    String? generationId,
    Map<String, Object?>? metadata,
    CancelToken? cancelToken,
  }) async {
    analyticsEvents.add(eventType);
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromResult({
    required String parentGenerationResultId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    startCalls++;
    startCancelToken = cancelToken;
    if (!startStarted.isCompleted) {
      startStarted.complete();
    }
    await _startCompleter.future;
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/api/templates/generations/from-result',
        ),
        type: DioExceptionType.cancel,
      );
    }
    return _generation(
      generationId: 'child-generation-1',
      status: TemplateGenerationStatus.queued,
    );
  }

  @override
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) async {
    rememberedGenerationIds.add(generationId);
  }
}

class _TestGenerationResultNetworkStatusController
    extends NetworkStatusController {
  _TestGenerationResultNetworkStatusController(this.initialHasInternet);

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}

TemplateGenerationResult _generation({
  required String generationId,
  required TemplateGenerationStatus status,
}) {
  final now = DateTime.utc(2026, 6, 15);
  return TemplateGenerationResult(
    generationId: generationId,
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: 3,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    userMediaExpired: false,
    templateTitle: 'Ready portrait',
  );
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'Future<void>\s+' + methodName + r'\s*\([^)]*\)\s*(?:async\s*)?\{',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = source.indexOf('{', methodMatch.start);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(openBraceIndex, index + 1);
      }
    }
  }

  fail('Method $methodName body was not closed.');
}
