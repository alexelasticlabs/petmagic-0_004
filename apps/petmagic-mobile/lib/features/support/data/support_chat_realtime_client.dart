import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';

final supportChatRealtimeClientProvider = Provider<SupportChatRealtimeClient>((
  ref,
) {
  final client = SignalRSupportChatRealtimeClient(
    sessionStorage: ref.watch(authSessionStorageProvider),
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
  SignalRSupportChatRealtimeClient({required AuthSessionStorage sessionStorage})
    : _sessionStorage = sessionStorage;

  static const _conversationUpdatedEvent = 'conversation-updated';

  final AuthSessionStorage _sessionStorage;
  final StreamController<SupportChatRealtimeUpdate> _eventsController =
      StreamController<SupportChatRealtimeUpdate>.broadcast();

  HubConnection? _connection;
  bool _isConnecting = false;

  @override
  Stream<SupportChatRealtimeUpdate> get events => _eventsController.stream;

  @override
  Future<void> connect() async {
    final connection = _connection ??= _buildConnection();
    if (_isConnecting || connection.state == HubConnectionState.Connected) {
      return;
    }

    _isConnecting = true;
    try {
      if (connection.state == HubConnectionState.Disconnected) {
        await connection.start();
      }
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection != null &&
        connection.state != HubConnectionState.Disconnected) {
      await connection.stop();
    }
  }

  HubConnection _buildConnection() {
    final connection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiBaseUrl}/hubs/support-chat',
          options: HttpConnectionOptions(accessTokenFactory: _readAccessToken),
        )
        .withAutomaticReconnect()
        .build();

    connection.on(_conversationUpdatedEvent, _handleConversationUpdated);
    return connection;
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
