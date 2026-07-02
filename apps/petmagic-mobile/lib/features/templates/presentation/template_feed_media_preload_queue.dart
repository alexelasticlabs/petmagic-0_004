import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';

final templateFeedMediaPreloadQueueProvider =
    Provider.autoDispose<TemplateFeedMediaPreloadQueue>((ref) {
      final queue = TemplateFeedMediaPreloadQueue();
      ref.onDispose(() => queue.cancelAll(reason: 'provider_dispose'));
      return queue;
    });

@immutable
class TemplateFeedMediaPreloadCandidate {
  const TemplateFeedMediaPreloadCandidate({
    required this.templateId,
    required this.url,
    this.mediaVersion,
  });

  final String templateId;
  final String url;
  final int? mediaVersion;

  String get cacheKey =>
      TemplateMediaCache.cacheKeyForMedia(url, mediaVersion: mediaVersion);
}

typedef TemplateFeedPreviewCacheLookup =
    Future<File?> Function(String url, {int? mediaVersion});

typedef TemplateFeedPreviewFetch =
    Future<File> Function(String url, {int? mediaVersion});

class TemplateFeedMediaPreloadQueue {
  TemplateFeedMediaPreloadQueue({
    TemplateFeedPreviewCacheLookup? previewCacheLookup,
    TemplateFeedPreviewFetch? previewFetch,
    int maxVideoPreloads = 2,
  }) : _previewCacheLookup =
           previewCacheLookup ?? TemplateMediaCache.getCachedPreviewFile,
       _previewFetch = previewFetch ?? TemplateMediaCache.fetchPreviewFile,
       _maxVideoPreloads = maxVideoPreloads.clamp(0, 2);

  final TemplateFeedPreviewCacheLookup _previewCacheLookup;
  final TemplateFeedPreviewFetch _previewFetch;
  final int _maxVideoPreloads;
  final Set<String> _activeCacheKeys = <String>{};
  int _generation = 0;
  int _mediaCacheHits = 0;
  int _mediaCacheMisses = 0;
  int _trafficBytesThisFeedSession = 0;
  int _videoPreloadCancellations = 0;

  int get mediaCacheHits => _mediaCacheHits;
  int get mediaCacheMisses => _mediaCacheMisses;
  int get trafficBytesThisFeedSession => _trafficBytesThisFeedSession;
  int get videoPreloadCancellations => _videoPreloadCancellations;
  int get activePreloadCount => _activeCacheKeys.length;

  void preloadVideoCandidates(
    Iterable<TemplateFeedMediaPreloadCandidate> candidates, {
    required String reason,
  }) {
    final selected = _dedupe(
      candidates,
    ).take(_maxVideoPreloads).toList(growable: false);
    final selectedKeys = selected
        .map((candidate) => candidate.cacheKey)
        .toSet();

    if (_activeCacheKeys.any((key) => !selectedKeys.contains(key))) {
      cancelAll(reason: 'video_candidates_changed');
    }

    final generation = _generation;
    for (final candidate in selected) {
      if (!_activeCacheKeys.add(candidate.cacheKey)) {
        continue;
      }
      unawaited(_preloadSingleVideo(candidate, generation, reason: reason));
    }
  }

  void cancelAll({required String reason}) {
    if (_activeCacheKeys.isNotEmpty) {
      _videoPreloadCancellations += _activeCacheKeys.length;
      AppLogger.info(
        feature: 'Templates.FeedMediaPreload',
        operation: 'video_preload_cancellations',
        message: 'Template feed media preload queue was cancelled.',
        context: {
          'reason': reason,
          'cancelledCount': _activeCacheKeys.length,
          'totalCount': _videoPreloadCancellations,
        },
      );
    }

    _generation++;
    _activeCacheKeys.clear();
  }

  Iterable<TemplateFeedMediaPreloadCandidate> _dedupe(
    Iterable<TemplateFeedMediaPreloadCandidate> candidates,
  ) sync* {
    final seen = <String>{};
    for (final candidate in candidates) {
      final url = candidate.url.trim();
      if (url.isEmpty || !seen.add(candidate.cacheKey)) {
        continue;
      }
      yield TemplateFeedMediaPreloadCandidate(
        templateId: candidate.templateId,
        url: url,
        mediaVersion: candidate.mediaVersion,
      );
    }
  }

  Future<void> _preloadSingleVideo(
    TemplateFeedMediaPreloadCandidate candidate,
    int generation, {
    required String reason,
  }) async {
    try {
      final cachedFile = await _previewCacheLookup(
        candidate.url,
        mediaVersion: candidate.mediaVersion,
      );
      if (!_isCurrent(candidate, generation)) {
        _recordStalePreload(candidate, reason: 'after_cache_lookup');
        return;
      }

      if (cachedFile != null) {
        _mediaCacheHits++;
        _logCacheMetrics(reason: reason);
        return;
      }

      _mediaCacheMisses++;
      final file = await _previewFetch(
        candidate.url,
        mediaVersion: candidate.mediaVersion,
      );
      if (!_isCurrent(candidate, generation)) {
        _recordStalePreload(candidate, reason: 'after_fetch');
        return;
      }

      _trafficBytesThisFeedSession += await _safeFileLength(file);
      _logCacheMetrics(reason: reason);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.FeedMediaPreload',
        operation: 'preload_video_candidate',
        message: 'Template feed video preload failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'templateId': candidate.templateId, 'reason': reason},
      );
    } finally {
      _activeCacheKeys.remove(candidate.cacheKey);
    }
  }

  bool _isCurrent(TemplateFeedMediaPreloadCandidate candidate, int generation) {
    return generation == _generation &&
        _activeCacheKeys.contains(candidate.cacheKey);
  }

  void _recordStalePreload(
    TemplateFeedMediaPreloadCandidate candidate, {
    required String reason,
  }) {
    _videoPreloadCancellations++;
    AppLogger.info(
      feature: 'Templates.FeedMediaPreload',
      operation: 'video_preload_cancellations',
      message: 'Template feed stale video preload was discarded.',
      context: {
        'templateId': candidate.templateId,
        'reason': reason,
        'totalCount': _videoPreloadCancellations,
      },
    );
  }

  Future<int> _safeFileLength(File file) async {
    try {
      return await file.length();
    } on FileSystemException {
      return 0;
    }
  }

  void _logCacheMetrics({required String reason}) {
    final total = _mediaCacheHits + _mediaCacheMisses;
    final hitRate = total == 0 ? 0 : _mediaCacheHits / total;
    AppLogger.info(
      feature: 'Templates.FeedMediaPreload',
      operation: 'media_cache_hit_rate',
      message: 'Template feed media cache metrics updated.',
      context: {
        'reason': reason,
        'hitRate': hitRate,
        'hits': _mediaCacheHits,
        'misses': _mediaCacheMisses,
        'trafficBytes': _trafficBytesThisFeedSession,
      },
    );
    AppLogger.info(
      feature: 'Templates.FeedMediaPreload',
      operation: 'traffic_per_feed_session',
      message: 'Template feed media traffic budget updated.',
      context: {'reason': reason, 'trafficBytes': _trafficBytesThisFeedSession},
    );
  }
}
