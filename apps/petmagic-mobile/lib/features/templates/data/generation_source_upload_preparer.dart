import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/templates/data/template_image_upload_support.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

final class PreparedGenerationSourceUpload {
  const PreparedGenerationSourceUpload({
    required OptimizedUploadFile optimizedFile,
    required this.fileName,
    required this.contentType,
  }) : _optimizedFile = optimizedFile;

  final OptimizedUploadFile _optimizedFile;
  final String fileName;
  final String contentType;

  XFile get file => _optimizedFile.file;

  Future<void> dispose() => _optimizedFile.dispose();
}

/// Validates both the selected and optimized generation source before upload.
final class GenerationSourceUploadPreparer {
  const GenerationSourceUploadPreparer({
    required ImageUploadOptimizer imageUploadOptimizer,
  }) : _imageUploadOptimizer = imageUploadOptimizer;

  static const _maxSourceImageBytes = 12 * 1024 * 1024;

  final ImageUploadOptimizer _imageUploadOptimizer;

  Future<PreparedGenerationSourceUpload> prepare(
    LocalMediaFile sourceImage, {
    RequestCancellation? cancelToken,
  }) async {
    final sourceName = _fileName(sourceImage.name, sourceImage.path);
    final sourceContentType =
        sourceImage.mimeType ?? _contentTypeFromName(sourceName);
    await _validate(
      filePath: sourceImage.path,
      declaredContentType: sourceContentType,
    );

    final optimized = await _imageUploadOptimizer.optimizeGenerationSource(
      XFile(sourceImage.path, name: sourceName, mimeType: sourceContentType),
      cancelToken: cancelToken,
    );
    try {
      final uploadFile = optimized.file;
      final uploadName = _fileName(uploadFile.name, uploadFile.path);
      final declaredUploadContentType =
          uploadFile.mimeType ?? _contentTypeFromName(uploadName);
      final detectedUploadContentType = await _validate(
        filePath: uploadFile.path,
        declaredContentType: declaredUploadContentType,
      );
      return PreparedGenerationSourceUpload(
        optimizedFile: optimized,
        fileName: uploadName,
        contentType: detectedUploadContentType,
      );
    } catch (error, stackTrace) {
      await optimized.dispose();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<String> _validate({
    required String filePath,
    required String declaredContentType,
  }) async {
    if (!_isAllowedImageContentType(declaredContentType) &&
        !_isGenericBinaryContentType(declaredContentType)) {
      throw const AppException('templates.source_image_type_not_allowed');
    }

    final size = await TemplateImageUploadSupport.fileSize(
      filePath,
      unavailableMessage: 'templates.source_image_unavailable',
    );
    if (size <= 0) {
      throw const AppException('templates.source_image_empty');
    }
    if (size > _maxSourceImageBytes) {
      throw const AppException('templates.source_image_too_large');
    }

    final detectedContentType =
        await TemplateImageUploadSupport.detectContentType(
          filePath,
          unavailableMessage: 'templates.source_image_unavailable',
        );
    if (detectedContentType == null ||
        !_isAllowedImageContentType(detectedContentType)) {
      throw const AppException('templates.source_image_type_not_allowed');
    }
    return detectedContentType;
  }

  String _fileName(String preferredName, String path) {
    final rawName = preferredName.isNotEmpty
        ? preferredName
        : path.split(Platform.pathSeparator).last;
    return TemplateImageUploadSupport.safeFileName(rawName);
  }

  String _contentTypeFromName(String fileName) =>
      TemplateImageUploadSupport.contentTypeFromName(fileName);

  bool _isAllowedImageContentType(String contentType) =>
      TemplateImageUploadSupport.isAllowedImageContentType(contentType);

  bool _isGenericBinaryContentType(String contentType) =>
      TemplateImageUploadSupport.isGenericBinaryContentType(contentType);
}
