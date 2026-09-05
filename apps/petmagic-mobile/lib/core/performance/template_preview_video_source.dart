import 'dart:io';

import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

typedef TemplatePreviewFileLookup =
    Future<File?> Function(String url, {int? mediaVersion});
typedef TemplatePreviewFileFetch =
    Future<File> Function(String url, {int? mediaVersion});

/// A file already owned by the bounded media cache; no extra in-memory copy.
class TemplatePreviewVideoSource {
  const TemplatePreviewVideoSource({required this.url, required this.file});

  final String url;
  final File file;
}

/// Prefer cached detail, then either cached feed derivative. On a cold miss,
/// download the adaptive derivative first so detail cannot delay first playback.
Future<TemplatePreviewVideoSource?> resolveTemplatePreviewVideoSource(
  String detailUrl, {
  List<String> fallbackUrls = const [],
  int? mediaVersion,
  bool cachedOnly = false,
  Set<String> excludedUrls = const {},
  TemplatePreviewFileLookup lookup = TemplateMediaCache.getCachedPreviewFile,
  TemplatePreviewFileFetch fetch = TemplateMediaCache.fetchPreviewFile,
}) async {
  if (parseSafeGenerationMediaUri(detailUrl) == null) {
    throw const FormatException('unsafe_template_preview_url');
  }
  final urls = <String>{detailUrl, ...fallbackUrls}
      .where(
        (url) =>
            !excludedUrls.contains(url) &&
            parseSafeGenerationMediaUri(url) != null,
      )
      .take(4)
      .toList();
  if (urls.isEmpty) return null;
  for (final url in urls) {
    final file = await lookup(url, mediaVersion: mediaVersion);
    if (file != null) return TemplatePreviewVideoSource(url: url, file: file);
  }
  if (cachedOnly) return null;
  final downloadOrder = [
    ...urls.where((url) => url != detailUrl),
    if (urls.contains(detailUrl)) detailUrl,
  ];
  for (var index = 0; index < downloadOrder.length; index++) {
    final url = downloadOrder[index];
    try {
      final file = await fetch(url, mediaVersion: mediaVersion);
      return TemplatePreviewVideoSource(url: url, file: file);
    } catch (error) {
      if (index == downloadOrder.length - 1 ||
          error is StateError &&
              (error.message == 'template_preview_cache_invalidated' ||
                  error.message == 'template_preview_download_too_large')) {
        rethrow;
      }
    }
  }
  return null;
}
