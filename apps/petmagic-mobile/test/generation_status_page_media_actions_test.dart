import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'generation_status_page_test_support.dart';

void main() {
  configureGenerationStatusPageTestHarness();

  testWidgets('generation status cancels active media share on disposal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = DelayedGenerationStatusMediaActions();
    final generation = generationStatusFixture();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedGenerationStatusAppLaunchController.new,
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            FakeGenerationStatusTemplateGenerationRepository(generation),
          ),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
          generationHistoryControllerProvider.overrideWith(
            IdleGenerationStatusHistoryController.new,
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

    final shareAction = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text.supportChatShareAction),
    );
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

      final repository = FakeGenerationStatusTemplateGenerationRepository(
        generationStatusFixture(),
        mediaAccessUrl: 'javascript:alert(1)',
      );
      final mediaActions = RecordingGenerationStatusMediaActions();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedGenerationStatusAppLaunchController.new,
            ),
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
            ),
            generationHistoryControllerProvider.overrideWith(
              IdleGenerationStatusHistoryController.new,
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
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.generationStatusSaveAction),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.fetchDownloadCalls, 1);
      expect(mediaActions.saveCalls, 0);
      await PetMagicNotificationCenter.instance.clearQueue();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.supportChatShareAction),
        ),
      );
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

      final repository = FakeGenerationStatusTemplateGenerationRepository(
        generationStatusFixture(
          generationId: 'g/ready #1?x=2',
          templateTitle: 'Movie *Star* / Pet?',
          localOutputPath: localOutput.path,
        ),
        mediaAccessFileName: '',
      );
      final mediaActions = RecordingGenerationStatusMediaActions();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedGenerationStatusAppLaunchController.new,
            ),
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
            ),
            generationHistoryControllerProvider.overrideWith(
              IdleGenerationStatusHistoryController.new,
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
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.generationStatusSaveAction),
        ),
      );
      await tester.pump();

      expect(repository.fetchDownloadCalls, 0);
      expect(mediaActions.savedFileNames, ['Movie_Star_Pet_g_ready_1_x_2.jpg']);
      expect(mediaActions.savedLocalPaths, [localOutput.path]);
      await PetMagicNotificationCenter.instance.clearQueue();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.supportChatShareAction),
        ),
      );
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

      final repository = FakeGenerationStatusTemplateGenerationRepository(
        generationStatusFixture(localOutputPath: localOutput.path),
        mediaAccessUrl: 'https://cdn.petmagic.test/result-fallback.jpg',
        mediaAccessFileName: '',
      );
      final mediaActions = RecordingGenerationStatusMediaActions();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedGenerationStatusAppLaunchController.new,
            ),
            templateGenerationRepositoryProvider.overrideWithValue(repository),
            realtimeClientProvider.overrideWithValue(
              const NoopRealtimeClient(),
            ),
            generationHistoryControllerProvider.overrideWith(
              IdleGenerationStatusHistoryController.new,
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
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.generationStatusSaveAction),
        ),
      );
      await tester.pump();

      expect(repository.fetchDownloadCalls, 1);
      expect(mediaActions.savedLocalPaths, [null]);
      expect(mediaActions.savedFileNames, [
        'Movie_Star_Pet_Poster_generation-1.jpg',
      ]);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.supportChatShareAction),
        ),
      );
      await tester.pump();

      expect(repository.fetchShareCalls, 1);
      expect(mediaActions.sharedLocalPaths, [null]);
      expect(mediaActions.sharedFileNames, [
        'Movie_Star_Pet_Poster_generation-1.jpg',
      ]);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation status cancels active local media sync on disposal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = DelayedGenerationStatusGalleryStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedGenerationStatusAppLaunchController.new,
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            FakeGenerationStatusTemplateGenerationRepository(
              generationStatusFixture(),
            ),
          ),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
          generationGalleryStoreProvider.overrideWithValue(store),
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
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedGenerationStatusAppLaunchController.new,
            ),
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

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      final removeAction = find.text(text.generationStatusRemoveWatermark);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.generationStatusShareWithWatermark),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(text.generationStatusSaveWithWatermark),
        ),
        findsOne,
      );
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
}

class _AuthenticatedGenerationStatusAppLaunchController
    extends AppLaunchController {
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
