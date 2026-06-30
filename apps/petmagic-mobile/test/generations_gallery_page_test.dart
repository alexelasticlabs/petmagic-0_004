import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() async {
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets('renders sections and expands ready grid', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final harness = _GalleryHarness(authenticated: false);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text(text.authSignInRequired), findsOneWidget);
    expect(find.text(text.generationStatusEmptyMessage), findsOneWidget);
    expect(find.text(text.profileSignInAction), findsOneWidget);
    expect(harness.controller.screenVisibilityCalls, [false]);
    expect(harness.controller.loadCalls, isEmpty);
  });

  testWidgets('gallery renders loading error and empty states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final loadingHarness = _GalleryHarness(
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

    final errorHarness = _GalleryHarness(
      initialState: const GenerationHistoryState(
        errorMessage: 'Network is unavailable',
      ),
    );
    addTearDown(errorHarness.router.dispose);

    await tester.pumpWidget(errorHarness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    var text = _text(tester);
    expect(find.text('Network is unavailable'), findsOneWidget);
    expect(find.text(text.retryAction), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final keyedErrorHarness = _GalleryHarness(
      initialState: const GenerationHistoryState(
        errorMessage: 'templates.connection_timeout',
      ),
    );
    addTearDown(keyedErrorHarness.router.dispose);

    await tester.pumpWidget(keyedErrorHarness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    text = _text(tester);
    expect(find.text(text.templatesConnectionTimeoutError), findsOneWidget);
    expect(find.text('templates.connection_timeout'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final emptyHarness = _GalleryHarness(items: const []);
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
    final item = _generation(
      generationId: 'g-ready-offline',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Offline Ready',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/offline-ready.jpg',
      updatedAtUtc: now,
    );
    final offlineHarness = _GalleryHarness(
      initialState: GenerationHistoryState(
        items: [item],
        showOfflineBanner: true,
        lastSyncedAtUtc: now,
      ),
    );
    addTearDown(offlineHarness.router.dispose);

    await tester.pumpWidget(offlineHarness.app());
    await tester.pumpAndSettle();
    var text = _text(tester);
    expect(find.text(text.generationStatusOfflineBannerTitle), findsOneWidget);
    expect(find.text(text.generationStatusOnlineBannerTitle), findsNothing);
    expect(find.text(text.retryAction), findsOneWidget);
    expect(find.text('Offline Ready'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final recoveredHarness = _GalleryHarness(
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
    text = _text(tester);
    expect(find.text(text.generationStatusOnlineBannerTitle), findsOneWidget);
    expect(find.text(text.generationStatusOfflineBannerTitle), findsNothing);
    expect(find.text(text.retryAction), findsNothing);
    expect(find.text('Offline Ready'), findsOneWidget);
  });

  testWidgets('filter chips call load and show filtered items', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

  testWidgets('ready card save action saves safe media URL', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mediaActions = _DelayedGenerationStatusMediaActions();
    final harness = _GalleryHarness(mediaActions: mediaActions);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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
    await _pumpUntil(tester, () => mediaActions.saveCalls > 0);

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

    final mediaActions = _DelayedGenerationStatusMediaActions(
      delayShare: false,
    );
    final generation = _generation(
      generationId: 'g/ready #1?x=2',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Movie *Star* / Pet?',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-name.jpg',
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
    );
    final harness = _GalleryHarness(
      items: [generation],
      mediaActions: mediaActions,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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
    await _pumpUntil(tester, () => mediaActions.shareCalls > 0);

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

    final mediaActions = _DelayedGenerationStatusMediaActions(
      delayShare: false,
    );
    final generation = _generation(
      generationId: 'g-ready-local',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Local Ready',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      localOutputPath: localOutput.path,
    );
    final harness = _GalleryHarness(
      items: [generation],
      mediaActions: mediaActions,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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
    await _pumpUntil(tester, () => mediaActions.saveCalls > 0);

    expect(mediaActions.savedUrls, ['']);
    expect(mediaActions.savedLocalPaths, [localOutput.path]);

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await _pumpUntil(tester, () => mediaActions.shareCalls > 0);

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

    final mediaActions = _DelayedGenerationStatusMediaActions(
      delayShare: false,
    );
    final generation = _generation(
      generationId: 'g-ready-corrupt',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Corrupt Local Ready',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-fallback.jpg',
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      localOutputPath: localOutput.path,
    );
    final harness = _GalleryHarness(
      items: [generation],
      mediaActions: mediaActions,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final generation = _generation(
      generationId: 'g-ready-preview-corrupt',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Corrupt Preview Ready',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-preview-fallback.jpg',
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      localPreviewPath: localPreview.path,
    );
    final harness = _GalleryHarness(items: [generation]);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

  testWidgets(
    'ready card tap opens details without waiting for markRead sync',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final markReadCompleter = Completer<void>();
      final harness = _GalleryHarness(markReadCompleter: markReadCompleter);
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final text = _text(tester);

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

    final harness = _GalleryHarness(
      items: [
        _generation(
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
    final text = _text(tester);

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
    final harness = _GalleryHarness(
      items: List<TemplateGenerationResult>.generate(
        300,
        (index) => _generation(
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
    final text = _text(tester);

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

    final mediaActions = _DelayedGenerationStatusMediaActions();
    final harness = _GalleryHarness(
      items: [
        _generation(
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
    final text = _text(tester);

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

    final mediaActions = _DelayedGenerationStatusMediaActions(delaySave: true);
    final harness = _GalleryHarness(mediaActions: mediaActions);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final mediaActions = _DelayedGenerationStatusMediaActions();
    final harness = _GalleryHarness(mediaActions: mediaActions);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

  testWidgets('ready card media actions reject unsafe output URLs', (
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

    final mediaActions = _DelayedGenerationStatusMediaActions();
    final harness = _GalleryHarness(
      items: [
        _generation(
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
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusSaveAction));
    await tester.pump();

    expect(mediaActions.saveCalls, 0);
    expect(mediaActions.savedUrls, isEmpty);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.supportChatShareAction));
    await tester.pump();

    expect(mediaActions.shareCalls, 0);
    expect(mediaActions.sharedUrls, isEmpty);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.generationStatusCopyLinkAction));
    await tester.pump();

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

    final harness = _GalleryHarness();
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

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final failed = _generation(
      generationId: 'g-failed-unread',
      status: TemplateGenerationStatus.failed,
      templateTitle: 'Failed Unread',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      isUnread: true,
    );
    final harness = _GalleryHarness(items: [failed]);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final failed = _generation(
      generationId: 'g-failed-pet',
      status: TemplateGenerationStatus.failed,
      templateTitle: 'Failed Pet Photo',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: DateTime.utc(2026, 5, 25, 14, 30),
      petId: 'pet/sheet',
      petPhotoId: 'photo sheet',
    );
    final harness = _GalleryHarness(items: [failed]);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

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

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(_GalleryTickerModeHost(child: harness.app()));
    await tester.pumpAndSettle();

    expect(harness.controller.refreshCalls, isEmpty);
    expect(harness.controller.loadCalls, [GenerationHistoryFilter.all]);
    expect(harness.controller.screenVisibilityCalls, [true]);

    final hostState = tester.state<_GalleryTickerModeHostState>(
      find.byType(_GalleryTickerModeHost),
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

    final harness = _GalleryHarness(hasPremiumAccess: false);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Экспорт без водяного знака'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AppLocalizations _text(WidgetTester tester) {
  final context = tester.element(find.byType(GenerationsGalleryPage).first);
  return AppLocalizations.of(context);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() isDone, {
  int maxPumps = 10,
}) async {
  for (var attempt = 0; attempt < maxPumps && !isDone(); attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _GalleryHarness {
  _GalleryHarness({
    List<TemplateGenerationResult>? items,
    GenerationHistoryState? initialState,
    this.mediaActions,
    this.authenticated = true,
    this.hasPremiumAccess,
    Completer<void>? markReadCompleter,
  }) : controller = _FakeGenerationHistoryController(
         items ?? initialState?.items ?? _sampleItems(),
         initialState: initialState,
         markReadCompleter: markReadCompleter,
       ),
       router = GoRouter(
         initialLocation: GenerationsGalleryPage.routePath,
         routes: [
           GoRoute(
             path: GenerationsGalleryPage.routePath,
             pageBuilder: (context, state) =>
                 const NoTransitionPage(child: GenerationsGalleryPage()),
           ),
           GoRoute(
             path: '${GenerationStatusPage.routePrefix}/:generationId',
             pageBuilder: (context, state) => NoTransitionPage(
               child: Scaffold(
                 body: Center(
                   child: Text(
                     'status:${state.pathParameters['generationId']}',
                   ),
                 ),
               ),
             ),
           ),
           GoRoute(
             path: TemplatesPage.routePath,
             pageBuilder: (context, state) {
               final query = state.uri.queryParameters;
               return NoTransitionPage(
                 child: Scaffold(
                   body: Center(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Text('templates-route'),
                         Text('templates-pet:${query['petId'] ?? ''}'),
                         Text('templates-photo:${query['petPhotoId'] ?? ''}'),
                       ],
                     ),
                   ),
                 ),
               );
             },
           ),
           GoRoute(
             path: SupportChatPage.routePath,
             pageBuilder: (context, state) {
               final query = state.uri.queryParameters;
               return NoTransitionPage(
                 child: Scaffold(
                   body: Center(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Text('support-route'),
                         Text(
                           'support-generation:${query[SupportChatPage.relatedGenerationIdQueryParam] ?? ''}',
                         ),
                         Text(
                           'support-message:${query[SupportChatPage.initialMessageQueryParam] ?? ''}',
                         ),
                       ],
                     ),
                   ),
                 ),
               );
             },
           ),
         ],
       );

  final _FakeGenerationHistoryController controller;
  final GoRouter router;
  final GenerationStatusMediaActions? mediaActions;
  final bool authenticated;
  final bool? hasPremiumAccess;

  Widget app() {
    return ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? _AuthenticatedAppLaunchController.new
              : _UnauthenticatedAppLaunchController.new,
        ),
        generationHistoryControllerProvider.overrideWith(() => controller),
        walletControllerProvider.overrideWith(
          hasPremiumAccess == null
              ? _IdleWalletController.new
              : () => _StaticWalletController(isPremium: hasPremiumAccess!),
        ),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
        if (mediaActions != null)
          generationStatusMediaActionsProvider.overrideWithValue(mediaActions!),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
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

class _UnauthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _StaticWalletController extends WalletController {
  _StaticWalletController({required this.isPremium});

  final bool isPremium;

  @override
  WalletState build() {
    return WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 20,
        adRewardsRemainingToday: 0,
        isPremium: isPremium,
        updatedAtUtc: DateTime.utc(2026, 6, 15),
      ),
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _FakeGenerationHistoryController extends GenerationHistoryController {
  _FakeGenerationHistoryController(
    this._allItems, {
    GenerationHistoryState? initialState,
    Completer<void>? markReadCompleter,
  }) : _initialState = initialState,
       _markReadCompleter = markReadCompleter;

  final List<TemplateGenerationResult> _allItems;
  final GenerationHistoryState? _initialState;
  final Completer<void>? _markReadCompleter;
  final List<GenerationHistoryFilter> loadCalls = [];
  final List<GenerationHistoryFilter> refreshCalls = [];
  final List<String> markReadCalls = [];
  final List<String> deleteGenerationCalls = [];
  final List<bool> screenVisibilityCalls = [];

  @override
  GenerationHistoryState build() {
    final initialState = _initialState;
    if (initialState != null) {
      return initialState;
    }
    final unread = _allItems.where((item) => item.isUnread).length;
    return GenerationHistoryState(items: _allItems, unreadCount: unread);
  }

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {
    screenVisibilityCalls.add(visible);
  }

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    final nextFilter = filter ?? state.filter;
    if (refresh) {
      refreshCalls.add(nextFilter);
    }
    loadCalls.add(nextFilter);
    if (_initialState != null) {
      return;
    }
    final filtered = _applyFilter(nextFilter);

    state = state.copyWith(
      filter: nextFilter,
      items: filtered,
      unreadCount: filtered.where((item) => item.isUnread).length,
      isLoading: false,
      clearError: true,
    );
  }

  @override
  Future<void> markRead(String generationId) async {
    markReadCalls.add(generationId);
    final completer = _markReadCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }

    final updated = [
      for (final item in state.items)
        if (item.generationId == generationId)
          TemplateGenerationResult(
            generationId: item.generationId,
            userId: item.userId,
            templateId: item.templateId,
            status: item.status,
            tokenCost: item.tokenCost,
            attemptCount: item.attemptCount,
            createdAtUtc: item.createdAtUtc,
            updatedAtUtc: item.updatedAtUtc,
            userMediaExpired: item.userMediaExpired,
            templateTitle: item.templateTitle,
            templateType: item.templateType,
            stage: item.stage,
            progressPercent: item.progressPercent,
            estimatedDurationLabel: item.estimatedDurationLabel,
            sourceImageAsset: item.sourceImageAsset,
            normalizedImageUrl: item.normalizedImageUrl,
            referenceMotionUrl: item.referenceMotionUrl,
            outputUrl: item.outputUrl,
            usedPreprocessingModel: item.usedPreprocessingModel,
            usedKlingModel: item.usedKlingModel,
            outputVideoDurationSeconds: item.outputVideoDurationSeconds,
            failureCode: item.failureCode,
            failureMessage: item.failureMessage,
            startedAtUtc: item.startedAtUtc,
            preprocessingCompletedAtUtc: item.preprocessingCompletedAtUtc,
            motionGenerationCompletedAtUtc: item.motionGenerationCompletedAtUtc,
            mediaImportCompletedAtUtc: item.mediaImportCompletedAtUtc,
            completedAtUtc: item.completedAtUtc,
            chargedAtUtc: item.chargedAtUtc,
            refundedAtUtc: item.refundedAtUtc,
            isUnread: false,
          )
        else
          item,
    ];

    state = state.copyWith(
      items: updated,
      unreadCount: updated.where((item) => item.isUnread).length,
    );
  }

  @override
  Future<void> deleteGeneration(String generationId) async {
    deleteGenerationCalls.add(generationId);
    _allItems.removeWhere((item) => item.generationId == generationId);
    final updated = [
      for (final item in state.items)
        if (item.generationId != generationId) item,
    ];

    state = state.copyWith(
      items: updated,
      unreadCount: updated.where((item) => item.isUnread).length,
    );
  }

  List<TemplateGenerationResult> _applyFilter(GenerationHistoryFilter filter) {
    return switch (filter) {
      GenerationHistoryFilter.all => List<TemplateGenerationResult>.from(
        _allItems,
      ),
      GenerationHistoryFilter.active =>
        _allItems.where((item) => !item.isTerminal).toList(growable: false),
      GenerationHistoryFilter.ready =>
        _allItems.where((item) => item.isCompleted).toList(growable: false),
      GenerationHistoryFilter.failed =>
        _allItems.where((item) => item.isFailed).toList(growable: false),
    };
  }
}

class _DelayedGenerationStatusMediaActions
    extends GenerationStatusMediaActions {
  _DelayedGenerationStatusMediaActions({
    this.delaySave = false,
    this.delayShare = true,
  });

  final bool delaySave;
  final bool delayShare;
  final saveStarted = Completer<void>();
  final shareStarted = Completer<void>();
  CancelToken? saveCancelToken;
  CancelToken? shareCancelToken;
  int saveCalls = 0;
  int shareCalls = 0;
  final savedUrls = <String>[];
  final sharedUrls = <String>[];
  final savedLocalPaths = <String?>[];
  final sharedLocalPaths = <String?>[];
  final savedFileNames = <String>[];
  final sharedFileNames = <String>[];

  @override
  Future<bool> saveToGallery({
    required String mediaUrl,
    required String fileName,
    required bool isVideo,
    required String albumName,
    required CancelToken cancelToken,
    String? localPath,
  }) {
    saveCalls++;
    savedUrls.add(mediaUrl);
    savedLocalPaths.add(localPath);
    savedFileNames.add(fileName);
    saveCancelToken = cancelToken;
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    if (!delaySave) {
      return Future.value(true);
    }
    return cancelToken.whenCancel.then((_) => false);
  }

  @override
  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required CancelToken cancelToken,
    String? localPath,
  }) {
    shareCalls++;
    sharedUrls.add(mediaUrl);
    sharedLocalPaths.add(localPath);
    sharedFileNames.add(fileName);
    shareCancelToken = cancelToken;
    if (!shareStarted.isCompleted) {
      shareStarted.complete();
    }
    if (!delayShare) {
      return Future.value();
    }
    return cancelToken.whenCancel.then((_) {});
  }
}

List<TemplateGenerationResult> _sampleItems() {
  final now = DateTime.utc(2026, 5, 25, 14, 30);

  return [
    _generation(
      generationId: 'g-active-1',
      status: TemplateGenerationStatus.generating,
      templateTitle: 'Little Space Explorer',
      templateType: 'video',
      tokenCost: 60,
      stage: 'generating',
      progressPercent: 65,
      estimatedDurationLabel: '1-2 мин',
      outputVideoDurationSeconds: 5,
      updatedAtUtc: now,
      isUnread: true,
    ),
    _generation(
      generationId: 'g-active-2',
      status: TemplateGenerationStatus.queued,
      templateTitle: 'Birthday Pet Party',
      templateType: 'video',
      tokenCost: 40,
      stage: 'queued',
      progressPercent: 15,
      updatedAtUtc: now.subtract(const Duration(minutes: 1)),
    ),
    _generation(
      generationId: 'g-ready-1',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Movie Star Pet Poster',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-1.jpg',
      updatedAtUtc: now.subtract(const Duration(minutes: 2)),
      isUnread: true,
    ),
    _generation(
      generationId: 'g-ready-2',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Superhero Pet',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: now.subtract(const Duration(minutes: 3)),
    ),
    _generation(
      generationId: 'g-ready-3',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Dance With Me',
      templateType: 'video',
      tokenCost: 60,
      outputVideoDurationSeconds: 4,
      updatedAtUtc: now.subtract(const Duration(minutes: 4)),
    ),
    _generation(
      generationId: 'g-ready-4',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Magic Wizard',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: now.subtract(const Duration(minutes: 5)),
    ),
    _generation(
      generationId: 'g-ready-5',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Hidden Ready',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: now.subtract(const Duration(minutes: 6)),
    ),
    _generation(
      generationId: 'g-failed-1',
      status: TemplateGenerationStatus.failed,
      templateTitle: 'Funny Hoodie',
      templateType: 'video',
      tokenCost: 60,
      stage: 'finalizing',
      updatedAtUtc: now.subtract(const Duration(minutes: 7)),
      refundedAtUtc: now.subtract(const Duration(minutes: 6)),
      petId: 'pet/route',
      petPhotoId: 'photo route',
    ),
  ];
}

TemplateGenerationResult _generation({
  required String generationId,
  required TemplateGenerationStatus status,
  required String templateTitle,
  required String templateType,
  required int tokenCost,
  required DateTime updatedAtUtc,
  String? stage,
  int? progressPercent,
  String? estimatedDurationLabel,
  String? outputUrl,
  double? outputVideoDurationSeconds,
  DateTime? refundedAtUtc,
  bool isUnread = false,
  String? localPreviewPath,
  String? localOutputPath,
  String? petId,
  String? petPhotoId,
}) {
  return TemplateGenerationResult(
    generationId: generationId,
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: tokenCost,
    attemptCount: 1,
    createdAtUtc: updatedAtUtc.subtract(const Duration(minutes: 2)),
    updatedAtUtc: updatedAtUtc,
    userMediaExpired: false,
    templateTitle: templateTitle,
    templateType: templateType,
    stage: stage,
    progressPercent: progressPercent,
    estimatedDurationLabel: estimatedDurationLabel,
    outputUrl: outputUrl,
    outputVideoDurationSeconds: outputVideoDurationSeconds,
    refundedAtUtc: refundedAtUtc,
    isUnread: isUnread,
    localPreviewPath: localPreviewPath,
    localOutputPath: localOutputPath,
    petId: petId,
    petPhotoId: petPhotoId,
  );
}

class _GalleryTickerModeHost extends StatefulWidget {
  const _GalleryTickerModeHost({required this.child});

  final Widget child;

  @override
  State<_GalleryTickerModeHost> createState() => _GalleryTickerModeHostState();
}

class _GalleryTickerModeHostState extends State<_GalleryTickerModeHost> {
  bool _enabled = true;

  void setEnabled(bool enabled) {
    setState(() {
      _enabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: _enabled, child: widget.child);
  }
}
