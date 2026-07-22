part of 'realtime_client.dart';

class ServerSentEventsRealtimeClient implements RealtimeClient {
  ServerSentEventsRealtimeClient({
    required ApiBaseUrlResolver apiBaseUrlResolver,
    required AuthSessionStore sessionStorage,
    HttpClient? httpClient,
    this.reconnectDelay = const Duration(seconds: 3),
    Duration connectionTimeout = const Duration(seconds: 8),
  }) : _apiBaseUrlResolver = apiBaseUrlResolver,
       _sessionStorage = sessionStorage,
       _httpClient = httpClient,
       _ownsHttpClient = httpClient == null,
       _connectionTimeout = connectionTimeout {
    _httpClient?.connectionTimeout = connectionTimeout;
  }

  final ApiBaseUrlResolver _apiBaseUrlResolver;
  final AuthSessionStore _sessionStorage;
  HttpClient? _httpClient;
  final bool _ownsHttpClient;
  final Duration reconnectDelay;
  final Duration _connectionTimeout;

  static const _eventTopicMaxLength = 128;
  static const _eventPayloadMaxLength = 8192;

  StreamController<RealtimeEvent>? _controller;
  Future<void>? _connectionLoop;
  Completer<void>? _stopSignal;
  int _connectionHolders = 0;

  @override
  Stream<RealtimeEvent> get events =>
      (_controller ??= StreamController<RealtimeEvent>.broadcast()).stream;

  @override
  Future<void> connect() async {
    _connectionHolders++;
    if (_connectionLoop != null) {
      return;
    }

    _stopSignal = Completer<void>();
    _connectionLoop = _runConnectionLoop();
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

    await _stopTransport(closeEvents: false);
  }

  Future<void> dispose() async {
    _connectionHolders = 0;
    await _stopTransport(closeEvents: true);
  }

  Future<void> _stopTransport({required bool closeEvents}) async {
    final stopSignal = _stopSignal;
    if (stopSignal != null && !stopSignal.isCompleted) {
      stopSignal.complete();
    }

    if (_ownsHttpClient) {
      _httpClient?.close(force: true);
      _httpClient = null;
    }

    final connectionLoop = _connectionLoop;
    _connectionLoop = null;
    _stopSignal = null;

    if (connectionLoop != null) {
      await connectionLoop;
    }

    if (closeEvents) {
      final controller = _controller;
      _controller = null;
      await controller?.close();
    }
  }

  Future<void> _runConnectionLoop() async {
    while (!_isStopping) {
      final candidates = await _apiBaseUrlResolver.prioritizedCandidates();

      for (final baseUrl in candidates) {
        if (_isStopping) {
          return;
        }

        final connected = await _tryConnect(baseUrl);
        if (connected) {
          break;
        }
      }

      if (_isStopping) {
        return;
      }

      await _waitBeforeReconnect();
    }
  }

  Future<bool> _tryConnect(String baseUrl) async {
    final requestId = RequestIdentity.createRequestId();
    final correlationId = RequestIdentity.createCorrelationId();
    try {
      final accessToken = await _readAccessToken();
      if (accessToken.isEmpty) {
        return false;
      }

      final httpClient = _httpClient ??= (HttpClient()
        ..connectionTimeout = _connectionTimeout);
      final request = await httpClient.getUrl(
        Uri.parse('$baseUrl/api/templates/generations/events'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.headers.set('X-PetMagic-Client', 'mobile-flutter');
      request.headers.set('X-Request-ID', requestId);
      request.headers.set('X-Correlation-ID', correlationId);

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return false;
      }

      await _apiBaseUrlResolver.markSuccessful(baseUrl);
      await _consumeResponse(response);
      return true;
    } catch (error, stackTrace) {
      if (_isStopping) {
        return false;
      }

      _logRealtimeFailure(
        'connect',
        error,
        stackTrace,
        requestId: requestId,
        correlationId: correlationId,
        context: {'base_url_origin': _realtimeLogSafeBaseUrlOrigin(baseUrl)},
      );
      await _apiBaseUrlResolver.invalidate(baseUrl);
      return false;
    }
  }

  Future<String> _readAccessToken() async {
    final session = await _sessionStorage.read();
    return session?.accessToken ?? '';
  }

  Future<void> _consumeResponse(HttpClientResponse response) async {
    String? currentEvent;
    final dataLines = <String>[];
    var dataLength = 0;
    var discardCurrentEvent = false;

    final stopSignal = _stopSignal;
    final streamCompleted = Completer<void>();
    var completedByStream = false;
    late final StreamSubscription<String> subscription;

    void handleLine(String line) {
      if (_isStopping) {
        return;
      }

      if (line.isEmpty) {
        _dispatchEvent(
          currentEvent,
          dataLines,
          discardEvent: discardCurrentEvent,
        );
        currentEvent = null;
        dataLines.clear();
        dataLength = 0;
        discardCurrentEvent = false;
        return;
      }

      if (line.startsWith(':')) {
        return;
      }

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        return;
      }

      if (line.startsWith('data:')) {
        final dataLine = line.substring(5).trimLeft();
        dataLength += dataLine.length + (dataLines.isEmpty ? 0 : 1);
        if (dataLength > _eventPayloadMaxLength) {
          discardCurrentEvent = true;
          dataLines.clear();
          return;
        }

        if (!discardCurrentEvent) {
          dataLines.add(dataLine);
        }
      }
    }

    subscription = response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            try {
              handleLine(line);
            } catch (error, stackTrace) {
              if (!streamCompleted.isCompleted) {
                streamCompleted.completeError(error, stackTrace);
              }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!streamCompleted.isCompleted) {
              streamCompleted.completeError(error, stackTrace);
            }
          },
          onDone: () {
            completedByStream = true;
            if (!streamCompleted.isCompleted) {
              streamCompleted.complete();
            }
          },
          cancelOnError: true,
        );

    try {
      await Future.any<void>([
        streamCompleted.future,
        if (stopSignal != null) stopSignal.future,
      ]);
    } finally {
      await subscription.cancel();
    }

    if (completedByStream && !_isStopping) {
      _dispatchEvent(
        currentEvent,
        dataLines,
        discardEvent: discardCurrentEvent,
      );
    }
  }

  void _dispatchEvent(
    String? eventName,
    List<String> dataLines, {
    required bool discardEvent,
  }) {
    if (discardEvent) {
      return;
    }

    final topic = eventName?.trim();
    if (topic == null || topic.isEmpty || topic.length > _eventTopicMaxLength) {
      return;
    }

    final controller = _controller;
    if (controller == null || controller.isClosed) {
      return;
    }

    controller.add(
      RealtimeEvent(topic: topic, payload: _parsePayload(dataLines.join('\n'))),
    );
  }

  Map<String, Object?> _parsePayload(String rawPayload) {
    if (rawPayload.trim().isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value as Object?),
        );
      }
    } catch (error, stackTrace) {
      _logRealtimeFailure(
        'parse_payload',
        error,
        stackTrace,
        context: {'payload_length': rawPayload.length},
      );
    }

    return const {};
  }

  void _logRealtimeFailure(
    String stage,
    Object error,
    StackTrace stackTrace, {
    String? requestId,
    String? correlationId,
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object>{'stage': stage};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        payload[entry.key] = value.toString();
      }
    }

    AppLogger.warn(
      feature: 'Realtime',
      operation: stage,
      message: 'Realtime client step failed',
      requestId: requestId,
      correlationId: correlationId,
      context: payload,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> _waitBeforeReconnect() async {
    final stopSignal = _stopSignal;
    if (stopSignal == null) {
      return;
    }

    await Future.any<void>([
      Future<void>.delayed(reconnectDelay),
      stopSignal.future,
    ]);
  }

  bool get _isStopping => _stopSignal?.isCompleted ?? true;
}

String _realtimeLogSafeBaseUrlOrigin(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'invalid';
  }

  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}
