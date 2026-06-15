import 'dart:async' show Completer;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    show DataSourceType;

void main() {
  late Directory sharedMediaCacheRoot;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() async {
    originalPathProvider = PathProviderPlatform.instance;
    sharedMediaCacheRoot = await Directory.systemTemp.createTemp(
      'petmagic-template-media-cache-shared-test-',
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

  test(
    'template presentation keeps network images bounded or cached',
    () async {
      final dartFiles = await Directory('lib/features/templates/presentation')
          .list(recursive: true)
          .where((entity) {
            return entity is File && entity.path.endsWith('.dart');
          })
          .cast<File>()
          .toList();

      expect(dartFiles, isNotEmpty);

      for (final file in dartFiles) {
        final source = await file.readAsString();
        if (!source.contains('Image.network(')) {
          continue;
        }

        expect(source, contains('cacheWidth:'));
        expect(source, contains('errorBuilder:'));
        expect(
          source,
          anyOf(
            contains('TemplateMediaCache.fetchThumbnailFile('),
            contains('CachedNetworkImage('),
          ),
          reason:
              '${file.path} may use Image.network only as a bounded fallback '
              'after trying a cached media path.',
        );
      }
    },
  );

  test(
    'template card fallback image path remains cached and bounded',
    () async {
      final source = await File(
        'lib/features/templates/presentation/widgets/template_card.dart',
      ).readAsString();

      expect(source, contains('parseSafeGenerationMediaUri(candidate)'));
      expect(source, isNot(contains('widget.template.previewAsset!.url;')));
      expect(
        source,
        isNot(
          contains(
            '_normalizeTemplateMediaUrl(widget.template.previewAsset!.url) ??',
          ),
        ),
      );
      expect(source, contains('TemplateMediaCache.fetchThumbnailFile'));
      expect(source, isNot(contains('thumbnailCache.getSingleFile(')));
      expect(source, contains('Image.file('));
      expect(source, isNot(contains('Image.network(')));
      expect(source, contains('TemplateMediaCache.removeThumbnailFile'));
      expect(source, contains('cacheWidth: cacheWidth'));
      expect(source, contains('filterQuality: FilterQuality.medium'));
    },
  );

  test(
    'template card image decode width stays bounded for invalid constraints',
    () async {
      final source = await File(
        'lib/features/templates/presentation/widgets/template_card.dart',
      ).readAsString();

      expect(source, contains('final int cacheWidth;'));
      expect(source, contains('int _cacheDimension('));
      expect(
        source,
        contains('static const int _defaultTemplateCardImageCacheWidth = 720;'),
      );
      expect(source, contains('return _defaultTemplateCardImageCacheWidth;'));
      expect(
        source,
        contains(
          '.clamp(_minTemplateCardImageCacheWidth, _maxTemplateCardImageCacheWidth)',
        ),
      );
      expect(source, contains('cacheWidth: widget.cacheWidth'));
    },
  );

  test('templates feed keeps a lazy paged sliver grid surface', () async {
    final source = await File(
      'lib/features/templates/presentation/templates_page.dart',
    ).readAsString();

    expect(source, contains('SliverGrid.builder('));
    expect(source, contains('itemCount: state.items.length'));
    expect(source, contains('itemBuilder: (context, index)'));
    expect(source, isNot(contains('visibleItems')));
    expect(source, contains('_templatesController.loadMore()'));
    expect(source, isNot(contains('GridView.count(')));
    expect(source, isNot(contains('children: state.items.map')));
  });

  test(
    'template of the day hero thumbnail is cached at bounded size',
    () async {
      final source = await File(
        'lib/features/templates/presentation/templates_page.dart',
      ).readAsString();

      expect(source, contains('TemplateMediaCache.thumbnailCache'));
      expect(source, contains('_templateMediaCacheDimension('));
      expect(source, contains('memCacheWidth: cacheWidth'));
      expect(source, contains('maxWidthDiskCache: cacheWidth'));
      expect(source, contains('placeholder: (context, url) =>'));
      expect(source, contains('const _TemplateOfTheDayMediaFallback()'));
      expect(source, contains('errorWidget: (context, url, error)'));
      expect(source, contains('filterQuality: FilterQuality.medium'));
    },
  );

  test('template page pet shortcut avatar is cached at bounded size', () async {
    final source = await File(
      'lib/features/templates/presentation/templates_page.dart',
    ).readAsString();

    expect(source, contains('const int _petShortcutAvatarCacheWidth = 64;'));
    expect(source, contains('memCacheWidth: _petShortcutAvatarCacheWidth'));
    expect(source, contains('maxWidthDiskCache: _petShortcutAvatarCacheWidth'));
    expect(source, contains('filterQuality: FilterQuality.medium'));
  });

  test(
    'template of the day video preview is visibility gated and cached',
    () async {
      final source = await File(
        'lib/features/templates/presentation/templates_page.dart',
      ).readAsString();

      expect(
        source,
        contains(
          "import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';",
        ),
      );
      expect(
        source,
        contains(
          "import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';",
        ),
      );
      expect(
        source,
        contains("import 'package:video_player/video_player.dart';"),
      );
      expect(
        source,
        contains(
          "import 'package:visibility_detector/visibility_detector.dart';",
        ),
      );
      expect(source, contains('final videoPreviewUrl ='));
      expect(source, contains('isVideoUrl(previewMediaUrl)'));
      expect(source, contains('_TemplateOfTheDayVideoPreview('));
      expect(source, contains('thumbnailUrl: thumbnailUrl'));
      expect(source, contains('VisibilityDetector('));
      expect(source, contains('_loadVisibilityFraction'));
      expect(source, contains('_playVisibilityFraction'));
      expect(source, contains('WidgetsBinding.instance.addObserver(this);'));
      expect(source, contains('WidgetsBinding.instance.removeObserver(this);'));
      expect(source, contains('state == AppLifecycleState.paused'));
      expect(source, contains('state == AppLifecycleState.hidden'));
      expect(source, contains('_disposeVideoController()'));
      expect(source, contains('bool _hasPreviewSlot = false;'));
      expect(
        source,
        contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
      );
      expect(
        source,
        contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
      );
      expect(source, contains('createCachedTemplatePreviewVideoController('));
      expect(source, contains('fallbackUri: safeUri'));
      expect(source, contains('await controller.setVolume(0);'));
      expect(source, contains('await controller.setLooping(true);'));
      expect(source, contains('TemplateMediaCache.thumbnailCache'));
    },
  );

  test('template media caches use bounded object counts and app TTL', () async {
    final source = await File(
      'lib/core/performance/template_media_cache.dart',
    ).readAsString();
    final presentationSource =
        await Directory('lib/features/templates/presentation')
            .list(recursive: true)
            .where((entity) => entity is File && entity.path.endsWith('.dart'))
            .cast<File>()
            .asyncMap((file) => file.readAsString())
            .join('\n');

    expect(source, contains('stalePeriod: AppConfig.mediaCacheStalePeriod'));
    expect(source, contains('maxNrOfCacheObjects: 300'));
    expect(source, contains('maxNrOfCacheObjects: 80'));
    expect(
      source,
      contains(
        'typedef _RememberedFilesByUrl = LinkedHashMap<String, _RememberedCacheFile>;',
      ),
    );
    expect(
      source,
      contains(
        'typedef _InvalidationCountsByUrl = LinkedHashMap<String, int>;',
      ),
    );
    expect(
      source,
      contains('typedef _FetchGenerationsByUrl = LinkedHashMap<String, int>;'),
    );
    expect(
      source,
      contains('typedef _BlockedCacheUrls = LinkedHashSet<String>;'),
    );
    expect(source, contains('static final _RememberedFilesByUrl'));
    expect(source, contains('static final _InvalidationCountsByUrl'));
    expect(source, contains('static final _FetchGenerationsByUrl'));
    expect(source, contains('static final _BlockedCacheUrls'));
    expect(source, contains('final DateTime validTill;'));
    expect(
      source,
      contains('!rememberedFile.validTill.isAfter(DateTime.now())'),
    );
    expect(source, contains('!cachedFile.validTill.isAfter(DateTime.now())'));
    expect(source, contains('_maxThumbnailFileReferences = 300'));
    expect(
      source,
      contains('_maxBlockedThumbnailCacheUrls = _maxThumbnailFileReferences'),
    );
    expect(
      source,
      contains('_maxBlockedPreviewCacheUrls = _maxPreviewFileReferences'),
    );
    expect(source, contains('_thumbnailInvalidationByUrl.clear();'));
    expect(source, contains('_previewInvalidationByUrl.clear();'));
    expect(source, contains('_latestThumbnailFetchGenerationByUrl.clear();'));
    expect(source, contains('_latestPreviewFetchGenerationByUrl.clear();'));
    expect(source, contains('_rememberLatestFetchGeneration('));
    expect(source, contains('_canInvalidateCompletedFetch('));
    expect(source, contains('_trimInvalidationMap('));
    expect(source, contains('_trimBlockedCacheUrls('));
    expect(source, contains('_blockedThumbnailCacheUrls.remove(url);'));
    expect(source, contains('_blockedPreviewCacheUrls.remove(url);'));
    expect(source, contains('AppConfig.mediaCacheMaxBytesSafe'));
    expect(source, contains('_scheduleThumbnailBudgetCleanup(file.parent)'));
    expect(source, contains('thumbnail_budget_cleanup'));
    expect(
      presentationSource,
      isNot(contains('thumbnailCache.getSingleFile(')),
    );
  });

  test('app startup installs a bounded decoded image cache budget', () async {
    final mainSource = await File('lib/main.dart').readAsString();
    final appSource = await File('lib/app/app.dart').readAsString();
    final budgetSource = await File(
      'lib/core/performance/decoded_image_cache_budget.dart',
    ).readAsString();

    expect(mainSource, contains('configureDecodedImageCacheBudget();'));
    expect(budgetSource, contains('cache.maximumSize ='));
    expect(budgetSource, contains('cache.maximumSizeBytes ='));
    expect(budgetSource, contains('AppConfig.decodedImageCacheMaxObjectsSafe'));
    expect(budgetSource, contains('AppConfig.decodedImageCacheMaxBytesSafe'));
    expect(budgetSource, contains('trimDecodedImageCache();'));
    expect(appSource, contains('DecodedImageCacheLifecycleObserver('));
  });

  test('thumbnail byte-budget cleanup removes oldest files first', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'petmagic-thumbnail-cache-budget-test-',
    );
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final oldImage = await _writeCacheFile(
      tempRoot,
      'old-thumb.jpg',
      bytes: 60,
      modifiedAt: DateTime.utc(2026, 1, 1),
    );
    final middleImage = await _writeCacheFile(
      tempRoot,
      'middle-thumb.jpg',
      bytes: 50,
      modifiedAt: DateTime.utc(2026, 1, 2),
    );
    final freshImage = await _writeCacheFile(
      tempRoot,
      'fresh-thumb.jpg',
      bytes: 50,
      modifiedAt: DateTime.utc(2026, 1, 3),
    );
    await tempRoot.createTemp('nested-cache-dir-');

    final remainingBytes =
        await TemplateMediaCache.trimThumbnailCacheDirectoryForTesting(
          tempRoot,
          maxBytes: 100,
        );

    expect(remainingBytes, lessThanOrEqualTo(100));
    expect(await oldImage.exists(), isFalse);
    expect(await middleImage.exists(), isTrue);
    expect(await freshImage.exists(), isTrue);
  });

  test(
    'preview video byte-budget cleanup removes oldest files first',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'petmagic-preview-cache-budget-test-',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final oldVideo = await _writeCacheFile(
        tempRoot,
        'old-preview.mp4',
        bytes: 60,
        modifiedAt: DateTime.utc(2026, 1, 1),
      );
      final middleVideo = await _writeCacheFile(
        tempRoot,
        'middle-preview.mp4',
        bytes: 50,
        modifiedAt: DateTime.utc(2026, 1, 2),
      );
      final freshVideo = await _writeCacheFile(
        tempRoot,
        'fresh-preview.mp4',
        bytes: 50,
        modifiedAt: DateTime.utc(2026, 1, 3),
      );
      await tempRoot.createTemp('nested-cache-dir-');

      final remainingBytes =
          await TemplateMediaCache.trimPreviewCacheDirectoryForTesting(
            tempRoot,
            maxBytes: 100,
          );

      expect(remainingBytes, lessThanOrEqualTo(100));
      expect(await oldVideo.exists(), isFalse);
      expect(await middleVideo.exists(), isTrue);
      expect(await freshVideo.exists(), isTrue);
    },
  );

  test(
    'template media caches avoid redownloading identical thumbnail and video urls',
    () async {
      await TemplateMediaCache.clearAll();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestCountsByPath = <String, int>{};
      final subscription = server.listen((request) async {
        final path = request.uri.path;
        requestCountsByPath[path] = (requestCountsByPath[path] ?? 0) + 1;
        if (path == '/shared-template-preview.mp4') {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        final isVideo = path.endsWith('.mp4');
        final bytes = isVideo
            ? const [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]
            : const [0xFF, 0xD8, 0xFF, 0xD9];

        request.response.headers
          ..contentType = isVideo
              ? ContentType('video', 'mp4')
              : ContentType('image', 'jpeg')
          ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        await TemplateMediaCache.clearAll();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final thumbnailUrl = '$baseUrl/template-thumb.jpg';
      final videoUrl = '$baseUrl/template-preview.mp4';
      final sharedVideoUrl = '$baseUrl/shared-template-preview.mp4';

      final firstThumbnail = await TemplateMediaCache.fetchThumbnailFile(
        thumbnailUrl,
      );
      final secondThumbnail = await TemplateMediaCache.fetchThumbnailFile(
        thumbnailUrl,
      );
      final firstVideo = await TemplateMediaCache.fetchPreviewFile(videoUrl);
      final cachedVideo = await TemplateMediaCache.getCachedPreviewFile(
        videoUrl,
      );
      final secondVideo = await TemplateMediaCache.fetchPreviewFile(videoUrl);

      expect(firstThumbnail.path, secondThumbnail.path);
      expect(firstVideo.path, secondVideo.path);
      expect(cachedVideo?.path, firstVideo.path);
      expect(requestCountsByPath['/template-thumb.jpg'], 1);
      expect(requestCountsByPath['/template-preview.mp4'], 1);
      final firstFetch = TemplateMediaCache.fetchPreviewFile(sharedVideoUrl);
      await Future<void>.delayed(Duration.zero);
      final secondFetch = TemplateMediaCache.fetchPreviewFile(sharedVideoUrl);
      final files = await Future.wait([firstFetch, secondFetch]);

      expect(files[0].path, files[1].path);
      expect(requestCountsByPath['/shared-template-preview.mp4'], 1);
    },
  );

  test(
    'template media cache rejects in-flight downloads after explicit removal',
    () async {
      await TemplateMediaCache.clearAll();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestCountsByPath = <String, int>{};
      final firstRequestStartedByPath = <String, Completer<void>>{
        '/stale-template-thumb.jpg': Completer<void>(),
        '/stale-template-preview.mp4': Completer<void>(),
      };
      final releaseFirstRequestByPath = <String, Completer<void>>{
        '/stale-template-thumb.jpg': Completer<void>(),
        '/stale-template-preview.mp4': Completer<void>(),
      };
      final subscription = server.listen((request) async {
        final path = request.uri.path;
        final requestCount = (requestCountsByPath[path] ?? 0) + 1;
        requestCountsByPath[path] = requestCount;
        if (requestCount == 1 && releaseFirstRequestByPath.containsKey(path)) {
          firstRequestStartedByPath[path]!.complete();
          await releaseFirstRequestByPath[path]!.future;
        }

        final isVideo = path.endsWith('.mp4');
        final bytes = isVideo
            ? const [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]
            : const [0xFF, 0xD8, 0xFF, 0xD9];

        request.response.headers
          ..contentType = isVideo
              ? ContentType('video', 'mp4')
              : ContentType('image', 'jpeg')
          ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        await TemplateMediaCache.clearAll();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final thumbnailUrl = '$baseUrl/stale-template-thumb.jpg';
      final videoUrl = '$baseUrl/stale-template-preview.mp4';

      final staleThumbnailFetch = TemplateMediaCache.fetchThumbnailFile(
        thumbnailUrl,
      );
      await firstRequestStartedByPath['/stale-template-thumb.jpg']!.future;
      await TemplateMediaCache.removeThumbnailFile(thumbnailUrl);
      releaseFirstRequestByPath['/stale-template-thumb.jpg']!.complete();
      await expectLater(staleThumbnailFetch, throwsA(isA<StateError>()));
      expect(
        await TemplateMediaCache.getCachedThumbnailFile(thumbnailUrl),
        isNull,
      );

      final freshThumbnail = await TemplateMediaCache.fetchThumbnailFile(
        thumbnailUrl,
      );
      expect(await freshThumbnail.exists(), isTrue);
      expect(
        await TemplateMediaCache.getCachedThumbnailFile(thumbnailUrl),
        isNotNull,
      );
      expect(requestCountsByPath['/stale-template-thumb.jpg'], 2);

      final staleVideoFetch = TemplateMediaCache.fetchPreviewFile(videoUrl);
      await firstRequestStartedByPath['/stale-template-preview.mp4']!.future;
      await TemplateMediaCache.removePreviewFile(videoUrl);
      releaseFirstRequestByPath['/stale-template-preview.mp4']!.complete();
      await expectLater(staleVideoFetch, throwsA(isA<StateError>()));
      expect(await TemplateMediaCache.getCachedPreviewFile(videoUrl), isNull);

      final freshVideo = await TemplateMediaCache.fetchPreviewFile(videoUrl);
      expect(await freshVideo.exists(), isTrue);
      expect(
        await TemplateMediaCache.getCachedPreviewFile(videoUrl),
        isNotNull,
      );
      expect(requestCountsByPath['/stale-template-preview.mp4'], 2);
    },
  );

  test(
    'explicit media removal does not cancel unrelated in-flight downloads',
    () async {
      await TemplateMediaCache.clearAll();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final delayedPaths = <String>{
        '/active-template-thumb.jpg',
        '/stale-template-thumb.jpg',
        '/active-template-preview.mp4',
        '/stale-template-preview.mp4',
      };
      final requestCountsByPath = <String, int>{};
      final firstRequestStartedByPath = <String, Completer<void>>{
        for (final path in delayedPaths) path: Completer<void>(),
      };
      final releaseFirstRequestByPath = <String, Completer<void>>{
        for (final path in delayedPaths) path: Completer<void>(),
      };
      final subscription = server.listen((request) async {
        final path = request.uri.path;
        final requestCount = (requestCountsByPath[path] ?? 0) + 1;
        requestCountsByPath[path] = requestCount;
        if (requestCount == 1 && delayedPaths.contains(path)) {
          firstRequestStartedByPath[path]!.complete();
          await releaseFirstRequestByPath[path]!.future;
        }

        final isVideo = path.endsWith('.mp4');
        final bytes = isVideo
            ? const [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]
            : const [0xFF, 0xD8, 0xFF, 0xD9];

        request.response.headers
          ..contentType = isVideo
              ? ContentType('video', 'mp4')
              : ContentType('image', 'jpeg')
          ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        await TemplateMediaCache.clearAll();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final activeThumbnailUrl = '$baseUrl/active-template-thumb.jpg';
      final staleThumbnailUrl = '$baseUrl/stale-template-thumb.jpg';
      final activeVideoUrl = '$baseUrl/active-template-preview.mp4';
      final staleVideoUrl = '$baseUrl/stale-template-preview.mp4';

      final activeThumbnailFetch = TemplateMediaCache.fetchThumbnailFile(
        activeThumbnailUrl,
      );
      await firstRequestStartedByPath['/active-template-thumb.jpg']!.future;
      final staleThumbnailFetch = TemplateMediaCache.fetchThumbnailFile(
        staleThumbnailUrl,
      );
      await firstRequestStartedByPath['/stale-template-thumb.jpg']!.future;

      await TemplateMediaCache.removeThumbnailFile(staleThumbnailUrl);
      final staleThumbnailExpectation = expectLater(
        staleThumbnailFetch,
        throwsA(isA<StateError>()),
      );
      releaseFirstRequestByPath['/active-template-thumb.jpg']!.complete();
      releaseFirstRequestByPath['/stale-template-thumb.jpg']!.complete();

      final activeThumbnail = await activeThumbnailFetch;
      await staleThumbnailExpectation;
      expect(await activeThumbnail.exists(), isTrue);
      expect(requestCountsByPath['/active-template-thumb.jpg'], 1);
      expect(requestCountsByPath['/stale-template-thumb.jpg'], 1);

      final activeVideoFetch = TemplateMediaCache.fetchPreviewFile(
        activeVideoUrl,
      );
      await firstRequestStartedByPath['/active-template-preview.mp4']!.future;
      final staleVideoFetch = TemplateMediaCache.fetchPreviewFile(
        staleVideoUrl,
      );
      await firstRequestStartedByPath['/stale-template-preview.mp4']!.future;

      await TemplateMediaCache.removePreviewFile(staleVideoUrl);
      final staleVideoExpectation = expectLater(
        staleVideoFetch,
        throwsA(isA<StateError>()),
      );
      releaseFirstRequestByPath['/active-template-preview.mp4']!.complete();
      releaseFirstRequestByPath['/stale-template-preview.mp4']!.complete();

      final activeVideo = await activeVideoFetch;
      await staleVideoExpectation;
      expect(await activeVideo.exists(), isTrue);
      expect(requestCountsByPath['/active-template-preview.mp4'], 1);
      expect(requestCountsByPath['/stale-template-preview.mp4'], 1);
    },
  );

  test(
    'template media caches refresh expired remembered thumbnail and video files',
    () async {
      await TemplateMediaCache.clearAll();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestCountsByPath = <String, int>{};
      final subscription = server.listen((request) async {
        final path = request.uri.path;
        requestCountsByPath[path] = (requestCountsByPath[path] ?? 0) + 1;
        final isVideo = path.endsWith('.mp4');
        final bytes = isVideo
            ? const [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]
            : const [0xFF, 0xD8, 0xFF, 0xD9];

        request.response.headers
          ..contentType = isVideo
              ? ContentType('video', 'mp4')
              : ContentType('image', 'jpeg')
          ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        await TemplateMediaCache.clearAll();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final thumbnailUrl = '$baseUrl/expired-template-thumb.jpg';
      final videoUrl = '$baseUrl/expired-template-preview.mp4';
      await TemplateMediaCache.thumbnailCache.putFile(
        thumbnailUrl,
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
        maxAge: const Duration(milliseconds: 250),
        fileExtension: 'jpg',
      );
      await TemplateMediaCache.previewVideoCache.putFile(
        videoUrl,
        Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]),
        maxAge: const Duration(milliseconds: 250),
        fileExtension: 'mp4',
      );

      expect(
        await TemplateMediaCache.getCachedThumbnailFile(thumbnailUrl),
        isNotNull,
      );
      expect(
        await TemplateMediaCache.getCachedPreviewFile(videoUrl),
        isNotNull,
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));

      final refreshedThumbnail = await TemplateMediaCache.fetchThumbnailFile(
        thumbnailUrl,
      );
      final refreshedVideo = await TemplateMediaCache.fetchPreviewFile(
        videoUrl,
      );

      expect(await refreshedThumbnail.exists(), isTrue);
      expect(await refreshedVideo.exists(), isTrue);
      expect(requestCountsByPath['/expired-template-thumb.jpg'], 1);
      expect(requestCountsByPath['/expired-template-preview.mp4'], 1);
    },
  );

  test(
    'template preview controller uses cached video files instead of network',
    () async {
      await TemplateMediaCache.clearAll();
      addTearDown(() async {
        await TemplateMediaCache.clearAll();
      });

      const previewUrl =
          'https://cdn.example.com/templates/shared-template-preview.mp4';
      await TemplateMediaCache.previewVideoCache.putFile(
        previewUrl,
        Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]),
        maxAge: const Duration(hours: 1),
        fileExtension: 'mp4',
      );

      final firstController = await createTemplatePreviewVideoController(
        previewUrl,
      );
      expect(firstController.dataSourceType, DataSourceType.file);
      expect(firstController.dataSource, startsWith('file://'));
      await firstController.dispose();

      final secondController = await createTemplatePreviewVideoController(
        previewUrl,
      );
      expect(secondController.dataSourceType, DataSourceType.file);
      expect(secondController.dataSource, startsWith('file://'));
      await secondController.dispose();
    },
  );

  test(
    'template preview controller downloads a video preview once per url',
    () async {
      await TemplateMediaCache.clearAll();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      final subscription = server.listen((request) async {
        if (request.uri.path == '/controller-preview.mp4') {
          requestCount += 1;
          request.response.headers
            ..contentType = ContentType('video', 'mp4')
            ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
          const bytes = [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50];
          request.response.contentLength = bytes.length;
          request.response.add(bytes);
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        await TemplateMediaCache.clearAll();
      });

      final previewUrl =
          'http://${server.address.host}:${server.port}/controller-preview.mp4';

      final firstController = await createTemplatePreviewVideoController(
        previewUrl,
      );
      expect(firstController.dataSourceType, DataSourceType.file);
      await firstController.dispose();

      final secondController = await createTemplatePreviewVideoController(
        previewUrl,
      );
      expect(secondController.dataSourceType, DataSourceType.file);
      await secondController.dispose();

      expect(requestCount, 1);
    },
  );

  test(
    'template preview controller does not fall back to network after invalidation',
    () async {
      await TemplateMediaCache.clearAll();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      final firstRequestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      final subscription = server.listen((request) async {
        if (request.uri.path == '/invalidated-controller-preview.mp4') {
          requestCount += 1;
          if (requestCount == 1) {
            firstRequestStarted.complete();
            await releaseFirstRequest.future;
          }

          request.response.headers
            ..contentType = ContentType('video', 'mp4')
            ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
          const bytes = [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50];
          request.response.contentLength = bytes.length;
          request.response.add(bytes);
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        await TemplateMediaCache.clearAll();
      });

      final previewUrl =
          'http://${server.address.host}:${server.port}/invalidated-controller-preview.mp4';
      final staleController = createTemplatePreviewVideoController(previewUrl);

      await firstRequestStarted.future;
      await TemplateMediaCache.removePreviewFile(previewUrl);
      releaseFirstRequest.complete();

      await expectLater(staleController, throwsA(isA<StateError>()));
      expect(requestCount, 1);

      final freshController = await createTemplatePreviewVideoController(
        previewUrl,
      );
      expect(freshController.dataSourceType, DataSourceType.file);
      await freshController.dispose();
      expect(requestCount, 2);
    },
  );

  test(
    'template flow sheet media URLs are checked before rendering or sharing',
    () async {
      final sheetSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
      ).readAsString();
      final contentSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
      ).readAsString();

      expect(
        sheetSource,
        contains(
          "import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';",
        ),
      );
      expect(contentSource, contains('parseSafeGenerationMediaUri('));
      expect(contentSource, contains('generation.outputUrl'));
      expect(contentSource, contains('asset?.url'));
      expect(
        contentSource,
        contains('final resultCacheWidth = _templatePreviewCacheDimension('),
      );
      expect(contentSource, contains('memCacheWidth: resultCacheWidth'));
      expect(contentSource, contains('maxWidthDiskCache: resultCacheWidth'));
      expect(contentSource, contains('TemplateMediaCache.thumbnailCache'));
      expect(contentSource, contains('memCacheWidth: cacheWidth'));
      expect(contentSource, contains('maxWidthDiskCache: cacheWidth'));
      expect(contentSource, isNot(contains('imageUrl: asset.url')));
      expect(
        contentSource,
        isNot(contains('_NetworkVideoPreview(url: asset.url)')),
      );
      expect(
        contentSource,
        isNot(contains('VideoPlayerController.networkUrl(Uri.parse(url))')),
      );
    },
  );

  test('template flow video preview is visibility-gated and cached', () async {
    final sheetSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
    ).readAsString();
    final cardSource = await File(
      'lib/features/templates/presentation/widgets/template_card.dart',
    ).readAsString();
    final contentSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
    ).readAsString();

    expect(cardSource, contains('VisibilityDetector('));
    expect(cardSource, contains('_prewarmVisibilityFraction'));
    expect(cardSource, contains('_playVisibilityFraction'));
    expect(
      cardSource,
      contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
    );
    expect(
      cardSource,
      contains('createTemplatePreviewVideoController(previewUrl)'),
    );
    expect(
      cardSource,
      contains('createCachedTemplatePreviewVideoController(previewUrl)'),
    );
    expect(cardSource, isNot(contains('VideoPlayerController.networkUrl(')));

    expect(
      sheetSource,
      contains(
        "import 'package:visibility_detector/visibility_detector.dart';",
      ),
    );
    expect(
      sheetSource,
      contains(
        "import 'package:petmagic_mobile/core/performance/template_media_cache.dart';",
      ),
    );
    expect(
      sheetSource,
      contains(
        "import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';",
      ),
    );
    expect(
      sheetSource,
      contains(
        "import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';",
      ),
    );
    expect(contentSource, contains('useSharedPreviewCache: true'));
    expect(contentSource, contains('VisibilityDetector('));
    expect(contentSource, contains('_loadVisibilityFraction'));
    expect(contentSource, contains('_playVisibilityFraction'));
    expect(contentSource, contains('_disposeVideoController()'));
    expect(contentSource, contains('bool _hasPreviewSlot = false;'));
    expect(
      contentSource,
      contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
    );
    expect(
      contentSource,
      contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
    );
    expect(contentSource, contains('void _releasePreviewSlot()'));
    expect(
      contentSource,
      contains('createCachedTemplatePreviewVideoController('),
    );
    expect(contentSource, contains('fallbackUri: safeUri'));
    expect(
      RegExp(
        r'_NetworkVideoPreview\(\s*url: safeAssetUrl,\s*useSharedPreviewCache: true,',
        multiLine: true,
      ).hasMatch(contentSource),
      isTrue,
    );
    expect(
      contentSource,
      contains(
        'if (!widget.useSharedPreviewCache) {\n'
        '      return VideoPlayerController.networkUrl(safeUri);\n'
        '    }\n'
        '\n'
        '    return createCachedTemplatePreviewVideoController(',
      ),
    );
  });

  test('active generation shell thumbnail is cached at thumbnail size', () async {
    final source = await File(
      'lib/shared/navigation/petmagic_shell.dart',
    ).readAsString();

    expect(
      source,
      contains('const _activeGenerationThumbnailCacheWidth = 96;'),
    );
    expect(
      source,
      contains(
        'memCacheWidth:\n                                      _activeGenerationThumbnailCacheWidth',
      ),
    );
    expect(
      source,
      contains(
        'maxWidthDiskCache:\n                                      _activeGenerationThumbnailCacheWidth',
      ),
    );
    expect(source, contains('parseSafeGenerationMediaUri('));
    expect(source, contains('filterQuality: FilterQuality.medium'));
    expect(
      source,
      isNot(contains('final previewUrl = generation.sourceImageAsset?.url')),
    );
  });

  test('generation gallery media URLs are checked before preview or copy', () async {
    final gallerySource = await File(
      'lib/features/templates/presentation/generations_gallery_page.dart',
    ).readAsString();
    final cardsSource = await File(
      'lib/features/templates/presentation/generations_gallery_page_cards.dart',
    ).readAsString();
    final actionsSource = await File(
      'lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart',
    ).readAsString();

    expect(
      gallerySource,
      contains(
        "import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';",
      ),
    );
    expect(cardsSource, contains('parseSafeGenerationMediaUri('));
    expect(cardsSource, contains('imageUrl: safePreviewImageUrl!'));
    expect(
      cardsSource,
      contains('const int _generationGalleryThumbnailCacheWidth = 320;'),
    );
    expect(
      cardsSource,
      contains(
        'cacheWidth:\n                                        _generationGalleryThumbnailCacheWidth',
      ),
    );
    expect(
      cardsSource,
      contains(
        'memCacheWidth:\n                                        _generationGalleryThumbnailCacheWidth',
      ),
    );
    expect(
      cardsSource,
      contains(
        'maxWidthDiskCache:\n                                        _generationGalleryThumbnailCacheWidth',
      ),
    );
    expect(cardsSource, contains('filterQuality: FilterQuality.medium'));
    expect(actionsSource, contains('parseSafeGenerationMediaUri(outputUrl)'));
    expect(actionsSource, contains('ClipboardData(text: safeUri.toString())'));
    expect(cardsSource, isNot(contains('imageUrl: previewImageUrl!')));
  });

  test(
    'selected local pet photo preview decodes to bounded thumbnail size',
    () async {
      final source = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
      ).readAsString();

      expect(
        source,
        contains('const int _selectedPetPhotoPreviewCacheWidth = 288;'),
      );
      expect(
        source,
        contains('const int _selectedPetPhotoPreviewCacheHeight = 354;'),
      );
      expect(
        source,
        contains('cacheWidth: _selectedPetPhotoPreviewCacheWidth'),
      );
      expect(
        source,
        contains('cacheHeight: _selectedPetPhotoPreviewCacheHeight'),
      );
      expect(source, contains('filterQuality: FilterQuality.medium'));
    },
  );

  test('generation status result media decodes with bounded cache sizes', () async {
    final source = await File(
      'lib/features/templates/presentation/generation_status_page_sections.dart',
    ).readAsString();

    expect(source, contains('const int _resultCardImageCacheWidth = 1080;'));
    expect(
      source,
      contains('const int _resultFullscreenImageCacheWidth = 1440;'),
    );
    expect(
      source,
      contains('const int _beforeAfterCompareImageCacheWidth = 1024;'),
    );
    expect(
      source,
      contains('ResizeImage(\n        FileImage(localOutputFile)'),
    );
    expect(source, contains('cacheWidth: _resultCardImageCacheWidth'));
    expect(source, contains('memCacheWidth: _resultCardImageCacheWidth'));
    expect(
      source,
      contains(
        'maxWidthDiskCache:\n                                        _resultCardImageCacheWidth',
      ),
    );
    expect(source, contains('cacheWidth: _resultFullscreenImageCacheWidth'));
    expect(source, contains('memCacheWidth: _resultFullscreenImageCacheWidth'));
    expect(
      source,
      contains('maxWidthDiskCache: _resultFullscreenImageCacheWidth'),
    );
    expect(source, contains('maxWidth: _beforeAfterCompareImageCacheWidth'));
    expect(source, contains('filterQuality: FilterQuality.medium'));
    expect(source, isNot(contains('memCacheWidth: 1080')));
    expect(source, isNot(contains('memCacheWidth: 1440')));
  });

  test(
    'generation result input media decodes with bounded cache sizes',
    () async {
      final source = await File(
        'lib/features/templates/presentation/generation_result_input_page.dart',
      ).readAsString();

      expect(source, contains('const int _parentPreviewCacheWidth = 900;'));
      expect(
        source,
        contains('const int _compatibleTemplateThumbnailCacheWidth = 240;'),
      );
      expect(source, contains('memCacheWidth: _parentPreviewCacheWidth'));
      expect(source, contains('maxWidthDiskCache: _parentPreviewCacheWidth'));
      expect(
        source,
        contains('memCacheWidth: _compatibleTemplateThumbnailCacheWidth'),
      );
      expect(
        source,
        contains(
          'maxWidthDiskCache:\n                              _compatibleTemplateThumbnailCacheWidth',
        ),
      );
      expect(source, contains('filterQuality: FilterQuality.medium'));
      expect(source, isNot(contains('memCacheWidth: 900')));
      expect(source, isNot(contains('memCacheWidth: 240')));
    },
  );

  test('template blocked balance sheet keeps a lazy scroll surface', () async {
    final source = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
    ).readAsString();

    expect(source, contains('child: ListView('));
    expect(source, contains('shrinkWrap: true'));
    expect(source, isNot(contains('SingleChildScrollView(')));
  });
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

Future<File> _writeCacheFile(
  Directory root,
  String fileName, {
  required int bytes,
  required DateTime modifiedAt,
}) async {
  final file = File('${root.path}/$fileName');
  await file.writeAsBytes(List<int>.filled(bytes, 1), flush: true);
  await file.setLastModified(modifiedAt);
  return file;
}
