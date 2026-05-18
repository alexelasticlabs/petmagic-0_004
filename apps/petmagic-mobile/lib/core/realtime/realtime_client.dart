import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final realtimeClientProvider = Provider<RealtimeClient>(
  (ref) => const NoopRealtimeClient(),
);
