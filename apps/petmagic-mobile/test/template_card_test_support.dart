import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

void showTemplateCard(WidgetTester tester, {Size size = const Size(320, 240)}) {
  final detector = tester.widget<VisibilityDetector>(
    find.byType(VisibilityDetector),
  );

  detector.onVisibilityChanged?.call(
    VisibilityInfo(
      key: detector.key!,
      size: size,
      visibleBounds: Offset.zero & size,
    ),
  );
}

void hideTemplateCard(WidgetTester tester, {Size size = const Size(320, 240)}) {
  final detector = tester.widget<VisibilityDetector>(
    find.byType(VisibilityDetector),
  );

  detector.onVisibilityChanged?.call(
    VisibilityInfo(key: detector.key!, size: size, visibleBounds: Rect.zero),
  );
}

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Widget buildTemplateCardHost(
  TemplateItem template, {
  Future<VideoPlayerController> Function(String previewUrl)?
  previewControllerFactory,
  int imageCacheWidth = 720,
  ThemeData? theme,
  bool hasPremiumAccess = true,
  Size size = const Size(320, 240),
  TemplateFeedPlaybackManager? playbackManager,
  TemplateCardFeaturedData? featuredData,
}) {
  final manager = playbackManager ?? TemplateFeedPlaybackManager();
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: TemplateCard(
            template: template,
            hasPremiumAccess: hasPremiumAccess,
            imageCacheWidth: imageCacheWidth,
            playbackManager: manager,
            featuredData: featuredData,
            previewControllerFactory: previewControllerFactory,
          ),
        ),
      ),
    ),
  );
}

Widget buildTemplateCardGridHost(List<TemplateItem> templates) {
  final playbackManager = TemplateFeedPlaybackManager();
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final template in templates)
              SizedBox(
                width: 188,
                height: 260,
                child: TemplateCard(
                  template: template,
                  hasPremiumAccess: true,
                  imageCacheWidth: 720,
                  playbackManager: playbackManager,
                  previewControllerFactory: (previewUrl) async =>
                      VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

TemplateItem videoTemplate({
  String id = 'video-template-test',
  String previewUrl = 'https://cdn.example.com/templates/test-preview.mp4',
  String? thumbnailUrl,
  String? animatedPreviewUrl,
  String? feedLoopLowUrl,
  String? feedLoopMediumUrl,
  int? mediaVersion,
}) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.video,
    title: 'Video Template',
    shortDescription: 'Template card viewport lifecycle test',
    petPhotoRequirements: const <String>['Clear pet photo'],
    category: 'test',
    tags: const <String>['viewport', 'video'],
    isPremium: false,
    tokenCost: 5,
    thumbnailUrl: thumbnailUrl,
    animatedPreviewUrl: animatedPreviewUrl,
    feedLoopLowUrl: feedLoopLowUrl,
    feedLoopMediumUrl: feedLoopMediumUrl,
    mediaVersion: mediaVersion,
    previewAsset: TemplateAsset(
      url: previewUrl,
      fileName: 'test-preview.mp4',
      contentType: 'video/mp4',
      durationSeconds: 6,
    ),
    referenceVideoDurationSeconds: 6,
  );
}

TemplateItem imageTemplate({
  String id = 'image-template-test',
  String previewUrl = 'https://cdn.example.com/templates/test-preview.jpg',
  String? assetUrl,
}) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.image,
    title: 'Image Template',
    shortDescription: 'Template card image lifecycle test',
    petPhotoRequirements: const <String>['Clear pet photo'],
    category: 'test',
    tags: const <String>['viewport', 'image'],
    isPremium: false,
    tokenCost: 5,
    thumbnailUrl: previewUrl,
    previewAsset: TemplateAsset(
      url: assetUrl ?? previewUrl,
      fileName: (assetUrl ?? previewUrl).split('/').last,
      contentType: 'image/jpeg',
    ),
  );
}

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 1;
  final Map<int, StreamController<VideoEvent>> _eventsByPlayerId =
      <int, StreamController<VideoEvent>>{};
  final Set<int> _initializedPlayerIds = <int>{};

  int createCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;
  final List<String?> createdUris = <String?>[];
  final List<DataSourceType> createdSourceTypes = <DataSourceType>[];
  final List<bool> loopingValues = <bool>[];
  final List<double> volumeValues = <double>[];
  final List<String> operations = <String>[];
  Completer<void>? initializedEventGate;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    createCalls += 1;
    createdUris.add(dataSource.uri);
    createdSourceTypes.add(dataSource.sourceType);
    operations.add('create');
    final playerId = _nextPlayerId++;
    final events = StreamController<VideoEvent>.broadcast();
    _eventsByPlayerId[playerId] = events;

    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    if (_initializedPlayerIds.add(playerId)) {
      unawaited(_emitInitializedEvent(playerId));
    }
    return _eventsByPlayerId[playerId]!.stream;
  }

  Future<void> _emitInitializedEvent(int playerId) async {
    final gate = initializedEventGate;
    if (gate != null) {
      await gate.future;
    } else {
      await Future<void>.microtask(() {});
    }

    _eventsByPlayerId[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 6),
        size: const Size(720, 1280),
      ),
    );
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loopingValues.add(looping);
    operations.add('setLooping:$looping');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumeValues.add(volume);
    operations.add('setVolume:$volume');
  }

  @override
  Future<void> play(int playerId) async {
    playCalls += 1;
    operations.add('play');
    _eventsByPlayerId[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls += 1;
    operations.add('pause');
    _eventsByPlayerId[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<Duration> getPosition(int playerId) async {
    return Duration.zero;
  }

  @override
  Widget buildView(int playerId) {
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose(int playerId) async {
    disposeCalls += 1;
    operations.add('dispose');
    await _eventsByPlayerId.remove(playerId)?.close();
  }
}

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.root);

  final Directory root;

  @override
  Future<String?> getTemporaryPath() async {
    return _ensureDirectory('tmp').path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _ensureDirectory('support').path;
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return _ensureDirectory('cache').path;
  }

  Directory _ensureDirectory(String name) {
    final directory = Directory('${root.path}/$name');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}

class TickerModeHost extends StatefulWidget {
  const TickerModeHost({
    required this.child,
    this.initialEnabled = true,
    super.key,
  });

  final Widget child;
  final bool initialEnabled;

  @override
  State<TickerModeHost> createState() => TickerModeHostState();
}

class TickerModeHostState extends State<TickerModeHost> {
  late bool _enabled = widget.initialEnabled;

  void setEnabled(bool enabled) {
    setState(() {
      _enabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: _enabled, child: widget.child);
  }
}
