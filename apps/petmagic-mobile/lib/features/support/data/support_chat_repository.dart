export 'package:petmagic_mobile/features/support/application/support_repository.dart'
    show SupportRepository, supportChatRepositoryProvider;

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/features/support/application/support_repository.dart';
import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_dto_mapper.dart';
import 'package:petmagic_mobile/features/support/data/support_attachment_upload_preparer.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

final dioSupportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportChatRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
    imageUploadOptimizer: const ImageUploadOptimizer(),
  );
});

class SupportChatRepository implements SupportRepository {
  SupportChatRepository({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    ImageUploadOptimizer? imageUploadOptimizer,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _attachmentUploadPreparer = SupportAttachmentUploadPreparer(
         imageUploadOptimizer:
             imageUploadOptimizer ?? const ImageUploadOptimizer(),
       ),
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final SupportAttachmentUploadPreparer _attachmentUploadPreparer;
  final AuthSessionCoordinator _authSessionCoordinator;

  static const _maxAttachmentCount = 5;

  @override
  Future<SupportChatConversation> openConversation({
    String? initialMessage,
    String source = 'MobileChat',
    String? assistantScenario,
    String? relatedGenerationId,
    String? relatedPaymentId,
    String? relatedSubscriptionId,
    RequestCancellation? cancelToken,
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
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return mapSupportChatConversationDto(response.data ?? const {});
  }

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    RequestCancellation? cancelToken,
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
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return mapSupportChatConversationDto(response.data ?? const {});
  }

  @override
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

    return mapSupportChatMessageDto(response.data ?? const {});
  }

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
    if (attachments.length > _maxAttachmentCount) {
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

  @override
  Future<void> markConversationRead(
    String conversationId, {
    RequestCancellation? cancelToken,
  }) async {
    final encodedConversationId = _supportPathSegment(conversationId);
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/support/conversation/$encodedConversationId/read',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
  }

  @override
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

    return mapSupportChatConversationDto(response.data ?? const {});
  }

  @override
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

    return mapSupportChatConversationDto(response.data ?? const {});
  }

  @override
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

    return mapSupportChatConversationDto(response.data ?? const {});
  }

  @override
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

    return mapSupportChatConversationDto(response.data ?? const {});
  }

  @override
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

  @override
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
