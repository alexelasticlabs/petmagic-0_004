import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';

void main() {
  test(
    'refresh clears loading after unexpected failure and allows retry',
    () async {
      final repository = _FlakyRefreshSupportChatRepository();
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWithValue(repository),
          supportChatRealtimeClientProvider.overrideWithValue(
            const _NoopSupportChatRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(supportChatControllerProvider.notifier);

      await controller.refresh();

      var state = container.read(supportChatControllerProvider);
      expect(repository.getConversationCalls, 1);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.conversation, isNull);
      expect(state.errorMessage, 'support.unavailable');

      await controller.refresh();

      state = container.read(supportChatControllerProvider);
      expect(repository.getConversationCalls, 2);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.conversation?.conversationId, 'conversation-1');
    },
  );
}

class _FlakyRefreshSupportChatRepository extends SupportChatRepository {
  _FlakyRefreshSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int getConversationCalls = 0;

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) async {
    getConversationCalls += 1;
    if (getConversationCalls == 1) {
      throw StateError('socket closed');
    }

    return _conversation();
  }
}

class _NoopSupportChatRealtimeClient implements SupportChatRealtimeClient {
  const _NoopSupportChatRealtimeClient();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<SupportChatRealtimeUpdate> get events => const Stream.empty();
}

SupportChatConversation _conversation() {
  return SupportChatConversation(
    conversationId: 'conversation-1',
    initiatorUserId: 'user-1',
    userEmail: 'pet@example.com',
    userDisplayName: 'Pet Parent',
    assignedAdminId: null,
    assignedAdminDisplayName: null,
    status: 'Open',
    priority: 'Normal',
    source: 'MobileChat',
    userUnreadCount: 0,
    adminUnreadCount: 0,
    createdAtUtc: DateTime.utc(2026, 1, 1),
    updatedAtUtc: DateTime.utc(2026, 1, 1),
    lastMessageAtUtc: null,
    messages: const [],
  );
}
