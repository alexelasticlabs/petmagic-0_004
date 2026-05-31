import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
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

    expect(find.text('Hidden Ready'), findsNothing);
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

  testWidgets('ready card action sheet exposes all actions and opens details', (
    tester,
  ) async {
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

    expect(find.text(text.generationStatusOpenStatusAction), findsOneWidget);
    expect(find.text(text.generationStatusSaveAction), findsOneWidget);
    expect(find.text(text.supportChatShareAction), findsOneWidget);
    expect(find.text(text.generationStatusDeleteAction), findsOneWidget);
    expect(find.text(text.generationStatusReportProblemAction), findsOneWidget);

    await tester.tap(find.text(text.generationStatusOpenStatusAction));
    await tester.pumpAndSettle();

    expect(find.text('status:g-ready-1'), findsOneWidget);
  });

  testWidgets('active card open button marks read and opens details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GalleryHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final text = _text(tester);

    await tester.tap(find.text(text.generationStatusOpenStatusAction).first);
    await tester.pumpAndSettle();

    expect(harness.controller.markReadCalls, contains('g-active-1'));
    expect(find.text('status:g-active-1'), findsOneWidget);
  });

  testWidgets('failed card buttons navigate to templates and support', (
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
  });
}

AppLocalizations _text(WidgetTester tester) {
  final context = tester.element(find.byType(GenerationsGalleryPage).first);
  return AppLocalizations.of(context);
}

class _GalleryHarness {
  _GalleryHarness()
    : controller = _FakeGenerationHistoryController(_sampleItems()),
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
                  child: Text('status:${state.pathParameters['generationId']}'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: TemplatesPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Center(child: Text('templates-route'))),
            ),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Center(child: Text('support-route'))),
            ),
          ),
        ],
      );

  final _FakeGenerationHistoryController controller;
  final GoRouter router;

  Widget app() {
    return ProviderScope(
      overrides: [
        generationHistoryControllerProvider.overrideWith(() => controller),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
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

class _FakeGenerationHistoryController extends GenerationHistoryController {
  _FakeGenerationHistoryController(this._allItems);

  final List<TemplateGenerationResult> _allItems;
  final List<GenerationHistoryFilter> loadCalls = [];
  final List<String> markReadCalls = [];

  @override
  GenerationHistoryState build() {
    final unread = _allItems.where((item) => item.isUnread).length;
    return GenerationHistoryState(items: _allItems, unreadCount: unread);
  }

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    final nextFilter = filter ?? state.filter;
    loadCalls.add(nextFilter);
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
  double? outputVideoDurationSeconds,
  DateTime? refundedAtUtc,
  bool isUnread = false,
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
    outputVideoDurationSeconds: outputVideoDurationSeconds,
    refundedAtUtc: refundedAtUtc,
    isUnread: isUnread,
  );
}
