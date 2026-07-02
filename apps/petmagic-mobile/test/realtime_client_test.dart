import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'polling realtime client keeps polling until the last consumer disconnects',
    () async {
      final client = PollingRealtimeClient(
        interval: const Duration(milliseconds: 15),
      );
      addTearDown(client.disconnect);

      final events = <RealtimeEvent>[];
      final firstSubscription = client.events.listen(events.add);
      addTearDown(firstSubscription.cancel);

      await client.connect();
      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events, isNotEmpty);

      events.clear();
      await client.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events, isNotEmpty);

      events.clear();
      await client.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events, isEmpty);

      final resumedEvents = <RealtimeEvent>[];
      final secondSubscription = client.events.listen(resumedEvents.add);
      addTearDown(secondSubscription.cancel);

      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(resumedEvents, isNotEmpty);
    },
  );

  test(
    'server-sent events realtime client keeps active base URL on non-200 endpoint responses',
    () async {
      final resolver = _TrackingApiBaseUrlResolver(const [
        'https://api.example',
      ]);
      final client = ServerSentEventsRealtimeClient(
        apiBaseUrlResolver: resolver,
        httpClient: _FakeHttpClient(
          onGetUrl: (_) async => _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(HttpStatus.unauthorized),
          ),
        ),
        reconnectDelay: const Duration(hours: 1),
      );
      addTearDown(client.disconnect);

      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(resolver.invalidatedBaseUrls, isEmpty);
      expect(resolver.successfulBaseUrls, isEmpty);
    },
  );

  test(
    'server-sent events realtime client invalidates base URL on transport failures',
    () async {
      final resolver = _TrackingApiBaseUrlResolver(const [
        'https://api.example',
      ]);
      final client = ServerSentEventsRealtimeClient(
        apiBaseUrlResolver: resolver,
        httpClient: _FakeHttpClient(
          onGetUrl: (_) async => _FakeHttpClientRequest(
            closeError: const SocketException('network down'),
          ),
        ),
        reconnectDelay: const Duration(hours: 1),
      );
      addTearDown(client.disconnect);

      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(resolver.invalidatedBaseUrls, ['https://api.example']);
      expect(resolver.successfulBaseUrls, isEmpty);
    },
  );

  test('server-sent events realtime client configures transport timeout', () {
    final httpClient = _FakeHttpClient(
      onGetUrl: (_) async =>
          _FakeHttpClientRequest(response: _FakeHttpClientResponse(HttpStatus.ok)),
    );

    ServerSentEventsRealtimeClient(
      apiBaseUrlResolver: _TrackingApiBaseUrlResolver(const ['https://api.example']),
      httpClient: httpClient,
      connectionTimeout: const Duration(seconds: 8),
    );

    expect(httpClient.connectionTimeout, const Duration(seconds: 8));
  });
}

class _TrackingApiBaseUrlResolver extends ApiBaseUrlResolver {
  _TrackingApiBaseUrlResolver(this._candidates);

  final List<String> _candidates;
  final List<String> invalidatedBaseUrls = <String>[];
  final List<String> successfulBaseUrls = <String>[];

  @override
  Future<List<String>> prioritizedCandidates() async => _candidates;

  @override
  Future<void> invalidate(String baseUrl) async {
    invalidatedBaseUrls.add(baseUrl);
  }

  @override
  Future<void> markSuccessful(String baseUrl) async {
    successfulBaseUrls.add(baseUrl);
  }
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({required this.onGetUrl});

  final Future<_FakeHttpClientRequest> Function(Uri uri) onGetUrl;
  bool closed = false;
  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => onGetUrl(url);

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({this.response, this.closeError});

  @override
  final _FakeHttpHeaders headers = _FakeHttpHeaders();
  final HttpClientResponse? response;
  final Object? closeError;

  @override
  Future<HttpClientResponse> close() async {
    final closeError = this.closeError;
    if (closeError != null) {
      throw closeError;
    }

    return response ?? _FakeHttpClientResponse(HttpStatus.ok);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, Object> values = <String, Object>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, {String body = ''})
    : _stream = Stream<List<int>>.fromIterable(
        body.isEmpty ? const <List<int>>[] : [utf8.encode(body)],
      );

  @override
  final int statusCode;
  final Stream<List<int>> _stream;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
