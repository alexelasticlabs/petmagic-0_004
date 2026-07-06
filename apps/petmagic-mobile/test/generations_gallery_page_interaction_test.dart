import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'generations_gallery_page_test_support.dart';

void main() {
  configureGenerationsGalleryPageTestHarness();

  testWidgets(
    'ready card tap opens details without waiting for markRead sync',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final markReadCompleter = Completer<void>();
      final harness = GalleryHarness(markReadCompleter: markReadCompleter);
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final text = galleryText(tester);

      final readyChip = find.widgetWithText(
        ChoiceChip,
        text.generationStatusFilterReady,
      );
      await tester.ensureVisible(readyChip);
      await tester.tap(readyChip, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Movie Star Pet Poster'));
      await tester.pumpAndSettle();

      expect(harness.controller.markReadCalls, ['g-ready-1']);
      expect(find.text('status:g-ready-1'), findsOneWidget);

      markReadCompleter.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ready card delete removes item and updates unread badge', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness(
      items: [
        galleryGenerationFixture(
          generationId: 'g-ready-delete',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Delete Me',
          templateType: 'image',
          tokenCost: 6,
          outputUrl: 'https://cdn.petmagic.test/delete-me.jpg',
          updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
          isUnread: true,
        ),
      ],
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    expect(find.text('Delete Me'), findsOneWidget);
    expect(find.text(text.generationStatusUnreadCount(1)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusDeleteAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(harness.controller.deleteGenerationCalls, ['g-ready-delete']);
    expect(find.text('Delete Me'), findsNothing);
    expect(find.text(text.generationStatusUnreadCount(1)), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready filter keeps a large creations grid lazy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.utc(2026, 5, 25, 14, 30);
    final harness = GalleryHarness(
      items: List<TemplateGenerationResult>.generate(
        300,
        (index) => galleryGenerationFixture(
          generationId: 'g-ready-$index',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Ready Pet $index',
          templateType: 'image',
          tokenCost: 6,
          updatedAtUtc: now.subtract(Duration(minutes: index)),
        ),
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    final readyChip = find.widgetWithText(
      ChoiceChip,
      text.generationStatusFilterReady,
    );
    await tester.ensureVisible(readyChip);
    await tester.tap(readyChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(harness.controller.loadCalls.last, GenerationHistoryFilter.ready);
    expect(find.text('Ready Pet 0'), findsOneWidget);
    expect(find.text('Ready Pet 299'), findsNothing);
    expect(
      find.byIcon(Icons.more_vert_rounded).evaluate().length,
      lessThan(60),
    );

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(1000));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    expect(
      find.byIcon(Icons.more_vert_rounded).evaluate().length,
      lessThan(60),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery cancels active media share on disposal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = DelayedGalleryGenerationStatusMediaActions();
    final harness = GalleryHarness(
      items: [
        galleryGenerationFixture(
          generationId: 'g-ready-video',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Ready Video',
          templateType: 'video',
          tokenCost: 60,
          outputUrl: 'https://cdn.petmagic.test/result.mp4?signature=secret',
          outputVideoDurationSeconds: 4,
          updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
        ),
      ],
      mediaActions: mediaActions,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await mediaActions.shareStarted.future;

    expect(mediaActions.shareCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(mediaActions.shareCancelToken?.isCancelled, isTrue);
  });

  testWidgets('gallery cancels active media save on disposal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = DelayedGalleryGenerationStatusMediaActions(
      delaySave: true,
    );
    final harness = GalleryHarness(mediaActions: mediaActions);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    final readyChip = find.widgetWithText(
      ChoiceChip,
      text.generationStatusFilterReady,
    );
    await tester.ensureVisible(readyChip);
    await tester.tap(readyChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusSaveAction));
    await mediaActions.saveStarted.future;

    expect(mediaActions.saveCalls, 1);
    expect(mediaActions.saveCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(mediaActions.saveCancelToken?.isCancelled, isTrue);
  });

  testWidgets('ready card blocks duplicate media actions while one is active', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = DelayedGalleryGenerationStatusMediaActions();
    final harness = GalleryHarness(mediaActions: mediaActions);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    final readyChip = find.widgetWithText(
      ChoiceChip,
      text.generationStatusFilterReady,
    );
    await tester.ensureVisible(readyChip);
    await tester.tap(readyChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await mediaActions.shareStarted.future;
    await tester.pumpAndSettle();

    expect(mediaActions.shareCalls, 1);
    expect(mediaActions.saveCalls, 0);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(text.generationStatusSaveAction),
      warnIfMissed: false,
    );
    await tester.tap(
      find.text(text.supportChatShareAction),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(mediaActions.shareCalls, 1);
    expect(mediaActions.saveCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(mediaActions.shareCancelToken?.isCancelled, isTrue);
  });

  test(
    'ready card media actions stop after local-media lookup if unmounted',
    () {
      final source = File(
        'lib/features/templates/presentation/'
        'generations_gallery_page_states_and_actions.dart',
      ).readAsStringSync();
      final saveBody = source.substring(
        source.indexOf('Future<void> _saveGenerationToGallery'),
        source.indexOf('Future<void> _shareGenerationFile'),
      );
      final shareBody = source.substring(
        source.indexOf('Future<void> _shareGenerationFile'),
        source.indexOf('Future<void> _copyGenerationLink'),
      );

      void expectMountedGuardAfterLocalLookup(String body) {
        final localLookupIndex = body.indexOf('await usableLocalMediaPath');
        final mountedGuardIndex = body.indexOf('if (!context.mounted)');
        final safeUriIndex = body.indexOf('parseSafeGenerationMediaUri');
        expect(localLookupIndex, isNonNegative);
        expect(mountedGuardIndex, isNonNegative);
        expect(safeUriIndex, isNonNegative);
        expect(localLookupIndex, lessThan(mountedGuardIndex));
        expect(mountedGuardIndex, lessThan(safeUriIndex));
        expect(
          body,
          contains(
            'galleryState._completeMediaAction(mediaActionCancelToken);',
          ),
        );
      }

      expectMountedGuardAfterLocalLookup(saveBody);
      expectMountedGuardAfterLocalLookup(shareBody);
    },
  );

  testWidgets('ready card media actions use fresh backend access URLs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final mediaActions = DelayedGalleryGenerationStatusMediaActions(
      delayShare: false,
    );
    final repository = FakeGalleryTemplateGenerationRepository(
      downloadUrl: 'https://cdn.petmagic.test/fresh-download.jpg?sig=download',
      shareUrl: 'https://cdn.petmagic.test/fresh-share.jpg?sig=share',
      downloadFileName: 'fresh-download.jpg',
      shareFileName: 'fresh-share.jpg',
      durableShareUrl: 'https://app.petmagic.app/share/generation/g-ready',
    );
    final harness = GalleryHarness(
      items: [
        galleryGenerationFixture(
          generationId: 'g-ready-unsafe',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Unsafe Ready',
          templateType: 'image',
          tokenCost: 6,
          outputUrl: 'javascript:alert(1)',
          updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
        ),
      ],
      mediaActions: mediaActions,
      repository: repository,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusSaveAction));
    await tester.pump();

    expect(repository.downloadCalls, ['g-ready-unsafe']);
    expect(mediaActions.saveCalls, 1);
    expect(mediaActions.savedUrls, [
      'https://cdn.petmagic.test/fresh-download.jpg?sig=download',
    ]);
    expect(mediaActions.savedFileNames, ['fresh-download.jpg']);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await tester.pump();

    expect(repository.shareCalls, ['g-ready-unsafe']);
    expect(mediaActions.shareCalls, 1);
    expect(mediaActions.sharedUrls, [
      'https://cdn.petmagic.test/fresh-share.jpg?sig=share',
    ]);
    expect(mediaActions.sharedFileNames, ['fresh-share.jpg']);
    expect(mediaActions.sharedTexts, [
      'https://app.petmagic.app/share/generation/g-ready',
    ]);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusCopyLinkAction));
    await tester.pump();

    expect(
      platformCalls
          .where((call) => call.method == 'Clipboard.setData')
          .map((call) => call.arguments)
          .toList(),
      [
        {'text': 'https://app.petmagic.app/share/generation/g-ready'},
      ],
    );
    expect(repository.shareCalls, ['g-ready-unsafe', 'g-ready-unsafe']);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready card media actions handle unavailable fresh access', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final mediaActions = DelayedGalleryGenerationStatusMediaActions(
      delayShare: false,
    );
    final repository = FakeGalleryTemplateGenerationRepository(
      downloadUrl: '',
      shareUrl: '',
      downloadFileName: '',
      shareFileName: '',
      durableShareUrl: '',
    );
    final harness = GalleryHarness(
      items: [
        galleryGenerationFixture(
          generationId: 'g-ready-not-ready',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Not Ready',
          templateType: 'image',
          tokenCost: 6,
          outputUrl: 'https://cdn.petmagic.test/stale.jpg?signature=old',
          updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
        ),
      ],
      mediaActions: mediaActions,
      repository: repository,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusSaveAction));
    await tester.pump();

    expect(repository.downloadCalls, ['g-ready-not-ready']);
    expect(mediaActions.saveCalls, 0);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await tester.pump();

    expect(repository.shareCalls, ['g-ready-not-ready']);
    expect(mediaActions.shareCalls, 0);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusCopyLinkAction));
    await tester.pump();

    expect(repository.shareCalls, ['g-ready-not-ready', 'g-ready-not-ready']);
    expect(
      platformCalls.where((call) => call.method == 'Clipboard.setData'),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('active card tap marks read and opens details', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Little Space Explorer'));
    await tester.pumpAndSettle();

    expect(harness.controller.markReadCalls, contains('g-active-1'));
    expect(find.text('status:g-active-1'), findsOneWidget);
  });

  testWidgets('failed card buttons preserve pet context and open support', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    final failedChip = find.widgetWithText(
      ChoiceChip,
      text.generationStatusFilterFailed,
    );
    await tester.ensureVisible(failedChip);
    await tester.tap(failedChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(text.generationStatusPickAnotherPhotoAction).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('templates-route'), findsOneWidget);
    expect(find.text('templates-pet:pet/route'), findsOneWidget);
    expect(find.text('templates-photo:photo route'), findsOneWidget);

    harness.router.go(GenerationsGalleryPage.routePath);
    await tester.pumpAndSettle();

    await tester.ensureVisible(failedChip);
    await tester.tap(failedChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(text.generationStatusContactSupportAction).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('support-route'), findsOneWidget);
    expect(find.text('support-generation:g-failed-1'), findsOneWidget);
  });

  testWidgets('failed card action sheet marks unread generation read', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final failed = galleryGenerationFixture(
      generationId: 'g-failed-unread',
      status: TemplateGenerationStatus.failed,
      templateTitle: 'Failed Unread',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      isUnread: true,
    );
    final harness = GalleryHarness(items: [failed]);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    final failedChip = find.widgetWithText(
      ChoiceChip,
      text.generationStatusFilterFailed,
    );
    await tester.ensureVisible(failedChip);
    await tester.tap(failedChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ListTile, text.generationStatusOpenStatusAction),
    );
    await tester.pumpAndSettle();

    expect(harness.controller.markReadCalls, ['g-failed-unread']);
    expect(find.text('status:g-failed-unread'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed card action sheet preserves pet context for templates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final failed = galleryGenerationFixture(
      generationId: 'g-failed-pet',
      status: TemplateGenerationStatus.failed,
      templateTitle: 'Failed Pet Photo',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      petId: 'pet/sheet',
      petPhotoId: 'photo sheet',
    );
    final harness = GalleryHarness(items: [failed]);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    final failedChip = find.widgetWithText(
      ChoiceChip,
      text.generationStatusFilterFailed,
    );
    await tester.ensureVisible(failedChip);
    await tester.tap(failedChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(text.generationStatusPickAnotherPhotoAction).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('templates-route'), findsOneWidget);
    expect(find.text('templates-pet:pet/sheet'), findsOneWidget);
    expect(find.text('templates-photo:photo sheet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery does not force refresh when tab is hidden and shown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(GalleryTickerModeHost(child: harness.app()));
    await tester.pumpAndSettle();

    expect(harness.controller.refreshCalls, isEmpty);
    expect(harness.controller.loadCalls, [GenerationHistoryFilter.all]);
    expect(harness.controller.screenVisibilityCalls, [true]);

    final hostState = tester.state<GalleryTickerModeHostState>(
      find.byType(GalleryTickerModeHost),
    );

    hostState.setEnabled(false);
    await tester.pump();
    await tester.pump();
    expect(harness.controller.screenVisibilityCalls, [true, false]);

    hostState.setEnabled(true);
    await tester.pump();
    await tester.pump();

    expect(harness.controller.refreshCalls, isEmpty);
    expect(harness.controller.loadCalls, [GenerationHistoryFilter.all]);
    expect(harness.controller.screenVisibilityCalls, [true, false, true]);
  });

  testWidgets('gallery premium upsell fits narrow widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness(hasPremiumAccess: false);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Экспорт без водяного знака'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
