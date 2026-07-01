import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';

void main() {
  test('stop cancels active support attachment upload', () async {
    final repository = _CancellableSupportChatRepository();
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
    final sendFuture = controller.sendAttachments(
      attachments: const [
        SupportChatUploadAttachment(
          filePath: '/tmp/photo.jpg',
          fileName: 'photo.jpg',
          contentType: 'image/jpeg',
        ),
      ],
      localeTag: 'en',
    );

    final cancelToken = await repository.uploadStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    controller.stop();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(sendFuture, completion(isFalse));
    final state = container.read(supportChatControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.sendProgress, isNull);
    expect(state.errorMessage, isNull);
  });

  test('provider disposal cancels active support attachment upload', () async {
    final repository = _CancellableSupportChatRepository();
    final container = ProviderContainer(
      overrides: [
        supportChatRepositoryProvider.overrideWithValue(repository),
        supportChatRealtimeClientProvider.overrideWithValue(
          const _NoopSupportChatRealtimeClient(),
        ),
      ],
    );

    final controller = container.read(supportChatControllerProvider.notifier);
    final sendFuture = controller.sendAttachments(
      attachments: const [
        SupportChatUploadAttachment(
          filePath: '/tmp/photo.jpg',
          fileName: 'photo.jpg',
          contentType: 'image/jpeg',
        ),
      ],
      localeTag: 'en',
    );

    final cancelToken = await repository.uploadStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    container.dispose();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(sendFuture, completion(isFalse));
  });

  test('provider disposal ignores delayed initial load completion', () async {
    final repository = _DelayedInitialLoadSupportChatRepository();
    final container = ProviderContainer(
      overrides: [
        supportChatRepositoryProvider.overrideWithValue(repository),
        supportChatRealtimeClientProvider.overrideWithValue(
          const _NoopSupportChatRealtimeClient(),
        ),
      ],
    );

    final controller = container.read(supportChatControllerProvider.notifier);
    final initializeFuture = controller.initialize();
    await repository.loadStarted.future;

    container.dispose();
    repository.completeLoad();

    await expectLater(initializeFuture, completes);
  });

  test('stop cancels active support conversation load quietly', () async {
    final repository = _CancellableConversationLoadSupportChatRepository();
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
    final initializeFuture = controller.initialize();

    final cancelToken = await repository.loadStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    controller.stop();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(initializeFuture, completes);
    final state = container.read(supportChatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.isRefreshing, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('stop cancels active support older-messages load quietly', () async {
    final repository = _CancellableLoadOlderSupportChatRepository();
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
    await controller.initialize();

    final loadOlderFuture = controller.loadOlderMessages();
    final cancelToken = await repository.loadOlderStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    controller.stop();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(loadOlderFuture, completes);
    final state = container.read(supportChatControllerProvider);
    expect(state.isLoadingOlder, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.conversation?.messages, hasLength(1));
  });

  test('stop cancels active support mark-read request quietly', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repository = _CancellableMarkReadSupportChatRepository();
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
    final initializeFuture = controller.initialize();

    final cancelToken = await repository.markReadStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    controller.stop();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(initializeFuture, completes);
    final state = container.read(supportChatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.conversation?.userUnreadCount, 1);
  });

  test(
    'concurrent initialize calls share a single conversation request',
    () async {
      final repository = _DelayedInitialLoadSupportChatRepository();
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
      final first = controller.initialize();
      final second = controller.initialize();

      await repository.loadStarted.future;
      expect(repository.getConversationCalls, 1);

      repository.completeLoad();

      await expectLater(Future.wait([first, second]), completes);
      expect(repository.getConversationCalls, 1);
      expect(
        container
            .read(supportChatControllerProvider)
            .conversation
            ?.conversationId,
        'conversation-1',
      );
    },
  );
}

class _CancellableSupportChatRepository extends SupportChatRepository {
  _CancellableSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> uploadStarted = Completer<CancelToken>();

  @override
  Future<SupportChatConversation> openConversation({
    String? initialMessage,
    String source = 'MobileChat',
    String? assistantScenario,
    String? relatedGenerationId,
    String? relatedPaymentId,
    String? relatedSubscriptionId,
    CancelToken? cancelToken,
  }) async {
    return _conversation();
  }

  @override
  Future<SupportChatMessage> sendAttachments({
    required String conversationId,
    required List<SupportChatUploadAttachment> attachments,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    uploadStarted.complete(token);
    await token.whenCancel;
    throw const RequestCancelledException();
  }
}

class _DelayedInitialLoadSupportChatRepository extends SupportChatRepository {
  _DelayedInitialLoadSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> loadStarted = Completer<void>();
  final Completer<SupportChatConversation> _loadCompleter =
      Completer<SupportChatConversation>();
  int getConversationCalls = 0;

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) {
    getConversationCalls += 1;
    if (!loadStarted.isCompleted) {
      loadStarted.complete();
    }
    return _loadCompleter.future;
  }

  void completeLoad() {
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete(_conversation());
    }
  }
}

class _CancellableConversationLoadSupportChatRepository
    extends SupportChatRepository {
  _CancellableConversationLoadSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> loadStarted = Completer<CancelToken>();

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    if (!loadStarted.isCompleted) {
      loadStarted.complete(token);
    }
    await token.whenCancel;
    throw const RequestCancelledException();
  }
}

class _CancellableLoadOlderSupportChatRepository extends SupportChatRepository {
  _CancellableLoadOlderSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> loadOlderStarted = Completer<CancelToken>();

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) async {
    if (beforeMessageCreatedAtUtc == null) {
      return _conversation(
        hasOlderMessages: true,
        oldestLoadedMessageCreatedAtUtc: DateTime.utc(2025, 12, 31),
        messages: [
          SupportChatMessage(
            messageId: 'message-1',
            conversationId: 'conversation-1',
            senderUserId: 'user-1',
            senderDisplayName: 'Pet Parent',
            isFromAdmin: false,
            senderType: 'User',
            body: 'Initial message',
            isRead: true,
            createdAtUtc: DateTime(2026, 1, 1),
            attachments: [],
          ),
        ],
      );
    }

    final token = cancelToken ?? CancelToken();
    if (!loadOlderStarted.isCompleted) {
      loadOlderStarted.complete(token);
    }
    await token.whenCancel;
    throw const RequestCancelledException();
  }
}

class _CancellableMarkReadSupportChatRepository extends SupportChatRepository {
  _CancellableMarkReadSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> markReadStarted = Completer<CancelToken>();

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) async {
    return _conversation(
      messages: [
        SupportChatMessage(
          messageId: 'message-admin-1',
          conversationId: 'conversation-1',
          senderUserId: 'admin-1',
          senderDisplayName: 'Support',
          isFromAdmin: true,
          senderType: 'Admin',
          body: 'Pending read',
          isRead: false,
          createdAtUtc: DateTime(2026, 1, 1, 0, 1),
          attachments: [],
        ),
      ],
      hasOlderMessages: false,
    ).copyWith(userUnreadCount: 1);
  }

  @override
  Future<void> markConversationRead(
    String conversationId, {
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    if (!markReadStarted.isCompleted) {
      markReadStarted.complete(token);
    }
    await token.whenCancel;
    throw const RequestCancelledException();
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

SupportChatConversation _conversation({
  List<SupportChatMessage> messages = const [],
  bool hasOlderMessages = false,
  DateTime? oldestLoadedMessageCreatedAtUtc,
}) {
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
    messages: messages,
    hasOlderMessages: hasOlderMessages,
    oldestLoadedMessageCreatedAtUtc: oldestLoadedMessageCreatedAtUtc,
  );
}
