import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_dto.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('discovery snapshots are isolated by locale', () async {
    final previousPreferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() {
      SharedPreferencesAsyncPlatform.instance = previousPreferences;
    });

    final preferences = SharedPreferencesAsync();
    final cache = TemplateDiscoveryCacheDataSource(preferences);
    final englishSnapshot = _snapshot('English category');
    final russianSnapshot = _snapshot('Russian category');

    await cache.write(englishSnapshot, localeTag: 'en-US');
    expect(await cache.read(localeTag: 'ru-RU'), isNull);

    await cache.write(russianSnapshot, localeTag: 'ru-RU');

    expect(
      (await cache.read(localeTag: 'en-US'))?.sections.single.category,
      'English category',
    );
    expect(
      (await cache.read(localeTag: 'ru-RU'))?.sections.single.category,
      'Russian category',
    );
  });

  test(
    'delayed response is cached under the request locale snapshot',
    () async {
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
      });

      final requestStarted = Completer<RequestOptions>();
      final response = Completer<ResponseBody>();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _DelayedHttpClientAdapter((options) {
          requestStarted.complete(options);
          return response.future;
        });
      final runtimeInfo = _MutableAppRuntimeInfo(
        const AppLocale(languageTag: 'en-US', countryCode: 'US'),
      );
      final cache = TemplateDiscoveryCacheDataSource(SharedPreferencesAsync());
      final repository = DefaultTemplateDiscoveryRepository(
        remoteDataSource: TemplateDiscoveryRemoteDataSource(
          dio,
          runtimeInfo: runtimeInfo,
        ),
        cacheDataSource: cache,
        runtimeInfo: runtimeInfo,
      );

      final fetch = repository.fetch();
      final request = await requestStarted.future;
      expect(request.queryParameters, {
        'sectionLimit': 24,
        'itemsPerSection': 12,
      });

      runtimeInfo.locale = const AppLocale(
        languageTag: 'ru-RU',
        countryCode: 'RU',
      );
      response.complete(
        ResponseBody.fromString(
          jsonEncode({
            'sections': [
              {'category': 'English category', 'items': <Object?>[]},
            ],
            'generatedAtUtc': '2026-09-04T08:00:00Z',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await fetch;

      TemplateDiscoveryDto? englishSnapshot;
      for (
        var attempt = 0;
        attempt < 20 && englishSnapshot == null;
        attempt++
      ) {
        await Future<void>.delayed(Duration.zero);
        englishSnapshot = await cache.read(localeTag: 'en-US');
      }

      expect(englishSnapshot?.sections.single.category, 'English category');
      expect(await cache.read(localeTag: 'ru-RU'), isNull);
    },
  );

  test('discovery cache strips credentials from URLs and file names', () async {
    final previousPreferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() {
      SharedPreferencesAsyncPlatform.instance = previousPreferences;
    });
    const signedPreview =
        'https://cdn.petmagic.test/feed.mp4?X-Amz-Signature=secret#preview';
    const signedThumbnail =
        'https://cdn.petmagic.test/thumb.jpg?token=secret#thumbnail';
    final snapshot = TemplateDiscoveryDto.fromJson({
      'sections': [
        {
          'category': 'Secure previews',
          'items': [
            {
              'id': 'secure-template',
              'type': 'Video',
              'title': 'Secure preview',
              'shortDescription': 'Signed delivery URLs',
              'category': {'title': 'Secure previews'},
              'media': {
                'thumbnailUrl': signedThumbnail,
                'feedLoopMediumUrl': signedPreview,
                'mediaKind': 'video',
                'mediaVersion': 4,
              },
              'version': 4,
            },
          ],
        },
      ],
      'generatedAtUtc': '2026-09-04T08:00:00Z',
    });
    final cache = TemplateDiscoveryCacheDataSource(SharedPreferencesAsync());

    await cache.write(snapshot, localeTag: 'en-US');
    final cached = await cache.read(localeTag: 'en-US');
    final item = cached!.sections.single.items.single;
    final serialized = jsonEncode(cached.toJson());

    expect(item.thumbnailUrl, 'https://cdn.petmagic.test/thumb.jpg');
    expect(item.previewAsset?.url, 'https://cdn.petmagic.test/feed.mp4');
    expect(item.previewAsset?.fileName, 'feed.mp4');
    expect(serialized, isNot(contains('secret')));
    expect(serialized, isNot(contains('X-Amz-Signature')));
    expect(serialized, isNot(contains('#preview')));
  });
}

TemplateDiscoveryDto _snapshot(String category) {
  return TemplateDiscoveryDto(
    sections: [
      TemplateDiscoverySectionDto(category: category, items: const []),
    ],
    generatedAtUtc: DateTime.utc(2026, 9, 4),
  );
}

final class _MutableAppRuntimeInfo implements AppRuntimeInfo {
  _MutableAppRuntimeInfo(this.locale);

  @override
  AppLocale locale;

  @override
  AppRuntimePlatform get platform => AppRuntimePlatform.other;
}

final class _DelayedHttpClientAdapter implements HttpClientAdapter {
  _DelayedHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
