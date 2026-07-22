import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'free user can inspect watermark paywall and unlock clean result',
    (tester) async {
      final repository = _IntegrationTemplateGenerationRepository(
        _generation(
          hasWatermark: true,
          canRemoveWatermark: true,
          watermarkMessage: 'Watermark added on the free plan',
        ),
      );
      await _pumpGenerationStatus(tester, repository);
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      expect(find.text(text.generationStatusWatermarkAddedFreePlan), findsOne);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text(text.generationStatusSaveWithWatermark), findsOne);
      expect(find.text(text.generationStatusShareWithWatermark), findsOne);
      expect(find.text(text.generationStatusUpgradePremium), findsOne);

      await tester.tap(find.text(text.generationStatusRemoveWatermark));
      await tester.pumpAndSettle();
      expect(
        find.text(text.generationStatusRemoveWatermarkSheetTitle),
        findsWidgets,
      );
      expect(
        find.text(text.generationStatusRemoveWatermarkUseCredit(1)),
        findsOne,
      );
      expect(repository.analyticsEvents, contains('remove_clicked'));
      expect(repository.analyticsEvents, contains('paywall_viewed'));

      await tester.tap(
        find.text(text.generationStatusRemoveWatermarkUseCredit(1)),
      );
      await tester.pumpAndSettle();

      expect(repository.removeWatermarkCalls, ['generation-1']);
      expect(find.text(text.generationStatusWatermarkRemoved), findsOne);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(
        find.text(text.generationStatusDownloadWithoutWatermark),
        findsOne,
      );
      expect(find.text(text.generationStatusShareWithWatermark), findsNothing);
    },
  );

  testWidgets(
    'premium user sees clean result actions without watermark controls',
    (tester) async {
      final repository = _IntegrationTemplateGenerationRepository(
        _generation(userPlan: 'premium', supportsGenerateSimilar: true),
      );
      await _pumpGenerationStatus(tester, repository);
      final text = AppLocalizations.of(
        tester.element(find.byType(GenerationStatusPage)),
      );

      expect(find.text(text.generationStatusSaveWithWatermark), findsNothing);
      expect(find.text(text.generationStatusRemoveWatermark), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text(text.generationStatusSaveAction), findsOne);
      expect(find.text(text.supportChatShareAction), findsOne);
      expect(find.text('Generate similar'), findsWidgets);
    },
  );
}

Future<void> _pumpGenerationStatus(
  WidgetTester tester,
  TemplateGenerationRepository repository,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 900));
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
}

class _IntegrationTemplateGenerationRepository
    extends TemplateGenerationRepository {
  _IntegrationTemplateGenerationRepository(this.generation)
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  TemplateGenerationResult generation;
  final analyticsEvents = <String>[];
  final removeWatermarkCalls = <String>[];

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    RequestCancellation? cancelToken,
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
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    RequestCancellation? cancelToken,
  }) async {
    removeWatermarkCalls.add(generationId);
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
      mediaUrl: 'https://cdn.petmagic.test/result-clean.jpg?signature=secret',
    );
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    RequestCancellation? cancelToken,
  }) async {
    analyticsEvents.add(eventType);
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

TemplateGenerationResult _generation({
  bool hasWatermark = false,
  bool canRemoveWatermark = false,
  bool isWatermarkRemoved = false,
  String userPlan = 'free',
  String? watermarkMessage,
  bool supportsGenerateSimilar = false,
}) {
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
    hasWatermark: hasWatermark,
    canRemoveWatermark: canRemoveWatermark,
    isWatermarkRemoved: isWatermarkRemoved,
    removeWatermarkCostCredits: 1,
    userPlan: userPlan,
    watermarkMessage: watermarkMessage,
    supportsGenerateSimilar: supportsGenerateSimilar,
  );
}
