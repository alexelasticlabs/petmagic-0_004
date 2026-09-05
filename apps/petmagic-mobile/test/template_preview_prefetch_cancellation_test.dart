import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_prefetcher.dart';

import 'template_media_performance_test_support.dart';

void main() {
  configureTemplateMediaPerformanceHarness(ensureWidgets: false);
  setUp(TemplateMediaCache.clearAll);
  tearDown(TemplateMediaCache.clearAll);

  test(
    'jumping in reverse cancels obsolete HQ before the new fast queue',
    () async {
      final oldDetailStarted = Completer<void>();
      final releaseOldDetail = Completer<void>();
      final newFastReady = Completer<void>();
      final requests = <String>[];
      final origin = await _server((request) async {
        requests.add(request.uri.path);
        if (request.uri.path == '/1/detail.mp4') {
          oldDetailStarted.complete();
          await releaseOldDetail.future;
        }
        request.response.add(Uint8List(128));
        await request.response.close();
      });
      final items = List.generate(
        4,
        (index) => _video(index, origin, detail: index == 1),
      );
      var changedSelection = false;
      final queue = TemplatePreviewPrefetcher(
        policy: () => _policy(allowDetail: true),
        onReady: () {
          if (changedSelection && !newFastReady.isCompleted) {
            newFastReady.complete();
          }
        },
      );
      try {
        queue.schedule(items, 0);
        await oldDetailStarted.future.timeout(const Duration(seconds: 3));
        expect(requests, ['/1/low.mp4', '/1/detail.mp4']);

        changedSelection = true;
        queue.schedule(items, 3, direction: -1);
        await newFastReady.future.timeout(const Duration(seconds: 3));
        expect(releaseOldDetail.isCompleted, isFalse);
        expect(requests, ['/1/low.mp4', '/1/detail.mp4', '/2/low.mp4']);
        final file = await TemplateMediaCache.getCachedPreviewFile(
          items[2].feedLoopLowUrl!,
          mediaVersion: items[2].mediaVersion,
        );
        expect(file, isNotNull);
        expect(await file!.length(), 128);
        expect(
          await TemplateMediaCache.getCachedPreviewFile(
            items[1].detailPreviewUrl!,
            mediaVersion: items[1].mediaVersion,
          ),
          isNull,
        );
      } finally {
        queue.dispose();
        releaseOldDetail.complete();
      }
    },
  );

  test(
    'selecting the in-flight target keeps one GET for foreground playback',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      final origin = await _server((request) async {
        expect(request.uri.path, '/1/low.mp4');
        if (++requests == 1) {
          started.complete();
          await release.future;
        }
        request.response.add(Uint8List(128));
        await request.response.close();
      });
      final items = [_video(0, origin), _video(1, origin)];
      final queue = TemplatePreviewPrefetcher(
        policy: () => _policy(allowDetail: false),
      );
      try {
        queue.schedule(items, 0);
        await started.future.timeout(const Duration(seconds: 3));
        queue.schedule(items, 1);
        final playback = TemplateMediaCache.fetchPreviewFile(
          items[1].feedLoopLowUrl!,
          mediaVersion: items[1].mediaVersion,
        );
        // Once playback joins, disposing optional work must preserve the GET.
        queue.dispose();
        release.complete();
        final file = await playback.timeout(const Duration(seconds: 3));
        expect(await file.length(), 128);
        expect(requests, 1);
        expect(
          await TemplateMediaCache.getCachedPreviewFile(
            items[1].feedLoopLowUrl!,
            mediaVersion: items[1].mediaVersion,
          ),
          file,
        );
      } finally {
        queue.dispose();
        if (!release.isCompleted) release.complete();
      }
    },
  );
}

TemplatePreviewPrefetchPolicy _policy({required bool allowDetail}) =>
    TemplatePreviewPrefetchPolicy(
      enabled: true,
      videoAhead: 1,
      imageAhead: 1,
      behind: 0,
      maxEstimatedBytes: 8 * 1024 * 1024,
      maxFileBytes: 4 * 1024 * 1024,
      allowDetailPrefetch: allowDetail,
    );

TemplateItem _video(int index, String origin, {bool detail = false}) =>
    TemplateItem(
      templateId: 'video-$index',
      templateType: TemplateType.video,
      title: 'Video $index',
      shortDescription: '',
      petPhotoRequirements: const [],
      category: '',
      tags: const [],
      isPremium: false,
      tokenCost: 1,
      feedLoopLowUrl: '$origin/$index/low.mp4',
      detailPreviewUrl: detail ? '$origin/$index/detail.mp4' : null,
      mediaKind: 'video',
      mediaVersion: 7,
      sizeBytes: detail ? 1024 * 1024 : null,
    );

Future<String> _server(Future<void> Function(HttpRequest) handle) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final subscription = server.listen((request) async {
    expect(
      request.headers.value('x-petmagic-local-download-constraint'),
      isNull,
    );
    request.response.headers
      ..contentType = ContentType('video', 'mp4')
      ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
    try {
      await handle(request);
    } on SocketException {
      // Cancellation can close the peer before the held response is released.
    }
  });
  addTearDown(() async {
    await subscription.cancel();
    await server.close(force: true);
  });
  return 'http://${server.address.host}:${server.port}';
}
