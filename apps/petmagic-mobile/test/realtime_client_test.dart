import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      await _waitUntil(() => events.isNotEmpty);

      expect(events, isNotEmpty);

      events.clear();
      await client.disconnect();
      await _waitUntil(() => events.isNotEmpty);

      expect(events, isNotEmpty);

      events.clear();
      await client.disconnect();
      final eventsAfterFinalDisconnect = events.length;
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events.length, eventsAfterFinalDisconnect);

      final resumedEvents = <RealtimeEvent>[];
      final secondSubscription = client.events.listen(resumedEvents.add);
      addTearDown(secondSubscription.cancel);

      await client.connect();
      await _waitUntil(() => resumedEvents.isNotEmpty);

      expect(resumedEvents, isNotEmpty);
    },
  );

  test('polling realtime client uses disposable one-shot timers', () {
    final source = File(
      'lib/core/realtime/realtime_client.dart',
    ).readAsStringSync();

    expect(source, contains('void _scheduleNextPoll()'));
    expect(source, contains('Timer(interval, ()'));
    expect(source, isNot(contains('Timer.periodic')));
  });

  test(
    'server-sent events realtime client keeps active base URL on non-200 endpoint responses',
    () async {
      final resolver = _TrackingApiBaseUrlResolver(const [
        'https://api.example',
      ]);
      final client = ServerSentEventsRealtimeClient(
        apiBaseUrlResolver: resolver,
        sessionStorage: _StaticAuthSessionStorage(),
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
        sessionStorage: _StaticAuthSessionStorage(),
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
      onGetUrl: (_) async => _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(HttpStatus.ok),
      ),
    );

    ServerSentEventsRealtimeClient(
      apiBaseUrlResolver: _TrackingApiBaseUrlResolver(const [
        'https://api.example',
      ]),
      sessionStorage: _StaticAuthSessionStorage(),
      httpClient: httpClient,
      connectionTimeout: const Duration(seconds: 8),
    );

    expect(httpClient.connectionTimeout, const Duration(seconds: 8));
  });

  test(
    'server-sent events realtime client uses authenticated gallery stream',
    () async {
      Uri? requestedUri;
      _FakeHttpClientRequest? capturedRequest;
      final client = ServerSentEventsRealtimeClient(
        apiBaseUrlResolver: _TrackingApiBaseUrlResolver(const [
          'https://api.example',
        ]),
        sessionStorage: _StaticAuthSessionStorage(
          accessToken: 'access-token-1',
        ),
        httpClient: _FakeHttpClient(
          onGetUrl: (uri) async {
            requestedUri = uri;
            capturedRequest = _FakeHttpClientRequest(
              response: _FakeHttpClientResponse(HttpStatus.ok),
            );
            return capturedRequest!;
          },
        ),
        reconnectDelay: const Duration(hours: 1),
      );
      addTearDown(client.disconnect);

      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        requestedUri?.toString(),
        'https://api.example/api/templates/generations/events',
      );
      expect(
        capturedRequest?.headers.values[HttpHeaders.authorizationHeader],
        'Bearer access-token-1',
      );
    },
  );

  test(
    'server-sent events realtime client keeps event stream subscriptions across reconnects',
    () async {
      var requestCount = 0;
      final client = ServerSentEventsRealtimeClient(
        apiBaseUrlResolver: _TrackingApiBaseUrlResolver(const [
          'https://api.example',
        ]),
        sessionStorage: _StaticAuthSessionStorage(),
        httpClient: _FakeHttpClient(
          onGetUrl: (_) async {
            requestCount++;
            return _FakeHttpClientRequest(
              response: _FakeHttpClientResponse(
                HttpStatus.ok,
                body: 'event: templates.feed.invalidated\n\n',
              ),
            );
          },
        ),
        reconnectDelay: const Duration(hours: 1),
      );
      addTearDown(client.dispose);

      final events = <RealtimeEvent>[];
      final subscription = client.events.listen(events.add);
      addTearDown(subscription.cancel);

      await client.connect();
      await _waitUntil(() => events.length == 1);

      await client.disconnect();
      await client.connect();
      await _waitUntil(() => events.length == 2);

      expect(requestCount, 2);
      expect(
        events.map((event) => event.topic),
        everyElement(RealtimeTopics.templatesFeedInvalidated),
      );
    },
  );

  test(
    'server-sent events realtime client cancels active response on disconnect',
    () async {
      var requestCount = 0;
      final responseController = StreamController<List<int>>();
      final client = ServerSentEventsRealtimeClient(
        apiBaseUrlResolver: _TrackingApiBaseUrlResolver(const [
          'https://api.example',
        ]),
        sessionStorage: _StaticAuthSessionStorage(),
        httpClient: _FakeHttpClient(
          onGetUrl: (_) async {
            requestCount++;
            return _FakeHttpClientRequest(
              response: _FakeHttpClientResponse(
                HttpStatus.ok,
                stream: responseController.stream,
              ),
            );
          },
        ),
        reconnectDelay: const Duration(hours: 1),
      );
      addTearDown(() async {
        await client.dispose();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      });

      await client.connect();
      await _waitUntil(() => requestCount == 1);
      await _waitUntil(() => responseController.hasListener);

      await client.disconnect().timeout(const Duration(seconds: 1));

      expect(responseController.hasListener, isFalse);
    },
  );

  test(
    'server-sent events realtime client drops oversized event payloads',
    () async {
      var requestCount = 0;
      final client = ServerSentEventsRealtimeClient(
        apiBaseUrlResolver: _TrackingApiBaseUrlResolver(const [
          'https://api.example',
        ]),
        sessionStorage: _StaticAuthSessionStorage(),
        httpClient: _FakeHttpClient(
          onGetUrl: (_) async {
            requestCount++;
            return _FakeHttpClientRequest(
              response: _FakeHttpClientResponse(
                HttpStatus.ok,
                body:
                    'event: templates.feed.invalidated\n'
                    'data: ${'x' * 9000}\n\n',
              ),
            );
          },
        ),
        reconnectDelay: const Duration(hours: 1),
      );
      addTearDown(client.dispose);

      final events = <RealtimeEvent>[];
      final subscription = client.events.listen(events.add);
      addTearDown(subscription.cancel);

      await client.connect();
      await _waitUntil(() => requestCount == 1);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(events, isEmpty);
    },
  );

  test('server-sent events realtime logs safe base URL origin only', () {
    final source = File(
      'lib/core/realtime/realtime_client.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'base_url_origin': _realtimeLogSafeBaseUrlOrigin(baseUrl)"),
    );
    expect(
      source,
      contains('String _realtimeLogSafeBaseUrlOrigin(String baseUrl)'),
    );
    expect(source, contains("return 'invalid';"));
    expect(source, contains("return '\${uri.scheme}://\${uri.host}\$port';"));
    expect(source, isNot(contains("context: {'base_url': baseUrl}")));
  });

  test(
    'lifecycle realtime client disconnects in background and resumes',
    () async {
      final delegate = _RecordingRealtimeClient();
      final client = LifecycleAwareRealtimeClient(delegate);
      addTearDown(client.dispose);

      await client.connect();
      await client.connect();

      expect(delegate.connectCalls, 1);
      expect(delegate.disconnectCalls, 0);

      client.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      expect(delegate.disconnectCalls, 1);

      client.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(delegate.connectCalls, 2);

      await client.disconnect();
      expect(delegate.disconnectCalls, 1);

      await client.disconnect();
      expect(delegate.disconnectCalls, 2);
    },
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Condition was not met before timeout.');
    }

    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
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

class _RecordingRealtimeClient implements RealtimeClient {
  int connectCalls = 0;
  int disconnectCalls = 0;
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

class _StaticAuthSessionStorage extends AuthSessionStorage {
  _StaticAuthSessionStorage({this.accessToken = 'access-token'});

  final String accessToken;

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2026, 1, 2),
      user: MobileUserProfile(
        userId: 'user-1',
        email: 'user@example.test',
        displayName: 'User',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: false,
        legalAcceptance: MobileLegalAcceptanceStatus(
          termsOfUseAccepted: true,
          termsOfUseAcceptedVersion: '1',
          termsOfUseAcceptedAtUtc: DateTime.utc(2026),
          privacyPolicyAccepted: true,
          privacyPolicyAcceptedVersion: '1',
          privacyPolicyAcceptedAtUtc: DateTime.utc(2026),
          currentTermsOfUseVersion: '1',
          currentPrivacyPolicyVersion: '1',
          requiresAcceptance: false,
        ),
        roles: const ['User'],
        avatar: null,
      ),
    );
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
  _FakeHttpClientResponse(
    this.statusCode, {
    String body = '',
    Stream<List<int>>? stream,
  }) : _stream =
           stream ??
           Stream<List<int>>.fromIterable(
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
