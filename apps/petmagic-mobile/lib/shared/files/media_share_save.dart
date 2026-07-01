import 'dart:io';

import 'package:dio/dio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

import 'device_file_saver.dart';
import 'file_name_sanitizer.dart';
import 'media_signature.dart';
import 'temp_media_cleanup.dart';

Future<File> cacheRemoteMediaFile({
  required String mediaUrl,
  required String fileName,
  Dio? client,
  Duration downloadTimeout = const Duration(seconds: 20),
  CancelToken? cancelToken,
  int maxBytes = defaultRemoteFileDownloadMaxBytes,
}) async {
  final bytes = await downloadFileBytes(
    mediaUrl,
    client: client,
    timeout: downloadTimeout,
    cancelToken: cancelToken,
    maxBytes: maxBytes,
  );
  if (!hasSupportedMediaSignature(bytes)) {
    throw StateError('Downloaded media file is not usable.');
  }
  final safeFileName = sanitizeFileName(
    fileName,
    fallback: 'petmagic_${DateTime.now().millisecondsSinceEpoch}',
  );
  final tempFile = TempMediaCleanup.createScopedTempFile(safeFileName);

  await tempFile.writeAsBytes(bytes, flush: true);
  return tempFile;
}

Future<void> shareRemoteMediaFile({
  required String mediaUrl,
  required String fileName,
  String? title,
  Duration downloadTimeout = const Duration(seconds: 20),
  CancelToken? cancelToken,
  int maxBytes = defaultRemoteFileDownloadMaxBytes,
}) async {
  final tempFile = await cacheRemoteMediaFile(
    mediaUrl: mediaUrl,
    fileName: fileName,
    downloadTimeout: downloadTimeout,
    cancelToken: cancelToken,
    maxBytes: maxBytes,
  );

  try {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(tempFile.path)], title: title, text: title),
    );
  } finally {
    await TempMediaCleanup.deleteIfExists(tempFile);
  }
}

Future<void> shareLocalMediaFile({
  required String filePath,
  required String fileName,
  String? title,
  CancelToken? cancelToken,
}) async {
  _throwIfCancelled(cancelToken, filePath);
  final usablePath = await usableLocalMediaPath(filePath);
  if (usablePath == null) {
    throw StateError('Local media file is not usable.');
  }

  final safeFileName = sanitizeFileName(
    fileName,
    fallback: 'petmagic_${DateTime.now().millisecondsSinceEpoch}',
  );
  _throwIfCancelled(cancelToken, filePath);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(usablePath, name: safeFileName)],
      title: title,
      text: title,
    ),
  );
}

Future<bool> saveRemoteMediaToGallery({
  required String mediaUrl,
  required String fileName,
  required bool isVideo,
  String? albumName,
  Duration downloadTimeout = const Duration(seconds: 20),
  CancelToken? cancelToken,
  int maxBytes = defaultRemoteFileDownloadMaxBytes,
}) async {
  final tempFile = await cacheRemoteMediaFile(
    mediaUrl: mediaUrl,
    fileName: fileName,
    downloadTimeout: downloadTimeout,
    cancelToken: cancelToken,
    maxBytes: maxBytes,
  );

  final saveTitle = sanitizeFileName(
    fileName,
    fallback: 'petmagic_${DateTime.now().millisecondsSinceEpoch}',
  );

  try {
    if (isVideo) {
      await PhotoManager.editor.saveVideo(
        tempFile,
        title: saveTitle,
        relativePath: albumName,
      );
    } else {
      await PhotoManager.editor.saveImageWithPath(
        tempFile.path,
        title: saveTitle,
        relativePath: albumName,
      );
    }
    await TempMediaCleanup.deleteIfExists(tempFile);
    return true;
  } catch (error, stackTrace) {
    AppLogger.warn(
      feature: 'Shared.MediaShareSave',
      operation: 'save_remote_to_gallery',
      message: 'Remote media save to gallery failed',
      context: {
        'isVideo': isVideo,
        'hasAlbumName': albumName?.trim().isNotEmpty ?? false,
        'extension': extractFileExtension(fileName) ?? '',
      },
      error: error,
      stackTrace: stackTrace,
    );
    TempMediaCleanup.scheduleTtlSweep();
    return false;
  }
}

Future<bool> saveLocalMediaToGallery({
  required String filePath,
  required String fileName,
  required bool isVideo,
  String? albumName,
  CancelToken? cancelToken,
}) async {
  _throwIfCancelled(cancelToken, filePath);
  final usablePath = await usableLocalMediaPath(filePath);
  if (usablePath == null) {
    return false;
  }
  final file = File(usablePath);

  final saveTitle = sanitizeFileName(
    fileName,
    fallback: 'petmagic_${DateTime.now().millisecondsSinceEpoch}',
  );

  try {
    _throwIfCancelled(cancelToken, filePath);
    if (isVideo) {
      await PhotoManager.editor.saveVideo(
        file,
        title: saveTitle,
        relativePath: albumName,
      );
    } else {
      await PhotoManager.editor.saveImageWithPath(
        file.path,
        title: saveTitle,
        relativePath: albumName,
      );
    }
    return true;
  } on DioException catch (error) {
    if (CancelToken.isCancel(error)) {
      rethrow;
    }
    AppLogger.warn(
      feature: 'Shared.MediaShareSave',
      operation: 'save_local_to_gallery',
      message: 'Local media save to gallery failed',
      context: {
        'isVideo': isVideo,
        'hasAlbumName': albumName?.trim().isNotEmpty ?? false,
        'extension': extractFileExtension(fileName) ?? '',
      },
      error: error,
      stackTrace: error.stackTrace,
    );
    return false;
  } catch (error, stackTrace) {
    AppLogger.warn(
      feature: 'Shared.MediaShareSave',
      operation: 'save_local_to_gallery',
      message: 'Local media save to gallery failed',
      context: {
        'isVideo': isVideo,
        'hasAlbumName': albumName?.trim().isNotEmpty ?? false,
        'extension': extractFileExtension(fileName) ?? '',
      },
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

Future<String?> usableLocalMediaPath(String? localPath) async {
  return usableLocalMediaPathSync(localPath);
}

String? usableLocalMediaPathSync(String? localPath) {
  final path = localPath?.trim();
  if (path == null || path.isEmpty) {
    return null;
  }

  try {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final stat = file.statSync();
    if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
      return null;
    }
    final handle = file.openSync();
    try {
      final header = handle.readSync(16);
      if (!hasSupportedMediaSignature(header)) {
        return null;
      }
    } finally {
      handle.closeSync();
    }
    return file.path;
  } catch (error, stackTrace) {
    AppLogger.warn(
      feature: 'Shared.MediaShareSave',
      operation: 'validate_local_media_path',
      message: 'Local media path validation failed',
      context: {'name': _safePathLabel(path)},
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

void _throwIfCancelled(CancelToken? cancelToken, String path) {
  if (cancelToken?.isCancelled != true) {
    return;
  }

  throw DioException.requestCancelled(
    requestOptions: RequestOptions(path: path),
    reason: 'media_action_cancelled',
  );
}

String _safePathLabel(String path) {
  final segments = Uri.file(path).pathSegments;
  return segments.isEmpty ? path : segments.last;
}
