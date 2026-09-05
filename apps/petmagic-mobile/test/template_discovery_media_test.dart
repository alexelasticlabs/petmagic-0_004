import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_media.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_rail.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'template_card_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerPlatform originalPlatform;
  late FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    MediaLifecyclePolicy.reset();
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    MediaLifecyclePolicy.reset();
  });

  testWidgets(
    'discovery plays MP4 when legacy API exposes it as thumbnail and feed loop',
    (tester) async {
      const previewUrl =
          'https://cdn.example.com/templates/legacy-video-thumbnail.mp4';
      final manager = TemplateFeedPlaybackManager()
        ..configure(
          feedKind: TemplateFeedKind.mixed,
          environment: const TemplateFeedPlaybackEnvironment(
            networkClass: TemplateFeedNetworkClass.cellular,
          ),
        );
      addTearDown(manager.dispose);

      await tester.pumpWidget(
        _DiscoveryMediaHost(
          manager: manager,
          template: videoTemplate(
            id: 'legacy-video-template',
            previewUrl: previewUrl,
            thumbnailUrl: previewUrl,
            feedLoopLowUrl: previewUrl,
            mediaVersion: 9,
          ),
          previewControllerFactory: (url) async =>
              VideoPlayerController.networkUrl(Uri.parse(url)),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
      _showDiscoveryMedia(tester);
      await pumpUntil(
        tester,
        () => fakePlatform.playCalls > 0,
        timeout: const Duration(seconds: 1),
      );
      await tester.pump();

      expect(fakePlatform.createdUris, [previewUrl]);
      expect(fakePlatform.loopingValues, everyElement(true));
      expect(fakePlatform.volumeValues, everyElement(0));
      expect(find.byType(VideoPlayer), findsOneWidget);

      _hideDiscoveryMedia(tester);
      await pumpUntil(
        tester,
        () => fakePlatform.disposeCalls == 1,
        timeout: const Duration(seconds: 1),
      );
      expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching light and dark theme keeps the same video playing', (
    tester,
  ) async {
    const url = 'https://cdn.example.com/theme-preview.mp4';
    final manager = TemplateFeedPlaybackManager()
      ..configure(
        feedKind: TemplateFeedKind.mixed,
        environment: const TemplateFeedPlaybackEnvironment(
          networkClass: TemplateFeedNetworkClass.cellular,
        ),
      );
    addTearDown(manager.dispose);
    final template = videoTemplate(
      previewUrl: url,
      thumbnailUrl: url,
      feedLoopLowUrl: url,
    );
    Future<VideoPlayerController> create(String url) async =>
        VideoPlayerController.networkUrl(Uri.parse(url));
    VideoPlayerController? original;
    for (final brightness in [
      Brightness.light,
      Brightness.dark,
      Brightness.light,
    ]) {
      await tester.pumpWidget(
        _DiscoveryMediaHost(
          manager: manager,
          template: template,
          previewControllerFactory: create,
          brightness: brightness,
        ),
      );
      await tester.pump();
      if (original == null) _showDiscoveryMedia(tester);
      await pumpUntil(
        tester,
        () => find.byType(VideoPlayer).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 1),
      );
      final controller = tester
          .widget<VideoPlayer>(find.byType(VideoPlayer))
          .controller;
      original ??= controller;
      expect(identical(controller, original), isTrue);
      expect(controller.value.isPlaying, isTrue);
      expect(fakePlatform.createCalls, 1);
      expect(fakePlatform.disposeCalls, 0);
    }
    _hideDiscoveryMedia(tester);
    await pumpUntil(
      tester,
      () => fakePlatform.disposeCalls == 1,
      timeout: const Duration(seconds: 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mixed discovery keeps static fallback on a slow connection', (
    tester,
  ) async {
    const previewUrl = 'https://cdn.example.com/templates/slow-network.mp4';
    final manager = TemplateFeedPlaybackManager()
      ..configure(
        feedKind: TemplateFeedKind.mixed,
        environment: const TemplateFeedPlaybackEnvironment(
          networkClass: TemplateFeedNetworkClass.slow,
        ),
      );
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      _DiscoveryMediaHost(
        manager: manager,
        template: videoTemplate(
          previewUrl: previewUrl,
          thumbnailUrl: previewUrl,
          feedLoopLowUrl: previewUrl,
        ),
        previewControllerFactory: (url) async =>
            VideoPlayerController.networkUrl(Uri.parse(url)),
      ),
    );
    await tester.pump();
    _showDiscoveryMedia(tester);
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    expect(fakePlatform.createCalls, 0);
    expect(find.byType(VideoPlayer), findsNothing);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed discovery preview exposes retry and recovers', (
    tester,
  ) async {
    const previewUrl = 'https://cdn.example.com/templates/retry-preview.mp4';
    final manager = TemplateFeedPlaybackManager()
      ..configure(
        feedKind: TemplateFeedKind.mixed,
        environment: const TemplateFeedPlaybackEnvironment(
          networkClass: TemplateFeedNetworkClass.cellular,
        ),
      );
    addTearDown(manager.dispose);
    var attempts = 0;

    await tester.pumpWidget(
      _DiscoveryMediaHost(
        manager: manager,
        template: videoTemplate(
          previewUrl: previewUrl,
          thumbnailUrl: previewUrl,
          feedLoopLowUrl: previewUrl,
        ),
        previewControllerFactory: (url) async {
          attempts++;
          if (attempts == 1) {
            throw StateError('preview unavailable');
          }
          return VideoPlayerController.networkUrl(Uri.parse(url));
        },
      ),
    );
    await tester.pump();
    await pumpUntil(
      tester,
      () => find.text('Preview unavailable').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 1),
    );

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await pumpUntil(
      tester,
      () => fakePlatform.playCalls > 0,
      timeout: const Duration(seconds: 1),
    );
    await tester.pump();

    expect(attempts, 2);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.text('Preview unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed preview releases the cellular slot to the next card', (
    tester,
  ) async {
    const failedUrl = 'https://cdn.example.com/templates/failed.mp4';
    const healthyUrl = 'https://cdn.example.com/templates/healthy.mp4';
    final manager = TemplateFeedPlaybackManager()
      ..configure(
        feedKind: TemplateFeedKind.mixed,
        environment: const TemplateFeedPlaybackEnvironment(
          networkClass: TemplateFeedNetworkClass.cellular,
        ),
      );
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      _TwoDiscoveryMediaHost(
        manager: manager,
        failedTemplate: videoTemplate(
          id: 'failed-template',
          previewUrl: failedUrl,
          thumbnailUrl: failedUrl,
          feedLoopLowUrl: failedUrl,
        ),
        healthyTemplate: videoTemplate(
          id: 'healthy-template',
          previewUrl: healthyUrl,
          thumbnailUrl: healthyUrl,
          feedLoopLowUrl: healthyUrl,
        ),
      ),
    );
    await tester.pump();

    _showDiscoveryMediaAt(tester, 0);
    _showDiscoveryMediaAt(tester, 1);
    await pumpUntil(
      tester,
      () =>
          find.text('Preview unavailable').evaluate().isNotEmpty &&
          fakePlatform.playCalls > 0,
      timeout: const Duration(seconds: 1),
    );

    expect(manager.activeVideoControllersCount, 1);
    expect(fakePlatform.createdUris, [healthyUrl]);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry remains tappable and accessible inside a discovery tile', (
    tester,
  ) async {
    const previewUrl = 'https://cdn.example.com/templates/tile-retry.mp4';
    final manager = TemplateFeedPlaybackManager()
      ..configure(
        feedKind: TemplateFeedKind.mixed,
        environment: const TemplateFeedPlaybackEnvironment(
          networkClass: TemplateFeedNetworkClass.cellular,
        ),
      );
    addTearDown(manager.dispose);
    var attempts = 0;
    var templateOpenCalls = 0;
    final template = videoTemplate(
      id: 'tile-retry-template',
      previewUrl: previewUrl,
      thumbnailUrl: previewUrl,
      feedLoopLowUrl: previewUrl,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TemplateDiscoveryRail(
            section: TemplateDiscoverySection(
              category: 'Funny',
              items: [template],
            ),
            sectionIndex: 0,
            moreLabel: 'See all',
            playbackManager: manager,
            previewControllerFactory: (url) async {
              attempts++;
              if (attempts == 1) {
                throw StateError('preview unavailable');
              }
              return VideoPlayerController.networkUrl(Uri.parse(url));
            },
            onMorePressed: () {},
            onTemplatePressed: (_) => templateOpenCalls++,
          ),
        ),
      ),
    );
    await tester.pump();
    _showDiscoveryMedia(tester);
    await pumpUntil(
      tester,
      () => find.text('Preview unavailable').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 1),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(find.semantics.byLabel('Retry'), findsOneWidget);
      final retryContext = tester.element(find.text('Retry'));
      final retryColor = TextButtonTheme.of(
        retryContext,
      ).style!.foregroundColor!.resolve({})!;
      expect(
        PetMagicPalettes.contrastRatio(
          retryColor,
          retryContext.petMagicColors.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(find.text('Retry'));
      await pumpUntil(
        tester,
        () => fakePlatform.playCalls > 0,
        timeout: const Duration(seconds: 1),
      );
    } finally {
      semantics.dispose();
    }

    expect(attempts, 2);
    expect(templateOpenCalls, 0);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DiscoveryMediaHost extends StatelessWidget {
  const _DiscoveryMediaHost({
    required this.manager,
    required this.template,
    required this.previewControllerFactory,
    this.brightness = Brightness.light,
  });

  final TemplateFeedPlaybackManager manager;
  final Brightness brightness;
  final TemplateItem template;
  final Future<VideoPlayerController> Function(String previewUrl)
  previewControllerFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 132,
            height: 198,
            child: TemplateDiscoveryMedia(
              category: 'Funny',
              paletteIndex: 1,
              template: template,
              playbackManager: manager,
              previewControllerFactory: previewControllerFactory,
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoDiscoveryMediaHost extends StatelessWidget {
  const _TwoDiscoveryMediaHost({
    required this.manager,
    required this.failedTemplate,
    required this.healthyTemplate,
  });

  final TemplateFeedPlaybackManager manager;
  final TemplateItem failedTemplate;
  final TemplateItem healthyTemplate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 132,
              height: 198,
              child: TemplateDiscoveryMedia(
                category: 'Funny',
                paletteIndex: 0,
                template: failedTemplate,
                playbackManager: manager,
                previewControllerFactory: (_) async =>
                    throw StateError('preview unavailable'),
              ),
            ),
            SizedBox(
              width: 132,
              height: 198,
              child: TemplateDiscoveryMedia(
                category: 'Funny',
                paletteIndex: 1,
                template: healthyTemplate,
                playbackManager: manager,
                previewControllerFactory: (url) async =>
                    VideoPlayerController.networkUrl(Uri.parse(url)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDiscoveryMedia(WidgetTester tester) {
  final detector = tester.widget<VisibilityDetector>(
    find.byType(VisibilityDetector),
  );
  detector.onVisibilityChanged?.call(
    VisibilityInfo(
      key: detector.key!,
      size: const Size(132, 198),
      visibleBounds: const Offset(0, 0) & const Size(132, 198),
    ),
  );
}

void _showDiscoveryMediaAt(WidgetTester tester, int index) {
  final detector = tester
      .widgetList<VisibilityDetector>(find.byType(VisibilityDetector))
      .elementAt(index);
  detector.onVisibilityChanged?.call(
    VisibilityInfo(
      key: detector.key!,
      size: const Size(132, 198),
      visibleBounds: const Offset(0, 0) & const Size(132, 198),
    ),
  );
}

void _hideDiscoveryMedia(WidgetTester tester) {
  final detector = tester.widget<VisibilityDetector>(
    find.byType(VisibilityDetector),
  );
  detector.onVisibilityChanged?.call(
    VisibilityInfo(
      key: detector.key!,
      size: const Size(132, 198),
      visibleBounds: Rect.zero,
    ),
  );
}
