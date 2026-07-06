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
  static const _conversationIdMaxLength = 128;

  final AuthSessionStorage _sessionStorage;
  final ApiBaseUrlResolver _apiBaseUrlResolver;
  final Duration _requestTimeout;
  final StreamController<SupportChatRealtimeUpdate> _eventsController =
      StreamController<SupportChatRealtimeUpdate>.broadcast();

  HubConnection? _connection;
  String? _connectionBaseUrl;
  int _connectionVersion = 0;
  int _connectionHolders = 0;
  bool _isConnecting = false;
  bool _isDisposed = false;

  @override
  Stream<SupportChatRealtimeUpdate> get events => _eventsController.stream;

  @override
  Future<void> connect() async {
    if (_isDisposed) {
      return;
    }

    _connectionHolders++;
    if (_connectionHolders > 1) {
      return;
    }

    if (_isConnecting) {
      return;
    }

    _isConnecting = true;
    var connectionEstablished = false;
    final connectionVersion = ++_connectionVersion;
    try {
      final accessToken = await _readAccessToken();
      if (accessToken.isEmpty || _shouldAbortConnect(connectionVersion)) {
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
        if (_shouldAbortConnect(connectionVersion)) {
          return;
        }

        attemptedBaseUrls.add(baseUrl);
        try {
          final connection = await _buildOrReuseConnection(baseUrl);
          if (_shouldAbortConnect(connectionVersion)) {
            await _stopConnectionIfCurrent(connection);
            return;
          }

          if (connection.state == HubConnectionState.Disconnected) {
            await connection.start();
          }

          if (_shouldAbortConnect(connectionVersion)) {
            await _stopConnectionIfCurrent(connection);
            return;
          }

          await _apiBaseUrlResolver.markSuccessful(baseUrl);
          connectionEstablished = true;
          return;
        } catch (error) {
          if (_shouldAbortConnect(connectionVersion)) {
            return;
          }

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
      if (_shouldAbortConnect(connectionVersion)) {
        await _stopConnectionIfCurrent(fallbackConnection);
        return;
      }

      if (fallbackConnection.state == HubConnectionState.Disconnected) {
        await fallbackConnection.start();
        if (_shouldAbortConnect(connectionVersion)) {
          await _stopConnectionIfCurrent(fallbackConnection);
          return;
        }

        await _apiBaseUrlResolver.markSuccessful(fallbackBaseUrl);
        connectionEstablished = true;
        return;
      }

      if (lastError != null) {
        throw lastError;
      }

      throw StateError('Unable to establish support chat realtime connection.');
    } finally {
      _isConnecting = false;
      if (!connectionEstablished && _connectionHolders > 0) {
        _connectionHolders = 0;
      }
    }
  }

  @override
  Future<void> disconnect() async {
    if (_connectionHolders == 0) {
      return;
    }

    _connectionHolders--;
    if (_connectionHolders > 0) {
      return;
    }

    await _stopConnection();
  }

  Future<void> _stopConnection() async {
    _connectionVersion++;
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
    _connectionHolders = 0;
    await _stopConnection();
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

  bool _shouldAbortConnect(int connectionVersion) =>
      _isDisposed || connectionVersion != _connectionVersion;

  Future<void> _stopConnectionIfCurrent(HubConnection connection) async {
    if (identical(_connection, connection)) {
      _connection = null;
      _connectionBaseUrl = null;
    }

    if (connection.state != HubConnectionState.Disconnected) {
      await connection.stop();
    }
  }

  HubConnection _buildConnection(String baseUrl) {
    final connection = HubConnectionBuilder()
        .withUrl(
          _supportChatHubUrlForBaseUrl(baseUrl),
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
    if (_isDisposed || _connection == null || _eventsController.isClosed) {
      return;
    }

    if (arguments == null || arguments.isEmpty) {
      return;
    }

    final payload = arguments.first;
    if (payload is! Map) {
      return;
    }

    final conversationId = _normalizeConversationId(payload['conversationId']);
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }

    _eventsController.add(
      SupportChatRealtimeUpdate(conversationId: conversationId),
    );
  }

  String? _normalizeConversationId(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > _conversationIdMaxLength) {
      return null;
    }

    return normalized;
  }
}

String _supportChatHubUrlForBaseUrl(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(baseUrl, 'baseUrl', 'Invalid API base URL.');
  }

  final authority = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  return '${uri.scheme}://$authority/hubs/support-chat';
}
