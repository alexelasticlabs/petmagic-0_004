import 'dart:io';

import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
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

  final safeFallbackUri =
      fallbackUri ?? parseSafeGenerationMediaUri(previewUrl);
  if (safeFallbackUri == null) {
    throw const FormatException('unsafe_template_preview_url');
  }

  return VideoPlayerController.networkUrl(safeFallbackUri);
}

bool _isPreviewCacheInvalidation(Object error) {
  return error is StateError &&
      error.message == 'template_preview_cache_invalidated';
}
