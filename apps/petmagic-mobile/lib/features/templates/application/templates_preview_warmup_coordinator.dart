import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_policy.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

/// Bounds and cancels speculative template thumbnail preloads.
final class TemplatesPreviewWarmupCoordinator {
  TemplatesPreviewWarmupCoordinator({
    required this.repository,
    required this.readState,
    required this.isMounted,
    required this.isScreenVisible,
    required this.requestVersion,
    required this.warmupThumbnail,
  });

  static const _previewLimit = 6;

  final TemplatesRepository Function() repository;
  final TemplatesState Function() readState;
  final bool Function() isMounted;
  final bool Function() isScreenVisible;
  final int Function() requestVersion;
  final Future<void> Function(String url, {int? mediaVersion}) warmupThumbnail;

  int _preloadVersion = 0;
  int _activeTasks = 0;
  int _cancellations = 0;

  int get preloadVersion => _preloadVersion;
  int get cancellations => _cancellations;

  Future<void> warmup(
    List<TemplateItem> items, {
    required int feedRequestVersion,
    required int preloadVersion,
    required String queryKey,
  }) async {
    final uniqueItems = <({String url, int? mediaVersion})>[];
    final uniqueKeys = <String>{};
    for (final item in items.take(_previewLimit)) {
      final thumbnailUrl = TemplatesFeedPolicy.normalizeMediaUrl(
        item.thumbnailUrl,
      );
      final previewUrl = TemplatesFeedPolicy.normalizeMediaUrl(
        item.previewAsset?.url,
      );
      final preferred = thumbnailUrl != null && !isVideoUrl(thumbnailUrl)
          ? thumbnailUrl
          : (!isVideoUrl(previewUrl) ? previewUrl : null);
      if (preferred != null &&
          uniqueKeys.add(
            TemplateMediaCache.cacheKeyForMedia(
              preferred,
              mediaVersion: item.mediaVersion,
            ),
          )) {
        uniqueItems.add((url: preferred, mediaVersion: item.mediaVersion));
      }
    }

    _activeTasks++;
    try {
      for (final item in uniqueItems) {
        if (!_shouldContinue(feedRequestVersion, preloadVersion, queryKey)) {
          _recordCancellation('before_url');
          return;
        }
        await _warmupSingle(item.url, mediaVersion: item.mediaVersion);
        if (!_shouldContinue(feedRequestVersion, preloadVersion, queryKey)) {
          _recordCancellation('after_url');
          return;
        }
      }
    } finally {
      _activeTasks--;
    }
  }

  bool invalidate(String reason, {TemplatesRepository? activeRepository}) {
    _preloadVersion++;
    if (_activeTasks <= 0) return false;
    (activeRepository ?? repository()).cancelPendingMetadataRequests();
    _recordCancellation(reason);
    return true;
  }

  Future<void> _warmupSingle(String url, {int? mediaVersion}) async {
    try {
      await warmupThumbnail(url, mediaVersion: mediaVersion);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'warmup_single_url',
        message: 'Template preview warmup failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'screenVisible': isScreenVisible()},
      );
    }
  }

  bool _shouldContinue(
    int feedRequestVersion,
    int preloadVersion,
    String queryKey,
  ) {
    if (!isMounted() ||
        !isScreenVisible() ||
        feedRequestVersion != requestVersion() ||
        preloadVersion != _preloadVersion ||
        readState().itemsQueryKey != queryKey) {
      return false;
    }
    return readState().query.copyWith(resetPage: true).cacheKey == queryKey;
  }

  void _recordCancellation(String reason) {
    _cancellations++;
    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'preload_cancellations',
      message: 'Cancelled stale template preview preload work.',
      context: {
        'reason': reason,
        'requestVersion': requestVersion(),
        'preloadVersion': _preloadVersion,
        'count': _cancellations,
      },
    );
  }
}
