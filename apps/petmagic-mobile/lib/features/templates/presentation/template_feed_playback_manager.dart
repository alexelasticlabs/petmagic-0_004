import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_media_preload_queue.dart';

enum TemplateFeedDisplayLevel { thumbnail, animatedPreview, videoPreview }

enum TemplateFeedKind { mixed, videoOnly }

enum TemplateFeedNetworkClass { wifi, cellular, slow, offline }

enum TemplateFeedAutoplayMode { off, light, balanced, rich }

@immutable
class TemplateFeedPlaybackEnvironment {
  const TemplateFeedPlaybackEnvironment({
    this.networkClass = TemplateFeedNetworkClass.wifi,
    this.dataSaverEnabled = false,
    this.lowPowerModeEnabled = false,
    this.appForeground = true,
  });

  final TemplateFeedNetworkClass networkClass;
  final bool dataSaverEnabled;
  final bool lowPowerModeEnabled;
  final bool appForeground;

  TemplateFeedPlaybackEnvironment copyWith({
    TemplateFeedNetworkClass? networkClass,
    bool? dataSaverEnabled,
    bool? lowPowerModeEnabled,
    bool? appForeground,
  }) {
    return TemplateFeedPlaybackEnvironment(
      networkClass: networkClass ?? this.networkClass,
      dataSaverEnabled: dataSaverEnabled ?? this.dataSaverEnabled,
      lowPowerModeEnabled: lowPowerModeEnabled ?? this.lowPowerModeEnabled,
      appForeground: appForeground ?? this.appForeground,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateFeedPlaybackEnvironment &&
        other.networkClass == networkClass &&
        other.dataSaverEnabled == dataSaverEnabled &&
        other.lowPowerModeEnabled == lowPowerModeEnabled &&
        other.appForeground == appForeground;
  }

  @override
  int get hashCode => Object.hash(
    networkClass,
    dataSaverEnabled,
    lowPowerModeEnabled,
    appForeground,
  );
}

final templateFeedPlaybackEnvironmentProvider =
    Provider<TemplateFeedPlaybackEnvironment>((ref) {
      final hasInternet = ref.watch(
        networkStatusControllerProvider.select((state) => state.hasInternet),
      );
      return TemplateFeedPlaybackEnvironment(
        networkClass: hasInternet
            ? TemplateFeedNetworkClass.wifi
            : TemplateFeedNetworkClass.offline,
      );
    });

final templateFeedPlaybackManagerProvider =
    Provider.autoDispose<TemplateFeedPlaybackManager>((ref) {
      final manager = TemplateFeedPlaybackManager(
        mediaPreloadQueue: ref.watch(templateFeedMediaPreloadQueueProvider),
      );
      ref.onDispose(manager.dispose);
      return manager;
    });

class TemplateFeedPlaybackCardSnapshot {
  const TemplateFeedPlaybackCardSnapshot({
    required this.cardId,
    required this.templateId,
    required this.displayLevel,
    required this.visibleFraction,
    required this.hasVideoControllerSlot,
    this.videoPreviewUrl,
    this.mediaVersion,
  });

  final String cardId;
  final String templateId;
  final TemplateFeedDisplayLevel displayLevel;
  final double visibleFraction;
  final bool hasVideoControllerSlot;
  final String? videoPreviewUrl;
  final int? mediaVersion;
}

class _PlaybackCardRecord {
  _PlaybackCardRecord({
    required this.cardId,
    required this.templateId,
    required this.isVideoTemplate,
    required this.hasAnimatedPreview,
    required this.visibleFraction,
    this.thumbnailUrl,
    this.animatedPreviewUrl,
    this.feedLoopLowUrl,
    this.feedLoopMediumUrl,
    this.fallbackPreviewUrl,
    this.mediaVersion,
  });

  final String cardId;
  String templateId;
  bool isVideoTemplate;
  bool hasAnimatedPreview;
  double visibleFraction;
  String? thumbnailUrl;
  String? animatedPreviewUrl;
  String? feedLoopLowUrl;
  String? feedLoopMediumUrl;
  String? fallbackPreviewUrl;
  int? mediaVersion;
  bool hasVideoControllerSlot = false;

  TemplateFeedDisplayLevel get displayLevel {
    if (hasVideoControllerSlot) {
      return TemplateFeedDisplayLevel.videoPreview;
    }

    return hasAnimatedPreview
        ? TemplateFeedDisplayLevel.animatedPreview
        : TemplateFeedDisplayLevel.thumbnail;
  }
}

class TemplateFeedPlaybackManager extends ChangeNotifier {
  static const double defaultFastScrollVelocityThreshold = 1800;
  static const double videoEligibilityVisibilityFraction = 0.58;

  TemplateFeedPlaybackManager({
    TemplateFeedMediaPreloadQueue? mediaPreloadQueue,
  }) : _mediaPreloadQueue = mediaPreloadQueue;

  final TemplateFeedMediaPreloadQueue? _mediaPreloadQueue;
  TemplateFeedKind _feedKind = TemplateFeedKind.mixed;
  TemplateFeedPlaybackEnvironment _environment =
      const TemplateFeedPlaybackEnvironment();
  double _scrollVelocityPixelsPerSecond = 0;
  String? _feedScopeKey;
  bool _disposed = false;
  int _maxActiveVideoControllersInSession = 0;
  int _videoPreloadCancellations = 0;
  final Map<String, _PlaybackCardRecord> _cards =
      <String, _PlaybackCardRecord>{};

  int get activeVideoControllersCount =>
      _cards.values.where((card) => card.hasVideoControllerSlot).length;

  int get maxActiveVideoControllersInSession =>
      _maxActiveVideoControllersInSession;

  int get videoPreloadCancellations => _videoPreloadCancellations;

  TemplateFeedAutoplayMode get autoplayMode {
    final budget = currentVideoPreviewBudget;
    if (budget <= 0) {
      return TemplateFeedAutoplayMode.off;
    }
    if (budget == 1) {
      return TemplateFeedAutoplayMode.light;
    }
    if (budget == 2) {
      return TemplateFeedAutoplayMode.balanced;
    }
    return TemplateFeedAutoplayMode.rich;
  }

  int get currentVideoPreviewBudget {
    if (!_environment.appForeground ||
        _environment.networkClass == TemplateFeedNetworkClass.offline ||
        isFastScrolling) {
      return 0;
    }

    if (_environment.dataSaverEnabled || _environment.lowPowerModeEnabled) {
      return 0;
    }

    return switch (_environment.networkClass) {
      TemplateFeedNetworkClass.slow =>
        _feedKind == TemplateFeedKind.videoOnly ? 1 : 0,
      TemplateFeedNetworkClass.cellular => 1,
      TemplateFeedNetworkClass.wifi =>
        _feedKind == TemplateFeedKind.videoOnly ? 3 : 2,
      TemplateFeedNetworkClass.offline => 0,
    };
  }

  bool get isFastScrolling =>
      _scrollVelocityPixelsPerSecond.abs() > defaultFastScrollVelocityThreshold;

  void configure({
    TemplateFeedKind? feedKind,
    TemplateFeedPlaybackEnvironment? environment,
    String? feedScopeKey,
  }) {
    if (_disposed) {
      return;
    }

    if (feedScopeKey != null && feedScopeKey != _feedScopeKey) {
      _feedScopeKey = feedScopeKey;
      _mediaPreloadQueue?.cancelAll(reason: 'feed_scope_changed');
    }

    final nextFeedKind = feedKind ?? _feedKind;
    final nextEnvironment = environment ?? _environment;
    if (nextFeedKind == _feedKind && nextEnvironment == _environment) {
      return;
    }

    _feedKind = nextFeedKind;
    _environment = nextEnvironment;
    _recomputePlaybackGrants(reason: 'conditions_changed');
  }

  void updateScrollVelocity(double pixelsPerSecond) {
    if (_disposed || pixelsPerSecond == _scrollVelocityPixelsPerSecond) {
      return;
    }

    final wasFast = isFastScrolling;
    _scrollVelocityPixelsPerSecond = pixelsPerSecond;
    if (wasFast != isFastScrolling || isFastScrolling) {
      _recomputePlaybackGrants(reason: 'scroll_velocity_changed');
    }
  }

  void updateCardVisibility({
    required String cardId,
    required String templateId,
    required bool isVideoTemplate,
    required bool hasAnimatedPreview,
    required double visibleFraction,
    String? thumbnailUrl,
    String? animatedPreviewUrl,
    String? feedLoopLowUrl,
    String? feedLoopMediumUrl,
    String? fallbackPreviewUrl,
    int? mediaVersion,
  }) {
    if (_disposed) {
      return;
    }

    final clampedVisibility = visibleFraction.clamp(0.0, 1.0);
    if (clampedVisibility <= 0) {
      unregisterCard(cardId);
      return;
    }

    final existing = _cards[cardId];
    if (existing == null) {
      _cards[cardId] = _PlaybackCardRecord(
        cardId: cardId,
        templateId: templateId,
        isVideoTemplate: isVideoTemplate,
        hasAnimatedPreview: hasAnimatedPreview,
        visibleFraction: clampedVisibility,
        thumbnailUrl: _normalizeMediaUrl(thumbnailUrl),
        animatedPreviewUrl: _normalizeMediaUrl(animatedPreviewUrl),
        feedLoopLowUrl: _normalizeMediaUrl(feedLoopLowUrl),
        feedLoopMediumUrl: _normalizeMediaUrl(feedLoopMediumUrl),
        fallbackPreviewUrl: _normalizeMediaUrl(fallbackPreviewUrl),
        mediaVersion: mediaVersion,
      );
    } else {
      existing
        ..templateId = templateId
        ..isVideoTemplate = isVideoTemplate
        ..hasAnimatedPreview = hasAnimatedPreview
        ..visibleFraction = clampedVisibility
        ..thumbnailUrl = _normalizeMediaUrl(thumbnailUrl)
        ..animatedPreviewUrl = _normalizeMediaUrl(animatedPreviewUrl)
        ..feedLoopLowUrl = _normalizeMediaUrl(feedLoopLowUrl)
        ..feedLoopMediumUrl = _normalizeMediaUrl(feedLoopMediumUrl)
        ..fallbackPreviewUrl = _normalizeMediaUrl(fallbackPreviewUrl)
        ..mediaVersion = mediaVersion;
    }

    _recomputePlaybackGrants(reason: 'visibility_changed');
  }

  void unregisterCard(String cardId) {
    if (_disposed) {
      return;
    }

    final removed = _cards.remove(cardId);
    if (removed == null) {
      return;
    }

    if (removed.hasVideoControllerSlot) {
      _releaseVideoSlot(removed);
      _recomputePlaybackGrants(reason: 'card_unregistered');
    } else {
      _syncMediaPreloadQueue(reason: 'card_unregistered');
    }
    notifyListeners();
  }

  TemplateFeedPlaybackCardSnapshot snapshotFor(String cardId) {
    final record = _cards[cardId];
    if (record == null) {
      return TemplateFeedPlaybackCardSnapshot(
        cardId: cardId,
        templateId: '',
        displayLevel: TemplateFeedDisplayLevel.thumbnail,
        visibleFraction: 0,
        hasVideoControllerSlot: false,
        videoPreviewUrl: null,
        mediaVersion: null,
      );
    }

    return TemplateFeedPlaybackCardSnapshot(
      cardId: record.cardId,
      templateId: record.templateId,
      displayLevel: record.displayLevel,
      visibleFraction: record.visibleFraction,
      hasVideoControllerSlot: record.hasVideoControllerSlot,
      videoPreviewUrl: _selectVideoPreviewUrl(record),
      mediaVersion: record.mediaVersion,
    );
  }

  void disposeAll({String reason = 'dispose_all'}) {
    _mediaPreloadQueue?.cancelAll(reason: reason);
    if (_cards.isEmpty) {
      return;
    }

    for (final card in _cards.values) {
      if (card.hasVideoControllerSlot) {
        _releaseVideoSlot(card);
      }
    }
    _cards.clear();
    _recordVideoPreloadCancellation(reason);
    notifyListeners();
  }

  void _recomputePlaybackGrants({required String reason}) {
    final budget = currentVideoPreviewBudget;
    final eligible =
        _cards.values
            .where(
              (card) =>
                  card.isVideoTemplate &&
                  card.visibleFraction >= videoEligibilityVisibilityFraction,
            )
            .toList(growable: false)
          ..sort((a, b) => b.visibleFraction.compareTo(a.visibleFraction));
    final grantedIds = eligible.take(budget).map((card) => card.cardId).toSet();
    var changed = false;

    for (final card in _cards.values) {
      final shouldHaveVideoSlot = grantedIds.contains(card.cardId);
      if (!shouldHaveVideoSlot && card.hasVideoControllerSlot) {
        _releaseVideoSlot(card);
        changed = true;
      }
    }

    for (final card in eligible) {
      if (!grantedIds.contains(card.cardId) || card.hasVideoControllerSlot) {
        continue;
      }

      if (MediaLifecyclePolicy.tryAcquireVideoPreviewSlot(
        maxConcurrent: budget,
      )) {
        card.hasVideoControllerSlot = true;
        changed = true;
      }
    }

    _maxActiveVideoControllersInSession =
        activeVideoControllersCount > _maxActiveVideoControllersInSession
        ? activeVideoControllersCount
        : _maxActiveVideoControllersInSession;

    _syncMediaPreloadQueue(reason: reason);

    if (changed) {
      if (budget == 0) {
        _recordVideoPreloadCancellation(reason);
      }
      AppLogger.info(
        feature: 'Templates.FeedPlayback',
        operation: 'active_video_controllers_count',
        message: 'Template feed autoplay budget updated.',
        context: {
          'activeCount': activeVideoControllersCount,
          'maxActiveCount': _maxActiveVideoControllersInSession,
          'budget': budget,
          'autoplayMode': autoplayMode.name,
          'reason': reason,
        },
      );
      notifyListeners();
    }
  }

  void _syncMediaPreloadQueue({required String reason}) {
    final candidates = _cards.values
        .where((card) => card.hasVideoControllerSlot)
        .map((card) {
          final url = _selectVideoPreviewUrl(card);
          if (url == null) {
            return null;
          }

          return TemplateFeedMediaPreloadCandidate(
            templateId: card.templateId,
            url: url,
            mediaVersion: card.mediaVersion,
          );
        })
        .whereType<TemplateFeedMediaPreloadCandidate>();

    _mediaPreloadQueue?.preloadVideoCandidates(candidates, reason: reason);
  }

  String? _selectVideoPreviewUrl(_PlaybackCardRecord card) {
    if (_environment.dataSaverEnabled ||
        _environment.lowPowerModeEnabled ||
        _environment.networkClass == TemplateFeedNetworkClass.offline ||
        !_environment.appForeground) {
      return null;
    }

    final preferLowQuality =
        _environment.networkClass == TemplateFeedNetworkClass.cellular ||
        _environment.networkClass == TemplateFeedNetworkClass.slow;
    return preferLowQuality
        ? card.feedLoopLowUrl ??
              card.feedLoopMediumUrl ??
              card.fallbackPreviewUrl
        : card.feedLoopMediumUrl ??
              card.feedLoopLowUrl ??
              card.fallbackPreviewUrl;
  }

  String? _normalizeMediaUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  void _releaseVideoSlot(_PlaybackCardRecord card) {
    if (!card.hasVideoControllerSlot) {
      return;
    }

    card.hasVideoControllerSlot = false;
    MediaLifecyclePolicy.releaseVideoPreviewSlot();
  }

  void _recordVideoPreloadCancellation(String reason) {
    _videoPreloadCancellations++;
    AppLogger.info(
      feature: 'Templates.FeedPlayback',
      operation: 'video_preload_cancellations',
      message: 'Template feed video preload/playback was cancelled.',
      context: {'reason': reason, 'count': _videoPreloadCancellations},
    );
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    disposeAll(reason: 'manager_dispose');
    _disposed = true;
    super.dispose();
  }
}
