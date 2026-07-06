import 'dart:io';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
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
    'support chat realtime skips hub connect when auth session is missing',
    () async {
      final resolver = _TrackingApiBaseUrlResolver(const [
        'http://127.0.0.1:5000',
      ]);
      final client = SignalRSupportChatRealtimeClient(
        sessionStorage: AuthSessionStorage(
          secureStorage: _FakeSecureStorage(<String, String>{}),
        ),
        apiBaseUrlResolver: resolver,
      );
      addTearDown(client.dispose);

      await client.connect();

      expect(resolver.prioritizedCandidatesCalls, 0);
      expect(resolver.invalidatedBaseUrls, isEmpty);
      expect(resolver.successfulBaseUrls, isEmpty);
      expect(resolver.resolveBaseUrlCalls, 0);
    },
  );

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
        sessionStorage: _sessionStorageWithTokens(),
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
        sessionStorage: _sessionStorageWithTokens(),
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

  test(
    'support chat realtime configures non-default negotiate timeout',
    () async {
      final source = await File(
        'lib/features/support/data/support_chat_realtime_client.dart',
      ).readAsString();

      expect(
        source,
        contains('Duration requestTimeout = const Duration(seconds: 8)'),
      );
      expect(
        source,
        contains('requestTimeout: _requestTimeout.inMilliseconds'),
      );
    },
  );

  test('support chat realtime builds hub URL from safe base origin', () async {
    final source = await File(
      'lib/features/support/data/support_chat_realtime_client.dart',
    ).readAsString();

    expect(source, contains('_supportChatHubUrlForBaseUrl(baseUrl)'));
    expect(
      source,
      contains('String _supportChatHubUrlForBaseUrl(String baseUrl)'),
    );
    expect(source, contains('Uri.tryParse(baseUrl.trim())'));
    expect(source, contains("'Invalid API base URL.'"));
    expect(
      source,
      contains("return '\${uri.scheme}://\$authority/hubs/support-chat';"),
    );
    expect(source, isNot(contains("'\$baseUrl/hubs/support-chat'")));
  });

  test(
    'support chat realtime validates hub conversation ids before dispatch',
    () async {
      final source = await File(
        'lib/features/support/data/support_chat_realtime_client.dart',
      ).readAsString();

      expect(source, contains('static const _conversationIdMaxLength = 128;'));
      expect(
        source,
        contains(
          'if (_isDisposed || _connection == null || _eventsController.isClosed)',
        ),
      );
      expect(
        source,
        contains(
          "final conversationId = _normalizeConversationId(payload['conversationId']);",
        ),
      );
      expect(
        source,
        contains('String? _normalizeConversationId(Object? value)'),
      );
      expect(source, contains('if (value is! String) {'));
      expect(
        source,
        contains(
          'normalized.isEmpty || normalized.length > _conversationIdMaxLength',
        ),
      );
      expect(source, isNot(contains("payload['conversationId']?.toString()")));
    },
  );

  test(
    'support chat realtime aborts stale connect attempts after disconnect or dispose',
    () async {
      final source = await File(
        'lib/features/support/data/support_chat_realtime_client.dart',
      ).readAsString();

      expect(source, contains('int _connectionVersion = 0;'));
      expect(
        source,
        contains('final connectionVersion = ++_connectionVersion;'),
      );
      expect(
        source,
        contains(
          'if (accessToken.isEmpty || _shouldAbortConnect(connectionVersion))',
        ),
      );
      expect(source, contains('_connectionVersion++;'));
      expect(
        source,
        contains('bool _shouldAbortConnect(int connectionVersion) =>'),
      );
      expect(
        source,
        contains('_isDisposed || connectionVersion != _connectionVersion'),
      );
      expect(
        source,
        contains(
          'Future<void> _stopConnectionIfCurrent(HubConnection connection)',
        ),
      );
      expect(source, contains('await _stopConnectionIfCurrent(connection);'));
      expect(
        source,
        contains('await _stopConnectionIfCurrent(fallbackConnection);'),
      );
    },
  );

  test(
    'support chat realtime keeps shared connection until last holder disconnects',
    () async {
      final source = await File(
        'lib/features/support/data/support_chat_realtime_client.dart',
      ).readAsString();

      expect(source, contains('int _connectionHolders = 0;'));
      expect(source, contains('_connectionHolders++;'));
      expect(source, contains('if (_connectionHolders > 1) {'));
      expect(source, contains('var connectionEstablished = false;'));
      expect(source, contains('connectionEstablished = true;'));
      expect(
        source,
        contains('if (!connectionEstablished && _connectionHolders > 0) {'),
      );
      expect(source, contains('if (_connectionHolders == 0) {'));
      expect(source, contains('_connectionHolders--;'));
      expect(source, contains('if (_connectionHolders > 0) {'));
      expect(source, contains('await _stopConnection();'));
      expect(source, contains('_connectionHolders = 0;'));
      expect(
        source,
        isNot(
          contains(
            'Future<void> disconnect() async {\n    _connectionVersion++;',
          ),
        ),
      );
    },
  );
}

class _TrackingApiBaseUrlResolver extends ApiBaseUrlResolver {
  _TrackingApiBaseUrlResolver(this._candidates);

  final List<String> _candidates;
  final List<String> invalidatedBaseUrls = <String>[];
  final List<String> successfulBaseUrls = <String>[];
  int prioritizedCandidatesCalls = 0;
  int resolveBaseUrlCalls = 0;

  @override
  Future<List<String>> prioritizedCandidates() async {
    prioritizedCandidatesCalls++;
    return _candidates;
  }

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

AuthSessionStorage _sessionStorageWithTokens() {
  return AuthSessionStorage(
    secureStorage: _FakeSecureStorage({
      AuthSessionStorage.sessionKey: jsonEncode(_session.toJson()),
    }),
  );
}

final _session = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresAtUtc: DateTime.utc(2035),
  user: const MobileUserProfile(
    userId: 'user-1',
    email: 'pet@example.com',
    displayName: 'Pet Parent',
    isPremium: false,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: MobileLegalAcceptanceStatus(
      termsOfUseAccepted: true,
      termsOfUseAcceptedVersion: '1',
      termsOfUseAcceptedAtUtc: null,
      privacyPolicyAccepted: true,
      privacyPolicyAcceptedVersion: '1',
      privacyPolicyAcceptedAtUtc: null,
      currentTermsOfUseVersion: '1',
      currentPrivacyPolicyVersion: '1',
      requiresAcceptance: false,
    ),
    roles: ['User'],
    avatar: null,
  ),
);

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage(this.values);

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }
}
