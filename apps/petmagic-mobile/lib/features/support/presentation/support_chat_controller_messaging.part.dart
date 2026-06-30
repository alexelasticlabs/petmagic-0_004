part of 'support_chat_controller.dart';

mixin _SupportChatControllerMessagingMixin
    on
        Notifier<SupportChatState>,
        _SupportChatControllerScope,
        _SupportChatControllerConversationMixin {
  Future<bool> sendMessage(
    String value, {
    required String localeTag,
    String? replyToMessageId,
    String? relatedGenerationId,
  }) async {
    final body = value.trim();
    final normalizedRelatedGenerationId = relatedGenerationId?.trim();
    final conversation = state.conversation;
    if (body.isEmpty || state.isSending) {
      return false;
    }

    if (conversation != null && _isConversationReadOnlyForUser(conversation)) {
      return false;
    }

    state = state.copyWith(
      isSending: true,
      clearError: true,
      clearSendProgress: true,
    );

    try {
      if (conversation == null) {
        final createdConversation = await _repository.openConversation(
          initialMessage: body,
          source: 'MobileChat',
          assistantScenario: 'Support',
          relatedGenerationId:
              normalizedRelatedGenerationId == null ||
                  normalizedRelatedGenerationId.isEmpty
              ? null
              : normalizedRelatedGenerationId,
        );
        if (!ref.mounted) {
          return false;
        }
        _updateStateIfMounted(
          (state) => state.copyWith(
            isSending: false,
            conversation: createdConversation,
            clearError: true,
            clearSendProgress: true,
          ),
        );
        await _markReadIfNeeded(createdConversation);
        if (!ref.mounted) {
          return false;
        }
      } else {
        final message = await _repository.sendMessage(
          conversationId: conversation.conversationId,
          body: body,
          localeTag: localeTag,
          replyToMessageId: replyToMessageId,
        );

        if (!ref.mounted) {
          return false;
        }
        _updateStateIfMounted(
          (state) => state.copyWith(
            isSending: false,
            conversation: _appendOutgoingMessage(conversation, message),
            clearError: true,
            clearSendProgress: true,
          ),
        );
      }
      _resumePendingRealtimeRefreshIfNeeded();
      return true;
    } on AppException catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: error.message,
          clearSendProgress: true,
        ),
      );
      return false;
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: 'support.unavailable',
          clearSendProgress: true,
        ),
      );
      return false;
    }
  }

  Future<bool> sendImageAttachment(
    XFile file, {
    String? body,
    required String localeTag,
  }) async {
    return sendAttachment(
      filePath: file.path,
      fileName: file.name,
      contentType: resolveContentTypeForUpload(file.path),
      localeTag: localeTag,
      body: body,
    );
  }

  String resolveContentTypeForUpload(String path) {
    return _resolveContentType(path);
  }

  Future<bool> sendAttachments({
    required List<SupportChatUploadAttachment> attachments,
    required String localeTag,
    String? body,
    String? replyToMessageId,
  }) async {
    if (attachments.isEmpty || state.isSending) {
      return false;
    }

    var conversation = state.conversation;
    if (conversation != null && _isConversationReadOnlyForUser(conversation)) {
      return false;
    }

    state = state.copyWith(
      isSending: true,
      clearError: true,
      sendProgress: 0,
      sendingAttachmentIndex: attachments.length == 1 ? 1 : null,
      sendingAttachmentTotal: attachments.length,
    );

    CancelToken? uploadCancelToken;
    try {
      if (conversation == null) {
        conversation = await _repository.openConversation(source: 'MobileChat');
        if (!ref.mounted) {
          return false;
        }
        _updateStateIfMounted(
          (state) => state.copyWith(conversation: conversation),
        );
      }

      uploadCancelToken = _newActiveUploadCancelToken();
      final message = await _repository.sendAttachments(
        conversationId: conversation.conversationId,
        attachments: attachments,
        localeTag: localeTag,
        body: body,
        replyToMessageId: replyToMessageId,
        cancelToken: uploadCancelToken,
        onSendProgress: (sent, total) {
          if (total <= 0) {
            return;
          }

          _updateStateIfMounted(
            (state) => state.copyWith(
              sendProgress: (sent / total).clamp(0.0, 1.0).toDouble(),
            ),
          );
        },
      );

      final attachmentFailure = _messageFromAttachmentFailure(message);
      if (!ref.mounted) {
        return false;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          conversation: _appendOutgoingMessage(conversation!, message),
          errorMessage: attachmentFailure,
          clearError: attachmentFailure == null,
          clearSendProgress: true,
        ),
      );
      _resumePendingRealtimeRefreshIfNeeded();
      return attachmentFailure == null;
    } on RequestCancelledException {
      _updateStateIfMounted(
        (state) => state.copyWith(isSending: false, clearSendProgress: true),
      );
      return false;
    } on AppException catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: error.message,
          clearSendProgress: true,
        ),
      );
      return false;
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: 'support.attachment_unavailable',
          clearSendProgress: true,
        ),
      );
      return false;
    } finally {
      final cancelToken = uploadCancelToken;
      if (cancelToken != null) {
        _clearActiveUpload(cancelToken);
      }
    }
  }

  Future<bool> sendAttachment({
    required String filePath,
    required String fileName,
    required String contentType,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    int? attachmentBatchIndex,
    int? attachmentBatchTotal,
  }) async {
    var conversation = state.conversation;
    if (state.isSending) {
      return false;
    }

    if (conversation != null && _isConversationReadOnlyForUser(conversation)) {
      return false;
    }

    state = state.copyWith(
      isSending: true,
      clearError: true,
      sendProgress: 0,
      sendingAttachmentIndex: attachmentBatchIndex,
      sendingAttachmentTotal: attachmentBatchTotal,
    );

    CancelToken? uploadCancelToken;
    try {
      if (conversation == null) {
        conversation = await _repository.openConversation(source: 'MobileChat');
        if (!ref.mounted) {
          return false;
        }
        _updateStateIfMounted(
          (state) => state.copyWith(conversation: conversation),
        );
      }

      uploadCancelToken = _newActiveUploadCancelToken();
      final message = await _repository.sendAttachment(
        conversationId: conversation.conversationId,
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
        localeTag: localeTag,
        body: body,
        replyToMessageId: replyToMessageId,
        cancelToken: uploadCancelToken,
        onSendProgress: (sent, total) {
          if (total <= 0) {
            return;
          }

          _updateStateIfMounted(
            (state) => state.copyWith(
              sendProgress: (sent / total).clamp(0.0, 1.0).toDouble(),
            ),
          );
        },
      );

      final attachmentFailure = _messageFromAttachmentFailure(message);

      if (!ref.mounted) {
        return false;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          conversation: _appendOutgoingMessage(conversation!, message),
          errorMessage: attachmentFailure,
          clearError: attachmentFailure == null,
          clearSendProgress: true,
        ),
      );
      _resumePendingRealtimeRefreshIfNeeded();
      return message.isAttachmentUploaded;
    } on RequestCancelledException {
      _updateStateIfMounted(
        (state) => state.copyWith(isSending: false, clearSendProgress: true),
      );
      return false;
    } on AppException catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: error.message,
          clearSendProgress: true,
        ),
      );
      return false;
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: 'support.attachment_unavailable',
          clearSendProgress: true,
        ),
      );
      return false;
    } finally {
      final cancelToken = uploadCancelToken;
      if (cancelToken != null) {
        _clearActiveUpload(cancelToken);
      }
    }
  }

  Future<bool> retryAttachment({
    required String messageId,
    required String filePath,
    required String fileName,
    required String contentType,
  }) async {
    final conversation = state.conversation;
    if (conversation == null || conversation.isReadOnly || state.isSending) {
      return false;
    }

    state = state.copyWith(isSending: true, clearError: true);

    CancelToken? uploadCancelToken;
    try {
      uploadCancelToken = _newActiveUploadCancelToken();
      final message = await _repository.retryAttachment(
        conversationId: conversation.conversationId,
        messageId: messageId,
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
        cancelToken: uploadCancelToken,
      );

      final attachmentFailure = _messageFromAttachmentFailure(message);
      if (!ref.mounted) {
        return false;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          conversation: _upsertMessage(conversation, message),
          errorMessage: attachmentFailure,
          clearError: attachmentFailure == null,
        ),
      );
      _resumePendingRealtimeRefreshIfNeeded();
      return message.isAttachmentUploaded;
    } on RequestCancelledException {
      _updateStateIfMounted(
        (state) => state.copyWith(isSending: false, clearSendProgress: true),
      );
      return false;
    } on AppException catch (error) {
      _updateStateIfMounted(
        (state) =>
            state.copyWith(isSending: false, errorMessage: error.message),
      );
      return false;
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: 'support.attachment_unavailable',
        ),
      );
      return false;
    } finally {
      final cancelToken = uploadCancelToken;
      if (cancelToken != null) {
        _clearActiveUpload(cancelToken);
      }
    }
  }

  SupportChatConversation _appendOutgoingMessage(
    SupportChatConversation conversation,
    SupportChatMessage message,
  ) {
    return conversation.copyWith(
      status: 'New',
      userUnreadCount: 0,
      adminUnreadCount: conversation.adminUnreadCount + 1,
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      isReadOnly: false,
      canReopen: false,
      clearResolvedAt: true,
      clearReopenUntil: true,
      clearClosedAt: true,
      messages: [...conversation.messages, message],
    );
  }

  SupportChatConversation _upsertMessage(
    SupportChatConversation conversation,
    SupportChatMessage message,
  ) {
    final index = conversation.messages.indexWhere(
      (existing) => existing.messageId == message.messageId,
    );
    if (index < 0) {
      return _appendOutgoingMessage(conversation, message);
    }

    final updatedMessages = [...conversation.messages];
    updatedMessages[index] = message;
    return conversation.copyWith(
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      messages: updatedMessages,
    );
  }

  String? _messageFromAttachmentFailure(SupportChatMessage message) {
    if (!message.isAttachmentFailed) {
      return null;
    }

    return message.attachmentUploadErrorCode ??
        'support.attachment_unavailable';
  }

  String _resolveContentType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.jpg')) {
      return 'image/jpeg';
    }

    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lowerPath.endsWith('.mp4') || lowerPath.endsWith('.m4v')) {
      return 'video/mp4';
    }

    if (lowerPath.endsWith('.mov') || lowerPath.endsWith('.qt')) {
      return 'video/quicktime';
    }

    return 'application/octet-stream';
  }
}
