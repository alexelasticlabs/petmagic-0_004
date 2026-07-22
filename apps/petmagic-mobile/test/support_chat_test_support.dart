import 'dart:async';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';

class FakeSupportChatRepository extends SupportChatRepository {
  FakeSupportChatRepository({
    this.emptyConversation = false,
    bool hasConversation = true,
  }) : _hasConversation = hasConversation,
       super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final bool emptyConversation;
  bool _hasConversation;
  String? lastSentBody;
  int openConversationCalls = 0;
  int getConversationCalls = 0;
  String? lastOpenedInitialMessage;
  String? lastOpenedRelatedGenerationId;

  void seedConversation(SupportChatConversation conversation) {
    _hasConversation = true;
    _conversation = conversation;
  }

  late SupportChatConversation _conversation = SupportChatConversation(
    conversationId: 'conversation-1',
    initiatorUserId: 'user-1',
    userEmail: 'pet@example.com',
    userDisplayName: 'Pet Parent',
    assignedAdminId: 'admin-1',
    assignedAdminDisplayName: 'PetMagic Support',
    status: 'Open',
    priority: 'Normal',
    source: 'Direct',
    userUnreadCount: 1,
    adminUnreadCount: 0,
    createdAtUtc: DateTime.utc(2026, 1, 1, 10),
    updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
    lastMessageAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
    messages: emptyConversation
        ? []
        : [
            SupportChatMessage(
              messageId: 'message-1',
              conversationId: 'conversation-1',
              senderUserId: 'admin-1',
              senderDisplayName: 'PetMagic Support',
              isFromAdmin: true,
              senderType: 'Admin',
              body: 'How can we help today?',
              isRead: false,
              attachments: const [],
              createdAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
            ),
          ],
  );

  @override
  Future<SupportChatConversation> openConversation({
    String source = 'Direct',
    String? assistantScenario,
    String? initialMessage,
    String? relatedGenerationId,
    String? relatedPaymentId,
    String? relatedSubscriptionId,
    RequestCancellation? cancelToken,
  }) async {
    openConversationCalls += 1;
    lastOpenedInitialMessage = initialMessage;
    lastOpenedRelatedGenerationId = relatedGenerationId;
    if (!_hasConversation) {
      _hasConversation = true;
      final now = DateTime.utc(2026, 1, 1, 10, 10);
      final initialMessages = <SupportChatMessage>[];
      final trimmedInitial = initialMessage?.trim() ?? '';
      if (trimmedInitial.isNotEmpty) {
        initialMessages.add(
          SupportChatMessage(
            messageId: 'message-2',
            conversationId: 'conversation-1',
            senderUserId: 'user-1',
            senderDisplayName: 'Pet Parent',
            isFromAdmin: false,
            senderType: 'User',
            body: trimmedInitial,
            isRead: false,
            attachments: const [],
            createdAtUtc: now,
          ),
        );
      }

      _conversation = SupportChatConversation(
        conversationId: 'conversation-1',
        initiatorUserId: 'user-1',
        userEmail: 'pet@example.com',
        userDisplayName: 'Pet Parent',
        assignedAdminId: 'admin-1',
        assignedAdminDisplayName: 'PetMagic Support',
        status: initialMessages.isEmpty ? 'Open' : 'WaitingForSupport',
        priority: 'Normal',
        source: source,
        userUnreadCount: 0,
        adminUnreadCount: initialMessages.isEmpty ? 0 : 1,
        createdAtUtc: DateTime.utc(2026, 1, 1, 10),
        updatedAtUtc: now,
        lastMessageAtUtc: initialMessages.isEmpty ? null : now,
        messages: initialMessages,
      );
      return _conversation;
    }

    return _conversation;
  }

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    RequestCancellation? cancelToken,
  }) async {
    getConversationCalls += 1;
    if (!_hasConversation) {
      throw const AppException(
        'support.conversation_not_found',
        statusCode: 404,
      );
    }
    return _conversation;
  }

  @override
  Future<SupportChatMessage> sendMessage({
    required String conversationId,
    required String body,
    required String localeTag,
    String? replyToMessageId,
  }) async {
    if (!_hasConversation) {
      throw const AppException(
        'support.conversation_not_found',
        statusCode: 404,
      );
    }

    lastSentBody = body;
    final message = SupportChatMessage(
      messageId: 'message-2',
      conversationId: conversationId,
      senderUserId: 'user-1',
      senderDisplayName: 'Pet Parent',
      isFromAdmin: false,
      senderType: 'User',
      body: body,
      isRead: false,
      attachments: const [],
      createdAtUtc: DateTime.utc(2026, 1, 1, 10, 10),
    );

    _conversation = _conversation.copyWith(
      adminUnreadCount: _conversation.adminUnreadCount + 1,
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      messages: [..._conversation.messages, message],
    );

    return message;
  }

  @override
  Future<void> markConversationRead(
    String conversationId, {
    RequestCancellation? cancelToken,
  }) async {
    _conversation = _conversation.copyWith(
      userUnreadCount: 0,
      messages: _conversation.messages
          .map(
            (message) => message.isFromAdmin
                ? message.copyWith(
                    isRead: true,
                    readAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
                  )
                : message,
          )
          .toList(growable: false),
    );
  }
}

class ThrowingSupportChatRepository extends SupportChatRepository {
  ThrowingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    RequestCancellation? cancelToken,
  }) async {
    throw Exception('unexpected support failure');
  }
}

class DelayedSupportChatRepository extends SupportChatRepository {
  DelayedSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    RequestCancellation? cancelToken,
  }) async {
    return Completer<SupportChatConversation>().future;
  }
}

class FakeSupportChatRealtimeClient implements SupportChatRealtimeClient {
  const FakeSupportChatRealtimeClient();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<SupportChatRealtimeUpdate> get events => const Stream.empty();
}

class TrackingSupportChatRealtimeClient implements SupportChatRealtimeClient {
  TrackingSupportChatRealtimeClient();

  final StreamController<SupportChatRealtimeUpdate> _controller =
      StreamController<SupportChatRealtimeUpdate>.broadcast();
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> connect() async {
    connectCalls++;
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
