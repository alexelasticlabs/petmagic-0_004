import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';

import 'support_chat_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'screen visibility pauses support realtime without reloading conversation',
    () async {
      final repository = FakeSupportChatRepository();
      final realtimeClient = TrackingSupportChatRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWithValue(repository),
          supportChatRealtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );
      addTearDown(() {
        realtimeClient.closeStream();
        container.dispose();
      });

      final controller = container.read(supportChatControllerProvider.notifier);

      await controller.start();

      expect(realtimeClient.connectCalls, 1);

      controller.setScreenVisible(false);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);
      expect(repository.openConversationCalls, 0);

      controller.setScreenVisible(true);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.connectCalls, 2);
      expect(realtimeClient.disconnectCalls, 1);
      expect(repository.openConversationCalls, 0);
    },
  );

  test(
    'resume after suspend keeps loaded support conversation without refetching it',
    () async {
      final repository = FakeSupportChatRepository();
      final realtimeClient = TrackingSupportChatRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWithValue(repository),
          supportChatRealtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );
      addTearDown(() {
        realtimeClient.closeStream();
        container.dispose();
      });

      final controller = container.read(supportChatControllerProvider.notifier);

      await controller.start();

      expect(repository.getConversationCalls, 1);
      expect(realtimeClient.connectCalls, 1);

      controller.suspend();
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);

      controller.setScreenVisible(true);
      await controller.start();

      expect(repository.getConversationCalls, 1);
      expect(realtimeClient.connectCalls, 2);
      expect(realtimeClient.disconnectCalls, 1);
    },
  );

  test(
    'does not connect support realtime while internet is unavailable',
    () async {
      final repository = FakeSupportChatRepository();
      final realtimeClient = TrackingSupportChatRealtimeClient();
      final networkController = _TestNetworkStatusController(
        initialHasInternet: false,
      );
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWithValue(repository),
          supportChatRealtimeClientProvider.overrideWithValue(realtimeClient),
          networkStatusControllerProvider.overrideWith(() => networkController),
        ],
      );
      addTearDown(() {
        realtimeClient.closeStream();
        container.dispose();
      });

      final controller = container.read(supportChatControllerProvider.notifier);

      await controller.start();

      expect(repository.getConversationCalls, 1);
      expect(realtimeClient.connectCalls, 0);

      controller.setScreenVisible(false);
      await Future<void>.delayed(Duration.zero);
      controller.setScreenVisible(true);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.connectCalls, 0);
      expect(realtimeClient.disconnectCalls, 0);
    },
  );

  test(
    'pauses support realtime offline and reconnects after internet restore',
    () async {
      final repository = FakeSupportChatRepository();
      final realtimeClient = TrackingSupportChatRealtimeClient();
      final networkController = _TestNetworkStatusController(
        initialHasInternet: true,
      );
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWithValue(repository),
          supportChatRealtimeClientProvider.overrideWithValue(realtimeClient),
          networkStatusControllerProvider.overrideWith(() => networkController),
        ],
      );
      addTearDown(() {
        realtimeClient.closeStream();
        container.dispose();
      });

      final controller = container.read(supportChatControllerProvider.notifier);

      await controller.start();

      expect(realtimeClient.connectCalls, 1);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);
      expect(realtimeClient.connectCalls, 1);

      networkController.setHasInternet(true);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.connectCalls, 2);
      expect(realtimeClient.disconnectCalls, 1);
      expect(repository.getConversationCalls, 1);
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
  Future<void> dispose() async {}

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

class _TestNetworkStatusController extends NetworkStatusController {
  _TestNetworkStatusController({required this.initialHasInternet});

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}
