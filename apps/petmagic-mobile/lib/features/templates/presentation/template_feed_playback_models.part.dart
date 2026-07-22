part of 'template_feed_playback_manager.dart';

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
