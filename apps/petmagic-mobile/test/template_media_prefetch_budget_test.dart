import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/performance/media_prefetch_budget.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';

import 'template_media_performance_test_support.dart';

void main() {
  configureTemplateMediaPerformanceHarness(ensureWidgets: false);
  setUp(TemplateMediaCache.clearAll);
  tearDown(TemplateMediaCache.clearAll);

  test(
    'real Content-Length rejects optional file; required playback retries',
    () async {
      var requests = 0;
      final origin = await _server((request) async {
        requests++;
        request.response.contentLength = 96;
        request.response.add(Uint8List(96));
        await request.response.close();
      });
      final budget = MediaPrefetchBudget(maxBytes: 256, maxFileBytes: 64);
      await expectLater(
        TemplateMediaCache.fetchPreviewFile(origin.url, prefetchBudget: budget),
        throwsA(isA<MediaPrefetchLimitException>()),
      );
      expect(await TemplateMediaCache.getCachedPreviewFile(origin.url), isNull);
      expect(budget.receivedBytes, 0);
      final file = await TemplateMediaCache.fetchPreviewFile(origin.url);
      expect(await file.length(), 96);
      expect(requests, 2);
      expect(await TemplateMediaCache.fetchPreviewFile(origin.url), file);
      expect(requests, 2);
    },
  );

  test(
    'chunked responses share actual wave allowance and stop subsequent HTTP',
    () async {
      var requests = 0;
      final origin = await _server((request) async {
        requests++;
        request.response.add(Uint8List(64));
        await request.response.close();
      });
      final budget = MediaPrefetchBudget(maxBytes: 96, maxFileBytes: 80);
      final first = await TemplateMediaCache.fetchPreviewFile(
        '${origin.url}/1',
        prefetchBudget: budget,
      );
      expect(await first.length(), 64);
      await expectLater(
        TemplateMediaCache.fetchPreviewFile(
          '${origin.url}/2',
          prefetchBudget: budget,
        ),
        throwsA(isA<MediaPrefetchLimitException>()),
      );
      expect(budget.canDownload, isFalse);
      expect(
        await TemplateMediaCache.getCachedPreviewFile('${origin.url}/2'),
        isNull,
      );
      await expectLater(
        TemplateMediaCache.fetchPreviewFile(
          '${origin.url}/3',
          prefetchBudget: budget,
        ),
        throwsA(isA<MediaPrefetchLimitException>()),
      );
      expect(requests, 2);
    },
  );

  test(
    'playback promotes an in-flight prefetch without a second GET',
    () async {
      var requests = 0;
      final started = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final origin = await _server((request) async {
        requests++;
        started.complete();
        await release.future;
        request.response.contentLength = 128;
        request.response.add(Uint8List(128));
        await request.response.close();
      });
      final budget = MediaPrefetchBudget(maxBytes: 32, maxFileBytes: 32);
      final prefetch = TemplateMediaCache.fetchPreviewFile(
        origin.url,
        mediaVersion: 5,
        prefetchBudget: budget,
      );
      await started.future;
      final playback = TemplateMediaCache.fetchPreviewFile(
        origin.url,
        mediaVersion: 5,
      );
      budget.cancel();
      release.complete();
      final files = await Future.wait([prefetch, playback]);
      expect(files[0].path, files[1].path);
      expect(await files[1].length(), 128);
      expect(requests, 1);
      expect(budget.receivedBytes, 0);
    },
  );

  test('cancelled optional transfer releases queue for a newer wave', () async {
    var requests = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final origin = await _server((request) async {
      requests++;
      if (requests == 1) {
        started.complete();
        await release.future;
      }
      request.response.add(Uint8List(16));
      await request.response.close();
    });
    final oldBudget = MediaPrefetchBudget(maxBytes: 64, maxFileBytes: 64);
    final old = TemplateMediaCache.fetchPreviewFile(
      origin.url,
      prefetchBudget: oldBudget,
    );
    final rejected = expectLater(
      old,
      throwsA(isA<MediaPrefetchLimitException>()),
    );
    await started.future;
    oldBudget.cancel();
    final newBudget = MediaPrefetchBudget(maxBytes: 64, maxFileBytes: 64);
    final newer = TemplateMediaCache.fetchPreviewFile(
      origin.url,
      prefetchBudget: newBudget,
    );
    await rejected.timeout(const Duration(seconds: 3));
    expect(
      await (await newer.timeout(const Duration(seconds: 3))).length(),
      16,
    );
    expect(release.isCompleted, isFalse);
    expect(newBudget.receivedBytes, 16);
    expect(requests, 2);
    release.complete();
  });

  for (final midBody in [false, true]) {
    test(
      'cancelling ${midBody ? 'mid-body' : 'before headers'} frees a saturated '
      'preview queue without releasing the stalled origin',
      () async {
        final capacity = TemplateMediaCache
            .previewVideoCache
            .config
            .fileService
            .concurrentFetches;
        final budgets = List.generate(
          capacity,
          (_) => MediaPrefetchBudget(maxBytes: 64, maxFileBytes: 64),
        );
        final started = Completer<void>();
        final release = Completer<void>();
        var stalledRequests = 0;
        var freshRequests = 0;
        final origin = await _server((request) async {
          if (request.uri.path.endsWith('/fresh')) {
            freshRequests++;
            request.response.add(Uint8List(16));
            await request.response.close();
            return;
          }
          if (midBody) {
            request.response.bufferOutput = false;
            request.response.add(Uint8List(16));
            await request.response.flush();
          }
          if (++stalledRequests == capacity) started.complete();
          await release.future;
          await request.response.close();
        });
        final rejected = <Future<void>>[];
        try {
          for (var index = 0; index < capacity; index++) {
            rejected.add(
              expectLater(
                TemplateMediaCache.fetchPreviewFile(
                  '${origin.url}/stalled-$index',
                  prefetchBudget: budgets[index],
                ),
                throwsA(isA<MediaPrefetchLimitException>()),
              ),
            );
          }
          await started.future.timeout(const Duration(seconds: 3));
          if (midBody) {
            await _waitForReceivedChunks(budgets);
          }
          // Every transport slot is held by an origin behind the barrier.
          // Cancelling just one must let required playback use that slot.
          final playback = TemplateMediaCache.fetchPreviewFile(
            '${origin.url}/fresh',
          );
          budgets.first.cancel();
          await rejected.first.timeout(const Duration(seconds: 3));
          final file = await playback.timeout(const Duration(seconds: 3));
          expect(await file.length(), 16);
          expect(freshRequests, 1);
          expect(stalledRequests, capacity);
          expect(release.isCompleted, isFalse);
          expect(
            budgets.skip(1).every((budget) => !budget.isCancelled),
            isTrue,
          );
          expect(
            await TemplateMediaCache.getCachedPreviewFile(
              '${origin.url}/stalled-0',
            ),
            isNull,
          );
        } finally {
          for (final budget in budgets) {
            budget.cancel();
          }
          release.complete();
          await Future.wait(rejected).timeout(const Duration(seconds: 3));
        }
      },
    );
  }

  for (final preview in [false, true]) {
    test(
      '${preview ? 'preview' : 'thumbnail'} disk hit consumes no speculative allowance',
      () async {
        const url = 'https://cdn.example.com/cached-budget';
        final cache = preview
            ? TemplateMediaCache.previewVideoCache
            : TemplateMediaCache.thumbnailCache;
        await cache.putFile(
          url,
          Uint8List(128),
          fileExtension: preview ? 'mp4' : 'jpg',
        );
        final fetch = preview
            ? TemplateMediaCache.fetchPreviewFile
            : TemplateMediaCache.fetchThumbnailFile;
        final budget = MediaPrefetchBudget(maxBytes: 1, maxFileBytes: 1);
        expect(await (await fetch(url, prefetchBudget: budget)).length(), 128);
        expect(budget.receivedBytes, 0);
      },
    );
  }
}

Future<void> _waitForReceivedChunks(List<MediaPrefetchBudget> budgets) async {
  final elapsed = Stopwatch()..start();
  while (budgets.any((budget) => budget.receivedBytes != 16)) {
    if (elapsed.elapsed > const Duration(seconds: 3)) {
      fail(
        'Initial response chunks did not reach the download constraints: '
        '${budgets.map((budget) => budget.receivedBytes).toList()}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<({String url})> _server(
  Future<void> Function(HttpRequest) handle,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final subscription = server.listen((request) async {
    expect(
      request.headers.value('x-petmagic-local-download-constraint'),
      isNull,
      reason: 'Cache manager context must never become an HTTP header',
    );
    request.response.headers
      ..contentType = ContentType('video', 'mp4')
      ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
    try {
      await handle(request);
    } on SocketException {
      // A correctly rejected/cancelled response may close the peer early.
    }
  });
  addTearDown(() async {
    await subscription.cancel();
    await server.close(force: true);
  });
  return (url: 'http://${server.address.host}:${server.port}/media');
}
