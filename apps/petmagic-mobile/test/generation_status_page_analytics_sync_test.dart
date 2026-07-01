import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'generation_status_page_test_support.dart';

void main() {
  configureGenerationStatusPageTestHarness();

  testWidgets(
    'generation status records template of the day completion after polling',
    (tester) async {
      final repository = FakeGenerationStatusTemplateGenerationRepository(
        generationStatusFixture(status: TemplateGenerationStatus.queued),
      );
      final featured = templateOfTheDayFixture();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
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
            home: GenerationStatusPage(
              generationId: 'generation-1',
              templateOfTheDay: featured,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(repository.analyticsEvents, isEmpty);

      repository.generation = generationStatusFixture(
        status: TemplateGenerationStatus.completed,
        userPlan: 'premium',
      );
      await tester.pump(const Duration(seconds: 8));
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
    final repository = FakeGenerationStatusTemplateGenerationRepository(
      generationStatusFixture(
        status: TemplateGenerationStatus.failed,
        failureCode: 'provider_failed',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
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
          home: GenerationStatusPage(
            generationId: 'generation-1',
            templateOfTheDay: templateOfTheDayFixture(),
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

      final repository = FakeGenerationStatusTemplateGenerationRepository(
        generationStatusFixture(
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
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
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

      final repository = FakeGenerationStatusTemplateGenerationRepository(
        generationStatusFixture(
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
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
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

      final repository = FakeGenerationStatusTemplateGenerationRepository(
        generationStatusFixture(
          userPlan: 'premium',
          supportsGenerateSimilar: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
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

      final generation = generationStatusFixture(
        generationId: 'generation-fresh',
        templateTitle: 'Fresh Pet Portrait',
      );
      final historyController = TrackingGenerationStatusHistoryController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateGenerationRepositoryProvider.overrideWithValue(
              FakeGenerationStatusTemplateGenerationRepository(generation),
            ),
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
            ),
            generationHistoryControllerProvider.overrideWith(
              () => historyController,
            ),
            generationGalleryStoreProvider.overrideWithValue(
              NoopGenerationStatusGalleryStore(),
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

      final generation = generationStatusFixture(
        generationId: 'generation-local',
        templateTitle: 'Local Pet Portrait',
      );
      final historyController = TrackingGenerationStatusHistoryController();
      final store = ImmediateGenerationStatusGalleryStore(
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
              FakeGenerationStatusTemplateGenerationRepository(generation),
            ),
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
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
