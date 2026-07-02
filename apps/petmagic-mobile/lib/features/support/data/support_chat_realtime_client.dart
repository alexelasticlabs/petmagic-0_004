import 'dart:async';
import 'dart:io';

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
    unawaited(client.dispose());
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
  Future<void> dispose();
}

class SignalRSupportChatRealtimeClient implements SupportChatRealtimeClient {
  SignalRSupportChatRealtimeClient({
    required AuthSessionStorage sessionStorage,
    required ApiBaseUrlResolver apiBaseUrlResolver,
    Duration requestTimeout = const Duration(seconds: 8),
  }) : _sessionStorage = sessionStorage,
       _apiBaseUrlResolver = apiBaseUrlResolver,
       _requestTimeout = requestTimeout;

  static const _conversationUpdatedEvent = 'conversation-updated';

  final AuthSessionStorage _sessionStorage;
  final ApiBaseUrlResolver _apiBaseUrlResolver;
  final Duration _requestTimeout;
  final StreamController<SupportChatRealtimeUpdate> _eventsController =
      StreamController<SupportChatRealtimeUpdate>.broadcast();

  HubConnection? _connection;
  String? _connectionBaseUrl;
  bool _isConnecting = false;
  bool _isDisposed = false;

  @override
  Stream<SupportChatRealtimeUpdate> get events => _eventsController.stream;

  @override
  Future<void> connect() async {
    if (_isDisposed) {
      return;
    }

    if (_isConnecting) {
      return;
    }

    _isConnecting = true;
    try {
      final accessToken = await _readAccessToken();
      if (accessToken.isEmpty) {
        return;
      }

      final candidates = [...await _apiBaseUrlResolver.prioritizedCandidates()];
      final active = _apiBaseUrlResolver.activeBaseUrl;
      if (active != null && !candidates.contains(active)) {
        candidates.insert(0, active);
      }

      Object? lastError;
      final attemptedBaseUrls = <String>{};
      var hasRetriableTransportFailure = false;
      for (final baseUrl in candidates) {
        attemptedBaseUrls.add(baseUrl);
        try {
          final connection = await _buildOrReuseConnection(baseUrl);
          if (connection.state == HubConnectionState.Disconnected) {
            await connection.start();
          }

          await _apiBaseUrlResolver.markSuccessful(baseUrl);
          return;
        } catch (error) {
          lastError = error;
          final shouldInvalidate = _shouldInvalidateBaseUrlOnConnectFailure(
            error,
          );
          if (shouldInvalidate) {
            hasRetriableTransportFailure = true;
            await _apiBaseUrlResolver.invalidate(baseUrl);
          }
        }
      }

      if (attemptedBaseUrls.isNotEmpty && !hasRetriableTransportFailure) {
        if (lastError != null) {
          throw lastError;
        }

        throw StateError(
          'Unable to establish support chat realtime connection.',
        );
      }

      final fallbackBaseUrl = await _apiBaseUrlResolver.resolveBaseUrl(
        forceRefresh: true,
      );
      if (attemptedBaseUrls.contains(fallbackBaseUrl)) {
        if (lastError != null) {
          throw lastError;
        }

        throw StateError(
          'Unable to establish support chat realtime connection.',
        );
      }

      final fallbackConnection = await _buildOrReuseConnection(fallbackBaseUrl);
      if (fallbackConnection.state == HubConnectionState.Disconnected) {
        await fallbackConnection.start();
        await _apiBaseUrlResolver.markSuccessful(fallbackBaseUrl);
        return;
      }

      if (lastError != null) {
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

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    await disconnect();
    if (!_eventsController.isClosed) {
      await _eventsController.close();
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
            requestTimeout: _requestTimeout.inMilliseconds,
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

  bool _shouldInvalidateBaseUrlOnConnectFailure(Object error) {
    if (error is SocketException ||
        error is HandshakeException ||
        error is TlsException ||
        error is TimeoutException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    final statusCodeMatch = RegExp(r'^(\d{3}):').firstMatch(message);
    if (statusCodeMatch != null) {
      final statusCode = int.tryParse(statusCodeMatch.group(1)!);
      if (statusCode == 401 || statusCode == 403) {
        return false;
      }
      if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
        return false;
      }
      if (statusCode == 400 || statusCode == 404) {
        return true;
      }
    }

    return message.contains('socketexception') ||
        message.contains('connection refused') ||
        message.contains('network is unreachable') ||
        message.contains('timed out');
  }

  void _handleConversationUpdated(List<Object?>? arguments) {
    if (_eventsController.isClosed) {
      return;
    }

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
