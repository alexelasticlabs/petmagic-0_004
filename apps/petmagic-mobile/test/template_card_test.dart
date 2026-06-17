import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerPlatform originalPlatform;
  late _FakeVideoPlayerPlatform fakePlatform;
  late Directory sharedMediaCacheRoot;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() async {
    originalPathProvider = PathProviderPlatform.instance;
    sharedMediaCacheRoot = await Directory.systemTemp.createTemp(
      'petmagic-template-card-media-cache-test-',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
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
    fakePlatform = _FakeVideoPlayerPlatform();
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
    final template = _videoTemplate();
    await tester.pumpWidget(
      _buildHost(
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
      final template = _videoTemplate(
        id: 'video-template-muted-loop',
        previewUrl: 'https://cdn.example.com/templates/muted-loop-preview.mp4',
      );

      await tester.pumpWidget(
        _buildHost(
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
      await _pumpUntil(
        tester,
        () =>
            fakePlatform.loopingValues.contains(true) &&
            fakePlatform.volumeValues.contains(0),
        timeout: const Duration(seconds: 1),
      );
      expect(fakePlatform.loopingValues, [true]);
      expect(fakePlatform.volumeValues, [0]);

      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(320, 240),
          visibleBounds: const Rect.fromLTWH(0, 0, 320, 180),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(fakePlatform.createCalls, equals(1));
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

    final template = _videoTemplate(
      id: 'video-template-cached-card-preview',
      previewUrl: previewUrl,
    );

    await tester.pumpWidget(_buildHost(template));
    await tester.pump();
    _showTemplateCard(tester);
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => fakePlatform.createdSourceTypes.contains(DataSourceType.file),
      timeout: const Duration(seconds: 2),
    );
    await tester.pump();

    expect(fakePlatform.createCalls, equals(1));
    expect(fakePlatform.createdSourceTypes, [DataSourceType.file]);
    expect(fakePlatform.createdUris, isNot(contains(previewUrl)));

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 2),
    );

    await tester.pumpWidget(_buildHost(template));
    await tester.pump();
    _showTemplateCard(tester);
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));
    await tester.pump();
    await _pumpUntil(
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
    await _pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard ignores duplicate and stale video preview init', (
    tester,
  ) async {
    final firstTemplate = _videoTemplate(
      id: 'video-template-first',
      previewUrl: 'https://cdn.example.com/templates/first-preview.mp4',
    );
    final secondTemplate = _videoTemplate(
      id: 'video-template-second',
      previewUrl: 'https://cdn.example.com/templates/second-preview.mp4',
    );
    final firstController = Completer<VideoPlayerController>();
    final secondController = Completer<VideoPlayerController>();
    final requestedUrls = <String>[];

    await tester.pumpWidget(
      _buildHost(
        firstTemplate,
        previewControllerFactory: (previewUrl) {
          requestedUrls.add(previewUrl);
          return firstController.future;
        },
      ),
    );
    await tester.pump();

    _showTemplateCard(tester);
    _showTemplateCard(tester);

    expect(requestedUrls, [firstTemplate.previewAsset!.url]);

    await tester.pumpWidget(
      _buildHost(
        secondTemplate,
        previewControllerFactory: (previewUrl) {
          requestedUrls.add(previewUrl);
          return secondController.future;
        },
      ),
    );
    await tester.pump();
    _showTemplateCard(tester);

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
      final template = _videoTemplate(
        id: 'video-template-scroll-away',
        previewUrl: 'https://cdn.example.com/templates/scroll-away.mp4',
      );
      final firstController = Completer<VideoPlayerController>();
      final requestedUrls = <String>[];

      await tester.pumpWidget(
        _buildHost(
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

      _showTemplateCard(tester);
      await tester.pump();

      expect(requestedUrls, [template.previewAsset!.url]);
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

      _hideTemplateCard(tester);
      await tester.pump(const Duration(milliseconds: 80));

      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

      firstController.complete(
        VideoPlayerController.networkUrl(Uri.parse(template.previewAsset!.url)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(fakePlatform.createCalls, equals(0));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

      _showTemplateCard(tester);
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
      final template = _videoTemplate(
        id: 'video-template-initialize-race',
        previewUrl: 'https://cdn.example.com/templates/init-race.mp4',
      );
      final initializeGate = Completer<void>();
      fakePlatform.initializedEventGate = initializeGate;

      await tester.pumpWidget(
        _buildHost(
          template,
          previewControllerFactory: (previewUrl) async =>
              VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
        ),
      );
      await tester.pump();

      _showTemplateCard(tester);
      await _pumpUntil(
        tester,
        () => fakePlatform.operations.contains('setVolume:0.0'),
        timeout: const Duration(seconds: 1),
      );

      expect(fakePlatform.createCalls, equals(1));
      expect(fakePlatform.disposeCalls, equals(0));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

      _hideTemplateCard(tester);
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
      await _pumpUntil(
        tester,
        () => fakePlatform.disposeCalls == 1,
        timeout: const Duration(seconds: 1),
      );

      expect(fakePlatform.playCalls, equals(0));
      expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TemplateCard keeps video preview alive while tab is offstage', (
    tester,
  ) async {
    final template = _videoTemplate(
      id: 'video-template-hidden-tab',
      previewUrl: 'https://cdn.example.com/templates/hidden-tab-preview.mp4',
    );

    await tester.pumpWidget(
      _TickerModeHost(
        child: _buildHost(
          template,
          previewControllerFactory: (previewUrl) async =>
              VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
        ),
      ),
    );
    await tester.pump();

    _showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(1));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

    final hostState = tester.state<_TickerModeHostState>(
      find.byType(_TickerModeHost),
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

    expect(fakePlatform.disposeCalls, equals(0));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

    hostState.setEnabled(true);
    await tester.pump();
    _showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 80));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard releases visible video preview on app background', (
    tester,
  ) async {
    final template = _videoTemplate(
      id: 'video-template-app-background',
      previewUrl: 'https://cdn.example.com/templates/app-background.mp4',
    );

    await tester.pumpWidget(
      _buildHost(
        template,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();

    _showTemplateCard(tester);
    await _pumpUntil(
      tester,
      () => fakePlatform.playCalls > 0,
      timeout: const Duration(seconds: 1),
    );

    expect(fakePlatform.createCalls, equals(1));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pumpUntil(
      tester,
      () =>
          fakePlatform.disposeCalls == 1 &&
          MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 1),
    );

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpUntil(
      tester,
      () =>
          fakePlatform.createCalls == 2 &&
          MediaLifecyclePolicy.activeVideoPreviews == 1,
      timeout: const Duration(seconds: 1),
    );

    expect(fakePlatform.createCalls, equals(2));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 1),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard limits concurrent visible video previews', (
    tester,
  ) async {
    final templates = List<TemplateItem>.generate(
      6,
      (index) => _videoTemplate(
        id: 'video-template-$index',
        previewUrl: 'https://cdn.example.com/templates/preview-$index.mp4',
      ),
    );

    await tester.pumpWidget(_buildGridHost(templates));
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
    await _pumpUntil(
      tester,
      () => fakePlatform.createCalls >= 4,
      timeout: const Duration(seconds: 1),
    );

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(4));
    expect(fakePlatform.createCalls, equals(4));
    expect(
      fakePlatform.createdUris,
      templates
          .take(4)
          .map((template) => template.previewAsset!.url)
          .toList(growable: false),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(
      tester,
      () => MediaLifecyclePolicy.activeVideoPreviews == 0,
      timeout: const Duration(seconds: 1),
    );

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard resets stale preview state when media changes', (
    tester,
  ) async {
    final firstTemplate = _videoTemplate(
      id: 'video-template-stale',
      previewUrl: 'https://cdn.example.com/templates/stale-preview.mp4',
    );
    final secondTemplate = _videoTemplate(
      id: firstTemplate.templateId,
      previewUrl: 'https://cdn.example.com/templates/recovered-preview.mp4',
    );

    await tester.pumpWidget(
      _buildHost(
        firstTemplate,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();
    _showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(1));
    expect(fakePlatform.createdUris, [firstTemplate.previewAsset!.url]);

    await tester.pumpWidget(
      _buildHost(
        secondTemplate,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();
    _showTemplateCard(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(2));
    expect(fakePlatform.createdUris, [
      firstTemplate.previewAsset!.url,
      secondTemplate.previewAsset!.url,
    ]);
  });

  testWidgets('TemplateCard keeps image subtree stable across filter context', (
    tester,
  ) async {
    final template = _imageTemplate();

    await tester.pumpWidget(
      _buildHost(template, renderContextKey: 'all|all||20'),
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
      _buildHost(template, renderContextKey: 'all|portrait||20'),
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
    final source = await File(
      'lib/features/templates/presentation/widgets/template_card.dart',
    ).readAsString();
    final withThumbnail = _imageTemplate(
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
      final template = _videoTemplate(id: 'video-template-error-layout');

      await tester.pumpWidget(
        _buildHost(
          template,
          theme: AppTheme.dark(),
          hasPremiumAccess: false,
          size: const Size(188, 260),
          previewControllerFactory: (_) async =>
              throw StateError('preview unavailable'),
        ),
      );
      await tester.pump();

      _showTemplateCard(tester, size: const Size(188, 260));
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
}

void _showTemplateCard(
  WidgetTester tester, {
  Size size = const Size(320, 240),
}) {
  final detector = tester.widget<VisibilityDetector>(
    find.byType(VisibilityDetector),
  );

  detector.onVisibilityChanged?.call(
    VisibilityInfo(
      key: detector.key!,
      size: size,
      visibleBounds: Offset.zero & size,
    ),
  );
}

void _hideTemplateCard(
  WidgetTester tester, {
  Size size = const Size(320, 240),
}) {
  final detector = tester.widget<VisibilityDetector>(
    find.byType(VisibilityDetector),
  );

  detector.onVisibilityChanged?.call(
    VisibilityInfo(key: detector.key!, size: size, visibleBounds: Rect.zero),
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Widget _buildHost(
  TemplateItem template, {
  Future<VideoPlayerController> Function(String previewUrl)?
  previewControllerFactory,
  String renderContextKey = 'all|all||20',
  ThemeData? theme,
  bool hasPremiumAccess = true,
  Size size = const Size(320, 240),
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: TemplateCard(
            template: template,
            hasPremiumAccess: hasPremiumAccess,
            renderContextKey: renderContextKey,
            previewControllerFactory: previewControllerFactory,
          ),
        ),
      ),
    ),
  );
}

Widget _buildGridHost(List<TemplateItem> templates) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final template in templates)
              SizedBox(
                width: 188,
                height: 260,
                child: TemplateCard(
                  template: template,
                  hasPremiumAccess: true,
                  renderContextKey: 'all|all||20',
                  previewControllerFactory: (previewUrl) async =>
                      VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

TemplateItem _videoTemplate({
  String id = 'video-template-test',
  String previewUrl = 'https://cdn.example.com/templates/test-preview.mp4',
}) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.video,
    title: 'Video Template',
    shortDescription: 'Template card viewport lifecycle test',
    petPhotoRequirements: const <String>['Clear pet photo'],
    category: 'test',
    tags: const <String>['viewport', 'video'],
    isPremium: false,
    tokenCost: 5,
    previewAsset: TemplateAsset(
      url: previewUrl,
      fileName: 'test-preview.mp4',
      contentType: 'video/mp4',
      durationSeconds: 6,
    ),
    referenceVideoDurationSeconds: 6,
  );
}

TemplateItem _imageTemplate({
  String id = 'image-template-test',
  String previewUrl = 'https://cdn.example.com/templates/test-preview.jpg',
  String? assetUrl,
}) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.image,
    title: 'Image Template',
    shortDescription: 'Template card image lifecycle test',
    petPhotoRequirements: const <String>['Clear pet photo'],
    category: 'test',
    tags: const <String>['viewport', 'image'],
    isPremium: false,
    tokenCost: 5,
    thumbnailUrl: previewUrl,
    previewAsset: TemplateAsset(
      url: assetUrl ?? previewUrl,
      fileName: (assetUrl ?? previewUrl).split('/').last,
      contentType: 'image/jpeg',
    ),
  );
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 1;
  final Map<int, StreamController<VideoEvent>> _eventsByPlayerId =
      <int, StreamController<VideoEvent>>{};
  final Set<int> _initializedPlayerIds = <int>{};

  int createCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;
  final List<String?> createdUris = <String?>[];
  final List<DataSourceType> createdSourceTypes = <DataSourceType>[];
  final List<bool> loopingValues = <bool>[];
  final List<double> volumeValues = <double>[];
  final List<String> operations = <String>[];
  Completer<void>? initializedEventGate;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    createCalls += 1;
    createdUris.add(dataSource.uri);
    createdSourceTypes.add(dataSource.sourceType);
    operations.add('create');
    final playerId = _nextPlayerId++;
    final events = StreamController<VideoEvent>.broadcast();
    _eventsByPlayerId[playerId] = events;

    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    if (_initializedPlayerIds.add(playerId)) {
      unawaited(_emitInitializedEvent(playerId));
    }
    return _eventsByPlayerId[playerId]!.stream;
  }

  Future<void> _emitInitializedEvent(int playerId) async {
    final gate = initializedEventGate;
    if (gate != null) {
      await gate.future;
    } else {
      await Future<void>.microtask(() {});
    }

    _eventsByPlayerId[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 6),
        size: const Size(720, 1280),
      ),
    );
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loopingValues.add(looping);
    operations.add('setLooping:$looping');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumeValues.add(volume);
    operations.add('setVolume:$volume');
  }

  @override
  Future<void> play(int playerId) async {
    playCalls += 1;
    operations.add('play');
    _eventsByPlayerId[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls += 1;
    operations.add('pause');
    _eventsByPlayerId[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<Duration> getPosition(int playerId) async {
    return Duration.zero;
  }

  @override
  Widget buildView(int playerId) {
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose(int playerId) async {
    disposeCalls += 1;
    operations.add('dispose');
    await _eventsByPlayerId.remove(playerId)?.close();
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final Directory root;

  @override
  Future<String?> getTemporaryPath() async {
    return _ensureDirectory('tmp').path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _ensureDirectory('support').path;
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return _ensureDirectory('cache').path;
  }

  Directory _ensureDirectory(String name) {
    final directory = Directory('${root.path}/$name');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}

class _TickerModeHost extends StatefulWidget {
  const _TickerModeHost({required this.child});

  final Widget child;

  @override
  State<_TickerModeHost> createState() => _TickerModeHostState();
}

class _TickerModeHostState extends State<_TickerModeHost> {
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
