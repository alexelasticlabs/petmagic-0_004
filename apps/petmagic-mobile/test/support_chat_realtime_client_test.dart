import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'support chat realtime disconnect keeps event stream reusable for next start',
    () async {
      final client = SignalRSupportChatRealtimeClient(
        sessionStorage: AuthSessionStorage(),
        apiBaseUrlResolver: ApiBaseUrlResolver(),
      );

      var streamClosed = false;
      final subscription = client.events.listen(
        (_) {},
        onDone: () {
          streamClosed = true;
        },
      );
      addTearDown(subscription.cancel);

      await client.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(streamClosed, isFalse);

      final secondSubscription = client.events.listen((_) {});
      addTearDown(secondSubscription.cancel);
    },
  );

  test('support chat realtime dispose closes the event stream', () async {
    final client = SignalRSupportChatRealtimeClient(
      sessionStorage: AuthSessionStorage(),
      apiBaseUrlResolver: ApiBaseUrlResolver(),
    );

    var streamClosed = false;
    final subscription = client.events.listen(
      (_) {},
      onDone: () {
        streamClosed = true;
      },
    );
    addTearDown(subscription.cancel);

    await client.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(streamClosed, isTrue);
  });

  test(
    'support chat realtime keeps active base URL on non-transport hub failures',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      });

      final resolver = _TrackingApiBaseUrlResolver([
        'http://${server.address.address}:${server.port}',
      ]);
      final client = SignalRSupportChatRealtimeClient(
        sessionStorage: AuthSessionStorage(),
        apiBaseUrlResolver: resolver,
      );
      addTearDown(client.dispose);

      try {
        await client.connect().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Expected: the hub endpoint is intentionally unauthorized.
      }

      expect(resolver.invalidatedBaseUrls, isEmpty);
      expect(resolver.successfulBaseUrls, isEmpty);
      expect(
        resolver.resolveBaseUrlCalls,
        0,
        reason:
            'connect should not re-probe the same host after a non-transport failure',
      );
    },
  );

  test(
    'support chat realtime invalidates base URL on negotiation failures',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      });

      final resolver = _TrackingApiBaseUrlResolver([
        'http://${server.address.address}:${server.port}',
      ]);
      final client = SignalRSupportChatRealtimeClient(
        sessionStorage: AuthSessionStorage(),
        apiBaseUrlResolver: resolver,
      );
      addTearDown(client.dispose);

      try {
        await client.connect().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Expected: the hub negotiation endpoint intentionally rejects the connection.
      }

      expect(resolver.invalidatedBaseUrls, [
        'http://${server.address.address}:${server.port}',
      ]);
      expect(resolver.successfulBaseUrls, isEmpty);
    },
  );
}

class _TrackingApiBaseUrlResolver extends ApiBaseUrlResolver {
  _TrackingApiBaseUrlResolver(this._candidates);

  final List<String> _candidates;
  final List<String> invalidatedBaseUrls = <String>[];
  final List<String> successfulBaseUrls = <String>[];
  int resolveBaseUrlCalls = 0;

  @override
  Future<List<String>> prioritizedCandidates() async => _candidates;

  @override
  Future<String> resolveBaseUrl({bool forceRefresh = false}) async {
    resolveBaseUrlCalls++;
    return _candidates.first;
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
