import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

void main() {
  test('templates feed query clamps page size before request mapping', () {
    expect(
      const TemplatesQuery(pageSize: 1000).toQueryParameters()['take'],
      100,
    );
    expect(const TemplatesQuery(pageSize: 0).toQueryParameters()['take'], 1);
    expect(const TemplatesQuery(pageSize: -20).toQueryParameters()['take'], 1);
    expect(const TemplatesQuery(pageSize: 1000).cacheKey, contains('|100'));
  });

  test(
    'fetchFeed uses public feed contract instead of catalog metadata',
    () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({
              'items': [
                {
                  'id': 'template-video-1',
                  'type': 'Video',
                  'title': 'Magic portrait',
                  'shortDescription': 'Animated pet portrait',
                  'category': {
                    'id': null,
                    'slug': 'portrait',
                    'title': 'Portrait',
                  },
                  'tags': ['portrait', 'video'],
                  'isPremium': true,
                  'access': 'premium',
                  'tokenCost': 17,
                  'thumbnailUrl': 'https://cdn.petmagic.test/thumb.jpg',
                  'media': {
                    'thumbnailUrl': 'https://cdn.petmagic.test/thumb.jpg',
                    'animatedPreviewUrl':
                        'https://cdn.petmagic.test/animated.webp',
                    'feedLoopLowUrl': 'https://cdn.petmagic.test/low.mp4',
                    'feedLoopMediumUrl': 'https://cdn.petmagic.test/medium.mp4',
                    'mediaKind': 'video',
                    'aspectRatio': null,
                    'durationMs': 4800,
                    'sizeBytes': 123456,
                    'dominantColor': '#123456',
                    'blurHash': 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
                    'mediaVersion': 43,
                  },
                  'mediaKind': 'video',
                  'durationMs': 4800,
                  'sizeBytes': 123456,
                  'version': 42,
                  'mediaVersion': 43,
                },
              ],
              'nextCursor': 'next-cursor',
              'hasMore': true,
              'generatedAtUtc': '2026-06-14T12:00:00Z',
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
      final dataSource = TemplatesRemoteDataSource(
        dio,
        runtimeInfo: const DefaultAppRuntimeInfo(
          locale: AppLocale(languageTag: 'ru-BY', countryCode: 'BY'),
        ),
      );

      final response = await dataSource.fetchFeed(
        const TemplatesQuery(
          type: TemplateType.video,
          category: ' Portrait ',
          search: ' magic ',
          cursor: 'cursor-1',
          page: 3,
          pageSize: 30,
        ),
      );

      expect(response.hasMore, isTrue);
      expect(response.nextCursor, 'next-cursor');
      final item = response.items.single;
      expect(item.templateId, 'template-video-1');
      expect(item.templateType, 'Video');
      expect(item.tokenCost, 17);
      expect(item.category, 'Portrait');
      expect(item.thumbnailUrl, 'https://cdn.petmagic.test/thumb.jpg');
      expect(
        item.animatedPreviewUrl,
        'https://cdn.petmagic.test/animated.webp',
      );
      expect(item.feedLoopLowUrl, 'https://cdn.petmagic.test/low.mp4');
      expect(item.feedLoopMediumUrl, 'https://cdn.petmagic.test/medium.mp4');
      expect(item.mediaKind, 'video');
      expect(item.durationMs, 4800);
      expect(item.sizeBytes, 123456);
      expect(item.mediaVersion, 43);
      expect(item.previewAsset?.url, 'https://cdn.petmagic.test/medium.mp4');
      expect(item.previewAsset?.contentType, 'video/mp4');
      expect(item.previewAsset?.durationSeconds, 4.8);
      expect(item.petPhotoRequirements, isEmpty);
      expect(item.version, 42);
      expect(item.updatedAtUtc, isNull);
      final domainItem = item.toDomain();
      expect(domainItem.templateType, TemplateType.video);
      expect(domainItem.tokenCost, 17);
      expect(domainItem.feedLoopLowUrl, 'https://cdn.petmagic.test/low.mp4');
      expect(
        domainItem.feedLoopMediumUrl,
        'https://cdn.petmagic.test/medium.mp4',
      );
      expect(domainItem.supportsGenerationResultInput, isFalse);
      expect(domainItem.requiredInputMediaType, isNull);
      expect(domainItem.recommendedAfterImageGeneration, isFalse);
      expect(domainItem.supportsGenerateSimilar, isTrue);
      expect(domainItem.defaultVariationStrength, 'medium');
      expect(capturedOptions?.path, '/api/templates/feed');
      expect(capturedOptions?.queryParameters, {
        'type': 'Video',
        'category': 'Portrait',
        'search': 'magic',
        'cursor': 'cursor-1',
        'take': 30,
        'locale': 'ru-BY',
      });
      expect(capturedOptions?.queryParameters, isNot(contains('page')));
      expect(capturedOptions?.queryParameters, isNot(contains('pageSize')));
    },
  );

  test(
    'fetchCatalogPage uses public paged catalog metadata endpoint',
    () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({
              'items': [
                {
                  'id': 'catalog-template-1',
                  'type': 'Image',
                  'title': 'Catalog portrait',
                  'category': 'Portrait',
                  'thumbnailUrl': 'https://cdn.petmagic.test/catalog-thumb.jpg',
                  'previewUrl': 'https://cdn.petmagic.test/catalog-thumb.jpg',
                  'priceTokens': 12,
                  'isPremium': false,
                  'tags': ['catalog', 'portrait'],
                  'version': 42,
                  'updatedAtUtc': '2026-06-15T12:00:00Z',
                },
              ],
              'page': 3,
              'pageSize': 100,
              'hasMore': true,
              'totalCount': 201,
              'generatedAtUtc': '2026-06-15T12:00:01Z',
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      final response = await dataSource.fetchCatalogPage(
        page: 3,
        pageSize: 100,
      );
      final item = response.items.single;

      expect(capturedOptions?.path, '/api/templates');
      expect(capturedOptions?.queryParameters, {'page': 3, 'pageSize': 100});
      expect(response.page, 3);
      expect(response.hasMore, isTrue);
      expect(item.templateId, 'catalog-template-1');
      expect(item.templateType, 'Image');
      expect(item.tokenCost, 12);
      expect(item.thumbnailUrl, 'https://cdn.petmagic.test/catalog-thumb.jpg');
      expect(
        item.previewAsset?.url,
        'https://cdn.petmagic.test/catalog-thumb.jpg',
      );
      expect(item.version, 42);
      expect(item.updatedAtUtc, DateTime.utc(2026, 6, 15, 12));
    },
  );

  test('fetchTemplateOfTheDay parses nullable public response', () async {
    RequestOptions? capturedOptions;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'template': {
              'templateId': 'template-day-1',
              'title': 'Hero pet',
              'subtitle': 'Today magic idea',
              'badgeText': 'Template of the Day',
              'type': 'Video',
              'thumbnailUrl': null,
              'previewMediaUrl': 'https://cdn.petmagic.test/day.mp4',
              'isPremium': true,
              'requiredPlan': 'premium',
              'date': '2026-06-14',
              'source': 'manual',
              'category': 'Portrait',
              'tags': ['daily', 'video'],
              'tokenCost': 12,
              'previewAsset': {
                'url': 'https://cdn.petmagic.test/day.mp4',
                'fileName': 'day.mp4',
                'contentType': 'video/mp4',
                'fileSizeBytes': 64000,
                'durationSeconds': 4.5,
              },
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplatesRemoteDataSource(
      dio,
      runtimeInfo: const DefaultAppRuntimeInfo(
        locale: AppLocale(languageTag: 'ru-BY', countryCode: 'BY'),
      ),
    );

    final response = await dataSource.fetchTemplateOfTheDay();
    final template = response.toDomain();

    expect(capturedOptions?.path, '/api/templates/template-of-the-day');
    expect(capturedOptions?.queryParameters, {'locale': 'ru-BY'});
    expect(template?.templateId, 'template-day-1');
    expect(template?.templateType, TemplateType.video);
    expect(template?.isPremium, isTrue);
    expect(template?.source, 'manual');
    expect(template?.date, DateTime.utc(2026, 6, 14));
    expect(template?.category, 'Portrait');
    expect(template?.tags, ['daily', 'video']);
    expect(template?.tokenCost, 12);
    expect(template?.previewAsset?.url, 'https://cdn.petmagic.test/day.mp4');
    expect(template?.previewAsset?.contentType, 'video/mp4');
  });

  test('fetchTemplateOfTheDay accepts missing template', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'template': null}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplatesRemoteDataSource(dio);

    final response = await dataSource.fetchTemplateOfTheDay();

    expect(response.toDomain(), isNull);
  });

  test(
    'fetchTemplate loads public detail without touching feed cache',
    () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({
              'templateId': 'template-detail-1',
              'templateType': 'Image',
              'title': 'Detail portrait',
              'shortDescription': 'Single public template',
              'category': 'Portrait',
              'tags': ['portrait'],
              'isPremium': false,
              'tokenCost': 12,
              'thumbnailUrl': 'https://cdn.petmagic.test/detail-thumb.jpg',
              'previewAsset': {
                'url': 'https://cdn.petmagic.test/detail-thumb.jpg',
                'fileName': 'detail-thumb.jpg',
                'contentType': 'image/jpeg',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      final response = await dataSource.fetchTemplate('template-detail-1');
      final template = response.toDomain();

      expect(capturedOptions?.path, '/api/templates/template-detail-1');
      expect(capturedOptions?.queryParameters, isEmpty);
      expect(template.templateId, 'template-detail-1');
      expect(
        template.thumbnailUrl,
        'https://cdn.petmagic.test/detail-thumb.jpg',
      );
      expect(
        template.previewAsset?.url,
        'https://cdn.petmagic.test/detail-thumb.jpg',
      );
    },
  );

  test('fetchTemplate encodes reserved template id path segment', () async {
    const templateId = 'template/detail 1?#fragment';
    RequestOptions? capturedOptions;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'templateId': templateId,
            'templateType': 'Image',
            'title': 'Reserved path detail',
            'shortDescription': 'Single public template',
            'category': 'Portrait',
            'tags': ['portrait'],
            'isPremium': false,
            'tokenCost': 12,
            'thumbnailUrl': 'https://cdn.petmagic.test/detail-thumb.jpg',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplatesRemoteDataSource(dio);

    final response = await dataSource.fetchTemplate(templateId);

    expect(
      capturedOptions?.path,
      '/api/templates/${Uri.encodeComponent(templateId)}',
    );
    expect(capturedOptions?.path, isNot(contains(templateId)));
    expect(capturedOptions?.queryParameters, isEmpty);
    expect(response.templateId, templateId);
  });

  test(
    'fetchRandomTemplate sends backend mode category and premium filters',
    () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({
              'template': {
                'templateId': 'template-random-video',
                'templateType': 'Video',
                'title': 'Random dance',
                'shortDescription': 'Backend selected template',
                'category': 'Dance',
                'tags': ['random', 'dance'],
                'isPremium': false,
                'tokenCost': 30,
                'thumbnailUrl': null,
                'previewAsset': {
                  'url': 'https://cdn.petmagic.test/random-dance.mp4',
                  'fileName': 'random-dance.mp4',
                  'contentType': 'video/mp4',
                  'durationSeconds': 5.2,
                },
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      final response = await dataSource.fetchRandomTemplate(
        mode: TemplateRandomMode.video,
        category: ' Dance ',
        includePremium: false,
      );
      final template = response.toDomain();

      expect(capturedOptions?.path, '/api/templates/random');
      expect(capturedOptions?.queryParameters, {
        'type': 'Video',
        'category': 'Dance',
        'includePremium': false,
      });
      expect(template?.templateId, 'template-random-video');
      expect(template?.templateType, TemplateType.video);
      expect(template?.previewAsset?.durationSeconds, 5.2);
    },
  );

  test(
    'fetchRandomTemplate omits type for all mode and accepts empty result',
    () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'template': null}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      final response = await dataSource.fetchRandomTemplate(
        mode: TemplateRandomMode.any,
        category: null,
        includePremium: true,
      );

      expect(capturedOptions?.path, '/api/templates/random');
      expect(capturedOptions?.queryParameters, {'includePremium': true});
      expect(response.toDomain(), isNull);
    },
  );

  test('fetchRandomTemplate sends strict premium access filter', () async {
    RequestOptions? capturedOptions;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({'template': null}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplatesRemoteDataSource(dio);

    await dataSource.fetchRandomTemplate(
      mode: TemplateRandomMode.image,
      category: 'Portrait',
      includePremium: false,
      access: TemplateRandomAccess.premium,
    );

    expect(capturedOptions?.path, '/api/templates/random');
    expect(capturedOptions?.queryParameters, {
      'type': 'Image',
      'category': 'Portrait',
      'includePremium': false,
      'access': 'premium',
    });
  });

  test(
    'cancelPendingRandomTemplateRequest cancels active random request',
    () async {
      final randomStarted = Completer<RequestOptions>();
      final randomCancelled = Completer<void>();

      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _CancellableFakeHttpClientAdapter((
          options,
          cancelFuture,
        ) async {
          randomStarted.complete(options);
          await cancelFuture;
          randomCancelled.complete();
          throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'hidden templates tab',
          );
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      final randomFuture = dataSource.fetchRandomTemplate(
        mode: TemplateRandomMode.video,
        category: 'Motion',
        includePremium: false,
      );
      final randomExpectation = expectLater(
        randomFuture,
        throwsA(isA<RequestCancelledException>()),
      );
      final startedOptions = await randomStarted.future;

      dataSource.cancelPendingRandomTemplateRequest();

      await randomCancelled.future;
      await randomExpectation;
      expect(startedOptions.path, '/api/templates/random');
      expect(startedOptions.queryParameters, {
        'type': 'Video',
        'category': 'Motion',
        'includePremium': false,
      });
    },
  );

  test(
    'cancelPendingMetadataRequests cancels active metadata requests',
    () async {
      final categoriesStarted = Completer<RequestOptions>();
      final categoriesCancelled = Completer<void>();
      final featuredStarted = Completer<RequestOptions>();
      final featuredCancelled = Completer<void>();

      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _CancellableFakeHttpClientAdapter((
          options,
          cancelFuture,
        ) async {
          switch (options.path) {
            case '/api/templates/categories':
              categoriesStarted.complete(options);
              await cancelFuture;
              categoriesCancelled.complete();
              throw DioException.requestCancelled(
                requestOptions: options,
                reason: 'hidden templates tab',
              );
            case '/api/templates/template-of-the-day':
              featuredStarted.complete(options);
              await cancelFuture;
              featuredCancelled.complete();
              throw DioException.requestCancelled(
                requestOptions: options,
                reason: 'hidden templates tab',
              );
            default:
              fail('Unexpected request path: ${options.path}');
          }
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      final categoriesFuture = dataSource.fetchCategories();
      final featuredFuture = dataSource.fetchTemplateOfTheDay();
      final categoriesExpectation = expectLater(
        categoriesFuture,
        throwsA(isA<RequestCancelledException>()),
      );
      final featuredExpectation = expectLater(
        featuredFuture,
        throwsA(isA<RequestCancelledException>()),
      );

      final categoriesOptions = await categoriesStarted.future;
      final featuredOptions = await featuredStarted.future;

      dataSource.cancelPendingMetadataRequests();

      await categoriesCancelled.future;
      await featuredCancelled.future;
      await categoriesExpectation;
      await featuredExpectation;
      expect(categoriesOptions.path, '/api/templates/categories');
      expect(featuredOptions.path, '/api/templates/template-of-the-day');
    },
  );

  test('recordAnalyticsEvent posts metadata payload', () async {
    RequestOptions? capturedOptions;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString('', 204);
      });
    final dataSource = TemplatesRemoteDataSource(dio);

    await dataSource.recordAnalyticsEvent(
      templateId: 'template-day-1',
      eventType: 'viewed',
      source: 'manual',
      generationId: 'generation-1',
      metadata: const <String, Object?>{
        'templateId': 'template-day-1',
        'type': 'video',
        'source': 'manual',
        'isPremium': true,
        'userPlan': 'free',
        'date': '2026-06-14',
        'screen': 'templates',
      },
    );

    expect(
      capturedOptions?.path,
      '/api/templates/template-day-1/analytics/events',
    );
    expect(capturedOptions?.data, {
      'eventType': 'viewed',
      'source': 'manual',
      'deviceClass': 'web',
      'generationId': 'generation-1',
      'metadata': {
        'templateId': 'template-day-1',
        'type': 'video',
        'source': 'manual',
        'isPremium': true,
        'userPlan': 'free',
        'date': '2026-06-14',
        'screen': 'templates',
      },
    });
  });

  test(
    'recordAnalyticsEvent encodes reserved template id path segment',
    () async {
      const templateId = 'template/day 1?#fragment';
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString('', 204);
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      await dataSource.recordAnalyticsEvent(
        templateId: templateId,
        eventType: 'viewed',
        source: 'manual',
      );

      expect(
        capturedOptions?.path,
        '/api/templates/${Uri.encodeComponent(templateId)}/analytics/events',
      );
      expect(capturedOptions?.path, isNot(contains(templateId)));
      expect(capturedOptions?.data, {
        'eventType': 'viewed',
        'source': 'manual',
        'deviceClass': 'web',
      });
    },
  );

  test(
    'recordAnalyticsEvent maps runtime platforms without sending locale country',
    () async {
      const expectedDeviceClasses = <AppRuntimePlatform, String>{
        AppRuntimePlatform.android: 'android',
        AppRuntimePlatform.ios: 'ios',
        AppRuntimePlatform.other: 'web',
      };

      for (final entry in expectedDeviceClasses.entries) {
        RequestOptions? capturedOptions;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
          ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
            capturedOptions = options;
            return ResponseBody.fromString('', 204);
          });
        final dataSource = TemplatesRemoteDataSource(
          dio,
          runtimeInfo: DefaultAppRuntimeInfo(
            locale: const AppLocale(languageTag: 'ru-BY', countryCode: 'BY'),
            platform: entry.key,
          ),
        );

        await dataSource.recordAnalyticsEvent(
          templateId: 'template-device-${entry.value}',
          eventType: 'viewed',
        );

        expect(capturedOptions?.data, {
          'eventType': 'viewed',
          'deviceClass': entry.value,
        });
      }
    },
  );

  test('fetchFeed cancels a superseded in-flight feed request', () async {
    final firstStarted = Completer<RequestOptions>();
    final firstCancelled = Completer<void>();
    final secondStarted = Completer<RequestOptions>();
    var requestCount = 0;

    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _CancellableFakeHttpClientAdapter((
        options,
        cancelFuture,
      ) async {
        requestCount++;
        if (requestCount == 1) {
          firstStarted.complete(options);
          await cancelFuture;
          firstCancelled.complete();
          throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'superseded templates feed request',
          );
        }

        secondStarted.complete(options);
        return ResponseBody.fromString(
          jsonEncode({
            'items': [
              {
                'templateId': 'latest-search-result',
                'templateType': 'Image',
                'title': 'Latest result',
                'shortDescription': 'Only latest query should complete',
                'category': 'Portrait',
                'tags': ['latest'],
                'isPremium': false,
                'tokenCost': 1,
              },
            ],
            'nextCursor': null,
            'hasMore': false,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplatesRemoteDataSource(dio);

    final firstFuture = dataSource.fetchFeed(
      const TemplatesQuery(search: 'cat'),
    );
    final firstExpectation = expectLater(
      firstFuture,
      throwsA(isA<RequestCancelledException>()),
    );
    await firstStarted.future;

    final secondFuture = dataSource.fetchFeed(
      const TemplatesQuery(search: 'dog'),
    );

    await firstCancelled.future;
    await firstExpectation;

    final secondResponse = await secondFuture;

    expect(requestCount, 2);
    expect((await secondStarted.future).queryParameters, {
      'search': 'dog',
      'take': 20,
    });
    expect(secondResponse.items.single.templateId, 'latest-search-result');
  });

  test('fetchFeed clears active cancel token after request failure', () async {
    final firstCancelObserved = Completer<void>();
    var requestCount = 0;

    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _CancellableFakeHttpClientAdapter((
        options,
        cancelFuture,
      ) async {
        requestCount++;
        if (requestCount == 1) {
          unawaited(
            cancelFuture?.then((_) {
                  if (!firstCancelObserved.isCompleted) {
                    firstCancelObserved.complete();
                  }
                }) ??
                Future<void>.value(),
          );
          throw DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 500,
              data: const {'message': 'templates.server_error'},
            ),
            type: DioExceptionType.badResponse,
          );
        }

        return ResponseBody.fromString(
          jsonEncode({
            'items': [
              {
                'templateId': 'recovered-result',
                'templateType': 'Image',
                'title': 'Recovered result',
                'shortDescription':
                    'Second request should not cancel old token',
                'category': 'Portrait',
                'tags': ['latest'],
                'isPremium': false,
                'tokenCost': 1,
              },
            ],
            'nextCursor': null,
            'hasMore': false,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplatesRemoteDataSource(dio);

    await expectLater(
      dataSource.fetchFeed(const TemplatesQuery(search: 'broken')),
      throwsA(isA<AppException>()),
    );

    final response = await dataSource.fetchFeed(
      const TemplatesQuery(search: 'recovered'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(requestCount, 2);
    expect(firstCancelObserved.isCompleted, isFalse);
    expect(response.items.single.templateId, 'recovered-result');
  });

  test(
    'fetchFeed treats nested cancelled app exception as request cancellation',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            message: 'Lifecycle aborted request',
            error: const AppException('request_cancelled'),
          );
        });
      final dataSource = TemplatesRemoteDataSource(dio);

      await expectLater(
        dataSource.fetchFeed(const TemplatesQuery(search: 'cancelled')),
        throwsA(isA<RequestCancelledException>()),
      );
    },
  );
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._handler);

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

class _CancellableFakeHttpClientAdapter implements HttpClientAdapter {
  _CancellableFakeHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Future<dynamic>? cancelFuture,
  )
  _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    return _handler(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
