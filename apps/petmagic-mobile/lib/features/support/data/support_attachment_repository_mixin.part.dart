part of 'support_chat_repository.dart';

mixin _SupportAttachmentRepositoryMixin on _SupportChatRepositoryBase {
  @override
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
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final prepared = await _attachmentUploadPreparer.prepare(
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
      cancelToken: cancelToken,
    );
    try {
      final trimmedBody = body?.trim() ?? '';
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/support/conversation/$encodedConversationId/attachments',
          data: FormData.fromMap({
            if (trimmedBody.isNotEmpty) 'body': trimmedBody,
            'locale': localeTag,
            if (replyToMessageId?.trim().isNotEmpty == true)
              'replyToMessageId': replyToMessageId!.trim(),
            'file': await MultipartFile.fromFile(
              prepared.filePath,
              filename: prepared.safeFileName,
              contentType: MediaType.parse(prepared.contentType),
            ),
          }),
          options: authenticatedMultipartRequestOptions(session.accessToken),
          onSendProgress: onSendProgress,
          cancelToken: cancelToken.toDioCancelToken(),
        ),
        retryTransientFailures: false,
      );

      return mapSupportChatMessageDto(response.data ?? const {});
    } finally {
      await prepared.dispose();
    }
  }

  @override
  Future<SupportChatMessage> sendAttachments({
    required String conversationId,
    required List<SupportChatUploadAttachment> attachments,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    UploadProgressCallback? onSendProgress,
    RequestCancellation? cancelToken,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    if (attachments.isEmpty) {
      throw const AppException(
        'support.attachment_invalid_upload',
        statusCode: 400,
      );
    }
    if (attachments.length > _SupportChatRepositoryBase._maxAttachmentCount) {
      throw const AppException('support.attachment_too_many', statusCode: 400);
    }

    final preparedAttachments = <PreparedSupportAttachmentUpload>[];
    try {
      for (final attachment in attachments) {
        preparedAttachments.add(
          await _attachmentUploadPreparer.prepare(
            filePath: attachment.filePath,
            fileName: attachment.fileName,
            contentType: attachment.contentType,
            cancelToken: cancelToken,
          ),
        );
      }

      final multipartFiles = await Future.wait(
        preparedAttachments.map(
          (entry) => MultipartFile.fromFile(
            entry.filePath,
            filename: entry.safeFileName,
            contentType: MediaType.parse(entry.contentType),
          ),
        ),
      );
      final trimmedBody = body?.trim() ?? '';
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/support/conversation/$encodedConversationId/messages/attachments',
          data: FormData.fromMap({
            if (trimmedBody.isNotEmpty) 'body': trimmedBody,
            'locale': localeTag,
            if (replyToMessageId?.trim().isNotEmpty == true)
              'replyToMessageId': replyToMessageId!.trim(),
            'files': multipartFiles,
          }),
          options: authenticatedMultipartRequestOptions(session.accessToken),
          onSendProgress: onSendProgress,
          cancelToken: cancelToken.toDioCancelToken(),
        ),
        retryTransientFailures: false,
      );

      return mapSupportChatMessageDto(response.data ?? const {});
    } finally {
      for (final prepared in preparedAttachments) {
        await prepared.dispose();
      }
    }
  }

  @override
  Future<SupportChatMessage> retryAttachment({
    required String conversationId,
    required String messageId,
    required String filePath,
    required String fileName,
    required String contentType,
    RequestCancellation? cancelToken,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final encodedMessageId = _supportPathSegment(messageId);
    final prepared = await _attachmentUploadPreparer.prepare(
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
      cancelToken: cancelToken,
    );
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/support/conversation/$encodedConversationId/messages/$encodedMessageId/attachment/retry',
          data: FormData.fromMap({
            'file': await MultipartFile.fromFile(
              prepared.filePath,
              filename: prepared.safeFileName,
              contentType: MediaType.parse(prepared.contentType),
            ),
          }),
          options: authenticatedMultipartRequestOptions(session.accessToken),
          cancelToken: cancelToken.toDioCancelToken(),
        ),
        retryTransientFailures: false,
      );

      return mapSupportChatMessageDto(response.data ?? const {});
    } finally {
      await prepared.dispose();
    }
  }
}
