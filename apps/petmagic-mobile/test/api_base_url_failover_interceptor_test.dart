import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/api_base_url_failover_interceptor.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('does not replay unsafe requests across base URL failover', () async {
    final resolver = _FakeBaseUrlResolver(
      resolvedBaseUrl: 'https://api-primary.test',
      candidates: const [
        'https://api-primary.test',
        'https://api-secondary.test',
      ],
    );
    final seenBaseUrls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api-default.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        seenBaseUrls.add(options.baseUrl);
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'primary_down',
        );
      });
    dio.interceptors.add(
      ApiBaseUrlFailoverInterceptor(dio: dio, baseUrlResolver: resolver),
    );

    await expectLater(
      dio.post<void>(
        '/api/auth/refresh',
        data: const {'refreshToken': 'refresh-token'},
      ),
      throwsA(isA<DioException>()),
    );

    expect(seenBaseUrls, const ['https://api-primary.test']);
    expect(resolver.invalidatedBaseUrls, isEmpty);
  });

  test('replays safe GET requests across base URL failover', () async {
    final resolver = _FakeBaseUrlResolver(
      resolvedBaseUrl: 'https://api-primary.test',
      candidates: const [
        'https://api-primary.test',
        'https://api-secondary.test',
      ],
    );
    final seenBaseUrls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api-default.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        seenBaseUrls.add(options.baseUrl);
        if (options.baseUrl == 'https://api-primary.test') {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'primary_down',
          );
        }

        return ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    dio.interceptors.add(
      ApiBaseUrlFailoverInterceptor(dio: dio, baseUrlResolver: resolver),
    );

    final response = await dio.get<dynamic>('/api/templates');

    expect(response.statusCode, 200);
    expect(seenBaseUrls, const [
      'https://api-primary.test',
      'https://api-secondary.test',
    ]);
    expect(resolver.invalidatedBaseUrls, const ['https://api-primary.test']);
    expect(resolver.successfulBaseUrls, contains('https://api-secondary.test'));
  });

  test('preserves typed JSON maps while rewriting response URLs', () async {
    final resolver = _FakeBaseUrlResolver(
      resolvedBaseUrl: 'https://api.petgpt.app',
      candidates: const ['https://api.petgpt.app'],
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petgpt.app'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          '{"serverClientId":"web-client","nested":{"url":"http://localhost:5000/media/file.jpg"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    dio.interceptors.add(
      ApiBaseUrlFailoverInterceptor(dio: dio, baseUrlResolver: resolver),
    );

    final response = await dio.get<Map<String, dynamic>>(
      '/api/auth/external/google/mobile-config',
    );

    expect(response.data?['serverClientId'], 'web-client');
    expect(response.data?['nested'], isA<Map<String, dynamic>>());
    expect(
      (response.data?['nested'] as Map<String, dynamic>)['url'],
      'https://api.petgpt.app:5000/media/file.jpg',
    );
  });
}

class _FakeBaseUrlResolver extends ApiBaseUrlResolver {
  _FakeBaseUrlResolver({
    required this.resolvedBaseUrl,
    required this.candidates,
  });

  final String resolvedBaseUrl;
  final List<String> candidates;
  final List<String> invalidatedBaseUrls = <String>[];
  final List<String> successfulBaseUrls = <String>[];

  @override
  Future<String> resolveBaseUrl({bool forceRefresh = false}) async {
    return resolvedBaseUrl;
  }

  @override
  Future<List<String>> prioritizedCandidates() async {
    return candidates;
  }

  @override
  Future<void> invalidate(String baseUrl) async {
    invalidatedBaseUrls.add(baseUrl);
  }

  @override
  Future<void> markSuccessful(String baseUrl) async {
    successfulBaseUrls.add(baseUrl);
  }
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
