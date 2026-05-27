import 'dart:io';

import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';

import 'device_file_saver.dart';

Future<File> cacheRemoteMediaFile({
  required String mediaUrl,
  required String fileName,
}) async {
  final bytes = await downloadFileBytes(mediaUrl);
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
}) async {
  final tempFile = await cacheRemoteMediaFile(
    mediaUrl: mediaUrl,
    fileName: fileName,
  );

  await SharePlus.instance.share(
    ShareParams(files: [XFile(tempFile.path)], title: title, text: title),
  );
}

Future<bool> saveRemoteMediaToGallery({
  required String mediaUrl,
  required String fileName,
  required bool isVideo,
  String? albumName,
}) async {
  final tempFile = await cacheRemoteMediaFile(
    mediaUrl: mediaUrl,
    fileName: fileName,
  );

  final saved = isVideo
      ? await GallerySaver.saveVideo(tempFile.path, albumName: albumName)
      : await GallerySaver.saveImage(tempFile.path, albumName: albumName);

  return saved ?? false;
}
