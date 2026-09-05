import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_repository.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_discovery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_playback_coordinator.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_category_carousel.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_rail.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'template_card_test_support.dart';
import 'templates_page_lifecycle_test_support.dart'
    show RandomTemplatesRepository;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('caption uses only its measured height at text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpDiscoveryPage(
        tester,
        repository: _FakeDiscoveryRepository(_discoveryFixture()),
        navigator: _RecordingNavigator(),
        textScaler: TextScaler.linear(scale),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('discovery-rail-Pet Mischief'));
      final title = find.text(_mischiefCard.title);
      await Scrollable.ensureVisible(tester.element(title), alignment: 0.4);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(rail).bottom - tester.getRect(title).bottom,
        inInclusiveRange(0, 1),
      );
      final nextSection = find.byWidgetPredicate(
        (widget) =>
            widget is TemplateDiscoveryRail &&
            widget.section.category == 'Pawsome Frames',
      );
      expect(
        tester.getRect(nextSection).top - tester.getRect(title).bottom,
        inInclusiveRange(8, 9),
      );
      final style = tester.widget<Text>(title).style!;
      expect(style.fontFamily, isNot('Comfortaa'));
      expect(style.fontWeight, FontWeight.w600);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('discovery has one compact toolbar and portrait premium cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpDiscoveryPage(
      tester,
      repository: _FakeDiscoveryRepository(_discoveryFixture()),
      navigator: _RecordingNavigator(),
    );
    final catalog = find.byKey(const ValueKey('discovery-catalog-launcher'));
    final random = find.byKey(const ValueKey('discovery-random-launcher'));
    expect(tester.getSize(catalog).height, inInclusiveRange(48, 52));
    expect(tester.getRect(catalog).top, tester.getRect(random).top);
    expect(
      find.byKey(const ValueKey('discovery-search-launcher')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('discovery-format-video')), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final frame = find.byKey(const ValueKey('discovery-frame-frames-card'));
    await Scrollable.ensureVisible(tester.element(frame), alignment: 0.5);
    await tester.pumpAndSettle();
    final frameRect = tester.getRect(frame);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('discovery-more-Pawsome Frames')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(frameRect.width / frameRect.height, closeTo(2 / 3, 0.001));
    final price = tester.getRect(
      find.byKey(const ValueKey('discovery-price-frames-card')),
    );
    expect(frameRect.contains(price.topLeft), isTrue);
    expect(frameRect.contains(price.bottomRight), isTrue);
    expect(
      tester.getRect(find.text(_framesCard.title)).top,
      greaterThan(frameRect.bottom),
    );
    final decoration =
        tester.widget<Container>(frame).foregroundDecoration! as BoxDecoration;
    expect((decoration.border! as Border).top.width, 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discovery renders category content and preserves catalog navigation intent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeDiscoveryRepository(_discoveryFixture());
      final navigator = _RecordingNavigator();

      await _pumpDiscoveryPage(
        tester,
        repository: repository,
        navigator: navigator,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -210));
      await _pumpUntil(
        tester,
        () => find.byType(TemplateDiscoveryRail).evaluate().length == 2,
      );

      expect(repository.fetchCalls, 1);
      expect(find.byType(TemplateCategoryCarousel), findsOneWidget);
      expect(find.byType(TemplateDiscoveryRail), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('discovery-rail-Pet Mischief')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-rail-Pawsome Frames')),
        findsOneWidget,
      );

      final semantics = tester.ensureSemantics();
      try {
        final text = AppLocalizations.of(
          tester.element(find.byType(TemplatesDiscoveryPage)),
        );

        final categoryAction = find.semantics.byLabel('Pet Mischief, 1 / 2');
        tester.semantics.performAction(categoryAction, SemanticsAction.tap);
        await tester.pump();
        final categoryDestination =
            navigator.pushes.last as TemplatesDestination;
        expect(categoryDestination.category, 'Pet Mischief');
        expect(categoryDestination.payload, isNull);

        final moreAction = find.semantics.byLabel(
          RegExp('${RegExp.escape(text.discoverMoreAction)}: Pet Mischief'),
        );
        tester.semantics.performAction(moreAction, SemanticsAction.tap);
        await tester.pump();
        final moreDestination = navigator.pushes.last as TemplatesDestination;
        expect(moreDestination.category, 'Pet Mischief');
        expect(moreDestination.autofocusSearch, isFalse);
        expect(moreDestination.payload, isNull);

        final catalogAction = find.semantics.byLabel(
          text.generationStatusAllTemplatesAction,
        );
        tester.semantics.performAction(catalogAction, SemanticsAction.tap);
        await tester.pump();
        final catalogDestination =
            navigator.pushes.last as TemplatesDestination;
        expect(catalogDestination.category, isNull);
        expect(catalogDestination.autofocusSearch, isFalse);
        expect(catalogDestination.payload, isNull);

        final premiumCardLabel =
            '${_framesCard.title}, ${text.videoLabel}, 0:07, '
            '${text.premiumLabel}, 8 PawSpark';
        await tester.ensureVisible(find.text(_framesCard.title));
        await tester.pump();
        expect(find.text('0:07'), findsOneWidget);
        expect(tester.widget<Text>(find.text(_framesCard.title)).maxLines, 2);
        final templateAction = find.semantics.byLabel(premiumCardLabel);
        expect(templateAction.evaluate().single.label, premiumCardLabel);
        tester.semantics.performAction(templateAction, SemanticsAction.tap);
        await tester.pump();
        final cardDestination = navigator.pushes.last as TemplatesDestination;
        expect(cardDestination.category, 'Pawsome Frames');
        expect(cardDestination.autofocusSearch, isFalse);
        final previewSession =
            cardDestination.payload! as TemplatePreviewSession;
        expect(identical(previewSession.initialTemplate, _framesCard), isTrue);
        expect(previewSession.source, TemplatePreviewSource.discovery);
        expect(navigator.pushes, hasLength(4));
      } finally {
        semantics.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discovery random uses backend selection and opens preview', (
    tester,
  ) async {
    final repository = RandomTemplatesRepository(
      items: [imageTemplate(id: 'outside-discovery')],
    );
    final navigator = _RecordingNavigator();
    await _pumpDiscoveryPage(
      tester,
      repository: _FakeDiscoveryRepository(_discoveryFixture()),
      navigator: navigator,
      randomRepository: repository,
    );
    final text = AppLocalizations.of(
      tester.element(find.byType(TemplatesDiscoveryPage)),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-random-launcher')),
    );
    await tester.tap(find.byKey(const ValueKey('discovery-random-launcher')));
    await tester.pumpAndSettle();
    expect(find.text(text.randomTemplateSheetDescription), findsOneWidget);
    expect(repository.fetchRandomTemplateCalls, 0);
    await tester.tap(find.text(text.randomTemplateFindAction));
    await tester.pumpAndSettle();
    expect(repository.fetchRandomTemplateCalls, 1);
    expect(repository.lastRandomMode, TemplateRandomMode.any);
    expect(repository.lastRandomCategory, isNull);
    expect(repository.lastIncludePremium, isFalse);
    expect(repository.lastRandomAccess, TemplateRandomAccess.available);
    final session =
        (navigator.pushes.single as TemplatesDestination).payload!
            as TemplatePreviewSession;
    expect(session.initialTemplate.templateId, 'outside-discovery');
    expect(session.source, TemplatePreviewSource.random);
    expect(repository.cancelPendingRandomTemplateRequestCalls, 0);
    await tester.tap(find.byKey(const ValueKey('discovery-catalog-launcher')));
    await tester.pump();
    final catalog = navigator.pushes.last as TemplatesDestination;
    expect(catalog.category, isNull);
    expect(catalog.payload, isNull);
    expect(catalog.autofocusSearch, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discovery random dismissal cancels pending selection', (
    tester,
  ) async {
    final pending = Completer<TemplateItem?>();
    final repository = RandomTemplatesRepository(
      randomTemplateCompleter: pending,
    );
    final navigator = _RecordingNavigator();
    await _pumpDiscoveryPage(
      tester,
      repository: _FakeDiscoveryRepository(_discoveryFixture()),
      navigator: navigator,
      randomRepository: repository,
    );
    final text = AppLocalizations.of(
      tester.element(find.byType(TemplatesDiscoveryPage)),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-random-launcher')),
    );
    await tester.tap(find.byKey(const ValueKey('discovery-random-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.randomTemplateFindAction));
    await tester.pump();
    expect(repository.fetchRandomTemplateCalls, 1);
    expect(find.text(text.randomTemplateFinding), findsOneWidget);
    Navigator.of(tester.element(find.text(text.randomTemplateFinding))).pop();
    await tester.pumpAndSettle();
    expect(repository.cancelPendingRandomTemplateRequestCalls, 1);
    pending.complete(_mischiefCard);
    await tester.pumpAndSettle();
    expect(navigator.pushes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discovery ignores background random result and allows retry', (
    tester,
  ) async {
    final pending = Completer<TemplateItem?>();
    final repository = RandomTemplatesRepository(
      randomTemplateCompleter: pending,
    );
    final navigator = _RecordingNavigator();
    await _pumpDiscoveryPage(
      tester,
      repository: _FakeDiscoveryRepository(_discoveryFixture()),
      navigator: navigator,
      randomRepository: repository,
    );
    final text = AppLocalizations.of(
      tester.element(find.byType(TemplatesDiscoveryPage)),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-random-launcher')),
    );
    await tester.tap(find.byKey(const ValueKey('discovery-random-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.randomTemplateFindAction));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    pending.complete(_mischiefCard);
    await tester.pumpAndSettle();
    expect(repository.cancelPendingRandomTemplateRequestCalls, 1);
    expect(navigator.pushes, isEmpty);
    expect(find.text(text.randomTemplateNoMatches), findsOneWidget);
    await tester.tap(find.text(text.randomTemplateFindAction));
    await tester.pumpAndSettle();
    expect(repository.fetchRandomTemplateCalls, 2);
    expect(navigator.pushes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'discovery random shows ${fails ? 'retry on error' : 'empty state'}',
      (tester) async {
        final repository = RandomTemplatesRepository(throwOnRandom: fails);
        await _pumpDiscoveryPage(
          tester,
          repository: _FakeDiscoveryRepository(_discoveryFixture()),
          navigator: _RecordingNavigator(),
          randomRepository: repository,
        );
        final text = AppLocalizations.of(
          tester.element(find.byType(TemplatesDiscoveryPage)),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('discovery-random-launcher')),
        );
        await tester.tap(
          find.byKey(const ValueKey('discovery-random-launcher')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(text.randomTemplateFindAction));
        await tester.pumpAndSettle();
        expect(
          find.text(
            fails
                ? text.randomTemplateLoadFailed
                : text.randomTemplateNoMatches,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('discovery supports compact viewport at 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeDiscoveryRepository(_discoveryFixture());

    await _pumpDiscoveryPage(
      tester,
      repository: repository,
      navigator: _RecordingNavigator(),
      textScaler: const TextScaler.linear(2),
    );

    final text = AppLocalizations.of(
      tester.element(find.byType(TemplatesDiscoveryPage)),
    );
    expect(find.byType(TemplateCategoryCarousel), findsOneWidget);
    expect(find.text(text.discoverOpenCategoryAction), findsWidgets);
    expect(tester.takeException(), isNull);

    final verticalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
      description: 'vertical discovery scrollable',
    );
    await tester.scrollUntilVisible(
      find.text(_framesCard.title),
      240,
      scrollable: verticalScroll,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-rail-Pawsome Frames')),
      findsOneWidget,
    );
    expect(find.text(_framesCard.title), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible discovery video survives scrolling in all directions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final originalPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    MediaLifecyclePolicy.reset();
    addTearDown(() {
      VideoPlayerPlatform.instance = originalPlatform;
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
      MediaLifecyclePolicy.reset();
    });
    const previewUrl = 'https://cdn.example.com/templates/scroll-video.mp4';
    final video = videoTemplate(
      id: 'scroll-video',
      previewUrl: previewUrl,
      thumbnailUrl: previewUrl,
      feedLoopLowUrl: previewUrl,
    );
    final playbackManager = TemplateFeedPlaybackManager();
    addTearDown(playbackManager.dispose);

    await _pumpDiscoveryPage(
      tester,
      repository: _FakeDiscoveryRepository(
        _horizontalDiscoveryFixture(video: video),
      ),
      navigator: _RecordingNavigator(),
      playbackManager: playbackManager,
      networkTransport: NetworkTransportKind.cellular,
      previewControllerFactory: (url) async =>
          VideoPlayerController.networkUrl(Uri.parse(url)),
    );
    final media = find.byWidgetPredicate(
      (widget) =>
          widget is VisibilityDetector &&
          widget.key.toString().contains('scroll-video'),
    );
    await tester.ensureVisible(media);
    await tester.pump();
    await _pumpUntil(tester, () => fakePlatform.playCalls > 0);
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    final rail = find.byKey(const ValueKey('discovery-rail-Pet Mischief'));
    final horizontalScroll = find.descendant(
      of: rail,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    expect(horizontalScroll, findsOneWidget);

    final verticalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    for (final movement in [
      (horizontalScroll, const Offset(-30, 0)),
      (horizontalScroll, const Offset(30, 0)),
      (verticalScroll, const Offset(0, -30)),
      (verticalScroll, const Offset(0, 30)),
    ]) {
      final position = tester.state<ScrollableState>(movement.$1).position;
      final previousPixels = position.pixels;
      final gesture = await tester.startGesture(tester.getCenter(media));
      await gesture.moveBy(movement.$2);
      await gesture.moveBy(movement.$2);
      await tester.pump(const Duration(milliseconds: 600));
      expect(position.pixels, isNot(previousPixels));
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(fakePlatform.disposeCalls, 0);
      expect(controller.value.isPlaying, isTrue);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(controller),
      );
      expect(fakePlatform.createCalls, 1);
      expect(playbackManager.activeVideoControllersCount, 1);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refreshing another section keeps an unchanged visible preview playing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final originalPlatform = VideoPlayerPlatform.instance;
      final fakePlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      MediaLifecyclePolicy.reset();
      addTearDown(() {
        VideoPlayerPlatform.instance = originalPlatform;
        VisibilityDetectorController.instance.updateInterval = const Duration(
          milliseconds: 500,
        );
        MediaLifecyclePolicy.reset();
      });
      const previewUrl = 'https://cdn.example.com/templates/refresh-video.mp4';
      final video = videoTemplate(
        id: 'refresh-video',
        previewUrl: previewUrl,
        thumbnailUrl: previewUrl,
        feedLoopLowUrl: previewUrl,
      );
      final repository = _FakeDiscoveryRepository(
        _discoveryRefreshFixture(video: video, otherCategory: 'Before'),
      );
      final playbackManager = TemplateFeedPlaybackManager();
      addTearDown(playbackManager.dispose);

      await _pumpDiscoveryPage(
        tester,
        repository: repository,
        navigator: _RecordingNavigator(),
        playbackManager: playbackManager,
        networkTransport: NetworkTransportKind.cellular,
        previewControllerFactory: (url) async =>
            VideoPlayerController.networkUrl(Uri.parse(url)),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -210));
      await tester.pump();
      final detector = tester.widget<VisibilityDetector>(
        find.byWidgetPredicate(
          (widget) =>
              widget is VisibilityDetector &&
              widget.key.toString().contains('refresh-video'),
        ),
      );
      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(132, 198),
          visibleBounds: const Offset(0, 0) & const Size(132, 198),
        ),
      );
      await _pumpUntil(tester, () => fakePlatform.playCalls > 0);
      expect(playbackManager.activeVideoControllersCount, 1);
      expect(fakePlatform.createCalls, 1);

      repository.discovery = _discoveryRefreshFixture(
        video: video,
        otherCategory: 'After',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TemplatesDiscoveryPage)),
        listen: false,
      );
      await container
          .read(templateDiscoveryControllerProvider.notifier)
          .loadInitial(forceRefresh: true);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('discovery-rail-After')),
        findsOneWidget,
      );
      expect(playbackManager.activeVideoControllersCount, 1);
      expect(fakePlatform.createCalls, 1);
      expect(fakePlatform.disposeCalls, 0);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('pinned discovery search stays below the top safe inset', (
    tester,
  ) async {
    const topInset = 24.0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDiscoveryPage(
      tester,
      repository: _FakeDiscoveryRepository(_scrollableDiscoveryFixture()),
      navigator: _RecordingNavigator(),
      topPadding: topInset,
    );
    final verticalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
      description: 'vertical discovery scrollable',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('discovery-rail-Pet Portraits')),
      300,
      scrollable: verticalScroll,
    );
    await tester.pump();
    final position = tester.state<ScrollableState>(verticalScroll).position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    final searchRect = tester.getRect(
      find.byKey(const ValueKey('discovery-catalog-launcher')),
    );
    expect(searchRect.top, greaterThanOrEqualTo(topInset));
    expect(searchRect.top, lessThanOrEqualTo(topInset + 8));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('discovery-random-launcher')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      find.byKey(const ValueKey('discovery-random-launcher')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('discovery-catalog-launcher')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('discovery remount retries cached state after remote error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _RemountDiscoveryRepository(_discoveryFixture());
    final hostKey = GlobalKey<_DiscoveryMountHostState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateDiscoveryRepositoryProvider.overrideWithValue(repository),
          appLaunchControllerProvider.overrideWith(
            _GuestAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          networkStatusControllerProvider.overrideWith(
            _OnlineNetworkStatusController.new,
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppNavigationScope(
            navigator: _RecordingNavigator(),
            child: Scaffold(body: _DiscoveryMountHost(key: hostKey)),
          ),
        ),
      ),
    );

    await _pumpUntil(tester, () => repository.fetchCalls == 1);
    final providerContainer = ProviderScope.containerOf(
      tester.element(find.byType(_DiscoveryMountHost)),
      listen: false,
    );
    repository.failFirst(
      const AppException('templates.discovery_remote_failed'),
    );
    await _pumpUntil(tester, () {
      final state = providerContainer.read(templateDiscoveryControllerProvider);
      return state.hasLoaded &&
          state.loadedFromCache &&
          state.errorMessage == 'templates.discovery_remote_failed';
    });
    expect(
      providerContainer.read(templateDiscoveryControllerProvider).sections,
      isNotEmpty,
    );

    hostKey.currentState!.setPageMounted(false);
    await tester.pump();
    expect(repository.cancelCalls, 1);

    hostKey.currentState!.setPageMounted(true);
    await _pumpUntil(tester, () => repository.fetchCalls == 2);
    repository.completeSecond(_discoveryFixture());
    await _pumpUntil(tester, () {
      final state = providerContainer.read(templateDiscoveryControllerProvider);
      return state.hasLoaded &&
          !state.loadedFromCache &&
          state.errorMessage == null &&
          !state.isRefreshing;
    });

    expect(repository.fetchCalls, 2);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -210));
    await tester.pump();
    expect(find.byType(TemplateCategoryCarousel), findsOneWidget);
    expect(find.byType(TemplateDiscoveryRail), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('discovery refreshes hydrated access on app resume', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeDiscoveryRepository(_discoveryFixture());
    final walletController = _TrackingWalletController();
    final profileController = _TrackingProfileController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateDiscoveryRepositoryProvider.overrideWithValue(repository),
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => walletController),
          profileControllerProvider.overrideWith(() => profileController),
          networkStatusControllerProvider.overrideWith(
            _OnlineNetworkStatusController.new,
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppNavigationScope(
            navigator: _RecordingNavigator(),
            child: const Scaffold(body: TemplatesDiscoveryPage()),
          ),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () =>
          repository.fetchCalls == 1 &&
          walletController.syncSnapshotCalls == 1 &&
          profileController.initializeCalls == 1,
    );

    expect(walletController.forceRefreshValues, [false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpUntil(tester, () => walletController.syncSnapshotCalls == 2);

    expect(walletController.forceRefreshValues, [false, true]);
    expect(profileController.initializeCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

const _mischiefCard = TemplateItem(
  templateId: 'mischief-card',
  templateType: TemplateType.image,
  title: 'Mischief card',
  shortDescription: 'Playful pets',
  petPhotoRequirements: [],
  category: 'Pet Mischief',
  tags: ['funny'],
  isPremium: false,
  tokenCost: 4,
);

const _framesCard = TemplateItem(
  templateId: 'frames-card',
  templateType: TemplateType.video,
  title: 'Frames card',
  shortDescription: 'Pet portraits',
  petPhotoRequirements: [],
  category: 'Pawsome Frames',
  tags: ['portrait'],
  isPremium: true,
  tokenCost: 8,
  durationMs: 6500,
);

TemplateDiscovery _discoveryFixture() {
  return TemplateDiscovery(
    sections: const [
      TemplateDiscoverySection(
        category: 'Pet Mischief',
        items: [_mischiefCard],
      ),
      TemplateDiscoverySection(
        category: 'Pawsome Frames',
        items: [_framesCard],
      ),
    ],
    generatedAtUtc: DateTime.utc(2026, 9, 4),
  );
}

TemplateDiscovery _scrollableDiscoveryFixture() {
  return TemplateDiscovery(
    sections: const [
      TemplateDiscoverySection(
        category: 'Pet Mischief',
        items: [_mischiefCard],
      ),
      TemplateDiscoverySection(
        category: 'Pawsome Frames',
        items: [_framesCard],
      ),
      TemplateDiscoverySection(
        category: 'Adventure Pets',
        items: [_mischiefCard],
      ),
      TemplateDiscoverySection(
        category: 'Cozy Companions',
        items: [_framesCard],
      ),
      TemplateDiscoverySection(
        category: 'Pet Portraits',
        items: [_mischiefCard],
      ),
    ],
    generatedAtUtc: DateTime.utc(2026, 9, 4),
  );
}

TemplateDiscovery _horizontalDiscoveryFixture({required TemplateItem video}) {
  return TemplateDiscovery(
    sections: [
      TemplateDiscoverySection(
        category: 'Pet Mischief',
        items: [video, _mischiefCard, _framesCard],
      ),
      const TemplateDiscoverySection(
        category: 'Pawsome Frames',
        items: [_framesCard],
      ),
    ],
    generatedAtUtc: DateTime.utc(2026, 9, 4),
  );
}

TemplateDiscovery _discoveryRefreshFixture({
  required TemplateItem video,
  required String otherCategory,
}) {
  return TemplateDiscovery(
    sections: [
      TemplateDiscoverySection(category: 'Video', items: [video]),
      TemplateDiscoverySection(
        category: otherCategory,
        items: const [_mischiefCard],
      ),
    ],
    generatedAtUtc: DateTime.utc(2026, 9, 4),
  );
}

Future<void> _pumpDiscoveryPage(
  WidgetTester tester, {
  required _FakeDiscoveryRepository repository,
  required _RecordingNavigator navigator,
  TextScaler textScaler = TextScaler.noScaling,
  double topPadding = 0,
  TemplateFeedPlaybackManager? playbackManager,
  NetworkTransportKind networkTransport = NetworkTransportKind.unknown,
  TemplatePreviewControllerFactory? previewControllerFactory,
  TemplatesRepository? randomRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (randomRepository != null)
          templatesRepositoryProvider.overrideWithValue(randomRepository),
        templateDiscoveryRepositoryProvider.overrideWithValue(repository),
        appLaunchControllerProvider.overrideWith(_GuestAppLaunchController.new),
        walletControllerProvider.overrideWith(_IdleWalletController.new),
        networkStatusControllerProvider.overrideWith(
          () => _OnlineNetworkStatusController(networkTransport),
        ),
        if (playbackManager != null)
          templateDiscoveryPlaybackManagerProvider.overrideWithValue(
            playbackManager,
          ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: textScaler,
            padding: EdgeInsets.only(top: topPadding),
            viewPadding: EdgeInsets.only(top: topPadding),
          ),
          child: child!,
        ),
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppNavigationScope(
          navigator: navigator,
          child: Scaffold(
            body: TemplatesDiscoveryPage(
              previewControllerFactory: previewControllerFactory,
            ),
          ),
        ),
      ),
    ),
  );
  await _pumpUntil(
    tester,
    () =>
        repository.fetchCalls == 1 &&
        find.byType(TemplateCategoryCarousel).evaluate().isNotEmpty,
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (condition()) {
      return;
    }
  }
  fail('Timed out waiting for discovery content.');
}

final class _FakeDiscoveryRepository implements TemplateDiscoveryRepository {
  _FakeDiscoveryRepository(this.discovery);

  TemplateDiscovery discovery;
  int fetchCalls = 0;

  @override
  Future<TemplateDiscovery?> readCached() async => null;

  @override
  Future<TemplateDiscovery> fetch() async {
    fetchCalls++;
    return discovery;
  }

  @override
  void cancelPendingRequest() {}
}

final class _RemountDiscoveryRepository implements TemplateDiscoveryRepository {
  _RemountDiscoveryRepository(this.cached);

  final TemplateDiscovery cached;
  final Completer<TemplateDiscovery> _firstFetch =
      Completer<TemplateDiscovery>();
  final Completer<TemplateDiscovery> _secondFetch =
      Completer<TemplateDiscovery>();
  int fetchCalls = 0;
  int cancelCalls = 0;

  @override
  Future<TemplateDiscovery?> readCached() async => cached;

  @override
  Future<TemplateDiscovery> fetch() {
    fetchCalls++;
    return switch (fetchCalls) {
      1 => _firstFetch.future,
      2 => _secondFetch.future,
      _ => Future<TemplateDiscovery>.error(
        StateError('Unexpected discovery fetch #$fetchCalls.'),
      ),
    };
  }

  void failFirst(Object error) => _firstFetch.completeError(error);

  void completeSecond(TemplateDiscovery discovery) {
    _secondFetch.complete(discovery);
  }

  @override
  void cancelPendingRequest() {
    cancelCalls++;
  }
}

final class _DiscoveryMountHost extends StatefulWidget {
  const _DiscoveryMountHost({super.key});

  @override
  State<_DiscoveryMountHost> createState() => _DiscoveryMountHostState();
}

final class _DiscoveryMountHostState extends State<_DiscoveryMountHost> {
  bool _pageMounted = true;

  void setPageMounted(bool mounted) {
    setState(() => _pageMounted = mounted);
  }

  @override
  Widget build(BuildContext context) {
    return _pageMounted
        ? const TemplatesDiscoveryPage()
        : const SizedBox.shrink();
  }
}

final class _RecordingNavigator implements AppNavigator {
  final List<AppDestination> pushes = <AppDestination>[];

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

final class _GuestAppLaunchController extends AppLaunchController {
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

final class _AuthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: false,
    );
  }
}

final class _IdleWalletController extends WalletController {
  @override
  WalletState build() => const WalletState();

  @override
  Future<void> load({bool refresh = false}) async {}
}

final class _TrackingWalletController extends WalletController {
  int syncSnapshotCalls = 0;
  final List<bool> forceRefreshValues = <bool>[];

  @override
  WalletState build() {
    return WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 50,
        adRewardsRemainingToday: 0,
        isPremium: false,
        updatedAtUtc: DateTime.utc(2026, 9, 4),
      ),
      hasCompletedFullLoad: true,
    );
  }

  @override
  Future<void> syncSnapshot({bool forceRefresh = false}) async {
    syncSnapshotCalls++;
    forceRefreshValues.add(forceRefresh);
  }
}

final class _TrackingProfileController extends ProfileController {
  int initializeCalls = 0;

  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: '',
      email: '',
      password: '',
      confirmPassword: '',
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {
    initializeCalls++;
    state = state.copyWith(
      profile: const MobileUserProfile(
        userId: 'user-1',
        email: 'pet@example.com',
        displayName: 'Pet Parent',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: false,
        legalAcceptance: MobileLegalAcceptanceStatus(
          termsOfUseAccepted: true,
          termsOfUseAcceptedVersion: '1.0',
          termsOfUseAcceptedAtUtc: null,
          privacyPolicyAccepted: true,
          privacyPolicyAcceptedVersion: '1.0',
          privacyPolicyAcceptedAtUtc: null,
          currentTermsOfUseVersion: '1.0',
          currentPrivacyPolicyVersion: '1.0',
          requiresAcceptance: false,
        ),
        roles: ['user'],
        avatar: null,
      ),
    );
  }
}

final class _OnlineNetworkStatusController extends NetworkStatusController {
  _OnlineNetworkStatusController([
    this.transport = NetworkTransportKind.unknown,
  ]);

  final NetworkTransportKind transport;

  @override
  NetworkStatusState build() =>
      NetworkStatusState(hasInternet: true, transport: transport);
}
