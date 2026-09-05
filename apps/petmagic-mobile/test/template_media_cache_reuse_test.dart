import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:video_player/video_player.dart';

import 'template_media_performance_test_support.dart';

void main() {
  configureTemplateMediaPerformanceHarness(ensureWidgets: false);
  setUp(TemplateMediaCache.clearAll);
  tearDown(TemplateMediaCache.clearAll);

  test('explicit removal and clear delete the physical cached files', () async {
    const thumbnailUrl = 'https://cdn.example.com/remove-thumbnail.jpg';
    const previewUrl = 'https://cdn.example.com/remove-preview.mp4';
    final thumbnail = await TemplateMediaCache.thumbnailCache.putFile(
      thumbnailUrl,
      Uint8List(20),
      fileExtension: 'jpg',
    );
    final preview = await TemplateMediaCache.previewVideoCache.putFile(
      previewUrl,
      Uint8List(20),
      fileExtension: 'mp4',
    );
    await TemplateMediaCache.getCachedThumbnailFile(thumbnailUrl);
    await TemplateMediaCache.getCachedPreviewFile(previewUrl);
    await TemplateMediaCache.removeThumbnailFile(thumbnailUrl);
    expect(await thumbnail.exists(), isFalse);
    expect(await preview.exists(), isTrue);
    await TemplateMediaCache.clearAll();
    expect(await preview.exists(), isFalse);
  });

  test(
    'prefetch and page controllers share one download and survive memory release',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      final requestStarted = Completer<void>();
      final releaseResponse = Completer<void>();
      final subscription = server.listen((request) async {
        requestCount++;
        requestStarted.complete();
        await releaseResponse.future;
        request.response.headers
          ..contentType = ContentType('video', 'mp4')
          ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
        request.response.add(const [0, 0, 0, 24, 102, 116, 121, 112]);
        await request.response.close();
      });
      addTearDown(() async {
        if (!releaseResponse.isCompleted) releaseResponse.complete();
        await subscription.cancel();
        await server.close(force: true);
      });
      final url = 'http://${server.address.host}:${server.port}/shared.mp4';
      final prefetch = TemplateMediaCache.fetchPreviewFile(
        url,
        mediaVersion: 2,
      );
      final firstPage = createCachedTemplatePreviewVideoController(
        url,
        mediaVersion: 2,
      );
      final secondPage = createCachedTemplatePreviewVideoController(
        url,
        mediaVersion: 2,
      );
      await requestStarted.future;
      releaseResponse.complete();
      final file = await prefetch;
      final controllers = await Future.wait([firstPage, secondPage]);
      for (final controller in controllers) {
        expect(controller.dataSourceType, DataSourceType.file);
        expect(
          Uri.parse(controller.dataSource).toFilePath().replaceAll('\\', '/'),
          file.path.replaceAll('\\', '/'),
        );
        await controller.dispose();
      }
      final key = TemplateMediaCache.cacheKeyForMedia(url, mediaVersion: 2);
      expect(
        TemplateMediaCache.previewVideoCache.store.memoryCacheContainsKey(key),
        isTrue,
      );
      TemplateMediaCache.releaseMemoryReferences();
      expect(
        TemplateMediaCache.previewVideoCache.store.memoryCacheContainsKey(key),
        isFalse,
      );
      final reopened = await createCachedTemplatePreviewVideoController(
        url,
        mediaVersion: 2,
      );
      expect(reopened.dataSourceType, DataSourceType.file);
      expect(
        Uri.parse(reopened.dataSource).toFilePath().replaceAll('\\', '/'),
        file.path.replaceAll('\\', '/'),
      );
      await reopened.dispose();
      expect(requestCount, 1);
    },
  );

  for (final preview in [false, true]) {
    test(
      '${preview ? 'preview' : 'thumbnail'} budget retains a recently revisited older file',
      () async {
        final cache = preview
            ? TemplateMediaCache.previewVideoCache
            : TemplateMediaCache.thumbnailCache;
        final extension = preview ? 'mp4' : 'jpg';
        final files = <File>[];
        for (var index = 0; index < 3; index++) {
          final file = await cache.putFile(
            'https://cdn.example.com/recency-$index.$extension',
            Uint8List(60),
            maxAge: const Duration(hours: 1),
            fileExtension: extension,
          );
          await file.setLastModified(DateTime.utc(2026, 1, index + 1));
          files.add(file);
        }
        final url = 'https://cdn.example.com/recency-0.$extension';
        final revisited = preview
            ? await TemplateMediaCache.getCachedPreviewFile(url)
            : await TemplateMediaCache.getCachedThumbnailFile(url);
        expect(revisited?.path, files.first.path);
        // Eviction still uses the persisted access time after releasing RAM.
        TemplateMediaCache.releaseMemoryReferences();
        final retainedBytes = preview
            ? await TemplateMediaCache.trimPreviewCacheDirectoryForTesting(
                files.first.parent,
                maxBytes: 120,
              )
            : await TemplateMediaCache.trimThumbnailCacheDirectoryForTesting(
                files.first.parent,
                maxBytes: 120,
              );
        expect(retainedBytes, 120);
        expect(await files[0].exists(), isTrue);
        expect(await files[1].exists(), isFalse);
        expect(await files[2].exists(), isTrue);
      },
    );
  }

  test(
    'preview controller cannot bypass the download size limit with streaming',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      final subscription = server.listen((request) async {
        requestCount++;
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.contentLength =
            TemplateMediaCache.maxPreviewDownloadBytesForTesting + 1;
        request.response.add(const [0]);
        try {
          await request.response.close();
        } on Object {
          // Header rejection cancels the response before the full body arrives.
        }
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final url = 'http://${server.address.host}:${server.port}/oversized.mp4';
      await expectLater(
        createCachedTemplatePreviewVideoController(url),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'template_preview_download_too_large',
          ),
        ),
      );
      expect(requestCount, 1);
      expect(await TemplateMediaCache.getCachedPreviewFile(url), isNull);
    },
  );

  test('preview downloads respect the concurrency budget', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var activeRequests = 0;
    var peakRequests = 0;
    final subscription = server.listen((request) async {
      activeRequests++;
      if (activeRequests > peakRequests) peakRequests = activeRequests;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      request.response.headers
        ..contentType = ContentType('video', 'mp4')
        ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
      request.response.add(const [0, 0, 0, 24, 102, 116, 121, 112]);
      await request.response.close();
      activeRequests--;
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final files = await Future.wait(
      List.generate(
        9,
        (index) => TemplateMediaCache.fetchPreviewFile(
          'http://${server.address.host}:${server.port}/concurrent-$index.mp4',
        ),
      ),
    );
    expect(files, hasLength(9));
    expect(peakRequests, inInclusiveRange(2, 3));
  });
}
