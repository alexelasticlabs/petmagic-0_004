import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_entitlement_provider.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';

import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  group('TemplatePreviewSession', () {
    test('detail media kind overrides the generation template type', () {
      final imageDetailForVideoTemplate = _template(
        'video-with-image-detail',
        title: 'Video template',
        templateType: TemplateType.video,
        detailPreviewUrl: 'https://cdn.petmagic.test/detail-without-extension',
        mediaKind: 'image',
      );
      final videoDetailForImageTemplate = _template(
        'image-with-video-detail',
        title: 'Image template',
        detailPreviewUrl: 'https://cdn.petmagic.test/detail-without-extension',
        mediaKind: 'video',
      );

      expect(imageDetailForVideoTemplate.detailPreviewIsVideo, isFalse);
      expect(videoDetailForImageTemplate.detailPreviewIsVideo, isTrue);
    });

    test('deduplicates items while preserving the selected instance', () {
      final first = _template('first', title: 'First');
      final staleSelected = _template('second', title: 'Stale second');
      final selected = _template(
        'second',
        title: 'Selected second',
        tokenCost: 22,
        version: 7,
      );
      final third = _template('third', title: 'Third');

      final session = TemplatePreviewSession.fromSelection(
        items: [first, staleSelected, staleSelected, third],
        selectedTemplate: selected,
        source: TemplatePreviewSource.discovery,
      );

      expect(session.items.map((item) => item.templateId), [
        'first',
        'second',
        'third',
      ]);
      expect(session.initialIndex, 1);
      expect(identical(session.initialTemplate, selected), isTrue);
      expect(session.source, TemplatePreviewSource.discovery);
      expect(() => session.items.add(first), throwsUnsupportedError);
    });
  });

  group('TemplatePreviewPage', () {
    testWidgets(
      'warms both neighbours and defers quality changes during a swipe',
      (tester) async {
        final fixtures = _previewFixtures();
        await _pumpPreviewHost(
          tester,
          session: TemplatePreviewSession(
            items: fixtures.feed,
            initialIndex: 1,
          ),
          repository: _TrackingTemplatesRepository(
            feedItems: fixtures.feed,
            details: fixtures.details,
          ),
        );
        List<TemplateMediaFrame> frames() => tester
            .widgetList<TemplateMediaFrame>(
              find.byType(TemplateMediaFrame, skipOffstage: false),
            )
            .toList();
        expect(frames(), hasLength(3));
        expect(frames().every((frame) => frame.prepareOffscreen), isTrue);
        final registry = frames().first.playbackRegistry;
        expect(registry, isNotNull);
        expect(
          frames().every((frame) => frame.playbackRegistry == registry),
          isTrue,
        );
        expect(frames().every((frame) => frame.playWhenActive), isTrue);

        final gesture = await tester.startGesture(const Offset(300, 300));
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump();
        expect(frames().every((frame) => !frame.allowDetailUpgrade), isTrue);
        expect(frames().every((frame) => frame.prepareOffscreen), isTrue);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(frames().every((frame) => frame.allowDetailUpgrade), isTrue);
        expect(
          frames().every((frame) => frame.playbackRegistry == registry),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('opens on the requested session index', (tester) async {
      final fixtures = _previewFixtures();
      final repository = _TrackingTemplatesRepository(
        feedItems: fixtures.feed,
        details: fixtures.details,
      );

      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: fixtures.feed, initialIndex: 1),
        repository: repository,
      );

      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('template-preview-page-view')),
      );
      expect(pageView.controller?.initialPage, 1);
      expect(
        find.byKey(const ValueKey('template-preview-summary:second')),
        findsOneWidget,
      );
      expect(repository.fetchTemplateIds, ['second']);
      expect(repository.forceRefreshValues, [isFalse]);
      expect(repository.analyticsSources, ['catalog']);
    });

    testWidgets(
      'requires detail at least as new as the selected feed version',
      (tester) async {
        final feed = _template('updated', title: 'Updated', version: 3);
        final cached = _template('updated', title: 'Cached', version: 2);
        final repository = _TrackingTemplatesRepository(
          feedItems: [feed],
          details: {'updated': cached},
        );
        await _pumpPreviewHost(
          tester,
          session: TemplatePreviewSession.single(feed),
          repository: repository,
        );
        expect(repository.minimumVersions, [3]);
        expect(repository.forceRefreshValues, [false]);
        expect(repository.analyticsSources, ['catalog']);
      },
    );

    testWidgets('attributes a featured detail view once', (tester) async {
      final featured = _template('featured', title: 'Featured');
      final repository = _TrackingTemplatesRepository(
        feedItems: [featured],
        details: {'featured': featured},
      );

      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(
          featured,
          source: TemplatePreviewSource.featured,
        ),
        repository: repository,
      );

      expect(repository.fetchTemplateIds, ['featured']);
      expect(repository.analyticsSources, ['featured']);
    });

    testWidgets('centers a selected thumbnail outside the first viewport', (
      tester,
    ) async {
      final items = List<TemplateItem>.generate(
        12,
        (index) => _template('item-$index', title: 'Template $index'),
      );
      final repository = _TrackingTemplatesRepository(
        feedItems: items,
        details: {for (final item in items) item.templateId: item},
      );

      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: items, initialIndex: 10),
        repository: repository,
      );

      final rail = tester.widget<ListView>(
        find.byKey(const ValueKey('template-preview-thumbnail-rail')),
      );
      expect(rail.controller?.offset, greaterThan(0));
      final selectedThumbnail = find.byKey(
        const ValueKey('template-preview-thumbnail:item-10'),
      );
      expect(selectedThumbnail, findsOneWidget);
      expect(
        tester.getCenter(selectedThumbnail).dx,
        closeTo(tester.getCenter(find.byType(ListView)).dx, 1),
      );
    });

    testWidgets('slow short drag snaps back and full swipe commits selection', (
      tester,
    ) async {
      final fixtures = _previewFixtures();
      final repository = _TrackingTemplatesRepository(
        feedItems: fixtures.feed,
        details: fixtures.details,
      );
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: fixtures.feed, initialIndex: 1),
        repository: repository,
      );

      final pageView = find.byKey(const ValueKey('template-preview-page-view'));
      final slowDrag = await tester.startGesture(tester.getCenter(pageView));
      await slowDrag.moveBy(const Offset(-70, 0));
      await tester.pump(const Duration(milliseconds: 700));
      await slowDrag.up();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('template-preview-summary:second')),
        findsOneWidget,
      );
      expect(repository.fetchTemplateIds, ['second']);

      await tester.fling(pageView, const Offset(-360, 0), 900);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('template-preview-summary:third')),
        findsOneWidget,
      );
      expect(repository.fetchTemplateIds, ['second', 'third']);
    });

    testWidgets('thumbnail tap switches the selected template', (tester) async {
      final fixtures = _previewFixtures();
      final repository = _TrackingTemplatesRepository(
        feedItems: fixtures.feed,
        details: fixtures.details,
      );
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: fixtures.feed, initialIndex: 0),
        repository: repository,
      );

      final semantics = tester.ensureSemantics();
      final semanticThumbnail = find.bySemanticsLabel('Third template');
      expect(
        tester
            .getSemantics(semanticThumbnail)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      tester.semantics.performAction(
        find.semantics.byLabel('Third template'),
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('template-preview-summary:third')),
        findsOneWidget,
      );
      expect(repository.fetchTemplateIds, ['first', 'third']);
      semantics.dispose();
    });

    testWidgets('CTA returns the resolved selected template contract', (
      tester,
    ) async {
      final fixtures = _previewFixtures();
      final repository = _TrackingTemplatesRepository(
        feedItems: fixtures.feed,
        details: fixtures.details,
      );
      Object? routeResult;
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: fixtures.feed, initialIndex: 0),
        repository: repository,
        onResult: (result) => routeResult = result,
      );

      await tester.tap(
        find.byKey(const ValueKey('template-preview-thumbnail:third')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('template-preview-cta')));
      await tester.pumpAndSettle();

      expect(routeResult, isA<TemplatePreviewResult>());
      final result = routeResult! as TemplatePreviewResult;
      expect(result.action, TemplateDetailAction.upload);
      expect(result.selectedTemplate.templateId, 'third');
      expect(result.selectedTemplate.version, 303);
      expect(result.selectedTemplate.tokenCost, 33);
    });

    testWidgets('CTA keeps viewer open when required detail refresh fails', (
      tester,
    ) async {
      final template = _template('offline', title: 'Offline template');
      final repository = _FailingTemplatesRepository(template);
      Object? routeResult;
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(template),
        repository: repository,
        onResult: (result) => routeResult = result,
      );

      await tester.tap(find.byKey(const ValueKey('template-preview-cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(routeResult, isNull);
      expect(
        find.byKey(const ValueKey('template-preview-summary:offline')),
        findsOneWidget,
      );
      final text = AppLocalizations.of(
        tester.element(find.byType(TemplatePreviewPage)),
      );
      expect(find.text(text.templatesRequestFailedError), findsOneWidget);
      final cta = tester.widget<FilledButton>(
        find.byKey(const ValueKey('template-preview-cta')),
      );
      expect(cta.onPressed, isNotNull);
      expect(repository.fetchCalls, 2);
    });

    testWidgets(
      'shows description inline and distinguishes result from waiting',
      (tester) async {
        final feed = _template(
          'video-info',
          title: 'Dance',
          templateType: TemplateType.video,
        );
        final repository = _DelayedTemplatesRepository(feedItem: feed);
        await _pumpPreviewHost(
          tester,
          session: TemplatePreviewSession.single(feed),
          repository: repository,
          locale: const Locale('ru'),
        );
        expect(find.text('Dance description'), findsOneWidget);
        expect(find.text('Видео · длительность не указана'), findsOneWidget);
        expect(find.text('Создание обычно занимает 2-4 мин'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('template-preview-details')),
          findsNothing,
        );
        repository.detail.complete(
          _template(
            'video-info',
            title: 'Dance',
            templateType: TemplateType.video,
            referenceVideoDurationSeconds: 5,
            description: 'Ваш питомец повторит движения из ролика.',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Результат: видео ≈ 5 с'), findsOneWidget);
        expect(
          find.text('Ваш питомец повторит движения из ролика.'),
          findsOneWidget,
        );
        expect(find.byType(TemplateDetailContent), findsNothing);
      },
    );

    testWidgets('back during detail hydration never opens a late sheet', (
      tester,
    ) async {
      final template = _template('closing-details', title: 'Closing details');
      final repository = _DelayedTemplatesRepository(feedItem: template);
      var resultCallbacks = 0;
      Object? routeResult = const Object();
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(template),
        repository: repository,
        onResult: (result) {
          resultCallbacks++;
          routeResult = result;
        },
      );
      await tester.tap(find.byKey(const ValueKey('template-preview-back')));
      repository.detail.complete(template);
      await tester.pumpAndSettle();
      expect(find.byType(TemplatePreviewPage), findsNothing);
      expect(find.byType(TemplateDetailContent), findsNothing);
      expect(resultCallbacks, 1);
      expect(routeResult, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('system back during CTA loading cannot pop twice', (
      tester,
    ) async {
      final template = _template('closing-action', title: 'Closing action');
      final repository = _DelayedTemplatesRepository(feedItem: template);
      var resultCallbacks = 0;
      Object? routeResult = const Object();
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(template),
        repository: repository,
        onResult: (result) {
          resultCallbacks++;
          routeResult = result;
        },
      );

      await tester.tap(find.byKey(const ValueKey('template-preview-cta')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      repository.detail.complete(template);
      await tester.pumpAndSettle();

      expect(find.byType(TemplatePreviewPage), findsNothing);
      expect(
        find.byKey(const ValueKey('open-template-preview')),
        findsOneWidget,
      );
      expect(resultCallbacks, 1);
      expect(routeResult, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses free copy and marks video thumbnails before selection', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final image = _template('free-image', title: 'Free image');
      final video = _template(
        'video-next',
        title: 'Video next',
        templateType: TemplateType.video,
      );
      final repository = _TrackingTemplatesRepository(
        feedItems: [image, video],
        details: {'free-image': image, 'video-next': video},
      );
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: [image, video], initialIndex: 0),
        repository: repository,
      );

      final text = AppLocalizations.of(
        tester.element(find.byType(TemplatePreviewPage)),
      );
      expect(find.text(text.freeLabel), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('template-preview-thumbnail:video-next'),
          ),
          matching: find.byKey(const ValueKey('template-preview-video-badge')),
        ),
        findsOneWidget,
      );
      final videoSemantics = tester.getSemantics(
        find.bySemanticsLabel('Video next'),
      );
      expect(videoSemantics.getSemanticsData().hint, text.videoLabel);
      expect(videoSemantics.getSemanticsData().value, '2 / 2');
      semantics.dispose();
    });

    testWidgets('single-item session hides the rail and disables paging', (
      tester,
    ) async {
      final only = _template('only', title: 'Only template');
      final repository = _TrackingTemplatesRepository(
        feedItems: [only],
        details: {'only': only},
      );
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(
          only,
          source: TemplatePreviewSource.deepLink,
          initialDetailResolved: true,
        ),
        repository: repository,
      );

      expect(
        find.byKey(const ValueKey('template-preview-summary:only')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('template-preview-thumbnail-rail')),
        findsNothing,
      );
      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('template-preview-page-view')),
      );
      expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
      expect(
        find.byKey(const ValueKey('template-preview-cta')),
        findsOneWidget,
      );
      expect(repository.fetchTemplateIds, isEmpty);
    });

    testWidgets('fits a compact viewport at 200 percent text scale', (
      tester,
    ) async {
      final fixtures = _previewFixtures();
      final repository = _TrackingTemplatesRepository(
        feedItems: fixtures.feed,
        details: fixtures.details,
      );

      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: fixtures.feed, initialIndex: 1),
        repository: repository,
        viewSize: const Size(320, 568),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('template-preview-summary:second')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('template-preview-cta')),
        findsOneWidget,
      );
    });

    testWidgets('fits Russian video CTA in light theme at 200 percent scale', (
      tester,
    ) async {
      final video = _template(
        'video',
        title: 'Очень длинное название волшебного видео с питомцем',
        templateType: TemplateType.video,
      );
      final repository = _TrackingTemplatesRepository(
        feedItems: [video],
        details: {'video': video},
      );

      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(video),
        repository: repository,
        viewSize: const Size(320, 568),
        textScale: 2,
        locale: const Locale('ru'),
        useLightTheme: true,
      );

      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('template-preview-cta')),
          matching: find.byType(Text),
        ),
      );
      expect(label.data, 'Загрузить фото для видео');
      expect(label.maxLines, 2);
    });

    testWidgets('loads and deduplicates the next preview page near the edge', (
      tester,
    ) async {
      final first = _template('first', title: 'First');
      final second = _template('second', title: 'Second');
      final third = _template('third', title: 'Third');
      var loadCalls = 0;
      final repository = _TrackingTemplatesRepository(
        feedItems: [first, second, third],
        details: {'first': first, 'second': second, 'third': third},
      );

      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(
          items: [first, second],
          initialIndex: 0,
          loadMore: () async {
            loadCalls++;
            return TemplatePreviewPageBatch(
              items: [second, third],
              hasMore: false,
            );
          },
        ),
        repository: repository,
      );

      expect(loadCalls, 1);
      expect(
        find.byKey(const ValueKey('template-preview-thumbnail:third')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('template-preview-thumbnail:second')),
        findsOneWidget,
      );
    });

    testWidgets('offers pagination retry after a transient failure', (
      tester,
    ) async {
      final first = _template('first', title: 'First');
      final second = _template('second', title: 'Second');
      final third = _template('third', title: 'Third');
      var loadCalls = 0;
      final repository = _TrackingTemplatesRepository(
        feedItems: [first, second, third],
        details: {'first': first, 'second': second, 'third': third},
      );

      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(
          items: [first, second],
          initialIndex: 0,
          loadMore: () async {
            loadCalls++;
            if (loadCalls == 1) {
              throw StateError('temporary paging failure');
            }
            return TemplatePreviewPageBatch(items: [third], hasMore: false);
          },
        ),
        repository: repository,
      );

      expect(
        find.byKey(const ValueKey('template-preview-pagination-retry')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('template-preview-pagination-retry')),
      );
      await tester.pumpAndSettle();

      expect(loadCalls, 2);
      expect(
        find.byKey(const ValueKey('template-preview-thumbnail:third')),
        findsOneWidget,
      );
    });

    testWidgets('rechecks premium access after delayed detail resolution', (
      tester,
    ) async {
      final feed = _template('premium-race', title: 'Initially free');
      final resolved = _template(
        'premium-race',
        title: 'Now premium',
        isPremium: true,
      );
      final repository = _DelayedTemplatesRepository(feedItem: feed);
      final navigator = _RecordingAppNavigator();
      Object? routeResult;
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(feed),
        repository: repository,
        hasPremiumAccess: false,
        isAuthenticated: true,
        appNavigator: navigator,
        onResult: (result) => routeResult = result,
      );

      await tester.tap(find.byKey(const ValueKey('template-preview-cta')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('template-preview-details')),
        findsNothing,
      );

      repository.detail.complete(resolved);
      await tester.pumpAndSettle();

      expect(routeResult, isNull);
      expect(navigator.pushes.whereType<PremiumDestination>(), hasLength(1));
      expect(
        find.byKey(const ValueKey('template-preview-summary:premium-race')),
        findsOneWidget,
      );
      expect(repository.analyticsSources, ['catalog']);
    });

    testWidgets('does not open premium when delayed detail becomes free', (
      tester,
    ) async {
      final feed = _template(
        'premium-race-free',
        title: 'Initially premium',
        isPremium: true,
      );
      final resolved = _template('premium-race-free', title: 'Now free');
      final repository = _DelayedTemplatesRepository(feedItem: feed);
      final navigator = _RecordingAppNavigator();
      Object? routeResult;
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(feed),
        repository: repository,
        hasPremiumAccess: false,
        isAuthenticated: true,
        appNavigator: navigator,
        onResult: (result) => routeResult = result,
      );

      await tester.tap(find.byKey(const ValueKey('template-preview-cta')));
      await tester.pump();

      repository.detail.complete(resolved);
      await tester.pumpAndSettle();

      expect(routeResult, isA<TemplatePreviewResult>());
      final result = routeResult! as TemplatePreviewResult;
      expect(result.selectedTemplate.templateId, resolved.templateId);
      expect(result.selectedTemplate.isPremium, isFalse);
      expect(navigator.pushes.whereType<PremiumDestination>(), isEmpty);
      expect(repository.analyticsSources, ['catalog']);
    });

    testWidgets('expanded description keeps premium CTA in the same viewer', (
      tester,
    ) async {
      final premium = _template(
        'premium-details',
        title: 'Premium details',
        isPremium: true,
        description: List.filled(10, 'Your pet in a magical scene.').join(' '),
      );
      final repository = _TrackingTemplatesRepository(
        feedItems: [premium],
        details: {'premium-details': premium},
      );
      final navigator = _RecordingAppNavigator();
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession.single(premium),
        repository: repository,
        hasPremiumAccess: false,
        isAuthenticated: true,
        appNavigator: navigator,
      );
      await tester.tap(
        find.byKey(const ValueKey('template-preview-description-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show less'), findsOneWidget);
      expect(find.byType(TemplateDetailContent), findsNothing);
      await tester.tap(find.byKey(const ValueKey('template-preview-cta')));
      await tester.pumpAndSettle();
      expect(navigator.pushes.whereType<PremiumDestination>(), hasLength(1));
    });

    testWidgets('description expansion resets on swipe and keeps CTA visible', (
      tester,
    ) async {
      final items = [
        _template(
          'long-first',
          title: 'First',
          description: List.filled(
            18,
            'A detailed story about your pet.',
          ).join(' '),
        ),
        _template(
          'long-second',
          title: 'Second',
          description: List.filled(12, 'A different magical story.').join(' '),
        ),
      ];
      final repository = _TrackingTemplatesRepository(
        feedItems: items,
        details: {for (final item in items) item.templateId: item},
      );
      await _pumpPreviewHost(
        tester,
        session: TemplatePreviewSession(items: items, initialIndex: 0),
        repository: repository,
        viewSize: const Size(320, 568),
        textScale: 2,
      );
      final toggle = find.byKey(
        const ValueKey('template-preview-description-toggle'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cta = find.byKey(const ValueKey('template-preview-cta'));
      expect(cta.hitTestable(), findsOneWidget);
      // Swipe on the visible description, away from the independently scrollable rail.
      final visibleDescription = tester
          .getRect(find.text(items.first.shortDescription))
          .intersect(
            tester.getRect(
              find.byKey(const ValueKey('template-preview-information')),
            ),
          );
      await tester.flingFrom(
        Offset(visibleDescription.right - 24, visibleDescription.center.dy),
        const Offset(-250, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('template-preview-summary:long-second')),
        findsOneWidget,
      );
      expect(find.byTooltip('Show less'), findsNothing);
      expect(cta.hitTestable(), findsOneWidget);
    });

    testWidgets(
      'panel anchors do not move across premium, video and long text',
      (tester) async {
        final items = [
          _template(
            'premium-layout',
            title: 'A much longer title that takes two lines',
            isPremium: true,
            description: List.filled(15, 'A story about your pet.').join(' '),
          ),
          _template(
            'video-layout',
            title: 'Dance',
            templateType: TemplateType.video,
            description: 'Dance with me.',
            referenceVideoDurationSeconds: 5,
          ),
          _template('image-layout', title: 'Boss', description: ''),
        ];
        await _pumpPreviewHost(
          tester,
          session: TemplatePreviewSession(items: items, initialIndex: 0),
          repository: _TrackingTemplatesRepository(
            feedItems: items,
            details: {for (final item in items) item.templateId: item},
          ),
          hasPremiumAccess: false,
        );
        final rail = find.byKey(
          const ValueKey('template-preview-thumbnail-rail'),
        );
        final cta = find.byKey(const ValueKey('template-preview-cta'));
        final info = find.byKey(const ValueKey('template-preview-information'));
        final railRect = tester.getRect(rail);
        final ctaRect = tester.getRect(cta);
        final infoRect = tester.getRect(info);
        await tester.tap(
          find.byKey(const ValueKey('template-preview-description-toggle')),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(rail), railRect);
        expect(tester.getRect(cta), ctaRect);
        expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
        for (final id in ['video-layout', 'image-layout', 'premium-layout']) {
          await tester.tap(
            find.byKey(ValueKey('template-preview-thumbnail:$id')),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.getRect(rail), railRect);
          expect(tester.getRect(cta), ctaRect);
          await tester.pumpAndSettle();
          expect(tester.getRect(info), infoRect);
          expect(tester.getRect(rail), railRect);
          expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'description tap and cancelled drag never strand action or swipes',
      (tester) async {
        final fixtures = _previewFixtures();
        await _pumpPreviewHost(
          tester,
          session: TemplatePreviewSession(
            items: fixtures.feed,
            initialIndex: 0,
          ),
          repository: _TrackingTemplatesRepository(
            feedItems: fixtures.feed,
            details: fixtures.details,
          ),
        );
        final info = find.byKey(const ValueKey('template-preview-information'));
        final cta = find.byKey(const ValueKey('template-preview-cta'));
        await tester.tap(
          find.text(fixtures.details['first']!.shortDescription),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
        final gesture = await tester.startGesture(tester.getCenter(info));
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump();
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
        await tester.drag(info, const Offset(0, -40));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
        for (final id in ['second', 'third']) {
          await tester.fling(info, const Offset(-260, 0), 900);
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('template-preview-summary:$id')),
            findsOneWidget,
          );
          expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
        }
      },
    );

    testWidgets(
      'accessibility navigation does not disable autoplay or motion; mute follows selection',
      (tester) async {
        final fixtures = _previewFixtures();
        await _pumpPreviewHost(
          tester,
          session: TemplatePreviewSession(
            items: fixtures.feed,
            initialIndex: 0,
          ),
          repository: _TrackingTemplatesRepository(
            feedItems: fixtures.feed,
            details: fixtures.details,
          ),
          accessibleNavigation: true,
        );
        final frame = tester.widget<TemplateMediaFrame>(
          find.byType(TemplateMediaFrame).first,
        );
        expect(frame.autoplay, isTrue);
        expect(frame.muted, isFalse);
        expect(
          tester
              .widget<AnimatedSwitcher>(
                find.byKey(const ValueKey('template-preview-summary-switcher')),
              )
              .duration,
          isNot(Duration.zero),
        );
        frame.onMutedChanged!(true);
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('template-preview-thumbnail:second')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final page = tester
            .widget<PageView>(find.byType(PageView))
            .controller!
            .page!;
        expect(page, greaterThan(0));
        expect(page, lessThan(1));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<TemplateMediaFrame>(find.byType(TemplateMediaFrame))
              .every((frame) => frame.muted),
          isTrue,
        );
        final infoRect = tester.getRect(
          find.byKey(const ValueKey('template-preview-information')),
        );
        expect(infoRect.height, lessThanOrEqualTo(180));
        final railRect = tester.getRect(
          find.byKey(const ValueKey('template-preview-thumbnail-rail')),
        );
        expect(railRect.top, greaterThan(600));
      },
    );

    testWidgets(
      'reduced motion commits thumbnail selection without animation',
      (tester) async {
        final fixtures = _previewFixtures();
        final repository = _TrackingTemplatesRepository(
          feedItems: fixtures.feed,
          details: fixtures.details,
        );
        await _pumpPreviewHost(
          tester,
          session: TemplatePreviewSession(
            items: fixtures.feed,
            initialIndex: 0,
          ),
          repository: repository,
          disableAnimations: true,
        );

        final switcher = tester.widget<AnimatedSwitcher>(
          find.byKey(const ValueKey('template-preview-summary-switcher')),
        );
        expect(switcher.duration, Duration.zero);
        expect(
          tester
              .widget<TemplateMediaFrame>(find.byType(TemplateMediaFrame).first)
              .autoplay,
          isTrue,
        );

        await tester.tap(
          find.byKey(const ValueKey('template-preview-thumbnail:third')),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('template-preview-summary:third')),
          findsOneWidget,
        );
      },
    );
  });
}

Future<void> _pumpPreviewHost(
  WidgetTester tester, {
  required TemplatePreviewSession session,
  required TemplatesRepository repository,
  ValueChanged<Object?>? onResult,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  Size viewSize = const Size(430, 932),
  double textScale = 1,
  Locale locale = const Locale('en'),
  bool useLightTheme = false,
  bool hasPremiumAccess = true,
  bool isAuthenticated = true,
  AppNavigator? appNavigator,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        templatePremiumAccessProvider.overrideWithValue(hasPremiumAccess),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: useLightTheme ? AppTheme.light() : AppTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              disableAnimations: disableAnimations,
              accessibleNavigation: accessibleNavigation,
              textScaler: TextScaler.linear(textScale),
            ),
            child: AppNavigationScope(
              navigator: appNavigator ?? _RecordingAppNavigator(),
              child: child!,
            ),
          );
        },
        home: _PreviewHost(
          session: session,
          onResult: onResult,
          hasPremiumAccess: hasPremiumAccess,
          isAuthenticated: isAuthenticated,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('open-template-preview')));
  await tester.pumpAndSettle();

  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _PreviewHost extends StatelessWidget {
  const _PreviewHost({
    required this.session,
    required this.hasPremiumAccess,
    required this.isAuthenticated,
    this.onResult,
  });

  final TemplatePreviewSession session;
  final bool hasPremiumAccess;
  final bool isAuthenticated;
  final ValueChanged<Object?>? onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('open-template-preview'),
          onPressed: () async {
            final result = await Navigator.of(context).push<Object?>(
              MaterialPageRoute<Object?>(
                builder: (_) => TemplatePreviewPage(
                  template: session.initialTemplate,
                  session: session,
                  hasPremiumAccess: hasPremiumAccess,
                  isAuthenticated: isAuthenticated,
                ),
              ),
            );
            onResult?.call(result);
          },
          child: const Text('Open preview'),
        ),
      ),
    );
  }
}

class _TrackingTemplatesRepository extends FakeTemplatesRepository {
  _TrackingTemplatesRepository({
    required List<TemplateItem> feedItems,
    required this.details,
  }) : super(items: feedItems);

  final Map<String, TemplateItem> details;
  final List<String> fetchTemplateIds = [];
  final List<bool> forceRefreshValues = [];
  final List<String?> analyticsSources = [];
  final List<int?> minimumVersions = [];

  @override
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
    String? analyticsSource,
    int? minimumVersion,
  }) async {
    fetchTemplateIds.add(templateId);
    forceRefreshValues.add(forceRefresh);
    analyticsSources.add(analyticsSource);
    minimumVersions.add(minimumVersion);
    return details[templateId] ??
        super.fetchTemplate(
          templateId,
          forceRefresh: forceRefresh,
          analyticsSource: analyticsSource,
          minimumVersion: minimumVersion,
        );
  }
}

({List<TemplateItem> feed, Map<String, TemplateItem> details})
_previewFixtures() {
  final feed = [
    _template('first', title: 'First template', tokenCost: 1, version: 1),
    _template('second', title: 'Second template', tokenCost: 2, version: 2),
    _template('third', title: 'Third template', tokenCost: 3, version: 3),
  ];
  return (
    feed: feed,
    details: {
      'first': _template(
        'first',
        title: 'First template',
        tokenCost: 11,
        version: 101,
      ),
      'second': _template(
        'second',
        title: 'Second template',
        tokenCost: 22,
        version: 202,
      ),
      'third': _template(
        'third',
        title: 'Third template',
        tokenCost: 33,
        version: 303,
      ),
    },
  );
}

TemplateItem _template(
  String id, {
  required String title,
  int tokenCost = 0,
  int version = 0,
  TemplateType templateType = TemplateType.image,
  bool isPremium = false,
  String? detailPreviewUrl,
  String? mediaKind,
  String? description,
  double? referenceVideoDurationSeconds,
}) {
  return TemplateItem(
    templateId: id,
    templateType: templateType,
    title: title,
    shortDescription: description ?? '$title description',
    referenceVideoDurationSeconds: referenceVideoDurationSeconds,
    petPhotoRequirements: const ['Clear face'],
    category: 'Magic',
    tags: const ['test'],
    isPremium: isPremium,
    tokenCost: tokenCost,
    version: version,
    detailPreviewUrl: detailPreviewUrl,
    mediaKind: mediaKind,
  );
}

class _DelayedTemplatesRepository extends FakeTemplatesRepository {
  _DelayedTemplatesRepository({required TemplateItem feedItem})
    : super(items: [feedItem]);

  final Completer<TemplateItem> detail = Completer<TemplateItem>();
  final List<String?> analyticsSources = [];

  @override
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
    String? analyticsSource,
    int? minimumVersion,
  }) {
    analyticsSources.add(analyticsSource);
    return detail.future;
  }
}

class _FailingTemplatesRepository extends FakeTemplatesRepository {
  _FailingTemplatesRepository(TemplateItem item) : super(items: [item]);

  int fetchCalls = 0;

  @override
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
    String? analyticsSource,
    int? minimumVersion,
  }) async {
    fetchCalls++;
    throw StateError('detail unavailable');
  }
}

class _RecordingAppNavigator implements AppNavigator {
  final List<AppDestination> pushes = [];

  @override
  bool canPop() => false;

  @override
  void go(AppDestination destination) {}

  @override
  void pop<T extends Object?>([T? result]) {}

  @override
  Future<T?> push<T>(AppDestination destination) async {
    pushes.add(destination);
    return null;
  }

  @override
  void replace(AppDestination destination) {}
}
