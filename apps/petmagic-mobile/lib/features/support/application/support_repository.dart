import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';

typedef UploadProgressCallback = void Function(int sent, int total);

final supportChatRepositoryProvider = Provider<SupportRepository>((ref) {
  throw StateError(
    'SupportRepository is not bound. Add the app composition overrides.',
  );
});

abstract interface class SupportRepository {
  Future<SupportChatConversation> openConversation({
    String? initialMessage,
    String source = 'MobileChat',
    String? assistantScenario,
    String? relatedGenerationId,
    String? relatedPaymentId,
    String? relatedSubscriptionId,
    RequestCancellation? cancelToken,
  });

  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    RequestCancellation? cancelToken,
  });

  Future<SupportChatMessage> sendMessage({
    required String conversationId,
    required String body,
    required String localeTag,
    String? replyToMessageId,
  });

  Future<SupportChatMessage> sendAttachment({
    required String conversationId,
    required String filePath,
    required String fileName,
    required String contentType,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    UploadProgressCallback? onSendProgress,
    RequestCancellation? cancelToken,
  });

  Future<SupportChatMessage> sendAttachments({
    required String conversationId,
    required List<SupportChatUploadAttachment> attachments,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    UploadProgressCallback? onSendProgress,
    RequestCancellation? cancelToken,
  });

  Future<SupportChatMessage> retryAttachment({
    required String conversationId,
    required String messageId,
    required String filePath,
    required String fileName,
    required String contentType,
    RequestCancellation? cancelToken,
  });

  Future<void> markConversationRead(
    String conversationId, {
    RequestCancellation? cancelToken,
  });
  Future<SupportChatConversation> resolveConversation(String conversationId);
  Future<SupportChatConversation> reopenConversation(String conversationId);
  Future<SupportChatConversation> closeConversation(String conversationId);

  Future<SupportChatConversation> submitFeedback({
    required String conversationId,
    required int rating,
    String? comment,
  });

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  });
  Future<void> unregisterPushToken(String token);
}
