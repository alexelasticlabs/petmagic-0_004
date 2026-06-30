import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'generations_gallery_page_test_support.dart';

void main() {
  configureGenerationsGalleryPageTestHarness();

  testWidgets('renders sections and expands ready grid', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    expect(
      find.text(text.generationStatusSectionActive),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.text(text.generationStatusSectionReady),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.text(text.generationStatusSectionFailed),
      findsAtLeastNWidgets(1),
    );

    expect(find.text('Little Space Explorer'), findsOneWidget);
    expect(find.text('Movie Star Pet Poster'), findsOneWidget);
    expect(find.text('Hidden Ready'), findsNothing);

    final showMore = find.text(text.generationStatusShowMoreAction(1));
    final galleryScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      showMore,
      220,
      scrollable: galleryScrollable,
    );
    await tester.ensureVisible(showMore);
    await tester.pumpAndSettle();
    await tester.tap(showMore, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Hidden Ready'),
      120,
      scrollable: galleryScrollable,
    );
    expect(find.text('Hidden Ready'), findsOneWidget);

    final collapse = find.text(text.generationStatusCollapseAction);
    await tester.ensureVisible(collapse);
    await tester.tap(collapse);
    await tester.pumpAndSettle();

    expect(find.text('Hidden Ready'), findsNothing);
  });

  testWidgets('gallery shows unified auth gate for guests', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness(authenticated: false);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text(text.authSignInRequired), findsOneWidget);
    expect(find.text(text.generationStatusEmptyMessage), findsOneWidget);
    expect(find.text(text.profileSignInAction), findsOneWidget);
    expect(harness.controller.screenVisibilityCalls, [false]);
    expect(harness.controller.loadCalls, isEmpty);
  });

  testWidgets(
    'gallery loads wallet once for authenticated users without duplicates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final walletController = TrackingGalleryWalletController();
      final harness = GalleryHarness(walletController: walletController);
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(GalleryTickerModeHost(child: harness.app()));
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 1);

      final hostState = tester.state<GalleryTickerModeHostState>(
        find.byType(GalleryTickerModeHost),
      );
      hostState.setEnabled(false);
      await tester.pump();
      await tester.pump();

      hostState.setEnabled(true);
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 1);
    },
  );

  testWidgets('gallery does not load wallet for guests', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final walletController = TrackingGalleryWalletController();
    final harness = GalleryHarness(
      authenticated: false,
      walletController: walletController,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(walletController.loadCalls, 0);
  });

  testWidgets('gallery renders loading error and empty states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final loadingHarness = GalleryHarness(
      initialState: const GenerationHistoryState(isLoading: true),
    );
    addTearDown(loadingHarness.router.dispose);

    await tester.pumpWidget(loadingHarness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);

    final errorHarness = GalleryHarness(
      initialState: const GenerationHistoryState(
        errorMessage: 'Network is unavailable',
      ),
    );
    addTearDown(errorHarness.router.dispose);

    await tester.pumpWidget(errorHarness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    var text = galleryText(tester);
    expect(find.text('Network is unavailable'), findsOneWidget);
    expect(find.text(text.retryAction), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final keyedErrorHarness = GalleryHarness(
      initialState: const GenerationHistoryState(
        errorMessage: 'templates.connection_timeout',
      ),
    );
    addTearDown(keyedErrorHarness.router.dispose);

    await tester.pumpWidget(keyedErrorHarness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    text = galleryText(tester);
    expect(find.text(text.templatesConnectionTimeoutError), findsOneWidget);
    expect(find.text('templates.connection_timeout'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final emptyHarness = GalleryHarness(items: const []);
    addTearDown(emptyHarness.router.dispose);

    await tester.pumpWidget(emptyHarness.app());
    await tester.pumpAndSettle();
    expect(find.text(text.generationStatusEmptyTitle), findsOneWidget);
    expect(find.text(text.generationStatusEmptyMessage), findsOneWidget);
  });

  testWidgets('gallery renders offline and recovered data banners', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.utc(2026, 5, 25, 14, 30);
    final item = galleryGenerationFixture(
      generationId: 'g-ready-offline',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Offline Ready',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/offline-ready.jpg',
      updatedAtUtc: now,
    );
    final offlineHarness = GalleryHarness(
      initialState: GenerationHistoryState(
        items: [item],
        showOfflineBanner: true,
        lastSyncedAtUtc: now,
      ),
    );
    addTearDown(offlineHarness.router.dispose);

    await tester.pumpWidget(offlineHarness.app());
    await tester.pumpAndSettle();
    var text = galleryText(tester);
    expect(find.text(text.generationStatusOfflineBannerTitle), findsOneWidget);
    expect(find.text(text.generationStatusOnlineBannerTitle), findsNothing);
    expect(find.text(text.retryAction), findsOneWidget);
    expect(find.text('Offline Ready'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final recoveredHarness = GalleryHarness(
      initialState: GenerationHistoryState(
        items: [item],
        showOfflineBanner: true,
        isConnectionRecovered: true,
        lastSyncedAtUtc: now,
      ),
    );
    addTearDown(recoveredHarness.router.dispose);

    await tester.pumpWidget(recoveredHarness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    text = galleryText(tester);
    expect(find.text(text.generationStatusOnlineBannerTitle), findsOneWidget);
    expect(find.text(text.generationStatusOfflineBannerTitle), findsNothing);
    expect(find.text(text.retryAction), findsNothing);
    expect(find.text('Offline Ready'), findsOneWidget);
  });

  testWidgets('filter chips call load and show filtered items', (tester) async {
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

    expect(harness.controller.loadCalls.last, GenerationHistoryFilter.failed);
    expect(find.text('Funny Hoodie'), findsOneWidget);
    expect(find.text('Little Space Explorer'), findsNothing);
  });

  testWidgets('active filter renders progress and ETA without mixed items', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    final activeChip = find.widgetWithText(
      ChoiceChip,
      text.generationStatusFilterActive,
    );
    await tester.ensureVisible(activeChip);
    await tester.tap(activeChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(harness.controller.loadCalls.last, GenerationHistoryFilter.active);
    expect(find.text('Little Space Explorer'), findsOneWidget);
    expect(find.text('Movie Star Pet Poster'), findsNothing);
    expect(find.text('Funny Hoodie'), findsNothing);
    expect(find.text(text.templateFlowStepCreateMagic), findsOneWidget);
    expect(find.text('65%'), findsOneWidget);
    expect(find.text(text.generationStatusActiveInfoHint), findsOneWidget);
    expect(find.text('Cancel generation'), findsNothing);
    expect(
      find.text(text.generationStatusEtaEstimated('1-2 мин')),
      findsOneWidget,
    );
  });

  testWidgets('failed filter renders reason and recovery actions', (
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

    expect(harness.controller.loadCalls.last, GenerationHistoryFilter.failed);
    expect(find.text('Funny Hoodie'), findsOneWidget);
    expect(find.text('Movie Star Pet Poster'), findsNothing);
    expect(find.text('Little Space Explorer'), findsNothing);
    expect(find.text(text.generationStatusFailedTitle), findsOneWidget);
    expect(
      find.text(text.generationStatusFailureTechnicalHint),
      findsOneWidget,
    );
    expect(find.text(text.generationStatusTokensRefundedShort), findsOneWidget);
    expect(
      find.text(text.generationStatusPickAnotherPhotoAction),
      findsOneWidget,
    );
    expect(
      find.text(text.generationStatusContactSupportAction),
      findsOneWidget,
    );
  });

  testWidgets('ready card action sheet exposes all actions and opens details', (
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

    final harness = GalleryHarness();
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

    expect(find.text(text.generationStatusOpenStatusAction), findsOneWidget);
    expect(find.text(text.generationStatusSaveAction), findsOneWidget);
    expect(find.text(text.supportChatShareAction), findsOneWidget);
    expect(find.text(text.generationStatusCopyLinkAction), findsOneWidget);
    expect(find.text(text.generationStatusDeleteAction), findsOneWidget);
    expect(find.text(text.generationStatusReportProblemAction), findsOneWidget);

    await tester.tap(find.text(text.generationStatusCopyLinkAction));
    await tester.pump();

    final clipboardCall = platformCalls.lastWhere(
      (call) => call.method == 'Clipboard.setData',
    );
    expect(clipboardCall.arguments, {
      'text': 'https://cdn.petmagic.test/ready-1.jpg',
    });
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(text.generationStatusOpenStatusAction));
    await tester.pumpAndSettle();

    expect(harness.controller.markReadCalls, contains('g-ready-1'));
    expect(find.text('status:g-ready-1'), findsOneWidget);
  });

  testWidgets('ready card copy link handles clipboard failures', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard_unavailable');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final harness = GalleryHarness();
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
    await tester.tap(find.text(text.generationStatusCopyLinkAction));
    await tester.pump();

    expect(
      platformCalls.where((call) => call.method == 'Clipboard.setData'),
      hasLength(1),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready card report problem opens support route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness();
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
    await tester.tap(find.text(text.generationStatusReportProblemAction));
    await tester.pumpAndSettle();

    expect(find.text('support-route'), findsOneWidget);
    expect(find.text('support-generation:g-ready-1'), findsOneWidget);
    expect(
      find.textContaining(text.supportTicketFormRelatedGenerationLabel),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('report problem payload uses localized generation status labels', () {
    final pageSource = File(
      'lib/features/templates/presentation/generations_gallery_page.dart',
    ).readAsStringSync();
    final actionsSource = File(
      'lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart',
    ).readAsStringSync();

    expect(
      pageSource,
      contains(
        "import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart'",
      ),
    );
    expect(
      actionsSource,
      contains(
        "'\${text.generationStatusTitle}: \${statusTitle(text, generation)}'",
      ),
    );
    expect(actionsSource, isNot(contains('generation.status.name')));
  });

  testWidgets('ready card save action saves safe media URL', (tester) async {
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
    await tester.tap(find.text(text.generationStatusSaveAction));
    await pumpUntil(tester, () => mediaActions.saveCalls > 0);

    expect(mediaActions.saveCalls, 1);
    expect(mediaActions.savedUrls, ['https://cdn.petmagic.test/ready-1.jpg']);
    expect(mediaActions.shareCalls, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready card media actions sanitize generated file names', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = DelayedGalleryGenerationStatusMediaActions(
      delayShare: false,
    );
    final generation = galleryGenerationFixture(
      generationId: 'g/ready #1?x=2',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Movie *Star* / Pet?',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-name.jpg',
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
    );
    final harness = GalleryHarness(
      items: [generation],
      mediaActions: mediaActions,
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

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusSaveAction));
    await tester.pump();

    expect(mediaActions.savedFileNames, ['Movie_Star_Pet_g_ready_1_x_2.jpg']);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await pumpUntil(tester, () => mediaActions.shareCalls > 0);

    expect(mediaActions.sharedFileNames, ['Movie_Star_Pet_g_ready_1_x_2.jpg']);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready card media actions prefer cached local output file', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tempDir = Directory.systemTemp.createTempSync(
      'petmagic-gallery-local-output-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final localOutput = File(
      '${tempDir.path}${Platform.pathSeparator}ready-local.jpg',
    );
    localOutput.writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    expect(await usableLocalMediaPath(localOutput.path), localOutput.path);

    final mediaActions = DelayedGalleryGenerationStatusMediaActions(
      delayShare: false,
    );
    final generation = galleryGenerationFixture(
      generationId: 'g-ready-local',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Local Ready',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      localOutputPath: localOutput.path,
    );
    final harness = GalleryHarness(
      items: [generation],
      mediaActions: mediaActions,
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

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusSaveAction));
    await pumpUntil(tester, () => mediaActions.saveCalls > 0);

    expect(mediaActions.savedUrls, ['']);
    expect(mediaActions.savedLocalPaths, [localOutput.path]);

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await pumpUntil(tester, () => mediaActions.shareCalls > 0);

    expect(mediaActions.sharedUrls, ['']);
    expect(mediaActions.sharedLocalPaths, [localOutput.path]);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready card media actions ignore corrupted local output file', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tempDir = Directory.systemTemp.createTempSync(
      'petmagic-gallery-corrupt-local-output-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final localOutput = File(
      '${tempDir.path}${Platform.pathSeparator}ready-corrupt.jpg',
    );
    localOutput.writeAsBytesSync('not-media'.codeUnits);

    final mediaActions = DelayedGalleryGenerationStatusMediaActions(
      delayShare: false,
    );
    final generation = galleryGenerationFixture(
      generationId: 'g-ready-corrupt',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Corrupt Local Ready',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-fallback.jpg',
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      localOutputPath: localOutput.path,
    );
    final harness = GalleryHarness(
      items: [generation],
      mediaActions: mediaActions,
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

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusSaveAction));
    await tester.pump();

    expect(mediaActions.savedUrls, [
      'https://cdn.petmagic.test/ready-fallback.jpg',
    ]);
    expect(mediaActions.savedLocalPaths, [null]);

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await tester.pump();

    expect(mediaActions.sharedUrls, [
      'https://cdn.petmagic.test/ready-fallback.jpg',
    ]);
    expect(mediaActions.sharedLocalPaths, [null]);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready card ignores corrupted local preview file', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tempDir = Directory.systemTemp.createTempSync(
      'petmagic-gallery-corrupt-local-preview-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final localPreview = File(
      '${tempDir.path}${Platform.pathSeparator}ready-preview-corrupt.jpg',
    );
    localPreview.writeAsBytesSync('not-media'.codeUnits);

    final generation = galleryGenerationFixture(
      generationId: 'g-ready-preview-corrupt',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Corrupt Preview Ready',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-preview-fallback.jpg',
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      localPreviewPath: localPreview.path,
    );
    final harness = GalleryHarness(items: [generation]);
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

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is FileImage,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
