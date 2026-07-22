import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';

part 'polling_realtime_client.part.dart';
part 'server_sent_events_realtime_client.part.dart';

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

class LifecycleAwareRealtimeClient
    with WidgetsBindingObserver
    implements RealtimeClient {
  LifecycleAwareRealtimeClient(this._delegate) {
    WidgetsBinding.instance.addObserver(this);
  }

  final RealtimeClient _delegate;
  int _connectionHolders = 0;
  bool _isForeground = true;

  @override
  Stream<RealtimeEvent> get events => _delegate.events;

  @override
  Future<void> connect() async {
    _connectionHolders++;
    if (_connectionHolders > 1 || !_isForeground) {
      return;
    }

    await _delegate.connect();
  }

  @override
  Future<void> disconnect() async {
    if (_connectionHolders == 0) {
      return;
    }

    _connectionHolders--;
    if (_connectionHolders > 0 || !_isForeground) {
      return;
    }

    await _delegate.disconnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextIsForeground = state == AppLifecycleState.resumed;
    if (nextIsForeground == _isForeground) {
      return;
    }

    _isForeground = nextIsForeground;
    if (_connectionHolders == 0) {
      return;
    }

    if (_isForeground) {
      unawaited(_delegate.connect());
    } else {
      unawaited(_delegate.disconnect());
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _connectionHolders = 0;
    if (_delegate case final ServerSentEventsRealtimeClient client) {
      await client.dispose();
      return;
    }

    await _delegate.disconnect();
  }
}

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = LifecycleAwareRealtimeClient(
    ServerSentEventsRealtimeClient(
      apiBaseUrlResolver: ref.watch(apiBaseUrlResolverProvider),
      sessionStorage: ref.watch(authSessionStorageProvider),
    ),
  );
  ref.onDispose(() {
    unawaited(client.dispose());
  });
  return client;
});
