import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';

import 'device_file_saver.dart';
import 'temp_media_cleanup.dart';

Future<File> cacheRemoteMediaFile({
  required String mediaUrl,
  required String fileName,
  Duration downloadTimeout = const Duration(seconds: 20),
  CancelToken? cancelToken,
}) async {
  final bytes = await downloadFileBytes(
    mediaUrl,
    timeout: downloadTimeout,
    cancelToken: cancelToken,
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
}) async {
  final tempFile = await cacheRemoteMediaFile(
    mediaUrl: mediaUrl,
    fileName: fileName,
    downloadTimeout: downloadTimeout,
    cancelToken: cancelToken,
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
}) async {
  final tempFile = await cacheRemoteMediaFile(
    mediaUrl: mediaUrl,
    fileName: fileName,
    downloadTimeout: downloadTimeout,
    cancelToken: cancelToken,
  );

  final saved = isVideo
      ? await GallerySaver.saveVideo(tempFile.path, albumName: albumName)
      : await GallerySaver.saveImage(tempFile.path, albumName: albumName);

  final isSaved = saved ?? false;
  if (isSaved) {
    await TempMediaCleanup.deleteIfExists(tempFile);
  } else {
    TempMediaCleanup.scheduleTtlSweep();
  }

  return isSaved;
}
