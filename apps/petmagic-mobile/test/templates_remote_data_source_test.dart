import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

void main() {
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
                  'templateId': 'template-video-1',
                  'templateType': 'Video',
                  'title': 'Magic portrait',
                  'shortDescription': 'Animated pet portrait',
                  'category': 'Portrait',
                  'effectivePromoBadge': 'Trending',
                  'tags': ['portrait', 'video'],
                  'isPremium': true,
                  'tokenCost': 25,
                  'previewAsset': {
                    'url': 'https://cdn.petmagic.test/preview.mp4',
                    'fileName': 'preview.mp4',
                    'contentType': 'video/mp4',
                    'fileSizeBytes': 123456,
                    'durationSeconds': 4.8,
                  },
                  'musicDescription': 'Soft cinematic loop',
                  'referenceVideoDurationSeconds': 4.8,
                  'petPhotoRequirements': [
                    'Full body visible',
                    'Pet facing camera',
                  ],
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
      final dataSource = TemplatesRemoteDataSource(dio);

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
      expect(item.previewAsset?.contentType, 'video/mp4');
      expect(item.previewAsset?.durationSeconds, 4.8);
      expect(item.petPhotoRequirements, [
        'Full body visible',
        'Pet facing camera',
      ]);
      expect(item.effectivePromoBadge, 'Trending');
      expect(item.toDomain().templateType, TemplateType.video);
      expect(capturedOptions?.path, '/api/templates/feed');
      expect(capturedOptions?.queryParameters, {
        'type': 'Video',
        'category': 'Portrait',
        'search': 'magic',
        'cursor': 'cursor-1',
        'take': 30,
      });
      expect(capturedOptions?.queryParameters, isNot(contains('page')));
      expect(capturedOptions?.queryParameters, isNot(contains('pageSize')));
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
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplatesRemoteDataSource(dio);

    final response = await dataSource.fetchTemplateOfTheDay();
    final template = response.toDomain();

    expect(capturedOptions?.path, '/api/templates/template-of-the-day');
    expect(template?.templateId, 'template-day-1');
    expect(template?.templateType, TemplateType.video);
    expect(template?.isPremium, isTrue);
    expect(template?.source, 'manual');
    expect(template?.date, DateTime.utc(2026, 6, 14));
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
