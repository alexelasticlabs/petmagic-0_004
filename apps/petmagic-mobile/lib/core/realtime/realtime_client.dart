import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';

abstract final class RealtimeTopics {
  static const templatesFeedInvalidated = 'templates.feed.invalidated';
  static const templatesGenerationStatusChanged =
      'templates.generation.status_changed';
}

abstract interface class RealtimeClient {
  Stream<RealtimeEvent> get events;
  Future<void> connect();
  Future<void> disconnect();
}

class RealtimeEvent {
  const RealtimeEvent({required this.topic, this.payload = const {}});

  final String topic;
  final Map<String, Object?> payload;
}

class NoopRealtimeClient implements RealtimeClient {
  const NoopRealtimeClient();

  @override
  Stream<RealtimeEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}
}

class PollingRealtimeClient implements RealtimeClient {
  PollingRealtimeClient({
    this.interval = const Duration(seconds: 20),
    this.topics = const [RealtimeTopics.templatesFeedInvalidated],
  });

  final Duration interval;
  final List<String> topics;

  StreamController<RealtimeEvent>? _controller;
  Timer? _timer;
  bool _isConnected = false;

  @override
  Stream<RealtimeEvent> get events =>
      (_controller ??= StreamController<RealtimeEvent>.broadcast()).stream;

  @override
  Future<void> connect() async {
    if (_isConnected) {
      return;
    }

    _isConnected = true;
    final controller = _controller ??=
        StreamController<RealtimeEvent>.broadcast();
    _timer = Timer.periodic(interval, (_) {
      if (controller.isClosed) {
        return;
      }

      for (final topic in topics) {
        controller.add(RealtimeEvent(topic: topic));
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _isConnected = false;

    final controller = _controller;
    _controller = null;
    await controller?.close();
  }
}

class ServerSentEventsRealtimeClient implements RealtimeClient {
  ServerSentEventsRealtimeClient({
    required ApiBaseUrlResolver apiBaseUrlResolver,
    HttpClient? httpClient,
    this.reconnectDelay = const Duration(seconds: 3),
  }) : _apiBaseUrlResolver = apiBaseUrlResolver,
       _httpClient = httpClient;

  final ApiBaseUrlResolver _apiBaseUrlResolver;
  HttpClient? _httpClient;
  final Duration reconnectDelay;

  StreamController<RealtimeEvent>? _controller;
  Future<void>? _connectionLoop;
  Completer<void>? _stopSignal;

  @override
  Stream<RealtimeEvent> get events =>
      (_controller ??= StreamController<RealtimeEvent>.broadcast()).stream;

  @override
  Future<void> connect() async {
    if (_connectionLoop != null) {
      return;
    }

    _stopSignal = Completer<void>();
    _connectionLoop = _runConnectionLoop();
  }

  @override
  Future<void> disconnect() async {
    final stopSignal = _stopSignal;
    if (stopSignal != null && !stopSignal.isCompleted) {
      stopSignal.complete();
    }

    _httpClient?.close(force: true);
    _httpClient = null;

    final connectionLoop = _connectionLoop;
    _connectionLoop = null;
    _stopSignal = null;

    if (connectionLoop != null) {
      await connectionLoop;
    }

    final controller = _controller;
    _controller = null;
    await controller?.close();
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
    try {
      final httpClient = _httpClient ??= HttpClient();
      final request = await httpClient.getUrl(
        Uri.parse('$baseUrl/api/templates/events'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set('X-PetMagic-Client', 'mobile-flutter');

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        await _apiBaseUrlResolver.invalidate(baseUrl);
        return false;
      }

      await _apiBaseUrlResolver.markSuccessful(baseUrl);
      await _consumeResponse(response);
      return true;
    } catch (error, stackTrace) {
      _logRealtimeFailure(
        'connect',
        error,
        stackTrace,
        context: {'base_url': baseUrl},
      );
      await _apiBaseUrlResolver.invalidate(baseUrl);
      return false;
    }
  }

  Future<void> _consumeResponse(HttpClientResponse response) async {
    String? currentEvent;
    final dataLines = <String>[];

    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (_isStopping) {
        return;
      }

      if (line.isEmpty) {
        _dispatchEvent(currentEvent, dataLines);
        currentEvent = null;
        dataLines.clear();
        continue;
      }

      if (line.startsWith(':')) {
        continue;
      }

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    _dispatchEvent(currentEvent, dataLines);
  }

  void _dispatchEvent(String? eventName, List<String> dataLines) {
    final topic = eventName?.trim();
    if (topic == null || topic.isEmpty) {
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
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object>{'stage': stage};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        payload[entry.key] = value.toString();
      }
    }

    developer.Timeline.instantSync(
      'petmagic.realtime.error',
      arguments: payload,
    );
    developer.log(
      'ServerSentEventsRealtimeClient::$stage failed',
      name: 'PetMagic.Realtime',
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

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = ServerSentEventsRealtimeClient(
    apiBaseUrlResolver: ref.watch(apiBaseUrlResolverProvider),
  );
  ref.onDispose(() {
    unawaited(client.disconnect());
  });
  return client;
});
