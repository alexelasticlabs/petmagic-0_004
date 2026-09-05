import 'dart:async';

import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/performance/media_prefetch_budget.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_prefetch_policy.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

export 'template_preview_prefetch_policy.dart';

/// Downloads sequentially within a bounded horizon of the latest selection.
/// Fast feed media precedes optional detail; no native decoders are allocated.
class TemplatePreviewPrefetcher {
  TemplatePreviewPrefetcher({
    Future<void> Function(String, int?)? fetch,
    Future<void> Function(String, int?)? fetchThumbnail,
    bool Function()? canPrefetch,
    bool Function()? preferLowResolution,
    TemplatePreviewPrefetchPolicy Function()? policy,
    DateTime Function()? now,
    void Function()? onReady,
  }) : _fetch = fetch,
       _fetchThumbnail = fetchThumbnail,
       _canPrefetch = canPrefetch ?? (() => true),
       _preferLowResolution = preferLowResolution,
       _policy = policy ?? (() => TemplatePreviewPrefetchPolicy.wifi),
       _now = now ?? DateTime.now,
       _onReady = onReady;

  static const _detailStability = Duration(milliseconds: 700);
  final Future<void> Function(String, int?)? _fetch;
  final Future<void> Function(String, int?)? _fetchThumbnail;
  final bool Function() _canPrefetch;
  final bool Function()? _preferLowResolution;
  final TemplatePreviewPrefetchPolicy Function() _policy;
  final DateTime Function() _now;
  final void Function()? _onReady;
  final Map<String, _PrefetchCandidate> _pending = {};
  final Set<String> _completed = {};
  final Set<String> _reservedKeys = {};
  _PrefetchCandidate? _detail;
  TemplatePreviewPrefetchPolicy? _scheduledPolicy;
  Timer? _detailTimer;
  String? _selection;
  _PrefetchCandidate? _inFlight;
  DateTime? _selectedAt;
  int _generation = 0;
  int _estimatedWaveBytes = 0;
  bool _draining = false;
  bool _disposed = false;
  MediaPrefetchBudget? _waveBudget;
  MediaPrefetchBudget? _inFlightBudget;

  void schedule(List<TemplateItem> items, int index, {int direction = 1}) {
    if (_disposed) return;
    final policy = _policy();
    if (!_canPrefetch() ||
        !policy.enabled ||
        policy.maxEstimatedBytes <= 0 ||
        policy.maxFileBytes <= 0 ||
        index < 0 ||
        index >= items.length) {
      cancelPending();
      return;
    }
    final step = direction < 0 ? -1 : 1;
    final item = items[index];
    final selection = '${item.templateId}|${item.mediaVersion}|$index|$step';
    if (_selection != selection || _scheduledPolicy != policy) {
      // Keep the newly selected template's transfer for playback to join.
      // An obsolete heavy file must not delay the new direction's fast queue.
      final selectedTransfer =
          _inFlight?.templateId == item.templateId &&
          _inFlight?.version == item.mediaVersion;
      cancelPending(
        cancelTransfer: _scheduledPolicy != policy || !selectedTransfer,
      );
      _selection = selection;
      _selectedAt = _now();
      _scheduledPolicy = policy;
      _waveBudget = MediaPrefetchBudget(
        maxBytes: policy.maxEstimatedBytes,
        maxFileBytes: policy.maxFileBytes,
      );
    }
    _pending.clear();
    _detail = null;
    final preferLow =
        _preferLowResolution?.call() ??
        policy == TemplatePreviewPrefetchPolicy.cellular;
    final videoAhead = policy.videoAhead.clamp(0, 8);
    final imageAhead = policy.imageAhead.clamp(0, 8);
    final horizon = videoAhead > imageAhead ? videoAhead : imageAhead;
    for (var distance = 1; distance <= horizon; distance++) {
      final target = index + step * distance;
      if (target < 0 || target >= items.length) break;
      final next = items[target];
      if (distance > (_isVideo(next) ? videoAhead : imageAhead)) continue;
      final fast = _fastCandidate(next, preferLow: preferLow);
      _enqueue(fast, policy);
      if (distance == 1 && policy.allowDetailPrefetch) {
        _detail = _detailCandidate(next, fast?.url);
      }
    }
    for (var distance = 1; distance <= policy.behind.clamp(0, 2); distance++) {
      final target = index - step * distance;
      if (target < 0 || target >= items.length) break;
      _enqueue(_fastCandidate(items[target], preferLow: preferLow), policy);
    }
    unawaited(_drain());
  }

  bool _enqueue(
    _PrefetchCandidate? candidate,
    TemplatePreviewPrefetchPolicy policy,
  ) {
    if (candidate == null ||
        _completed.contains(candidate.key) ||
        _inFlight?.key == candidate.key ||
        _pending.containsKey(candidate.key)) {
      return false;
    }
    if (candidate.estimatedBytes > policy.maxFileBytes ||
        candidate.isDetail && !policy.allowDetailPrefetch) {
      return false;
    }
    if (!_reservedKeys.contains(candidate.key)) {
      if (_reservedKeys.length >= 16 ||
          _estimatedWaveBytes + candidate.estimatedBytes >
              policy.maxEstimatedBytes) {
        return false;
      }
      _reservedKeys.add(candidate.key);
      _estimatedWaveBytes += candidate.estimatedBytes;
    }
    _pending[candidate.key] = candidate;
    return true;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (!_disposed &&
          _pending.isNotEmpty &&
          _canPrefetch() &&
          _policy().enabled &&
          _waveBudget?.canDownload == true) {
        final candidate = _pending.remove(_pending.keys.first)!;
        final generation = _generation;
        _inFlight = candidate;
        final budget = _waveBudget!;
        _inFlightBudget = budget;
        try {
          await _download(candidate, budget);
          if (!_disposed) {
            _completed.add(candidate.key);
            if (_completed.length > 32) _completed.remove(_completed.first);
            if (generation == _generation &&
                _canPrefetch() &&
                _policy().enabled) {
              _onReady?.call();
            }
          }
        } on MediaPrefetchLimitException {
          // A normal admission/cancellation outcome, not a broken preview.
        } catch (error, stackTrace) {
          AppLogger.warn(
            feature: 'Templates.Preview',
            operation: 'prefetch_neighbour',
            message: 'Optional neighbour preview prefetch failed.',
            error: error,
            stackTrace: stackTrace,
          );
        } finally {
          _inFlight = null;
          _inFlightBudget = null;
        }
      }
    } finally {
      _draining = false;
      _scheduleDetail();
    }
  }

  void _scheduleDetail() {
    if (_disposed ||
        _detail == null ||
        _pending.isNotEmpty ||
        _inFlight != null) {
      return;
    }
    if (_waveBudget?.canDownload != true) return;
    if (!_canPrefetch() ||
        !_policy().enabled ||
        !_policy().allowDetailPrefetch) {
      cancelPending();
      return;
    }
    final remaining = _detailStability - _now().difference(_selectedAt!);
    if (remaining > Duration.zero) {
      final generation = _generation;
      _detailTimer ??= Timer(remaining, () {
        _detailTimer = null;
        if (generation == _generation) _scheduleDetail();
      });
      return;
    }
    final detail = _detail;
    _detail = null;
    if (_enqueue(detail, _policy())) unawaited(_drain());
  }

  void cancelPending({bool cancelTransfer = true}) {
    _generation++;
    _detailTimer?.cancel();
    _detailTimer = null;
    _pending.clear();
    _detail = null;
    _selection = null;
    _selectedAt = null;
    _scheduledPolicy = null;
    _reservedKeys.clear();
    _estimatedWaveBytes = 0;
    if (cancelTransfer) {
      _waveBudget?.cancel();
      _inFlightBudget?.cancel();
    }
    _waveBudget = null;
  }

  void dispose() {
    _disposed = true;
    cancelPending();
    _completed.clear();
  }

  static bool _isVideo(TemplateItem item) {
    final kind = item.mediaKind?.trim().toLowerCase();
    if (kind == 'image') return false;
    if (kind == 'video') return true;
    if (_safe(item.detailPreviewUrl) != null) return item.detailPreviewIsVideo;
    return isVideoPreview(item.previewAsset) ||
        isVideoUrl(item.feedLoopLowUrl) ||
        isVideoUrl(item.feedLoopMediumUrl) ||
        item.previewAsset == null && item.isVideo;
  }

  static String? _safe(String? url) =>
      parseSafeGenerationMediaUri(url)?.toString();

  static int? _knownSize(TemplateItem item, String url) {
    final asset = item.previewAsset;
    final size = url == _safe(item.detailPreviewUrl)
        ? item.sizeBytes
        : url == _safe(asset?.url)
        ? asset?.fileSizeBytes ??
              (_safe(item.detailPreviewUrl) == null ? item.sizeBytes : null)
        : null;
    return size != null && size > 0 ? size : null;
  }

  static _PrefetchCandidate? _fastCandidate(
    TemplateItem item, {
    required bool preferLow,
  }) {
    final low = _safe(item.feedLoopLowUrl);
    final medium = _safe(item.feedLoopMediumUrl);
    final feed = preferLow ? low ?? medium : medium ?? low;
    final isVideo = _isVideo(item);
    if (isVideo && feed != null) {
      return _PrefetchCandidate(
        item,
        feed,
        usesPreviewCache: true,
        estimatedBytes:
            _knownSize(item, feed) ?? (feed == low ? 512 : 1024) * 1024,
      );
    }
    final thumbnail =
        _safe(item.thumbnailUrl) ?? (!isVideo ? low ?? medium : null);
    if (thumbnail != null && !isVideoUrl(thumbnail)) {
      return _PrefetchCandidate(
        item,
        thumbnail,
        usesPreviewCache: false,
        estimatedBytes: 128 * 1024,
      );
    }
    // Unoptimized originals are optional only when their size is known.
    final original =
        _safe(item.previewAsset?.url) ?? _safe(item.detailPreviewUrl);
    if (original == null) return null;
    final size = _knownSize(item, original);
    if (size == null) return null;
    return _PrefetchCandidate(
      item,
      original,
      usesPreviewCache: isVideo,
      estimatedBytes: size,
    );
  }

  static _PrefetchCandidate? _detailCandidate(
    TemplateItem item,
    String? fastUrl,
  ) {
    final detail = _safe(item.detailPreviewUrl);
    if (detail == null || detail == fastUrl) return null;
    final size = _knownSize(item, detail);
    if (detail == _safe(item.previewAsset?.url) &&
        _safe(item.feedLoopLowUrl) == null &&
        _safe(item.feedLoopMediumUrl) == null &&
        size == null) {
      return null;
    }
    return _PrefetchCandidate(
      item,
      detail,
      usesPreviewCache: true,
      estimatedBytes: size ?? 4 * 1024 * 1024,
      isDetail: true,
    );
  }

  Future<void> _download(
    _PrefetchCandidate candidate,
    MediaPrefetchBudget budget,
  ) async {
    final injected = candidate.usesPreviewCache ? _fetch : _fetchThumbnail;
    if (injected != null) {
      await injected(candidate.url, candidate.version);
      return;
    }
    final fetch = candidate.usesPreviewCache
        ? TemplateMediaCache.fetchPreviewFile
        : TemplateMediaCache.fetchThumbnailFile;
    await fetch(
      candidate.url,
      mediaVersion: candidate.version,
      prefetchBudget: budget,
    );
  }
}

class _PrefetchCandidate {
  _PrefetchCandidate(
    TemplateItem item,
    this.url, {
    required this.usesPreviewCache,
    required this.estimatedBytes,
    this.isDetail = false,
  }) : templateId = item.templateId,
       version = item.mediaVersion;

  final String templateId;
  final String url;
  final int? version;
  final bool usesPreviewCache;
  final int estimatedBytes;
  final bool isDetail;
  String get key =>
      '${usesPreviewCache ? 'preview' : 'thumbnail'}|'
      '${TemplateMediaCache.cacheKeyForMedia(url, mediaVersion: version)}';
}
