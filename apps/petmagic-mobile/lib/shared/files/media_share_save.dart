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
  Duration downloadTimeout = const Duration(seconds: 20),
  CancelToken? cancelToken,
  int maxBytes = defaultRemoteFileDownloadMaxBytes,
}) async {
  final bytes = await downloadFileBytes(
    mediaUrl,
    timeout: downloadTimeout,
    cancelToken: cancelToken,
    maxBytes: maxBytes,
  );
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
