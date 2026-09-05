import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
  });

  test('template serialization preserves every optimized preview URL', () {
    final remote = TemplateItemDto.fromJson(_templatePayload());
    final restored = TemplateItemDto.fromJson(remote.toJson());

    _expectPreviewUrls(restored);
    expect(restored.toJson(), remote.toJson());
  });

  test(
    'first feed snapshot restores the same versioned preview URLs',
    () async {
      final cache = TemplatesCacheDataSource(SharedPreferencesAsync());
      await cache.writeFirstPage(
        const TemplatesQuery(),
        TemplatesFeedDto(
          items: [TemplateItemDto.fromJson(_templatePayload())],
          hasMore: true,
          nextCursor: 'next-page',
          page: 1,
        ),
      );

      final restored = await cache.readFirstPage(const TemplatesQuery());

      _expectPreviewUrls(restored!.items.single);
      expect(restored.nextCursor, 'next-page');
      expect(await cache.readCatalogItems(), isEmpty);
    },
  );

  test(
    'full catalog and discovery snapshots preserve optimized previews',
    () async {
      final preferences = SharedPreferencesAsync();
      final item = TemplateItemDto.fromJson(_templatePayload());
      final catalog = TemplatesCacheDataSource(preferences);
      await catalog.replaceCatalog([item], version: 9);
      final discovery = TemplateDiscoveryCacheDataSource(preferences);
      await discovery.write(
        TemplateDiscoveryDto(
          sections: [
            TemplateDiscoverySectionDto(category: 'Motion', items: [item]),
          ],
          generatedAtUtc: DateTime.utc(2026, 9, 5),
        ),
        localeTag: 'ru-RU',
      );

      _expectPreviewUrls((await catalog.readCatalogItems()).single);
      _expectPreviewUrls(
        (await discovery.read(
          localeTag: 'ru-RU',
        ))!.sections.single.items.single,
      );
    },
  );

  test(
    'detail cache hits do not extend the ten minute freshness limit',
    () async {
      var now = DateTime.utc(2026, 9, 5);
      var requests = 0;
      final repository = _repository((_) async {
        requests++;
        return _response(_templatePayload(title: 'Version $requests'));
      }, nowUtc: () => now);

      final initial = await repository.fetchTemplate('template-1');
      now = now.add(const Duration(minutes: 9));
      final cached = await repository.fetchTemplate('template-1');
      expect(identical(initial, cached), isTrue);
      expect(requests, 1);

      now = now.add(const Duration(minutes: 1));
      final refreshed = await repository.fetchTemplate('template-1');
      expect(refreshed.title, 'Version 2');
      expect(requests, 2);
    },
  );

  test(
    'cached openings record a view without waiting or repeating the GET',
    () async {
      final requests = <RequestOptions>[];
      final analyticsStarted = Completer<void>();
      final analyticsResponse = Completer<ResponseBody>();
      final repository = _repository((options) {
        requests.add(options);
        if (options.method == 'POST') {
          analyticsStarted.complete();
          return analyticsResponse.future;
        }
        return Future.value(_response(_templatePayload()));
      });

      await repository.fetchTemplate(
        'template-1',
        analyticsSource: 'discovery',
      );
      expect(requests.single.method, 'GET');
      expect(requests.single.queryParameters['source'], 'discovery');

      final cached = await repository
          .fetchTemplate('template-1', analyticsSource: ' catalog ')
          .timeout(const Duration(seconds: 1));
      await analyticsStarted.future;
      expect(cached.templateId, 'template-1');
      expect(analyticsResponse.isCompleted, isFalse);
      expect(requests.length, 2);
      expect(requests.last.path, '/api/templates/template-1/analytics/events');
      expect(requests.last.data, {
        'eventType': 'view',
        'source': 'catalog',
        'deviceClass': 'web',
      });

      // Technical cache reads are not additional user openings.
      await repository.fetchTemplate('template-1');
      await repository.fetchTemplate('template-1', analyticsSource: '  ');
      expect(requests.length, 2);
      analyticsResponse.complete(_response({}));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'cached view analytics failure does not fail or discard detail',
    () async {
      var detailRequests = 0;
      var analyticsRequests = 0;
      final analyticsStarted = Completer<void>();
      final repository = _repository((options) async {
        if (options.method == 'POST') {
          analyticsRequests++;
          analyticsStarted.complete();
          return _response({'error': 'analytics_unavailable'}, statusCode: 503);
        }
        detailRequests++;
        return _response(_templatePayload());
      });

      final initial = await repository.fetchTemplate('template-1');
      final cached = await repository.fetchTemplate(
        'template-1',
        analyticsSource: 'discovery',
      );
      await analyticsStarted.future;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(identical(cached, initial), isTrue);
      expect(analyticsRequests, 1);
      expect(
        identical(await repository.fetchTemplate('template-1'), initial),
        isTrue,
      );
      expect(detailRequests, 1);
    },
  );

  test(
    'concurrent openings share details and each retain their view source',
    () async {
      final requests = <RequestOptions>[];
      final detailStarted = Completer<void>();
      final detailResponse = Completer<ResponseBody>();
      final analyticsStarted = Completer<void>();
      final repository = _repository((options) {
        requests.add(options);
        if (options.method == 'POST') {
          analyticsStarted.complete();
          return Future.value(_response({}));
        }
        detailStarted.complete();
        return detailResponse.future;
      });

      final first = repository.fetchTemplate(
        'template-1',
        analyticsSource: 'discovery',
      );
      await detailStarted.future;
      final second = repository.fetchTemplate(
        'template-1',
        analyticsSource: 'catalog',
      );
      final technicalRead = repository.fetchTemplate('template-1');
      expect(requests.length, 1);
      detailResponse.complete(_response(_templatePayload()));
      final results = await Future.wait([first, second, technicalRead]);
      await analyticsStarted.future;

      expect(results.every((item) => identical(item, results.first)), isTrue);
      expect(requests.length, 2);
      expect(requests.first.queryParameters['source'], 'discovery');
      expect((requests.last.data as Map)['eventType'], 'view');
      expect((requests.last.data as Map)['source'], 'catalog');
    },
  );

  test('failed shared detail request does not record a reused view', () async {
    final requests = <RequestOptions>[];
    final detailStarted = Completer<void>();
    final detailResponse = Completer<ResponseBody>();
    final repository = _repository((options) {
      requests.add(options);
      detailStarted.complete();
      return detailResponse.future;
    });

    final first = repository.fetchTemplate(
      'template-1',
      analyticsSource: 'discovery',
    );
    await detailStarted.future;
    final second = repository.fetchTemplate(
      'template-1',
      analyticsSource: 'catalog',
    );
    final firstFailure = expectLater(first, throwsA(isA<Exception>()));
    final secondFailure = expectLater(second, throwsA(isA<Exception>()));
    detailResponse.complete(_response({}, statusCode: 404));
    await Future.wait([firstFailure, secondFailure]);

    expect(requests.length, 1);
    expect(requests.single.method, 'GET');
  });

  test(
    'late detail response cannot replace a completed forced refresh',
    () async {
      final firstStarted = Completer<void>();
      final firstResponse = Completer<ResponseBody>();
      var requests = 0;
      final repository = _repository((_) {
        requests++;
        if (requests == 1) {
          firstStarted.complete();
          return firstResponse.future;
        }
        return Future.value(
          _response(_templatePayload(title: 'Fresh details')),
        );
      });

      final first = repository.fetchTemplate('template-1');
      await firstStarted.future;
      final refreshed = await repository.fetchTemplate(
        'template-1',
        forceRefresh: true,
      );
      expect(refreshed.title, 'Fresh details');

      firstResponse.complete(_response(_templatePayload(title: 'Old details')));
      expect((await first).title, 'Old details');
      expect(
        (await repository.fetchTemplate('template-1')).title,
        'Fresh details',
      );
      expect(requests, 2);
    },
  );

  test(
    'newer feed version bypasses cached detail without a duplicate view',
    () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options) async {
        requests.add(options);
        return _response(_templatePayload(mediaVersion: requests.length));
      });

      final initial = await repository.fetchTemplate(
        'template-1',
        analyticsSource: 'discovery',
      );
      final updated = await repository.fetchTemplate(
        'template-1',
        minimumVersion: 2,
        analyticsSource: 'catalog',
      );

      expect(initial.mediaVersion, 1);
      expect(updated.mediaVersion, 2);
      expect(requests.map((request) => request.method), ['GET', 'GET']);
      expect(requests.last.queryParameters['source'], 'catalog');
      expect(requests.last.queryParameters, isNot(contains('minimumVersion')));
    },
  );

  test(
    'newer feed version retries stale shared detail without a view POST',
    () async {
      final requests = <RequestOptions>[];
      final firstStarted = Completer<void>();
      final firstResponse = Completer<ResponseBody>();
      final repository = _repository((options) {
        requests.add(options);
        if (requests.length == 1) {
          firstStarted.complete();
          return firstResponse.future;
        }
        return Future.value(_response(_templatePayload(mediaVersion: 2)));
      });

      final first = repository.fetchTemplate('template-1');
      await firstStarted.future;
      final opening = repository.fetchTemplate(
        'template-1',
        minimumVersion: 2,
        analyticsSource: 'discovery',
      );
      firstResponse.complete(_response(_templatePayload(mediaVersion: 1)));

      expect((await first).mediaVersion, 1);
      expect((await opening).mediaVersion, 2);
      expect(requests.map((request) => request.method), ['GET', 'GET']);
      expect(requests.last.queryParameters['source'], 'discovery');
      expect((await repository.fetchTemplate('template-1')).mediaVersion, 2);
      expect(requests.length, 2);
    },
  );

  test(
    'recently read details survive LRU eviction within the 64 item budget',
    () async {
      final requests = <String, int>{};
      final repository = _repository((options) async {
        final id = options.path.split('/').last;
        requests.update(id, (count) => count + 1, ifAbsent: () => 1);
        return _response({..._templatePayload(), 'templateId': id});
      });

      for (var index = 0; index < 64; index++) {
        await repository.fetchTemplate('template-$index');
      }
      await repository.fetchTemplate('template-0');
      await repository.fetchTemplate('template-64');
      await repository.fetchTemplate('template-0');
      await repository.fetchTemplate('template-1');

      expect(requests['template-0'], 1);
      expect(requests['template-1'], 2);
    },
  );
}

DefaultTemplatesRepository _repository(
  Future<ResponseBody> Function(RequestOptions) handler, {
  DateTime Function()? nowUtc,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
    ..httpClientAdapter = _Adapter(handler);
  return DefaultTemplatesRepository(
    remoteDataSource: TemplatesRemoteDataSource(dio),
    cacheDataSource: TemplatesCacheDataSource(SharedPreferencesAsync()),
    nowUtc: nowUtc,
  );
}

Map<String, Object?> _templatePayload({
  String title = 'Preview',
  int mediaVersion = 8,
}) => {
  'templateId': 'template-1',
  'templateType': 'Video',
  'title': title,
  'category': 'Motion',
  'tokenCost': 25,
  'version': 9,
  'media': {
    'thumbnailUrl': 'https://cdn.petmagic.test/thumb.webp',
    'animatedPreviewUrl': 'https://cdn.petmagic.test/animated.webp',
    'feedLoopLowUrl': 'https://cdn.petmagic.test/low.mp4',
    'feedLoopMediumUrl': 'https://cdn.petmagic.test/medium.mp4',
    'detailPreviewUrl': 'https://cdn.petmagic.test/detail.mp4',
    'mediaKind': 'video',
    'durationMs': 5000,
    'sizeBytes': 120000,
    'mediaVersion': mediaVersion,
  },
};

void _expectPreviewUrls(TemplateItemDto item) {
  expect(item.thumbnailUrl, 'https://cdn.petmagic.test/thumb.webp');
  expect(item.animatedPreviewUrl, 'https://cdn.petmagic.test/animated.webp');
  expect(item.feedLoopLowUrl, 'https://cdn.petmagic.test/low.mp4');
  expect(item.feedLoopMediumUrl, 'https://cdn.petmagic.test/medium.mp4');
  expect(item.detailPreviewUrl, 'https://cdn.petmagic.test/detail.mp4');
  expect(item.previewAsset?.url, 'https://cdn.petmagic.test/detail.mp4');
  expect(item.mediaVersion, 8);
  expect(item.version, 9);
}

ResponseBody _response(Map<String, Object?> json, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(json),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}
