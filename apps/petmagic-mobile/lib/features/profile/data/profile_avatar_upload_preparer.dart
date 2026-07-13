import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';

/// Owns avatar extension, signature and size validation plus optimization.
final class ProfileAvatarUploadPreparer {
  const ProfileAvatarUploadPreparer({
    required ImageUploadOptimizer imageUploadOptimizer,
  }) : _imageUploadOptimizer = imageUploadOptimizer;

  static const _maxAvatarBytes = UploadMediaPolicy.avatarMaxBytes;

  final ImageUploadOptimizer _imageUploadOptimizer;

  Future<PreparedProfileAvatarUpload> prepare(
    String filePath, {
    RequestCancellation? cancelToken,
  }) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final mediaType = _resolveMediaType(fileName);
    OptimizedUploadFile? optimizedAvatar;
    try {
      optimizedAvatar = await _imageUploadOptimizer.optimizeForAvatar(
        XFile(filePath, name: fileName, mimeType: mediaType.toString()),
        cancelToken: cancelToken,
      );
      final uploadFile = optimizedAvatar.file;
      final uploadFileName = uploadFile.name.isNotEmpty
          ? uploadFile.name
          : uploadFile.path.split(Platform.pathSeparator).last;
      final uploadMediaType = await _validateAvatarForUpload(
        filePath: uploadFile.path,
        mediaType: _resolveMediaType(uploadFileName),
      );
      return PreparedProfileAvatarUpload(
        filePath: uploadFile.path,
        fileName: uploadFileName,
        mediaType: uploadMediaType,
        optimizedFile: optimizedAvatar,
      );
    } catch (error, stackTrace) {
      await optimizedAvatar?.dispose();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<MediaType> _validateAvatarForUpload({
    required String filePath,
    required MediaType mediaType,
  }) async {
    if (!_isAllowedAvatarMediaType(mediaType)) {
      throw const AppException('profile.action_failed', statusCode: 400);
    }

    int fileSizeBytes;
    try {
      fileSizeBytes = await File(filePath).length();
    } on FileSystemException catch (error) {
      throw AppException(
        'profile.action_failed',
        statusCode: 400,
        cause: error,
      );
    }
    if (fileSizeBytes <= 0 || fileSizeBytes > _maxAvatarBytes) {
      throw const AppException('profile.action_failed', statusCode: 400);
    }

    final detectedMediaType = await _detectAvatarMediaType(filePath);
    if (detectedMediaType == null ||
        !_isAllowedAvatarMediaType(detectedMediaType)) {
      throw const AppException('profile.action_failed', statusCode: 400);
    }
    return detectedMediaType;
  }

  bool _isAllowedAvatarMediaType(MediaType mediaType) {
    return mediaType.type == 'image' &&
        (mediaType.subtype == 'jpeg' ||
            mediaType.subtype == 'png' ||
            mediaType.subtype == 'webp');
  }

  MediaType _resolveMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => throw const AppException('profile.action_failed', statusCode: 400),
    };
  }

  Future<MediaType?> _detectAvatarMediaType(String path) async {
    try {
      final chunks = await File(path).openRead(0, 32).toList();
      final header = [for (final chunk in chunks) ...chunk];
      final contentType = detectAvatarUploadContentType(header);
      return contentType == null ? null : MediaType.parse(contentType);
    } on FileSystemException catch (error) {
      throw AppException(
        'profile.action_failed',
        statusCode: 400,
        cause: error,
      );
    }
  }
}

final class PreparedProfileAvatarUpload {
  const PreparedProfileAvatarUpload({
    required this.filePath,
    required this.fileName,
    required this.mediaType,
    required this.optimizedFile,
  });

  final String filePath;
  final String fileName;
  final MediaType mediaType;
  final OptimizedUploadFile optimizedFile;

  Future<void> dispose() => optimizedFile.dispose();
}
