import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'template_card_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerPlatform originalPlatform;
  late FakeVideoPlayerPlatform fakePlatform;
  late Directory sharedMediaCacheRoot;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() async {
    originalPathProvider = PathProviderPlatform.instance;
    sharedMediaCacheRoot = await Directory.systemTemp.createTemp(
      'petmagic-template-card-media-cache-test-',
    );
    PathProviderPlatform.instance = FakePathProviderPlatform(
      sharedMediaCacheRoot,
    );
  });

  tearDownAll(() async {
    await TemplateMediaCache.clearAll();
    PathProviderPlatform.instance = originalPathProvider;
    if (await sharedMediaCacheRoot.exists()) {
      await sharedMediaCacheRoot.delete(recursive: true);
    }
  });

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    while (MediaLifecyclePolicy.activeVideoPreviews > 0) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
    }
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    while (MediaLifecyclePolicy.activeVideoPreviews > 0) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
    }
  });

  testWidgets('TemplateCard manages video preview lifecycle by viewport', (
    tester,
  ) async {
    final template = videoTemplate();
    await tester.pumpWidget(
      buildTemplateCardHost(
        template,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );

    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(320, 240),
        visibleBounds: const Rect.fromLTWH(0, 0, 320, 240),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, greaterThan(0));

    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(320, 240),
        visibleBounds: Rect.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 80));

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TemplateCard configures visible video preview as muted and looping',
    (tester) async {
      final template = videoTemplate(
        id: 'video-template-muted-loop',
        previewUrl: 'https://cdn.example.com/templates/muted-loop-preview.mp4',
      );

      await tester.pumpWidget(
        buildTemplateCardHost(
          template,
          previewControllerFactory: (previewUrl) async =>
              VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
        ),
      );
      await tester.pump();

      final detector = tester.widget<VisibilityDetector>(
        find.byType(VisibilityDetector),
      );

      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(320, 240),
          visibleBounds: const Rect.fromLTWH(0, 0, 320, 96),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(fakePlatform.createCalls, equals(1));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(320, 240),
          visibleBounds: const Rect.fromLTWH(0, 0, 320, 180),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(fakePlatform.createCalls, equals(2));
      await pumpUntil(
        tester,
        () =>
            fakePlatform.loopingValues.contains(true) &&
            fakePlatform.volumeValues.contains(0),
        timeout: const Duration(seconds: 1),
      );
      expect(fakePlatform.loopingValues, everyElement(true));
      expect(fakePlatform.volumeValues, everyElement(0));
      expect(fakePlatform.playCalls, greaterThan(0));
      final firstPlayIndex = fakePlatform.operations.indexOf('play');
      expect(firstPlayIndex, greaterThan(-1));
      expect(
        fakePlatform.operations.indexOf('setLooping:true'),
        lessThan(firstPlayIndex),
      );
      expect(
        fakePlatform.operations.indexOf('setVolume:0.0'),
        lessThan(firstPlayIndex),
      );

      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(320, 240),
          visibleBounds: const Rect.fromLTWH(0, 0, 320, 96),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(fakePlatform.pauseCalls, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TemplateCard reuses cached video preview file across rebuilds', (
    tester,
  ) async {
    const previewUrl =
        'https://cdn.example.com/templates/shared-card-preview.mp4';
    String? cachedPreviewPath;
    await tester.runAsync(() async {
      await TemplateMediaCache.clearAll();
      await TemplateMediaCache.previewVideoCache.putFile(
        previewUrl,
        Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]),
        maxAge: const Duration(hours: 1),
        fileExtension: 'mp4',
      );
      cachedPreviewPath = (await TemplateMediaCache.getCachedPreviewFile(
        previewUrl,
      ))?.path;
    });
    expect(cachedPreviewPath, isNotNull);
    addTearDown(() async {
      await tester.runAsync(() async {
        await TemplateMediaCache.clearAll();
      });
    });

    final template = videoTemplate(
      id: 'video-template-cached-card-preview',
      previewUrl: previewUrl,
    );

    await tester.pumpWidget(
      buildTemplateCardHost(
        template,
        previewControllerFactory: (_) async =>
            VideoPlayerController.file(File(cachedPreviewPath!)),
      ),
    );
    await tester.pump();
    showTemplateCard(tester);
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));
    await tester.pump();
    await pumpUntil(
      tester,
      () => fakePlatform.createdSourceTypes.contains(DataSourceType.file),
      timeout: const Duration(seconds: 2),
    );
    await tester.pump();

    expect(fakePlatform.createCalls, equals(1));
    expect(fakePlatform.createdSourceTypes, [DataSourceType.file]);
    expect(fakePlatform.createdUris, isNot(contains(previewUrl)));

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 2),
    );

    await tester.pumpWidget(
      buildTemplateCardHost(
        template,
        previewControllerFactory: (_) async =>
            VideoPlayerController.file(File(cachedPreviewPath!)),
      ),
    );
    await tester.pump();
    showTemplateCard(tester);
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));
    await tester.pump();
    await pumpUntil(
      tester,
      () => fakePlatform.createCalls == 2,
      timeout: const Duration(seconds: 2),
    );
    await tester.pump();

    expect(fakePlatform.createdSourceTypes, [
      DataSourceType.file,
      DataSourceType.file,
    ]);
    expect(fakePlatform.createdUris, isNot(contains(previewUrl)));

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard ignores duplicate and stale video preview init', (
    tester,
  ) async {
    final firstTemplate = videoTemplate(
      id: 'video-template-first',
      previewUrl: 'https://cdn.example.com/templates/first-preview.mp4',
    );
    final secondTemplate = videoTemplate(
      id: 'video-template-second',
      previewUrl: 'https://cdn.example.com/templates/second-preview.mp4',
    );
    final firstController = Completer<VideoPlayerController>();
    final secondController = Completer<VideoPlayerController>();
    final requestedUrls = <String>[];

    await tester.pumpWidget(
      buildTemplateCardHost(
        firstTemplate,
        previewControllerFactory: (previewUrl) {
          requestedUrls.add(previewUrl);
          return firstController.future;
        },
      ),
    );
    await tester.pump();

    showTemplateCard(tester);
    showTemplateCard(tester);

    expect(requestedUrls, [firstTemplate.previewAsset!.url]);

    await tester.pumpWidget(
      buildTemplateCardHost(
        secondTemplate,
        previewControllerFactory: (previewUrl) {
          requestedUrls.add(previewUrl);
          return secondController.future;
        },
      ),
    );
    await tester.pump();
    showTemplateCard(tester);

    expect(requestedUrls, [
      firstTemplate.previewAsset!.url,
      secondTemplate.previewAsset!.url,
    ]);

    firstController.complete(
      VideoPlayerController.networkUrl(
        Uri.parse(firstTemplate.previewAsset!.url),
      ),
    );
    await tester.pump();

    expect(fakePlatform.createCalls, equals(0));

    secondController.complete(
      VideoPlayerController.networkUrl(
        Uri.parse(secondTemplate.previewAsset!.url),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(1));
    expect(fakePlatform.createdUris, [secondTemplate.previewAsset!.url]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 80));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TemplateCard abandons async video init when card leaves viewport',
    (tester) async {
      final template = videoTemplate(
        id: 'video-template-scroll-away',
        previewUrl: 'https://cdn.example.com/templates/scroll-away.mp4',
      );
      final firstController = Completer<VideoPlayerController>();
      final requestedUrls = <String>[];

      await tester.pumpWidget(
        buildTemplateCardHost(
          template,
          previewControllerFactory: (previewUrl) {
            requestedUrls.add(previewUrl);
            if (requestedUrls.length == 1) {
              return firstController.future;
            }

            return Future.value(
              VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
            );
          },
        ),
      );
      await tester.pump();

      showTemplateCard(tester);
      await tester.pump();

      expect(requestedUrls, [template.previewAsset!.url]);
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

      hideTemplateCard(tester);
      await tester.pump(const Duration(milliseconds: 80));

      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

      firstController.complete(
        VideoPlayerController.networkUrl(Uri.parse(template.previewAsset!.url)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(fakePlatform.createCalls, equals(0));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

      showTemplateCard(tester);
      await tester.pump(const Duration(milliseconds: 120));

      expect(requestedUrls, [
        template.previewAsset!.url,
        template.previewAsset!.url,
      ]);
      expect(fakePlatform.createCalls, equals(1));
      expect(fakePlatform.createdUris, [template.previewAsset!.url]);
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 80));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TemplateCard defers stale video dispose until initialize completes',
    (tester) async {
      final template = videoTemplate(
        id: 'video-template-initialize-race',
        previewUrl: 'https://cdn.example.com/templates/init-race.mp4',
      );
      final initializeGate = Completer<void>();
      fakePlatform.initializedEventGate = initializeGate;

      await tester.pumpWidget(
        buildTemplateCardHost(
          template,
          previewControllerFactory: (previewUrl) async =>
              VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
        ),
      );
      await tester.pump();

      showTemplateCard(tester);
      await pumpUntil(
        tester,
        () => fakePlatform.operations.contains('setVolume:0.0'),
        timeout: const Duration(seconds: 1),
      );

      expect(fakePlatform.createCalls, equals(1));
      expect(fakePlatform.disposeCalls, equals(0));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

      hideTemplateCard(tester);
      await tester.pump(const Duration(milliseconds: 120));

      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
      expect(
        fakePlatform.disposeCalls,
        equals(0),
        reason:
            'Disposing while VideoPlayerController.initialize is still waiting '
            'can release the native surface before MediaCodec finishes setup.',
      );

      initializeGate.complete();
      await pumpUntil(
        tester,
        () => fakePlatform.disposeCalls == 1,
        timeout: const Duration(seconds: 1),
      );

      expect(fakePlatform.playCalls, equals(0));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TemplateCard releases video preview when card leaves viewport', (
    tester,
  ) async {
    final template = videoTemplate(
      id: 'video-template-hidden-tab',
      previewUrl: 'https://cdn.example.com/templates/hidden-tab-preview.mp4',
    );

    await tester.pumpWidget(
      TickerModeHost(
        child: buildTemplateCardHost(
          template,
          previewControllerFactory: (previewUrl) async =>
              VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
        ),
      ),
    );
    await tester.pump();

    showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(1));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

    final hostState = tester.state<TickerModeHostState>(
      find.byType(TickerModeHost),
    );
    hostState.setEnabled(false);
    await tester.pump();

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(320, 240),
        visibleBounds: Rect.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1000));

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

    hostState.setEnabled(true);
    await tester.pump();
    showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 80));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard releases visible video preview on app background', (
    tester,
  ) async {
    final template = videoTemplate(
      id: 'video-template-app-background',
      previewUrl: 'https://cdn.example.com/templates/app-background.mp4',
    );

    await tester.pumpWidget(
      buildTemplateCardHost(
        template,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();

    showTemplateCard(tester);
    await pumpUntil(
      tester,
      () => fakePlatform.playCalls > 0,
      timeout: const Duration(seconds: 1),
    );

    expect(fakePlatform.createCalls, equals(1));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpUntil(
      tester,
      () =>
          fakePlatform.disposeCalls == 1 &&
          MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 1),
    );

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpUntil(
      tester,
      () =>
          fakePlatform.createCalls == 2 &&
          MediaLifecyclePolicy.activeVideoPreviews == 1,
      timeout: const Duration(seconds: 1),
    );

    expect(fakePlatform.createCalls, equals(2));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 1),
    );

    expect(tester.takeException(), isNull);
  });

  test('TemplateCard featured countdown is gated by visibility lifecycle', () {
    final source = File(
      'lib/features/templates/presentation/widgets/template_card.dart',
    ).readAsStringSync();
    final initStateBody = _methodBody(source, 'void initState()');
    final lifecycleBody = _methodBody(
      source,
      'void _handleAppLifecycleChanged()',
    );
    final tickerGuardBody = _getterBody(
      source,
      'bool get _shouldRunFeaturedCountdownTicker',
    );

    expect(initStateBody, isNot(contains('_syncFeaturedCountdownTicker();')));
    expect(source, contains('void didChangeDependencies()'));
    expect(source, isNot(contains('Timer.periodic')));
    expect(source, contains('_featuredCountdownTimer = Timer(delay, ()'));
    expect(lifecycleBody, contains('_featuredCountdownTimer?.cancel();'));
    expect(tickerGuardBody, contains('AppLifecycleState.resumed'));
    expect(tickerGuardBody, contains('TickerMode.valuesOf(context).enabled'));
  });

  testWidgets('TemplateCard limits concurrent visible video previews', (
    tester,
  ) async {
    final templates = List<TemplateItem>.generate(
      6,
      (index) => videoTemplate(
        id: 'video-template-$index',
        previewUrl: 'https://cdn.example.com/templates/preview-$index.mp4',
      ),
    );

    await tester.pumpWidget(buildTemplateCardGridHost(templates));
    await tester.pump();

    final detectors = tester
        .widgetList<VisibilityDetector>(find.byType(VisibilityDetector))
        .toList(growable: false);
    expect(detectors, hasLength(6));
    for (final detector in detectors) {
      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(188, 260),
          visibleBounds: const Rect.fromLTWH(0, 0, 188, 260),
        ),
      );
    }
    await pumpUntil(
      tester,
      () => fakePlatform.createCalls >= 2,
      timeout: const Duration(seconds: 1),
    );

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(2));
    expect(fakePlatform.createCalls, equals(2));
    expect(
      fakePlatform.createdUris,
      templates
          .take(2)
          .map((template) => template.previewAsset!.url)
          .toList(growable: false),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 1),
    );

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard uses adaptive feed loop url selected by manager', (
    tester,
  ) async {
    final template = videoTemplate(
      id: 'video-template-adaptive-quality',
      previewUrl: 'https://cdn.example.com/templates/detail-preview.mp4',
      feedLoopLowUrl: 'https://cdn.example.com/templates/feed-low.mp4',
      feedLoopMediumUrl: 'https://cdn.example.com/templates/feed-medium.mp4',
      mediaVersion: 12,
    );
    final manager = TemplateFeedPlaybackManager()
      ..configure(
        environment: const TemplateFeedPlaybackEnvironment(
          networkClass: TemplateFeedNetworkClass.cellular,
        ),
      );
    final requestedUrls = <String>[];

    await tester.pumpWidget(
      buildTemplateCardHost(
        template,
        playbackManager: manager,
        previewControllerFactory: (previewUrl) async {
          requestedUrls.add(previewUrl);
          return VideoPlayerController.networkUrl(Uri.parse(previewUrl));
        },
      ),
    );
    await tester.pump();
    showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(requestedUrls, ['https://cdn.example.com/templates/feed-low.mp4']);
    expect(fakePlatform.createdUris, [
      'https://cdn.example.com/templates/feed-low.mp4',
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 1),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard resets stale preview state when media changes', (
    tester,
  ) async {
    final firstTemplate = videoTemplate(
      id: 'video-template-stale',
      previewUrl: 'https://cdn.example.com/templates/stale-preview.mp4',
    );
    final secondTemplate = videoTemplate(
      id: firstTemplate.templateId,
      previewUrl: 'https://cdn.example.com/templates/recovered-preview.mp4',
    );

    await tester.pumpWidget(
      buildTemplateCardHost(
        firstTemplate,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();
    showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(1));
    expect(fakePlatform.createdUris, [firstTemplate.previewAsset!.url]);

    await tester.pumpWidget(
      buildTemplateCardHost(
        secondTemplate,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();
    showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(2));
    expect(fakePlatform.createdUris, [
      firstTemplate.previewAsset!.url,
      secondTemplate.previewAsset!.url,
    ]);
  });

  testWidgets('TemplateCard keeps image subtree stable across cache sizing', (
    tester,
  ) async {
    final template = imageTemplate();

    await tester.pumpWidget(
      buildTemplateCardHost(template, imageCacheWidth: 720),
    );
    await tester.pump();

    expect(
      find.byKey(
        ValueKey(
          'template-image-${template.templateId}'
          '-${template.mediaIdentity}'
          '-0',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      buildTemplateCardHost(template, imageCacheWidth: 840),
    );
    await tester.pump();

    expect(
      find.byKey(
        ValueKey(
          'template-image-${template.templateId}'
          '-${template.mediaIdentity}'
          '-0',
        ),
      ),
      findsOneWidget,
    );
  });

  test('TemplateCard prefers thumbnail over original image preview', () async {
    final cardSource = await File(
      'lib/features/templates/presentation/widgets/template_card.dart',
    ).readAsString();
    final mediaSource = await File(
      'lib/features/templates/presentation/widgets/template_card_media.dart',
    ).readAsString();
    final source = '$cardSource\n$mediaSource';
    final withThumbnail = imageTemplate(
      previewUrl: 'https://cdn.example.com/templates/thumb.jpg',
      assetUrl: 'https://cdn.example.com/templates/original.jpg',
    );
    final withoutThumbnail = TemplateItem(
      templateId: 'image-template-without-thumb',
      templateType: TemplateType.image,
      title: 'Image Template',
      shortDescription: 'Template card image lifecycle test',
      petPhotoRequirements: const <String>['Clear pet photo'],
      category: 'test',
      tags: const <String>['viewport', 'image'],
      isPremium: false,
      tokenCost: 5,
      previewAsset: const TemplateAsset(
        url: 'https://cdn.example.com/templates/original.jpg',
        fileName: 'original.jpg',
        contentType: 'image/jpeg',
      ),
    );

    expect(
      source,
      contains('imageUrl: renderableThumbnailUrl ?? fallbackImageUrl'),
    );
    expect(
      source,
      contains(
        "import 'package:petmagic_mobile/core/lifecycle/app_lifecycle_signal.dart';",
      ),
    );
    expect(source, contains('AppLifecycleSignal.instance.addListener'));
    expect(source, contains('AppLifecycleSignal.instance.removeListener'));
    expect(source, isNot(contains('with WidgetsBindingObserver')));
    expect(source, contains('TemplateMediaCache.fetchThumbnailFile'));
    expect(source, contains('Image.file('));

    expect(
      resolveTemplateCardImageUrlForTesting(withThumbnail),
      'https://cdn.example.com/templates/thumb.jpg',
    );
    expect(
      resolveTemplateCardImageUrlForTesting(withoutThumbnail),
      'https://cdn.example.com/templates/original.jpg',
    );
  });

  test('TemplateCard never treats video preview url as image fallback', () {
    final videoWithThumbnail = TemplateItem(
      templateId: 'video-template-with-thumb',
      templateType: TemplateType.video,
      title: 'Video Template',
      shortDescription: 'Template card video preview resolver test',
      petPhotoRequirements: const <String>['Clear pet photo'],
      category: 'test',
      tags: const <String>['viewport', 'video'],
      isPremium: false,
      tokenCost: 5,
      thumbnailUrl: 'https://cdn.example.com/templates/video-thumb.jpg',
      previewAsset: const TemplateAsset(
        url: 'https://cdn.example.com/templates/video-preview.mp4',
        fileName: 'video-preview.mp4',
        contentType: 'video/mp4',
      ),
    );
    final videoWithoutThumbnail = TemplateItem(
      templateId: 'video-template-without-thumb',
      templateType: TemplateType.video,
      title: 'Video Template',
      shortDescription: 'Template card video preview resolver test',
      petPhotoRequirements: const <String>['Clear pet photo'],
      category: 'test',
      tags: const <String>['viewport', 'video'],
      isPremium: false,
      tokenCost: 5,
      previewAsset: const TemplateAsset(
        url: 'https://cdn.example.com/templates/video-preview.mp4',
        fileName: 'video-preview.mp4',
        contentType: 'video/mp4',
      ),
    );

    expect(
      resolveTemplateCardImageUrlForTesting(videoWithThumbnail),
      'https://cdn.example.com/templates/video-thumb.jpg',
    );
    expect(
      resolveTemplateCardImageUrlForTesting(videoWithoutThumbnail),
      isNull,
    );
  });

  testWidgets(
    'TemplateCard keeps preview error above details on narrow dark cards',
    (tester) async {
      final template = videoTemplate(id: 'video-template-error-layout');

      await tester.pumpWidget(
        buildTemplateCardHost(
          template,
          theme: AppTheme.dark(),
          hasPremiumAccess: false,
          size: const Size(188, 260),
          previewControllerFactory: (_) async =>
              throw StateError('preview unavailable'),
        ),
      );
      await tester.pump();

      showTemplateCard(tester, size: const Size(188, 260));
      await tester.pump(const Duration(milliseconds: 120));

      final errorText = find.text('Preview unavailable');
      final retryText = find.text('Retry');
      final titleText = find.text('Video Template');

      expect(errorText, findsOneWidget);
      expect(retryText, findsOneWidget);
      expect(titleText, findsOneWidget);
      expect(
        tester.getRect(errorText).bottom,
        lessThan(tester.getRect(titleText).top),
      );
      expect(
        tester.getRect(retryText).bottom,
        lessThan(tester.getRect(titleText).top),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TemplateCard constrains Russian featured badge on phone-width cards',
    (tester) async {
      await tester.pumpWidget(
        buildTemplateCardHost(
          imageTemplate(id: 'featured-russian-badge'),
          theme: AppTheme.dark(),
          size: const Size(164, 300),
          locale: const Locale('ru'),
          featuredData: const TemplateCardFeaturedData(
            badgeLabel: 'Выбор дня',
            actionLabel: 'Попробовать шаблон',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Выбор дня'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'Missing method $signature');
  final openBrace = source.indexOf('{', start);
  expect(openBrace, isNonNegative, reason: 'Missing body for $signature');

  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    final character = source[index];
    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(openBrace + 1, index);
      }
    }
  }

  fail('Unterminated body for $signature');
}

String _getterBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'Missing getter $signature');
  final end = source.indexOf(';', start);
  expect(end, isNonNegative, reason: 'Missing getter terminator $signature');
  return source.substring(start, end);
}
