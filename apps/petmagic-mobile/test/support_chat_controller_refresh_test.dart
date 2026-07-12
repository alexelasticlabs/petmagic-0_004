import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';

import 'support_chat_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('support chat controller does not cache dependencies in build', () {
    final source = File(
      'lib/features/support/presentation/support_chat_controller.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('late final SupportRepository')));
    expect(source, isNot(contains('late final SupportRealtimeGateway')));
    expect(source, contains('SupportRepository? _activeRepository;'));
    expect(source, contains('SupportRealtimeGateway? _activeRealtimeClient;'));
    expect(
      source,
      contains('_activeRepository = ref.read(supportChatRepositoryProvider);'),
    );
    expect(
      source,
      contains(
        '_activeRealtimeClient = ref.read(supportChatRealtimeClientProvider);',
      ),
    );
    expect(
      source,
      isNot(contains('_repository = ref.watch(supportChatRepositoryProvider)')),
    );
    expect(
      source,
      isNot(
        contains(
          '_realtimeClient = ref.watch(supportChatRealtimeClientProvider)',
        ),
      ),
    );
  });

  test(
    'refresh clears loading after unexpected failure and allows retry',
    () async {
      final repository = _FlakyRefreshSupportChatRepository();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            () => _MutableSupportChatAppLaunchController(true),
          ),
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
          appLaunchControllerProvider.overrideWith(
            () => _MutableSupportChatAppLaunchController(true),
          ),
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
          appLaunchControllerProvider.overrideWith(
            () => _MutableSupportChatAppLaunchController(true),
          ),
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
    'late support realtime connect disconnects after screen is hidden',
    () async {
      final repository = FakeSupportChatRepository();
      final realtimeClient = _DelayedConnectSupportChatRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            () => _MutableSupportChatAppLaunchController(true),
          ),
          supportChatRepositoryProvider.overrideWithValue(repository),
          supportChatRealtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );
      addTearDown(() {
        realtimeClient.closeStream();
        container.dispose();
      });

      final controller = container.read(supportChatControllerProvider.notifier);

      final startFuture = controller.start();
      await realtimeClient.connectStarted.future;

      controller.setScreenVisible(false);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 0);

      realtimeClient.completeConnect();
      await startFuture;
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.connectCalls, 1);
      expect(realtimeClient.disconnectCalls, 1);
    },
  );

  test(
    'does not load support conversation or connect realtime while internet is unavailable',
    () async {
      final repository = FakeSupportChatRepository();
      final realtimeClient = TrackingSupportChatRealtimeClient();
      final networkController = _TestNetworkStatusController(
        initialHasInternet: false,
      );
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            () => _MutableSupportChatAppLaunchController(true),
          ),
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

      expect(repository.getConversationCalls, 0);
      expect(realtimeClient.connectCalls, 0);

      controller.setScreenVisible(false);
      await Future<void>.delayed(Duration.zero);
      controller.setScreenVisible(true);
      await Future<void>.delayed(Duration.zero);

      expect(repository.getConversationCalls, 0);
      expect(realtimeClient.connectCalls, 0);
      expect(realtimeClient.disconnectCalls, 0);

      networkController.setHasInternet(true);
      await Future<void>.delayed(Duration.zero);

      expect(repository.getConversationCalls, 1);
      expect(realtimeClient.connectCalls, 1);
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
          appLaunchControllerProvider.overrideWith(
            () => _MutableSupportChatAppLaunchController(true),
          ),
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

  test(
    'support chat controller stops realtime and private refresh after sign out',
    () async {
      final repository = FakeSupportChatRepository();
      final realtimeClient = TrackingSupportChatRealtimeClient();
      final launchController = _MutableSupportChatAppLaunchController(true);
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(() => launchController),
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

      launchController.setAuthenticated(false);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);

      await controller.refresh();
      final sent = await controller.sendMessage('hello', localeTag: 'ru');

      expect(sent, isFalse);
      expect(
        repository.getConversationCalls,
        1,
        reason: 'support refresh must not call private API after sign out',
      );
      expect(
        repository.openConversationCalls,
        0,
        reason: 'support send must not open a conversation after sign out',
      );
      expect(realtimeClient.connectCalls, 1);
    },
  );

  test(
    'support chat controller stays idle for explicit unauthenticated app state',
    () async {
      final repository = FakeSupportChatRepository(hasConversation: false);
      final realtimeClient = TrackingSupportChatRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            () => _MutableSupportChatAppLaunchController(false),
          ),
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
      final sent = await controller.sendMessage('hello', localeTag: 'ru');
      final state = container.read(supportChatControllerProvider);

      expect(sent, isFalse);
      expect(state.isLoading, isFalse);
      expect(repository.getConversationCalls, 0);
      expect(repository.openConversationCalls, 0);
      expect(realtimeClient.connectCalls, 0);
    },
  );

  test('load older messages stops after duplicate-only page', () async {
    final repository = _DuplicateOlderMessagesSupportChatRepository();
    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          () => _MutableSupportChatAppLaunchController(true),
        ),
        supportChatRepositoryProvider.overrideWithValue(repository),
        supportChatRealtimeClientProvider.overrideWithValue(
          const _NoopSupportChatRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(supportChatControllerProvider.notifier);
    await controller.initialize();
    await controller.loadOlderMessages();
    await controller.loadOlderMessages();

    final state = container.read(supportChatControllerProvider);
    expect(repository.getConversationCalls, 2);
    expect(state.conversation?.messages.map((message) => message.messageId), [
      'message-1',
    ]);
    expect(state.conversation?.hasOlderMessages, isFalse);
  });
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

class _DuplicateOlderMessagesSupportChatRepository
    extends SupportChatRepository {
  _DuplicateOlderMessagesSupportChatRepository()
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
    if (beforeMessageCreatedAtUtc == null) {
      return _conversationWithOlderMessages();
    }

    return _conversationWithOlderMessages();
  }
}

class _MutableSupportChatAppLaunchController extends AppLaunchController {
  _MutableSupportChatAppLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: _isAuthenticated,
    );
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: value,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: value,
    );
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

class _DelayedConnectSupportChatRealtimeClient
    implements SupportChatRealtimeClient {
  final StreamController<SupportChatRealtimeUpdate> _controller =
      StreamController<SupportChatRealtimeUpdate>.broadcast();
  final Completer<void> connectStarted = Completer<void>();
  final Completer<void> _connectCompleter = Completer<void>();
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> connect() async {
    connectCalls++;
    if (!connectStarted.isCompleted) {
      connectStarted.complete();
    }
    await _connectCompleter.future;
  }

  void completeConnect() {
    if (!_connectCompleter.isCompleted) {
      _connectCompleter.complete();
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Stream<SupportChatRealtimeUpdate> get events => _controller.stream;

  void closeStream() {
    unawaited(_controller.close());
  }
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

SupportChatConversation _conversationWithOlderMessages() {
  final message = SupportChatMessage(
    messageId: 'message-1',
    conversationId: 'conversation-1',
    senderUserId: 'admin-1',
    senderDisplayName: 'PetMagic Support',
    isFromAdmin: true,
    senderType: 'Admin',
    body: 'Earlier context',
    isRead: true,
    attachments: const [],
    createdAtUtc: DateTime.utc(2026, 1, 1, 10),
  );

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
    updatedAtUtc: DateTime.utc(2026, 1, 1, 10),
    lastMessageAtUtc: message.createdAtUtc,
    messages: [message],
    hasOlderMessages: true,
    oldestLoadedMessageCreatedAtUtc: message.createdAtUtc,
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
