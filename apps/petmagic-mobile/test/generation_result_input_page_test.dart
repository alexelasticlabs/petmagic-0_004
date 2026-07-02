import 'dart:async';

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
  _ResultInputRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final Completer<void> startStarted = Completer<void>();
  final Completer<void> _startCompleter = Completer<void>();
  final List<String> analyticsEvents = <String>[];
  final List<String> rememberedGenerationIds = <String>[];

  int startCalls = 0;
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
