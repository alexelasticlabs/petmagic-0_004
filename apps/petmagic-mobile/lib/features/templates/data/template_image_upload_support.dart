import 'dart:io';

import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';

/// Shared filename, MIME and signature policy for template and pet images.
abstract final class TemplateImageUploadSupport {
  static String contentTypeFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static String safeFileName(String rawFileName) {
    final basename = rawFileName
        .replaceAll(r'\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    return sanitizeFileName(basename, fallback: 'petmagic_source_image.jpg');
  }

  static bool isAllowedImageContentType(String contentType) {
    final normalized = _normalizedContentType(contentType);
    return normalized == 'image/jpeg' ||
        normalized == 'image/png' ||
        normalized == 'image/webp' ||
        normalized == 'image/heic' ||
        normalized == 'image/heif';
  }

  static bool isGenericBinaryContentType(String contentType) {
    final normalized = _normalizedContentType(contentType);
    return normalized == 'application/octet-stream' ||
        normalized == 'binary/octet-stream' ||
        normalized == 'application/x-binary';
  }

  static Future<String?> detectContentType(
    String path, {
    required String unavailableMessage,
  }) async {
    final header = await _fileHeader(
      path,
      unavailableMessage: unavailableMessage,
    );
    return detectTemplateSourceImageContentType(header);
  }

  static Future<int> fileSize(
    String path, {
    required String unavailableMessage,
  }) async {
    try {
      return await File(path).length();
    } on FileSystemException catch (error) {
      throw AppException(unavailableMessage, cause: error);
    }
  }

  static Future<List<int>> _fileHeader(
    String path, {
    required String unavailableMessage,
  }) async {
    try {
      final chunks = await File(path).openRead(0, 32).toList();
      return [for (final chunk in chunks) ...chunk];
    } on FileSystemException catch (error) {
      throw AppException(unavailableMessage, cause: error);
    }
  }

  static String _normalizedContentType(String contentType) =>
      contentType.split(';').first.trim().toLowerCase();
}
