import 'dart:io';

import 'package:dio/dio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'device_file_saver.dart';
import 'file_name_sanitizer.dart';
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
  if (!_hasSupportedMediaSignature(bytes)) {
    throw StateError('Downloaded media file is not usable.');
  }
  final safeFileName = sanitizeFileName(
    fileName,
    fallback: 'petmagic_${DateTime.now().millisecondsSinceEpoch}',
  );
  final tempFile = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}petmagic_$safeFileName',
  );

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

  final shareResult = await SharePlus.instance.share(
    ShareParams(files: [XFile(tempFile.path)], title: title, text: title),
  );

  if (shareResult.status == ShareResultStatus.success) {
    await TempMediaCleanup.deleteIfExists(tempFile);
  } else {
    TempMediaCleanup.scheduleTtlSweep();
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
  } catch (_) {
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
    return false;
  } catch (_) {
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
      if (!_hasSupportedMediaSignature(header)) {
        return null;
      }
    } finally {
      handle.closeSync();
    }
    return file.path;
  } on Object {
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

bool _hasSupportedMediaSignature(List<int> header) {
  if (_startsWith(header, const [0xFF, 0xD8, 0xFF])) {
    return true;
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
    return true;
  }
  if (header.length >= 12 &&
      _asciiEquals(header, 0, 'RIFF') &&
      _asciiEquals(header, 8, 'WEBP')) {
    return true;
  }
  if (_asciiEquals(header, 0, 'GIF8')) {
    return true;
  }
  if (header.length >= 12 && _asciiEquals(header, 4, 'ftyp')) {
    return true;
  }
  return false;
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
