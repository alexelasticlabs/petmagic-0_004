import 'dart:async';

import 'package:dio/dio.dart';
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

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) {
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
