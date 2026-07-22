import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/support/domain/support_attachment_validation.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';

/// Validates, optimizes and names support attachments before multipart upload.
final class SupportAttachmentUploadPreparer {
  const SupportAttachmentUploadPreparer({
    required ImageUploadOptimizer imageUploadOptimizer,
  }) : _imageUploadOptimizer = imageUploadOptimizer;

  static const _imageMaxFileSizeBytes = UploadMediaPolicy.supportImageMaxBytes;
  static const _videoMaxFileSizeBytes = UploadMediaPolicy.supportVideoMaxBytes;
  static const _safeFileNameMaxLength = 120;

  final ImageUploadOptimizer _imageUploadOptimizer;

  Future<PreparedSupportAttachmentUpload> prepare({
    required String filePath,
    required String fileName,
    required String contentType,
    RequestCancellation? cancelToken,
  }) async {
    final sourceContentType = await _validate(
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
      final uploadContentType = await _validate(
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
        context: {'contentType': _safeContentTypeForLog(contentType)},
        error: error,
        stackTrace: stackTrace,
      );
      await optimizedFile?.dispose();
      rethrow;
    }
  }

  Future<String> _validate({
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
      _throwValidationError(declaredValidation.error);
    }

    final detectedContentType = await _detectContentType(filePath);
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
      _throwValidationError(detectedValidation.error);
    }
    return detectedContentType;
  }

  Never _throwValidationError(SupportAttachmentValidationError? error) {
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

  Future<String?> _detectContentType(String path) async {
    try {
      final chunks = await File(path).openRead(0, 32).toList();
      final header = [for (final chunk in chunks) ...chunk];
      return detectSupportAttachmentContentType(header);
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
    final normalized = value.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '';
    }
    final slashIndex = normalized.lastIndexOf('/');
    return slashIndex < 0 ? normalized : normalized.substring(slashIndex + 1);
  }

  String _sanitizeFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (sanitized.length <= _safeFileNameMaxLength) {
      return sanitized;
    }
    final extensionIndex = sanitized.lastIndexOf('.');
    final extension = extensionIndex > 0
        ? sanitized.substring(extensionIndex)
        : '';
    if (extension.length > 1 && extension.length <= 16) {
      final baseLength = _safeFileNameMaxLength - extension.length;
      return '${sanitized.substring(0, baseLength)}$extension';
    }
    return sanitized.substring(0, _safeFileNameMaxLength);
  }
}

String _safeContentTypeForLog(String contentType) {
  final normalized = contentType.trim().toLowerCase().replaceAll(
    RegExp(r'[\x00-\x1F\x7F]'),
    '',
  );
  if (normalized.isEmpty) {
    return 'unknown';
  }
  return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
}

final class PreparedSupportAttachmentUpload {
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
