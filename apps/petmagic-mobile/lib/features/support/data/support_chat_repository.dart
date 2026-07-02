import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/domain/support_attachment_validation.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';

final supportChatRepositoryProvider = Provider<SupportChatRepository>((ref) {
  return SupportChatRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
    imageUploadOptimizer: const ImageUploadOptimizer(),
  );
});

class SupportChatRepository {
  SupportChatRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    ImageUploadOptimizer? imageUploadOptimizer,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _imageUploadOptimizer =
           imageUploadOptimizer ?? const ImageUploadOptimizer(),
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final ImageUploadOptimizer _imageUploadOptimizer;
  final AuthSessionCoordinator _authSessionCoordinator;

  static const _maxAttachmentCount = 5;
  static const _imageMaxFileSizeBytes = UploadMediaPolicy.supportImageMaxBytes;
  static const _videoMaxFileSizeBytes = UploadMediaPolicy.supportVideoMaxBytes;

  Future<SupportChatConversation> openConversation({
    String? initialMessage,
    String source = 'MobileChat',
    String? assistantScenario,
    String? relatedGenerationId,
    String? relatedPaymentId,
    String? relatedSubscriptionId,
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) async => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/open',
        data: {
          'initialMessage': initialMessage?.trim().isEmpty ?? true
              ? null
              : initialMessage?.trim(),
          'source': source,
          ...?assistantScenario == null
              ? null
              : {'assistantScenario': assistantScenario},
          ...?relatedGenerationId == null
              ? null
              : {'relatedGenerationId': relatedGenerationId},
          ...?relatedPaymentId == null
              ? null
              : {'relatedPaymentId': relatedPaymentId},
          ...?relatedSubscriptionId == null
              ? null
              : {'relatedSubscriptionId': relatedSubscriptionId},
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{'take': _supportPageSize(take)};
    if (beforeMessageCreatedAtUtc != null) {
      query['beforeMessageCreatedAtUtc'] = beforeMessageCreatedAtUtc
          .toUtc()
          .toIso8601String();
    }
    if (beforeMessageId?.trim().isNotEmpty == true) {
      query['beforeMessageId'] = beforeMessageId!.trim();
    }

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/support/conversation',
        queryParameters: query,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatMessage> sendMessage({
    required String conversationId,
    required String body,
    required String localeTag,
    String? replyToMessageId,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) async => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$encodedConversationId/messages',
        data: {
          'body': body.trim(),
          'locale': localeTag,
          if (replyToMessageId?.trim().isNotEmpty == true)
            'replyToMessageId': replyToMessageId!.trim(),
        },
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return SupportChatMessage.fromJson(response.data ?? const {});
  }

  Future<SupportChatMessage> sendAttachment({
    required String conversationId,
    required String filePath,
    required String fileName,
    required String contentType,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final prepared = await _prepareAttachmentForUpload(
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
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );

      return SupportChatMessage.fromJson(response.data ?? const {});
    } finally {
      await prepared.dispose();
    }
  }

  Future<SupportChatMessage> sendAttachments({
    required String conversationId,
    required List<SupportChatUploadAttachment> attachments,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    if (attachments.isEmpty) {
      throw const AppException(
        'support.attachment_invalid_upload',
        statusCode: 400,
      );
    }
    if (attachments.length > _maxAttachmentCount) {
      throw const AppException('support.attachment_too_many', statusCode: 400);
    }

    final preparedAttachments = <PreparedSupportAttachmentUpload>[];
    try {
      for (final attachment in attachments) {
        preparedAttachments.add(
          await _prepareAttachmentForUpload(
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
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );

      return SupportChatMessage.fromJson(response.data ?? const {});
    } finally {
      for (final prepared in preparedAttachments) {
        await prepared.dispose();
      }
    }
  }

  Future<SupportChatMessage> retryAttachment({
    required String conversationId,
    required String messageId,
    required String filePath,
    required String fileName,
    required String contentType,
    CancelToken? cancelToken,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final encodedMessageId = _supportPathSegment(messageId);
    final prepared = await _prepareAttachmentForUpload(
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
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );

      return SupportChatMessage.fromJson(response.data ?? const {});
    } finally {
      await prepared.dispose();
    }
  }

  Future<void> markConversationRead(
    String conversationId, {
    CancelToken? cancelToken,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/support/conversation/$encodedConversationId/read',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );
  }

  Future<SupportChatConversation> resolveConversation(
    String conversationId,
  ) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$encodedConversationId/resolve',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatConversation> reopenConversation(
    String conversationId,
  ) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$encodedConversationId/reopen',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatConversation> closeConversation(
    String conversationId,
  ) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$encodedConversationId/close',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatConversation> submitFeedback({
    required String conversationId,
    required int rating,
    String? comment,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$encodedConversationId/feedback',
        data: {
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    await _authorizedRequest<void>(
      (session) => _dio.put<void>(
        '/api/support/notifications/push-token',
        data: {
          'token': token,
          'platform': platform,
          if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
          if (appVersion != null && appVersion.isNotEmpty)
            'appVersion': appVersion,
          if (locale != null && locale.isNotEmpty) 'locale': locale,
        },
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }

  Future<void> unregisterPushToken(String token) async {
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/support/notifications/push-token',
        data: {'token': token},
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'support.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }

  Future<String> _validateAttachmentForUpload({
    required String filePath,
    required String contentType,
  }) async {
    final normalizedContentType = contentType.trim().toLowerCase();
    int fileSizeBytes;
    try {
      fileSizeBytes = await File(filePath).length();
    } on FileSystemException {
      throw const AppException(
        'support.attachment_invalid_upload',
        statusCode: 400,
      );
    }

    if (fileSizeBytes <= 0) {
      throw const AppException(
        'support.attachment_invalid_upload',
        statusCode: 400,
      );
    }

    final declaredValidation = SupportAttachmentValidation.validate(
      contentType: normalizedContentType,
      fileSizeBytes: fileSizeBytes,
      imageMaxBytes: _imageMaxFileSizeBytes,
      videoMaxBytes: _videoMaxFileSizeBytes,
      videoMaxDuration: Duration.zero,
    );

    if (!declaredValidation.isAllowed) {
      _throwAttachmentValidationError(declaredValidation.error);
    }

    final detectedContentType = await _detectAttachmentContentType(filePath);
    if (detectedContentType == null) {
      throw const AppException(
        'support.attachment_content_type_not_allowed',
        statusCode: 400,
      );
    }

    final detectedValidation = SupportAttachmentValidation.validate(
      contentType: detectedContentType,
      fileSizeBytes: fileSizeBytes,
      imageMaxBytes: _imageMaxFileSizeBytes,
      videoMaxBytes: _videoMaxFileSizeBytes,
      videoMaxDuration: Duration.zero,
    );
    if (!detectedValidation.isAllowed) {
      _throwAttachmentValidationError(detectedValidation.error);
    }

    return detectedContentType;
  }

  Never _throwAttachmentValidationError(
    SupportAttachmentValidationError? error,
  ) {
    final message = switch (error) {
      SupportAttachmentValidationError.unsupportedFormat =>
        'support.attachment_content_type_not_allowed',
      SupportAttachmentValidationError.fileTooLarge =>
        'support.attachment_file_too_large',
      SupportAttachmentValidationError.videoTooLong =>
        'support.attachment_video_too_long',
      null => 'support.attachment_invalid_upload',
    };
    throw AppException(message, statusCode: 400);
  }

  Future<String?> _detectAttachmentContentType(String path) async {
    final header = await _attachmentHeader(path);
    return detectSupportAttachmentContentType(header);
  }

  Future<List<int>> _attachmentHeader(String path) async {
    try {
      final chunks = await File(path).openRead(0, 32).toList();
      return [for (final chunk in chunks) ...chunk];
    } on FileSystemException {
      throw const AppException(
        'support.attachment_invalid_upload',
        statusCode: 400,
      );
    }
  }

  String _safeMultipartFileName({
    required String fileName,
    required String filePath,
  }) {
    final preferred = _lastPathSegment(fileName);
    final fallback = _lastPathSegment(filePath);
    final sanitized = _sanitizeFileName(preferred);
    if (sanitized.isNotEmpty) {
      return sanitized;
    }

    final sanitizedFallback = _sanitizeFileName(fallback);
    return sanitizedFallback.isEmpty ? 'attachment' : sanitizedFallback;
  }

  String _lastPathSegment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final normalized = trimmed.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    return slashIndex < 0 ? normalized : normalized.substring(slashIndex + 1);
  }

  String _sanitizeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<PreparedSupportAttachmentUpload> _prepareAttachmentForUpload({
    required String filePath,
    required String fileName,
    required String contentType,
    CancelToken? cancelToken,
  }) async {
    final sourceContentType = await _validateAttachmentForUpload(
      filePath: filePath,
      contentType: contentType,
    );
    OptimizedUploadFile? optimizedFile;
    try {
      final isImage = sourceContentType.toLowerCase().startsWith('image/');
      optimizedFile = isImage
          ? await _imageUploadOptimizer.optimizeForSupportImage(
              XFile(filePath, name: fileName, mimeType: sourceContentType),
              cancelToken: cancelToken,
            )
          : null;
      final uploadFile =
          optimizedFile?.file ??
          XFile(filePath, name: fileName, mimeType: sourceContentType);
      final uploadContentType = await _validateAttachmentForUpload(
        filePath: uploadFile.path,
        contentType: uploadFile.mimeType ?? sourceContentType,
      );

      return PreparedSupportAttachmentUpload(
        filePath: uploadFile.path,
        contentType: uploadContentType,
        safeFileName: _safeMultipartFileName(
          fileName: uploadFile.name,
          filePath: uploadFile.path,
        ),
        optimizedFile: optimizedFile,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Support.Chat',
        operation: 'prepare_attachment_for_upload',
        message: 'Failed to prepare support attachment upload',
        context: {'contentType': contentType},
        error: error,
        stackTrace: stackTrace,
      );
      await optimizedFile?.dispose();
      rethrow;
    }
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final payload = NetworkErrorMapper.parseApiPayload(error);
    final safeMessage = NetworkErrorMapper.safePayloadMessage(payload);
    if (safeMessage != null) {
      return NetworkErrorMapper.fromMessage(
        error,
        safeMessage,
        includeCause: false,
      );
    }

    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return const AppException('support.unavailable', statusCode: 503);
    }

    return NetworkErrorMapper.fallback(
      error,
      fallbackMessage: fallbackMessage,
      includeCause: false,
    );
  }
}

String _supportPathSegment(String value) {
  return Uri.encodeComponent(value.trim());
}

int _supportPageSize(int take) {
  return take.clamp(1, 100);
}

class PreparedSupportAttachmentUpload {
  const PreparedSupportAttachmentUpload({
    required this.filePath,
    required this.contentType,
    required this.safeFileName,
    this.optimizedFile,
  });

  final String filePath;
  final String contentType;
  final String safeFileName;
  final OptimizedUploadFile? optimizedFile;

  Future<void> dispose() => optimizedFile?.dispose() ?? Future.value();
}
