import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/generation_result_reveal.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/generation_result_quick_actions.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';

import 'generation_status_page_test_support.dart';
import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();
  late Directory directory;
  late File resultFile;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'petmagic-result-experience-',
    );
    final photo = await rootBundle.load(
      'assets/rewards/profile-premium-dog.png',
    );
    resultFile = await File(
      '${directory.path}/result.png',
    ).writeAsBytes(photo.buffer.asUint8List());
  });
  tearDownAll(() async {
    expect(directory.parent.absolute.path, Directory.systemTemp.absolute.path);
    await directory.delete(recursive: true);
  });

  for (final brightness in Brightness.values) {
    testWidgets('completed result ${brightness.name} visual baseline', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      final generation =
          generationStatusFixture(
            localOutputPath: resultFile.path,
            templateTitle: 'Королевский портрет',
          ).copyWith(
            galleryMedia: const GalleryMedia(
              state: GalleryMediaState.resultReady,
              canDownload: true,
              canShare: true,
            ),
          );
      await tester.pumpWidget(_page(generation, brightness: brightness));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(GenerationStatusPage));
        await precacheImage(
          ResizeImage(FileImage(resultFile), width: 1080),
          context,
        );
        if (context.mounted) {
          await precacheImage(
            ResizeImage(FileImage(resultFile), width: 720),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GenerationResultReveal>(find.byType(GenerationResultReveal))
            .ready,
        isTrue,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/creation_result_${brightness.name}.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick actions use existing download and share flows', (
    tester,
  ) async {
    _size(tester, const Size(390, 900));
    final generation = generationStatusFixture().copyWith(
      galleryMedia: const GalleryMedia(
        state: GalleryMediaState.resultReady,
        canDownload: true,
        canShare: true,
      ),
    );
    final repository = FakeGenerationStatusTemplateGenerationRepository(
      generation,
    );
    final actions = RecordingGenerationStatusMediaActions();
    await tester.pumpWidget(
      _page(generation, repository: repository, actions: actions),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('result-quick-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.fetchDownloadCalls, 1);
    expect(actions.saveCalls, 1);
    final share = find.byKey(const ValueKey('result-quick-share'));
    await tester.ensureVisible(share);
    await tester.pumpAndSettle();
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(repository.fetchShareCalls, 1);
    expect(actions.shareCalls, 1);
    await PetMagicNotificationCenter.instance.clearQueue();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick actions prevent duplicate work while sharing', (
    tester,
  ) async {
    _size(tester, const Size(390, 900));
    final generation = generationStatusFixture().copyWith(
      galleryMedia: const GalleryMedia(
        state: GalleryMediaState.resultReady,
        canDownload: true,
        canShare: true,
      ),
    );
    final actions = DelayedGenerationStatusMediaActions();
    await tester.pumpWidget(_page(generation, actions: actions));
    await tester.pumpAndSettle();
    final share = find.byKey(const ValueKey('result-quick-share'));
    await tester.ensureVisible(share);
    await tester.pumpAndSettle();
    await tester.tap(share);
    await tester.pump();
    await actions.shareStarted.future;
    expect(tester.widget<FilledButton>(share).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('result-quick-save')),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(actions.shareCancelToken!.isCancelled, isTrue);
  });

  for (final state in [
    GalleryMediaState.expired,
    GalleryMediaState.hidden,
    GalleryMediaState.previewReadyOnly,
    GalleryMediaState.watermarkPreparing,
    GalleryMediaState.storageUnavailable,
  ]) {
    testWidgets('$state does not offer unavailable media actions', (
      tester,
    ) async {
      var calls = 0;
      final generation = generationStatusFixture().copyWith(
        galleryMedia: GalleryMedia(state: state),
      );
      await tester.pumpWidget(
        _app(
          child: GenerationResultQuickActions(
            generation: generation,
            busy: false,
            onSave: () => calls++,
            onShare: () => calls++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 0);
    });
  }

  for (final language in ['ru', 'en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('$language watermark actions fit at 200 percent text', (
      tester,
    ) async {
      _size(tester, const Size(320, 568));
      var calls = 0;
      final generation = generationStatusFixture(hasWatermark: true).copyWith(
        galleryMedia: const GalleryMedia(
          state: GalleryMediaState.resultReady,
          canDownload: true,
          canShare: true,
        ),
      );
      await tester.pumpWidget(
        _app(
          locale: Locale(language),
          scale: 2,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GenerationResultQuickActions(
                generation: generation,
                busy: false,
                onSave: () => calls++,
                onShare: () => calls++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.tap(find.byType(OutlinedButton));
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduced in [false, true]) {
    testWidgets('reveal waits for media and respects reduced motion $reduced', (
      tester,
    ) async {
      _size(tester, const Size(600, 800));
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      var builds = 0;
      final media = Builder(
        builder: (_) {
          builds++;
          return const SizedBox(width: 300, height: 400);
        },
      );
      await tester.pumpWidget(
        _app(
          reduced: reduced,
          child: ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (_, value, _) =>
                GenerationResultReveal(ready: value, child: media),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      ready.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, !reduced);
      final baselineBuilds = builds;
      await tester.pumpAndSettle();
      expect(builds, baselineBuilds);
      ready.value = false;
      await tester.pump();
      ready.value = true;
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _page(
  TemplateGenerationResult generation, {
  Brightness brightness = Brightness.light,
  FakeGenerationStatusTemplateGenerationRepository? repository,
  GenerationStatusMediaActions? actions,
}) => ProviderScope(
  overrides: [
    networkStatusControllerProvider.overrideWith(
      OnlineWidgetNetworkStatusController.new,
    ),
    appLaunchControllerProvider.overrideWith(
      AuthenticatedWidgetAppLaunchController.new,
    ),
    templateGenerationRepositoryProvider.overrideWithValue(
      repository ??
          FakeGenerationStatusTemplateGenerationRepository(generation),
    ),
    realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
    generationHistoryControllerProvider.overrideWith(
      IdleGenerationStatusHistoryController.new,
    ),
    generationStatusMediaActionsProvider.overrideWithValue(
      actions ?? RecordingGenerationStatusMediaActions(),
    ),
  ],
  child: _app(
    brightness: brightness,
    page: true,
    child: GenerationStatusPage(generationId: generation.generationId),
  ),
);

Widget _app({
  required Widget child,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('ru'),
  double scale = 1,
  bool reduced = false,
  bool page = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: child!,
  ),
  home: page ? child : Scaffold(body: child),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
