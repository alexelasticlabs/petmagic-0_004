import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/domain/support_attachment_validation.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

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
  static const _imageMaxFileSizeBytes = 10 * 1024 * 1024;
  static const _videoMaxFileSizeBytes = 50 * 1024 * 1024;

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
    final query = <String, dynamic>{'take': take};
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
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) async => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/messages',
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
          '/api/support/conversation/$conversationId/attachments',
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
          '/api/support/conversation/$conversationId/messages/attachments',
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
    final prepared = await _prepareAttachmentForUpload(
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
      cancelToken: cancelToken,
    );
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/support/conversation/$conversationId/messages/$messageId/attachment/retry',
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

  Future<void> markConversationRead(String conversationId) async {
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/support/conversation/$conversationId/read',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }

  Future<SupportChatConversation> resolveConversation(
    String conversationId,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/resolve',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatConversation> reopenConversation(
    String conversationId,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/reopen',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatConversation> closeConversation(
    String conversationId,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/close',
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
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/feedback',
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
    if (_startsWith(header, const [0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (_startsWith(header, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return 'image/png';
    }
    if (header.length >= 12 &&
        _asciiEquals(header, 0, 'RIFF') &&
        _asciiEquals(header, 8, 'WEBP')) {
      return 'image/webp';
    }
    if (header.length >= 12 && _asciiEquals(header, 4, 'ftyp')) {
      final brand = String.fromCharCodes(header.skip(8).take(4)).toLowerCase();
      const mp4Brands = {
        'mp41',
        'mp42',
        'isom',
        'iso2',
        'avc1',
        'm4v ',
        'm4a ',
      };
      if (brand == 'qt  ') {
        return 'video/quicktime';
      }
      if (mp4Brands.contains(brand)) {
        return 'video/mp4';
      }
    }

    return null;
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

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  bool _asciiEquals(List<int> bytes, int offset, String value) {
    if (bytes.length < offset + value.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
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
    final isImage = contentType.toLowerCase().startsWith('image/');
    final optimizedFile = isImage
        ? await _imageUploadOptimizer.optimizeForSupportImage(
            XFile(filePath, name: fileName, mimeType: contentType),
            cancelToken: cancelToken,
          )
        : null;
    final uploadFile =
        optimizedFile?.file ??
        XFile(filePath, name: fileName, mimeType: contentType);
    final uploadContentType = await _validateAttachmentForUpload(
      filePath: uploadFile.path,
      contentType: uploadFile.mimeType ?? contentType,
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
