import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerPlatform originalPlatform;
  late _FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    while (MediaLifecyclePolicy.activeVideoPreviews > 0) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
    }
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    while (MediaLifecyclePolicy.activeVideoPreviews > 0) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
    }
  });

  testWidgets('TemplateCard manages video preview lifecycle by viewport', (
    tester,
  ) async {
    final template = _videoTemplate();
    await tester.pumpWidget(
      _buildHost(
        template,
        previewControllerFactory: (previewUrl) async =>
            VideoPlayerController.networkUrl(Uri.parse(previewUrl)),
      ),
    );
    await tester.pump();

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );

    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(320, 240),
        visibleBounds: const Rect.fromLTWH(0, 0, 320, 240),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, greaterThan(0));

    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(320, 240),
        visibleBounds: Rect.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 80));

    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TemplateCard ignores duplicate and stale video preview init', (
    tester,
  ) async {
    final firstTemplate = _videoTemplate(
      id: 'video-template-first',
      previewUrl: 'https://cdn.example.com/templates/first-preview.mp4',
    );
    final secondTemplate = _videoTemplate(
      id: 'video-template-second',
      previewUrl: 'https://cdn.example.com/templates/second-preview.mp4',
    );
    final firstController = Completer<VideoPlayerController>();
    final secondController = Completer<VideoPlayerController>();
    final requestedUrls = <String>[];

    await tester.pumpWidget(
      _buildHost(
        firstTemplate,
        previewControllerFactory: (previewUrl) {
          requestedUrls.add(previewUrl);
          return firstController.future;
        },
      ),
    );
    await tester.pump();

    _showTemplateCard(tester);
    _showTemplateCard(tester);

    expect(requestedUrls, [firstTemplate.previewAsset!.url]);

    await tester.pumpWidget(
      _buildHost(
        secondTemplate,
        previewControllerFactory: (previewUrl) {
          requestedUrls.add(previewUrl);
          return secondController.future;
        },
      ),
    );
    await tester.pump();
    _showTemplateCard(tester);

    expect(requestedUrls, [
      firstTemplate.previewAsset!.url,
      secondTemplate.previewAsset!.url,
    ]);

    firstController.complete(
      VideoPlayerController.networkUrl(
        Uri.parse(firstTemplate.previewAsset!.url),
      ),
    );
    await tester.pump();

    expect(fakePlatform.createCalls, equals(0));

    secondController.complete(
      VideoPlayerController.networkUrl(
        Uri.parse(secondTemplate.previewAsset!.url),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(fakePlatform.createCalls, equals(1));
    expect(fakePlatform.createdUris, [secondTemplate.previewAsset!.url]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 80));
    expect(MediaLifecyclePolicy.activeVideoPreviews, equals(0));
    expect(tester.takeException(), isNull);
  });
}

void _showTemplateCard(WidgetTester tester) {
  final detector = tester.widget<VisibilityDetector>(
    find.byType(VisibilityDetector),
  );

  detector.onVisibilityChanged?.call(
    VisibilityInfo(
      key: detector.key!,
      size: const Size(320, 240),
      visibleBounds: const Rect.fromLTWH(0, 0, 320, 240),
    ),
  );
}

Widget _buildHost(
  TemplateItem template, {
  Future<VideoPlayerController> Function(String previewUrl)?
  previewControllerFactory,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 240,
          child: TemplateCard(
            template: template,
            hasPremiumAccess: true,
            previewControllerFactory: previewControllerFactory,
          ),
        ),
      ),
    ),
  );
}

TemplateItem _videoTemplate({
  String id = 'video-template-test',
  String previewUrl = 'https://cdn.example.com/templates/test-preview.mp4',
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
    previewAsset: TemplateAsset(
      url: previewUrl,
      fileName: 'test-preview.mp4',
      contentType: 'video/mp4',
      durationSeconds: 6,
    ),
    referenceVideoDurationSeconds: 6,
  );
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 1;
  final Map<int, StreamController<VideoEvent>> _eventsByPlayerId =
      <int, StreamController<VideoEvent>>{};

  int createCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;
  final List<String?> createdUris = <String?>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    createCalls += 1;
    createdUris.add(dataSource.uri);
    final playerId = _nextPlayerId++;
    final events = StreamController<VideoEvent>.broadcast();
    _eventsByPlayerId[playerId] = events;

    scheduleMicrotask(() {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 6),
          size: const Size(720, 1280),
        ),
      );
    });

    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventsByPlayerId[playerId]!.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls += 1;
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
    await _eventsByPlayerId.remove(playerId)?.close();
  }
}
