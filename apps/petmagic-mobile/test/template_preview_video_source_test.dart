import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_source.dart';

void main() {
  const detail = 'https://cdn.example.com/detail.mp4';
  const medium = 'https://cdn.example.com/medium.mp4';
  const low = 'https://cdn.example.com/low.mp4';
  late Map<String, File> cached;
  late List<String> fetched;
  late List<int?> versions;
  Future<File?> lookup(String url, {int? mediaVersion}) async {
    versions.add(mediaVersion);
    return cached[url];
  }

  Future<File> fetch(String url, {int? mediaVersion}) async {
    fetched.add(url);
    versions.add(mediaVersion);
    return File('preview.mp4');
  }

  Future<TemplatePreviewVideoSource?> resolve({bool cachedOnly = false}) =>
      resolveTemplatePreviewVideoSource(
        detail,
        fallbackUrls: [medium, low],
        mediaVersion: 7,
        cachedOnly: cachedOnly,
        lookup: lookup,
        fetch: fetch,
      );
  setUp(() {
    cached = {};
    fetched = [];
    versions = [];
  });

  test('cached detail wins without any new request', () async {
    cached[detail] = File('detail.mp4');
    cached[low] = File('low.mp4');
    expect((await resolve())?.url, detail);
    expect(fetched, isEmpty);
    expect(versions, everyElement(7));
  });
  test('already viewed low plays even when Wi-Fi prefers medium', () async {
    cached[low] = File('low.mp4');
    expect((await resolve())?.url, low);
    expect(fetched, isEmpty);
  });
  test('cold start downloads only the adaptive derivative', () async {
    expect((await resolve())?.url, medium);
    expect(fetched, [medium]);
    expect(versions, everyElement(7));
  });
  test('offscreen preparation never starts a download', () async {
    expect(await resolve(cachedOnly: true), isNull);
    expect(fetched, isEmpty);
  });
  test('deep link without derivatives still loads valid detail', () async {
    final result = await resolveTemplatePreviewVideoSource(
      detail,
      lookup: lookup,
      fetch: fetch,
    );
    expect(result?.url, detail);
    expect(fetched, [detail]);
  });
  test('unavailable derivatives fall back to playable detail', () async {
    final result = await resolveTemplatePreviewVideoSource(
      detail,
      fallbackUrls: [medium, low],
      lookup: lookup,
      fetch: (url, {mediaVersion}) async {
        fetched.add(url);
        if (url != detail) throw const HttpException('404');
        return File('detail.mp4');
      },
    );
    expect(result?.url, detail);
    expect(fetched, [medium, low, detail]);
  });
  test('invalidation stops fallback requests after cache clear', () async {
    await expectLater(
      resolveTemplatePreviewVideoSource(
        detail,
        fallbackUrls: [medium, low],
        lookup: lookup,
        fetch: (url, {mediaVersion}) async {
          fetched.add(url);
          throw StateError('template_preview_cache_invalidated');
        },
      ),
      throwsStateError,
    );
    expect(fetched, [medium]);
  });
}
