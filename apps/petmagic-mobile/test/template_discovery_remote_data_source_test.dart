import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_remote_data_source.dart';

void main() {
  test('fetch uses discovery endpoint locale and parses feed cards', () async {
    RequestOptions? capturedOptions;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'sections': [
              {
                'category': 'Pet Mischief',
                'items': [
                  {
                    'id': 'template-video-1',
                    'type': 'Video',
                    'title': 'Night Road Flee',
                    'shortDescription': 'Pets on a night drive',
                    'category': {
                      'id': null,
                      'slug': 'pet-mischief',
                      'title': 'Pet Mischief',
                    },
                    'tags': ['pets', 'night'],
                    'isPremium': true,
                    'access': 'premium',
                    'tokenCost': 9,
                    'thumbnailUrl': 'https://cdn.petmagic.test/night-road.jpg',
                    'media': {
                      'thumbnailUrl':
                          'https://cdn.petmagic.test/night-road.jpg',
                      'feedLoopLowUrl':
                          'https://cdn.petmagic.test/night-road.mp4',
                      'mediaKind': 'video',
                      'durationMs': 3200,
                      'mediaVersion': 5,
                    },
                    'mediaKind': 'video',
                    'durationMs': 3200,
                    'version': 6,
                    'mediaVersion': 5,
                  },
                ],
              },
            ],
            'generatedAtUtc': '2026-09-04T06:00:00Z',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    final dataSource = TemplateDiscoveryRemoteDataSource(
      dio,
      runtimeInfo: const DefaultAppRuntimeInfo(
        locale: AppLocale(languageTag: 'ru-BY', countryCode: 'BY'),
      ),
    );

    final response = await dataSource.fetch();

    expect(capturedOptions?.path, '/api/templates/discovery');
    expect(capturedOptions?.queryParameters, {
      'locale': 'ru-BY',
      'sectionLimit': 24,
      'itemsPerSection': 12,
    });
    expect(response.generatedAtUtc, DateTime.utc(2026, 9, 4, 6));
    final section = response.sections.single;
    expect(section.category, 'Pet Mischief');
    final item = section.items.single;
    expect(item.templateId, 'template-video-1');
    expect(item.templateType, 'Video');
    expect(item.tokenCost, 9);
    expect(item.category, 'Pet Mischief');
    expect(item.feedLoopLowUrl, 'https://cdn.petmagic.test/night-road.mp4');
  });

  test('cancelPendingRequest maps an active Dio cancellation', () async {
    final requestStarted = Completer<RequestOptions>();
    final cancellationObserved = Completer<void>();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _CancellableFakeHttpClientAdapter((
        options,
        cancelFuture,
      ) async {
        requestStarted.complete(options);
        await cancelFuture;
        cancellationObserved.complete();
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'discovery lifecycle ended',
        );
      });
    final dataSource = TemplateDiscoveryRemoteDataSource(dio);

    final fetchExpectation = expectLater(
      dataSource.fetch(),
      throwsA(isA<RequestCancelledException>()),
    );
    final options = await requestStarted.future;

    dataSource.cancelPendingRequest();

    await cancellationObserved.future;
    await fetchExpectation;
    expect(options.path, '/api/templates/discovery');
  });

  test('fetch maps safe server problem details and status code', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        throw DioException(
          requestOptions: options,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 503,
            data: const {'title': 'templates.catalog_unavailable'},
          ),
          type: DioExceptionType.badResponse,
        );
      });
    final dataSource = TemplateDiscoveryRemoteDataSource(dio);

    await expectLater(
      dataSource.fetch(),
      throwsA(
        isA<AppException>()
            .having(
              (error) => error.message,
              'message',
              'templates.catalog_unavailable',
            )
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.cause, 'cause', isA<DioException>()),
      ),
    );
  });
}

final class _FakeHttpClientAdapter implements HttpClientAdapter {
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

final class _CancellableFakeHttpClientAdapter implements HttpClientAdapter {
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
