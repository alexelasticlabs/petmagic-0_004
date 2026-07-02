import 'dart:io';

import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createCachedTemplatePreviewVideoController(
  String previewUrl, {
  int? mediaVersion,
  Uri? fallbackUri,
}) async {
  File? cachedFile;
  try {
    cachedFile = await TemplateMediaCache.getCachedPreviewFile(
      previewUrl,
      mediaVersion: mediaVersion,
    );
    cachedFile ??= await TemplateMediaCache.fetchPreviewFile(
      previewUrl,
      mediaVersion: mediaVersion,
    );
  } catch (error) {
    if (_isPreviewCacheInvalidation(error)) {
      rethrow;
    }
    cachedFile = null;
  }

  if (cachedFile != null) {
    return VideoPlayerController.file(cachedFile);
  }

  return VideoPlayerController.networkUrl(fallbackUri ?? Uri.parse(previewUrl));
}

bool _isPreviewCacheInvalidation(Object error) {
  return error is StateError &&
      error.message == 'template_preview_cache_invalidated';
}
