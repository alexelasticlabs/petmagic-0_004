import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:signalr_netcore/ihub_protocol.dart';

final supportChatRealtimeClientProvider = Provider<SupportChatRealtimeClient>((
  ref,
) {
  final client = SignalRSupportChatRealtimeClient(
    sessionStorage: ref.watch(authSessionStorageProvider),
    apiBaseUrlResolver: ref.watch(apiBaseUrlResolverProvider),
  );
  ref.onDispose(() {
    unawaited(client.disconnect());
  });
  return client;
});

class SupportChatRealtimeUpdate {
  const SupportChatRealtimeUpdate({required this.conversationId});

  final String conversationId;
}

abstract interface class SupportChatRealtimeClient {
  Stream<SupportChatRealtimeUpdate> get events;
  Future<void> connect();
  Future<void> disconnect();
}

class SignalRSupportChatRealtimeClient implements SupportChatRealtimeClient {
  SignalRSupportChatRealtimeClient({
    required AuthSessionStorage sessionStorage,
    required ApiBaseUrlResolver apiBaseUrlResolver,
  }) : _sessionStorage = sessionStorage,
       _apiBaseUrlResolver = apiBaseUrlResolver;

  static const _conversationUpdatedEvent = 'conversation-updated';

  final AuthSessionStorage _sessionStorage;
  final ApiBaseUrlResolver _apiBaseUrlResolver;
  final StreamController<SupportChatRealtimeUpdate> _eventsController =
      StreamController<SupportChatRealtimeUpdate>.broadcast();

  HubConnection? _connection;
  String? _connectionBaseUrl;
  bool _isConnecting = false;

  @override
  Stream<SupportChatRealtimeUpdate> get events => _eventsController.stream;

  @override
  Future<void> connect() async {
    if (_isConnecting) {
      return;
    }

    _isConnecting = true;
    try {
      final candidates = [...await _apiBaseUrlResolver.prioritizedCandidates()];
      final active = _apiBaseUrlResolver.activeBaseUrl;
      if (active != null && !candidates.contains(active)) {
        candidates.insert(0, active);
      }

      Object? lastError;
      for (final baseUrl in candidates) {
        try {
          final connection = await _buildOrReuseConnection(baseUrl);
          if (connection.state == HubConnectionState.Disconnected) {
            await connection.start();
          }

          await _apiBaseUrlResolver.markSuccessful(baseUrl);
          return;
        } catch (error) {
          lastError = error;
          await _apiBaseUrlResolver.invalidate(baseUrl);
        }
      }

      final fallbackBaseUrl = await _apiBaseUrlResolver.resolveBaseUrl(
        forceRefresh: true,
      );
      final fallbackConnection = await _buildOrReuseConnection(fallbackBaseUrl);
      if (fallbackConnection.state == HubConnectionState.Disconnected) {
        await fallbackConnection.start();
        await _apiBaseUrlResolver.markSuccessful(fallbackBaseUrl);
        return;
      }

      if (lastError is Exception) {
        throw lastError;
      }

      throw StateError('Unable to establish support chat realtime connection.');
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    _connectionBaseUrl = null;
    if (connection != null &&
        connection.state != HubConnectionState.Disconnected) {
      await connection.stop();
    }
  }

  Future<HubConnection> _buildOrReuseConnection(String baseUrl) async {
    final existingConnection = _connection;
    if (existingConnection != null && _connectionBaseUrl == baseUrl) {
      return existingConnection;
    }

    if (existingConnection != null &&
        existingConnection.state != HubConnectionState.Disconnected) {
      await existingConnection.stop();
    }

    final connection = _buildConnection(baseUrl);
    _connection = connection;
    _connectionBaseUrl = baseUrl;
    return connection;
  }

  HubConnection _buildConnection(String baseUrl) {
    final connection = HubConnectionBuilder()
        .withUrl(
          '$baseUrl/hubs/support-chat',
          options: HttpConnectionOptions(
            accessTokenFactory: _readAccessToken,
            headers: _buildConnectionHeaders(),
          ),
        )
        .withAutomaticReconnect()
        .build();

    connection.on(_conversationUpdatedEvent, _handleConversationUpdated);
    return connection;
  }

  MessageHeaders _buildConnectionHeaders() {
    final headers = MessageHeaders();
    headers.setHeaderValue('X-PetMagic-Client', 'mobile-flutter');
    headers.setHeaderValue('X-Request-ID', RequestIdentity.createRequestId());
    headers.setHeaderValue(
      'X-Correlation-ID',
      RequestIdentity.createCorrelationId(),
    );
    return headers;
  }

  Future<String> _readAccessToken() async {
    final session = await _sessionStorage.read();
    return session?.accessToken ?? '';
  }

  void _handleConversationUpdated(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return;
    }

    final payload = arguments.first;
    if (payload is! Map) {
      return;
    }

    final conversationId = payload['conversationId']?.toString();
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }

    _eventsController.add(
      SupportChatRealtimeUpdate(conversationId: conversationId),
    );
  }
}
