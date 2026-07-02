import 'dart:async' show Completer;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    show DataSourceType;

import 'template_media_performance_test_support.dart';

void main() {
  configureTemplateMediaPerformanceHarness(ensureWidgets: false);

  test('thumbnail byte-budget cleanup removes oldest files first', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'petmagic-thumbnail-cache-budget-test-',
    );
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final oldImage = await writeCacheFile(
      tempRoot,
      'old-thumb.jpg',
      bytes: 60,
      modifiedAt: DateTime.utc(2026, 1, 1),
    );
    final middleImage = await writeCacheFile(
      tempRoot,
      'middle-thumb.jpg',
      bytes: 50,
      modifiedAt: DateTime.utc(2026, 1, 2),
    );
    final freshImage = await writeCacheFile(
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

      final oldVideo = await writeCacheFile(
        tempRoot,
        'old-preview.mp4',
        bytes: 60,
        modifiedAt: DateTime.utc(2026, 1, 1),
      );
      final middleVideo = await writeCacheFile(
        tempRoot,
        'middle-preview.mp4',
        bytes: 50,
        modifiedAt: DateTime.utc(2026, 1, 2),
      );
      final freshVideo = await writeCacheFile(
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
    'template media cache keys include mediaVersion without changing request url',
    () async {
      await TemplateMediaCache.clearAll();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      final requestedQueries = <String>[];
      final subscription = server.listen((request) async {
        if (request.uri.path == '/versioned-preview.mp4') {
          requestCount += 1;
          requestedQueries.add(request.uri.query);
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
          'http://${server.address.host}:${server.port}/versioned-preview.mp4';
      final v1 = await TemplateMediaCache.fetchPreviewFile(
        previewUrl,
        mediaVersion: 1,
      );
      final v1Again = await TemplateMediaCache.fetchPreviewFile(
        previewUrl,
        mediaVersion: 1,
      );
      final v2 = await TemplateMediaCache.fetchPreviewFile(
        previewUrl,
        mediaVersion: 2,
      );

      expect(v1.path, v1Again.path);
      expect(v2.path, isNot(v1.path));
      expect(requestCount, 2);
      expect(requestedQueries, ['', '']);
      expect(
        TemplateMediaCache.cacheKeyForMedia(previewUrl, mediaVersion: 1),
        isNot(TemplateMediaCache.cacheKeyForMedia(previewUrl, mediaVersion: 2)),
      );
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
        maxAge: const Duration(seconds: 1),
        fileExtension: 'jpg',
      );
      await TemplateMediaCache.previewVideoCache.putFile(
        videoUrl,
        Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]),
        maxAge: const Duration(seconds: 1),
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

      await Future<void>.delayed(const Duration(milliseconds: 1100));

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
      final generationSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
      ).readAsString();
      final previewSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_media_preview.part.dart',
      ).readAsString().then((source) => source.replaceAll('\r\n', '\n'));
      final flowSource = '$contentSource\n$generationSource\n$previewSource';

      expect(
        sheetSource,
        contains(
          "import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';",
        ),
      );
      expect(
        sheetSource,
        contains("part 'template_flow_sheets_generation.part.dart';"),
      );
      expect(flowSource, contains('parseSafeGenerationMediaUri('));
      expect(flowSource, contains('generation.outputUrl'));
      expect(flowSource, contains('asset?.url'));
      expect(
        flowSource,
        contains('final resultCacheWidth = _templatePreviewCacheDimension('),
      );
      expect(flowSource, contains('memCacheWidth: resultCacheWidth'));
      expect(flowSource, contains('maxWidthDiskCache: resultCacheWidth'));
      expect(flowSource, isNot(contains('imageUrl: asset.url')));
      expect(
        flowSource,
        isNot(contains('_NetworkVideoPreview(url: asset.url)')),
      );
      expect(
        flowSource,
        isNot(contains('VideoPlayerController.networkUrl(Uri.parse(url))')),
      );
    },
  );
}
