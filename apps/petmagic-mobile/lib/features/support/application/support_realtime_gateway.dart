import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportChatRealtimeUpdate {
  const SupportChatRealtimeUpdate({required this.conversationId});
  final String conversationId;
}

final supportChatRealtimeClientProvider = Provider<SupportChatRealtimeClient>((
  ref,
) {
  throw StateError(
    'SupportRealtimeGateway is not bound. Add the app composition overrides.',
  );
});

abstract interface class SupportRealtimeGateway {
  Stream<SupportChatRealtimeUpdate> get events;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> dispose();
}

/// Compatibility-facing application port retained for existing test doubles.
abstract interface class SupportChatRealtimeClient
    implements SupportRealtimeGateway {}
