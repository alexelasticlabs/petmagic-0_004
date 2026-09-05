part of 'template_media_cache.dart';

final class _TemplateMediaCacheDownloads {
  static final Map<String, MediaDownloadConstraint> _constraints = {};

  static Future<File> fetch(
    String url, {
    required bool preview,
    int? mediaVersion,
    MediaPrefetchBudget? prefetchBudget,
  }) {
    Future<File> retry() => _TemplateMediaCacheDownloads.fetch(
      url,
      preview: preview,
      mediaVersion: mediaVersion,
      prefetchBudget: prefetchBudget,
    );
    final clearing = TemplateMediaCache._cacheClearInProgress;
    if (clearing != null) return clearing.then((_) => retry());
    final cacheKey = TemplateMediaCache.cacheKeyForMedia(
      url,
      mediaVersion: mediaVersion,
    );
    final requestKey = '${preview ? 'preview' : 'thumbnail'}|$cacheKey';
    final fetches = preview
        ? TemplateMediaCache._previewFetchesByUrl
        : TemplateMediaCache._thumbnailFetchesByUrl;
    final blocked = preview
        ? TemplateMediaCache._blockedPreviewCacheUrls
        : TemplateMediaCache._blockedThumbnailCacheUrls;
    final generations = preview
        ? TemplateMediaCache._latestPreviewFetchGenerationByUrl
        : TemplateMediaCache._latestThumbnailFetchGenerationByUrl;
    final invalidations = preview
        ? TemplateMediaCache._previewInvalidationByUrl
        : TemplateMediaCache._thumbnailInvalidationByUrl;
    final maxBlocked = preview
        ? TemplateMediaCache._maxBlockedPreviewCacheUrls
        : TemplateMediaCache._maxBlockedThumbnailCacheUrls;
    final generation = TemplateMediaCache._cacheGeneration;
    final inFlight = fetches[cacheKey];
    if (inFlight != null) {
      if (blocked.contains(cacheKey) || generations[cacheKey] != generation) {
        return _TemplateMediaCacheMaintenance.waitForInvalidatedFetch(
          inFlight,
          retry,
        );
      }
      final constraint = _constraints[requestKey];
      // A user opening the preview promotes its already running HTTP request.
      if (prefetchBudget == null) constraint?.promote();
      if (constraint == null || identical(constraint.budget, prefetchBudget)) {
        return inFlight;
      }
      return _joinPromotedOrNewQueue(inFlight, retry);
    }
    final constraint = prefetchBudget == null
        ? null
        : MediaDownloadConstraint(prefetchBudget);
    if (constraint != null) _constraints[requestKey] = constraint;
    MediaCacheTracking.rememberLatestGeneration(
      generations,
      cacheKey,
      generation,
      maxEntries: maxBlocked,
    );
    final download = preview
        ? TemplateMediaCache._fetchPreviewFile
        : TemplateMediaCache._fetchThumbnailFile;
    late final Future<File> fetch;
    fetch =
        download(
          url,
          cacheKey: cacheKey,
          mediaVersion: mediaVersion,
          generation: generation,
          urlInvalidation: invalidations[cacheKey] ?? 0,
          constraint: constraint,
        ).whenComplete(() {
          constraint?.dispose();
          if (identical(fetches[cacheKey], fetch)) fetches.remove(cacheKey);
          if (identical(_constraints[requestKey], constraint)) {
            _constraints.remove(requestKey);
          }
        });
    MediaCacheTracking.rememberInFlightFetch(
      fetches,
      cacheKey,
      fetch,
      maxEntries: preview
          ? TemplateMediaCache._maxPreviewInFlightFetches
          : TemplateMediaCache._maxThumbnailInFlightFetches,
    );
    return fetch;
  }

  static Future<File> _joinPromotedOrNewQueue(
    Future<File> previous,
    Future<File> Function() retry,
  ) async {
    try {
      return await previous;
    } on MediaPrefetchLimitException {
      // Let cache manager close its failed subject before a required retry.
      await Future<void>.delayed(Duration.zero);
      return retry();
    }
  }
}
