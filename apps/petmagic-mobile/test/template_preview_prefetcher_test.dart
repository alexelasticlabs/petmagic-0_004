import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_media_selection.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_prefetcher.dart';

void main() {
  test(
    'Wi-Fi follows bounded positions with different image and video horizons',
    () async {
      final calls = <String>[];
      final queue = _queue(calls);
      queue.schedule([
        _image(0),
        _image(1),
        _video(2),
        _image(3),
        _video(4),
        _video(5),
      ], 0);
      await _flush();
      expect(calls, ['thumb:1', 'medium:2', 'medium:4']);
      queue.dispose();
    },
  );

  test('cellular uses two low video positions and no backwards work', () async {
    final calls = <String>[];
    final queue = _queue(
      calls,
      policy: () => TemplatePreviewPrefetchPolicy.cellular,
    );
    queue.schedule(List.generate(6, _video), 1);
    await _flush();
    expect(calls, ['low:2', 'low:3']);
    queue.dispose();

    calls.clear();
    final images = _queue(
      calls,
      policy: () => TemplatePreviewPrefetchPolicy.cellular,
    );
    images.schedule(List.generate(5, _image), 1);
    await _flush();
    expect(calls, ['thumb:2']);
    images.dispose();
  });

  for (final generationVideo in [false, true]) {
    test('image media with feed aliases uses image horizon and thumbnail cache '
        '(generationVideo: $generationVideo)', () async {
      final calls = <String>[];
      final queue = TemplatePreviewPrefetcher(
        fetch: (url, _) async => calls.add('preview:${_label(url)}'),
        fetchThumbnail: (url, _) async => calls.add('thumbnail:${_label(url)}'),
      );
      queue.schedule(
        List.generate(
          5,
          (index) => _image(
            index,
            feedAliases: true,
            generationVideo: generationVideo,
          ),
        ),
        0,
      );
      await _flush();
      expect(calls, ['thumbnail:thumb:1', 'thumbnail:thumb:2']);
      queue.dispose();
    });
  }

  test(
    'backwards navigation reverses the horizon with one trailing position',
    () async {
      final calls = <String>[];
      final queue = _queue(calls);
      queue.schedule(List.generate(7, _video), 4, direction: -1);
      await _flush();
      expect(calls, [
        'medium:3',
        'medium:2',
        'medium:1',
        'medium:0',
        'medium:5',
      ]);
      queue.dispose();
    },
  );

  test(
    'sequential downloads discard old queued positions after rapid selection',
    () async {
      final calls = <String>[];
      final gates = <Completer<void>>[];
      final queue = TemplatePreviewPrefetcher(
        fetch: (url, _) {
          calls.add(_label(url));
          final gate = Completer<void>();
          gates.add(gate);
          return gate.future;
        },
      );
      final items = List.generate(8, _video);
      queue.schedule(items, 1);
      expect(calls, ['medium:2']);
      queue.schedule(items, 5);
      expect(calls, hasLength(1));
      gates[0].complete();
      await _flush();
      expect(calls, ['medium:2', 'medium:6']);
      gates[1].complete();
      await _flush();
      expect(calls.last, 'medium:7');
      gates[2].complete();
      await _flush();
      expect(calls.last, 'medium:4');
      gates[3].complete();
      await _flush();
      queue.schedule(items, 5);
      await _flush();
      expect(calls, hasLength(4));
      queue.dispose();
    },
  );

  test(
    'foreground loss finishes only the active file and suppresses readiness',
    () async {
      var allowed = true;
      var ready = 0;
      final gate = Completer<void>();
      final calls = <String>[];
      final queue = TemplatePreviewPrefetcher(
        canPrefetch: () => allowed,
        onReady: () => ready++,
        fetch: (url, _) async {
          calls.add(_label(url));
          await gate.future;
        },
      );
      final items = List.generate(3, _video);
      queue.schedule(items, 1);
      allowed = false;
      queue.schedule(items, 1);
      gate.complete();
      await _flush();
      expect(calls, ['medium:2']);
      expect(ready, 0);
      allowed = true;
      queue.schedule(items, 1);
      await _flush();
      expect(calls, ['medium:2', 'medium:0']);
      expect(ready, 1);
      queue.dispose();
    },
  );

  test('disabled policy and disposed queue perform no work', () async {
    final calls = <String>[];
    var policy = TemplatePreviewPrefetchPolicy.disabled;
    final queue = _queue(calls, policy: () => policy);
    queue.schedule(List.generate(4, _video), 0);
    await _flush();
    expect(calls, isEmpty);
    policy = TemplatePreviewPrefetchPolicy.wifi;
    queue.dispose();
    queue.schedule(List.generate(4, _video), 0);
    await _flush();
    expect(calls, isEmpty);
  });

  test(
    'failed futures can retry and successful cache completion notifies once',
    () async {
      var calls = 0;
      var ready = 0;
      final queue = TemplatePreviewPrefetcher(
        onReady: () => ready++,
        fetch: (_, _) async {
          calls++;
          if (calls == 1) throw StateError('offline');
        },
      );
      final items = [_video(0), _video(1)];
      queue.schedule(items, 0);
      await _flush();
      expect(ready, 0);
      queue.schedule(items, 0);
      await _flush();
      queue.schedule(items, 0);
      await _flush();
      expect(calls, 2);
      expect(ready, 1);
      queue.dispose();
    },
  );

  testWidgets('detail waits for 700 ms stability after fast media', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    final calls = <String>[];
    final queue = _queue(calls, now: () => now);
    queue.schedule([
      _video(0),
      _video(1, detail: true),
      _video(2, detail: true),
    ], 0);
    await tester.pump();
    expect(calls, ['medium:1', 'medium:2']);
    now = now.add(const Duration(milliseconds: 699));
    await tester.pump(const Duration(milliseconds: 699));
    expect(calls, hasLength(2));
    now = now.add(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, ['medium:1', 'medium:2', 'detail:1']);
    queue.dispose();
  });

  testWidgets('detail cannot jump ahead of an unfinished fast queue', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    final calls = <String>[];
    final gate = Completer<void>();
    final queue = TemplatePreviewPrefetcher(
      now: () => now,
      fetch: (url, _) async {
        calls.add(_label(url));
        if (calls.length == 1) await gate.future;
      },
    );
    queue.schedule([_video(0), _video(1, detail: true), _video(2)], 0);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['medium:1']);
    gate.complete();
    await tester.pump();
    expect(calls, ['medium:1', 'medium:2', 'detail:1']);
    queue.dispose();
  });

  testWidgets(
    'rapid swipes cancel old HQ timers and cancellation clears the last one',
    (tester) async {
      var now = DateTime.utc(2026);
      final calls = <String>[];
      final queue = _queue(calls, now: () => now);
      final items = List.generate(6, (index) => _video(index, detail: true));
      queue.schedule(items, 0);
      await tester.pump();
      now = now.add(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      queue.schedule(items, 1);
      await tester.pump();
      now = now.add(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      queue.schedule(items, 2);
      await tester.pump();
      expect(calls.where((url) => url.startsWith('detail:')), isEmpty);
      now = now.add(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(calls.where((url) => url.startsWith('detail:')), ['detail:3']);
      queue.schedule(items, 3);
      await tester.pump();
      queue.cancelPending();
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(calls.where((url) => url.startsWith('detail:')), ['detail:3']);
      queue.dispose();
    },
  );

  test(
    'estimated wave budget is preserved across repeated schedules',
    () async {
      const policy = TemplatePreviewPrefetchPolicy(
        enabled: true,
        videoAhead: 4,
        imageAhead: 2,
        behind: 1,
        maxEstimatedBytes: 1536 * 1024,
        maxFileBytes: 1024 * 1024,
        allowDetailPrefetch: false,
      );
      final calls = <String>[];
      final queue = _queue(calls, policy: () => policy);
      final items = [_video(0), _video(1), _image(2), _video(3), _video(4)];
      queue.schedule(items, 0);
      await _flush();
      queue.schedule(items, 0);
      await _flush();
      expect(calls, ['medium:1', 'thumb:2']);
      queue.dispose();
    },
  );

  test(
    'unoptimized originals require a known size within file admission limits',
    () async {
      final calls = <String>[];
      final queue = _queue(calls);
      queue.schedule([
        _video(0),
        _video(1, derivatives: false),
        _video(2, derivatives: false, size: 9 * 1024 * 1024),
        _video(3, derivatives: false, size: 512 * 1024),
      ], 0);
      await _flush();
      expect(calls, ['original:3']);
      queue.dispose();
    },
  );

  test(
    'versions invalidate completed keys while unsafe media is ignored',
    () async {
      final versions = <int?>[];
      final queue = TemplatePreviewPrefetcher(
        fetch: (_, version) async => versions.add(version),
      );
      queue.schedule([_video(0), _video(1, unsafe: true)], 0);
      await _flush();
      expect(versions, isEmpty);
      queue.schedule([_video(0), _video(1, version: 4)], 0);
      await _flush();
      queue.schedule([_video(0), _video(1, version: 5)], 0);
      await _flush();
      expect(versions, [4, 5]);
      queue.dispose();
    },
  );

  test(
    'medium fallback uses its own estimate when low is unavailable',
    () async {
      const policy = TemplatePreviewPrefetchPolicy(
        enabled: true,
        videoAhead: 2,
        imageAhead: 1,
        behind: 0,
        maxEstimatedBytes: 512 * 1024,
        maxFileBytes: 512 * 1024,
        allowDetailPrefetch: false,
      );
      final calls = <String>[];
      final queue = TemplatePreviewPrefetcher(
        policy: () => policy,
        preferLowResolution: () => true,
        fetch: (url, _) async => calls.add(_label(url)),
      );
      queue.schedule([_video(0), _video(1, includeLow: false), _video(2)], 0);
      await _flush();
      expect(calls, ['low:2']);
      queue.dispose();
    },
  );

  testWidgets('detail alias cannot bypass an unknown original size', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    final calls = <String>[];
    final queue = _queue(calls, now: () => now);
    queue.schedule([
      _video(0),
      _video(1, derivatives: false, detail: true, detailIsOriginal: true),
    ], 0);
    await tester.pump();
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);
    queue.dispose();
  });

  testWidgets(
    'image thumbnail precedes its distinct detail in the matching caches',
    (tester) async {
      var now = DateTime.utc(2026);
      final calls = <String>[];
      final queue = TemplatePreviewPrefetcher(
        now: () => now,
        fetch: (url, _) async => calls.add('preview:${_label(url)}'),
        fetchThumbnail: (url, _) async => calls.add('thumbnail:${_label(url)}'),
      );
      queue.schedule([_image(0), _image(1, detail: true)], 0);
      await tester.pump();
      expect(calls, ['thumbnail:thumb:1']);
      now = now.add(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(calls, ['thumbnail:thumb:1', 'preview:detail:1']);
      queue.dispose();
    },
  );

  test('same detail and thumbnail keep the shared feed image cache', () {
    final item = _image(1, detail: true, sameDetail: true);
    final selection = TemplatePreviewMediaSelection(item, expand: true);
    expect(selection.usesDetailImageCache, isFalse);
    expect(selection.imageUrl, item.thumbnailUrl);
  });
}

TemplatePreviewPrefetcher _queue(
  List<String> calls, {
  TemplatePreviewPrefetchPolicy Function()? policy,
  DateTime Function()? now,
}) => TemplatePreviewPrefetcher(
  policy: policy,
  now: now,
  fetch: (url, _) async => calls.add(_label(url)),
  fetchThumbnail: (url, _) async => calls.add(_label(url)),
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);
String _url(String kind, int index) => 'https://cdn.example.com/$kind/$index';
String _label(String url) => Uri.parse(url).pathSegments.join(':');

TemplateItem _video(
  int index, {
  bool detail = false,
  bool derivatives = true,
  bool includeLow = true,
  bool detailIsOriginal = false,
  bool unsafe = false,
  int? version,
  int? size,
}) => TemplateItem(
  templateId: 'video-$index',
  templateType: TemplateType.video,
  title: 'Video',
  shortDescription: '',
  petPhotoRequirements: const [],
  category: '',
  tags: const [],
  isPremium: false,
  tokenCost: 1,
  feedLoopLowUrl: derivatives && includeLow
      ? (unsafe ? 'file:///private.mp4' : _url('low', index))
      : null,
  feedLoopMediumUrl: derivatives
      ? (unsafe ? 'file:///private.mp4' : _url('medium', index))
      : null,
  detailPreviewUrl: detail
      ? _url(detailIsOriginal ? 'original' : 'detail', index)
      : null,
  mediaKind: 'video',
  mediaVersion: version,
  sizeBytes: size,
  previewAsset: TemplateAsset(
    url: _url('original', index),
    fileName: 'original.mp4',
    contentType: 'video/mp4',
    fileSizeBytes: size,
  ),
);

TemplateItem _image(
  int index, {
  bool detail = false,
  bool sameDetail = false,
  bool feedAliases = false,
  bool generationVideo = false,
}) => TemplateItem(
  templateId: 'image-$index',
  templateType: generationVideo ? TemplateType.video : TemplateType.image,
  title: 'Image',
  shortDescription: '',
  petPhotoRequirements: const [],
  category: '',
  tags: const [],
  isPremium: false,
  tokenCost: 1,
  thumbnailUrl: _url('thumb', index),
  feedLoopLowUrl: feedAliases ? _url('thumb', index) : null,
  feedLoopMediumUrl: feedAliases ? _url('thumb', index) : null,
  detailPreviewUrl: detail
      ? _url(sameDetail ? 'thumb' : 'detail', index)
      : null,
  mediaKind: 'image',
);
