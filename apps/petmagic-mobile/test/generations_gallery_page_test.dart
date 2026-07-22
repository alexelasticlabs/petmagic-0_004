import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'generations_gallery_page_test_support.dart';
import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();
  configureGenerationsGalleryPageTestHarness();

  for (final configuration in const [
    _GalleryGoldenConfiguration('compact', Size(320, 568)),
    _GalleryGoldenConfiguration('phone', Size(390, 844)),
    _GalleryGoldenConfiguration('tablet', Size(834, 1194)),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'creations ${configuration.name} ${brightness.name} visual baseline',
        (tester) async {
          const pathProviderChannel = MethodChannel(
            'plugins.flutter.io/path_provider',
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            pathProviderChannel,
            (call) async => Directory.systemTemp.path,
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              pathProviderChannel,
              null,
            );
          });
          tester.view.physicalSize = configuration.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final harness = GalleryHarness(
            networkStatusController: TestGalleryNetworkStatusController(
              initialHasInternet: true,
            ),
          );
          addTearDown(harness.router.dispose);

          await tester.pumpWidget(
            harness.app(brightness: brightness, disableAnimations: true),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(Scaffold).first,
            matchesGoldenFile(
              'goldens/creations_${configuration.name}_${brightness.name}.png',
            ),
          );
        },
      );
    }
  }

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

  testWidgets('renders load-more footer and calls controller loadMore', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness(
      initialState: GenerationHistoryState(
        items: sampleGalleryItems(),
        hasMore: true,
        nextCursor: 'cursor-2',
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);
    final galleryScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.text(text.generationStatusLoadMoreAction),
      260,
      scrollable: galleryScrollable,
    );
    await tester.tap(find.text(text.generationStatusLoadMoreAction));
    await tester.pump();

    expect(harness.controller.loadMoreCalls, 1);
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

  testWidgets(
    'gallery skips wallet preload when wallet snapshot is fully hydrated',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final walletController = TrackingGalleryWalletController(
        hasWallet: true,
        hasCompletedFullLoad: true,
      );
      final harness = GalleryHarness(walletController: walletController);
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.app());
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 0);
    },
  );

  testWidgets('gallery preloads wallet for partial wallet snapshot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final walletController = TrackingGalleryWalletController(hasWallet: true);
    final harness = GalleryHarness(walletController: walletController);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pump();
    await tester.pump();

    expect(walletController.loadCalls, 1);
  });

  testWidgets(
    'gallery defers wallet preload while offline and retries on reconnect',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final walletController = TrackingGalleryWalletController();
      final networkController = TestGalleryNetworkStatusController(
        initialHasInternet: false,
      );
      final harness = GalleryHarness(
        walletController: walletController,
        networkStatusController: networkController,
      );
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.app());
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 0);

      networkController.setHasInternet(true);
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
      networkStatusController: TestGalleryNetworkStatusController(
        initialHasInternet: true,
      ),
    );
    addTearDown(loadingHarness.router.dispose);

    await tester.pumpWidget(loadingHarness.app(disableAnimations: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/shared_loading.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);

    final errorHarness = GalleryHarness(
      initialState: const GenerationHistoryState(
        errorMessage: 'Network is unavailable',
      ),
      networkStatusController: TestGalleryNetworkStatusController(
        initialHasInternet: true,
      ),
    );
    addTearDown(errorHarness.router.dispose);

    await tester.pumpWidget(errorHarness.app(disableAnimations: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    var text = galleryText(tester);
    expect(find.text(text.templatesRequestFailedError), findsOneWidget);
    expect(find.text('Network is unavailable'), findsNothing);
    expect(find.text(text.retryAction), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/shared_error.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final keyedErrorHarness = GalleryHarness(
      initialState: const GenerationHistoryState(
        errorMessage: 'templates.connection_timeout',
      ),
      networkStatusController: TestGalleryNetworkStatusController(
        initialHasInternet: true,
      ),
    );
    addTearDown(keyedErrorHarness.router.dispose);

    await tester.pumpWidget(keyedErrorHarness.app(disableAnimations: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    text = galleryText(tester);
    expect(find.text(text.templatesConnectionTimeoutError), findsOneWidget);
    expect(find.text('templates.connection_timeout'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final emptyHarness = GalleryHarness(
      items: const [],
      networkStatusController: TestGalleryNetworkStatusController(
        initialHasInternet: true,
      ),
    );
    addTearDown(emptyHarness.router.dispose);

    await tester.pumpWidget(emptyHarness.app(disableAnimations: true));
    await tester.pumpAndSettle();
    expect(find.text(text.generationStatusEmptyTitle), findsOneWidget);
    expect(find.text(text.generationStatusEmptyMessage), findsOneWidget);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/shared_empty.png'),
    );
  });

  testWidgets('gallery renders offline and recovered data banners', (
    tester,
  ) async {
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => Directory.systemTemp.path,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProviderChannel,
        null,
      );
    });
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
      networkStatusController: TestGalleryNetworkStatusController(
        initialHasInternet: false,
      ),
    );
    addTearDown(offlineHarness.router.dispose);

    await tester.pumpWidget(offlineHarness.app(disableAnimations: true));
    await tester.pumpAndSettle();
    var text = galleryText(tester);
    expect(find.text(text.generationStatusOfflineBannerTitle), findsOneWidget);
    expect(find.text(text.generationStatusOnlineBannerTitle), findsNothing);
    expect(find.text(text.retryAction), findsOneWidget);
    expect(find.text('Offline Ready'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/shared_offline.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final recoveredHarness = GalleryHarness(
      initialState: GenerationHistoryState(
        items: [item],
        showOfflineBanner: true,
        isConnectionRecovered: true,
        lastSyncedAtUtc: now,
      ),
      networkStatusController: TestGalleryNetworkStatusController(
        initialHasInternet: true,
      ),
    );
    addTearDown(recoveredHarness.router.dispose);

    await tester.pumpWidget(recoveredHarness.app(disableAnimations: true));
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
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => Directory.systemTemp.path,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProviderChannel,
        null,
      );
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = GalleryHarness(
      networkStatusController: TestGalleryNetworkStatusController(
        initialHasInternet: true,
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app(disableAnimations: true));
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
    expect(find.text(text.generationStatusEtaNotifyHint), findsOneWidget);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/shared_pending.png'),
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
      'text': 'https://app.petmagic.app/share/generation/token',
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
      'lib/features/templates/presentation/generations_gallery_page_media_actions.dart',
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

  test('gallery gold CTA foreground is derived from its button tone', () {
    final chromeSource = _readGalleryChromeSource();

    expect(chromeSource, contains('final backgroundColor = colors.gold;'));
    expect(
      chromeSource,
      contains('final foregroundColor = colors.on(backgroundColor);'),
    );
    expect(chromeSource, isNot(contains('Color(0xFFF5BD3E)')));
    expect(
      chromeSource,
      isNot(contains('foregroundColor: const Color(0xFF241403)')),
    );
  });

  test('gallery premium upsell uses theme tokens for chrome copy', () {
    final chromeSource = _readGalleryChromeSource();

    expect(chromeSource, contains('final accent = colors.gold;'));
    expect(
      chromeSource,
      contains('border: Border.all(color: accent.withValues(alpha: 0.74))'),
    );
    expect(chromeSource, contains('color: colors.textStrong'));
    expect(chromeSource, contains('colors.textSoft.withValues('));
    expect(chromeSource, isNot(contains('const Color(0xFFF2C14E)')));
    expect(chromeSource, isNot(contains('const Color(0xFFFFC342)')));
    expect(chromeSource, isNot(contains('const Color(0xFF735018)')));
    expect(chromeSource, isNot(contains('const Color(0xFFFFD776)')));
    expect(chromeSource, isNot(contains('const Color(0xFF2D3B54)')));
  });

  test('gallery type badge foreground is derived from badge tone', () {
    final actionsSource = File(
      'lib/features/templates/presentation/generations_gallery_page_states.dart',
    ).readAsStringSync();

    expect(
      actionsSource,
      contains('final foreground = colors.on(background);'),
    );
    expect(actionsSource, contains('color: foreground'));
    expect(
      actionsSource,
      isNot(
        contains(
          'color: Colors.white,\n            fontWeight: FontWeight.w800',
        ),
      ),
    );
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
    expect(mediaActions.savedUrls, [
      'https://cdn.petmagic.test/fresh-download.jpg',
    ]);
    expect(mediaActions.shareCalls, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready card disables media actions for expired media', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = DelayedGalleryGenerationStatusMediaActions(
      delayShare: false,
    );
    final repository = FakeGalleryTemplateGenerationRepository();
    final generation = galleryGenerationFixture(
      generationId: 'g-expired-media',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Expired Media',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      galleryMedia: const GalleryMedia(
        state: GalleryMediaState.expired,
        mediaType: 'image',
        previewUrl: null,
        resultUrl: null,
        canDownload: false,
        canShare: false,
        userMessageKey: 'gallery.media.expired',
      ),
    );
    final harness = GalleryHarness(
      items: [generation],
      mediaActions: mediaActions,
      repository: repository,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    expect(find.text('Expired Media'), findsOneWidget);
    expect(find.text(text.generationStatusMediaExpiredMessage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    expect(
      find.text(text.generationStatusMediaExpiredMessage),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(
      find.text(text.generationStatusSaveAction),
      warnIfMissed: false,
    );
    await tester.tap(
      find.text(text.supportChatShareAction),
      warnIfMissed: false,
    );
    await tester.tap(
      find.text(text.generationStatusCopyLinkAction),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repository.downloadCalls, isEmpty);
    expect(repository.shareCalls, isEmpty);
    expect(mediaActions.saveCalls, 0);
    expect(mediaActions.shareCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready cards render explicit media availability messages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.utc(2026, 5, 25, 14, 30);
    final harness = GalleryHarness(
      items: [
        galleryGenerationFixture(
          generationId: 'g-preparing-media',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Preparing Media',
          templateType: 'image',
          tokenCost: 6,
          updatedAtUtc: now,
          galleryMedia: const GalleryMedia(
            state: GalleryMediaState.watermarkPreparing,
            mediaType: 'image',
            canDownload: false,
            canShare: false,
            userMessageKey: 'gallery.media.watermarkPreparing',
          ),
        ),
        galleryGenerationFixture(
          generationId: 'g-unavailable-media',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Unavailable Media',
          templateType: 'image',
          tokenCost: 6,
          updatedAtUtc: now.subtract(const Duration(minutes: 1)),
          galleryMedia: const GalleryMedia(
            state: GalleryMediaState.storageUnavailable,
            mediaType: 'image',
            canDownload: false,
            canShare: false,
            userMessageKey: 'gallery.media.storageUnavailable',
          ),
        ),
        galleryGenerationFixture(
          generationId: 'g-preview-only',
          status: TemplateGenerationStatus.completed,
          templateTitle: 'Preview Only',
          templateType: 'image',
          tokenCost: 6,
          updatedAtUtc: now.subtract(const Duration(minutes: 2)),
          galleryMedia: const GalleryMedia(
            state: GalleryMediaState.previewReadyOnly,
            mediaType: 'image',
            previewUrl: null,
            resultUrl: null,
            canDownload: false,
            canShare: false,
            userMessageKey: 'gallery.media.previewReadyOnly',
          ),
        ),
      ],
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = galleryText(tester);

    expect(
      find.text(text.generationStatusMediaWatermarkPreparingMessage),
      findsOneWidget,
    );
    expect(
      find.text(text.generationStatusMediaUnavailableMessage),
      findsOneWidget,
    );
    expect(
      find.text(text.generationStatusMediaPreviewOnlyMessage),
      findsOneWidget,
    );
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
      repository: FakeGalleryTemplateGenerationRepository(
        downloadUrl: 'https://cdn.petmagic.test/ready-name.jpg',
        shareUrl: 'https://cdn.petmagic.test/ready-name.jpg',
        downloadFileName: '',
        shareFileName: '',
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

    expect(mediaActions.savedUrls, [
      'https://cdn.petmagic.test/fresh-download.jpg',
    ]);
    expect(mediaActions.savedLocalPaths, [localOutput.path]);

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await pumpUntil(tester, () => mediaActions.shareCalls > 0);

    expect(mediaActions.sharedUrls, [
      'https://cdn.petmagic.test/fresh-share.jpg',
    ]);
    expect(mediaActions.sharedLocalPaths, [localOutput.path]);
    expect(mediaActions.sharedTexts, [
      'https://app.petmagic.app/share/generation/token',
    ]);
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
      repository: FakeGalleryTemplateGenerationRepository(
        downloadUrl: 'https://cdn.petmagic.test/ready-fallback.jpg',
        shareUrl: 'https://cdn.petmagic.test/ready-fallback.jpg',
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

class _GalleryGoldenConfiguration {
  const _GalleryGoldenConfiguration(this.name, this.size);

  final String name;
  final Size size;
}

String _readGalleryChromeSource() {
  return [
    'lib/features/templates/presentation/generations_gallery_page_filters_and_chrome.dart',
    'lib/features/templates/presentation/generations_gallery_page_premium_chrome.part.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}
