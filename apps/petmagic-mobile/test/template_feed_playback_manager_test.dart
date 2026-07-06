import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'dart:async';
import 'dart:io';

import 'package:petmagic_mobile/features/templates/presentation/template_feed_media_preload_queue.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';

void main() {
  setUp(MediaLifecyclePolicy.reset);
  tearDown(MediaLifecyclePolicy.reset);

  test('mixed feed grants video preview only up to balanced budget', () {
    final manager = TemplateFeedPlaybackManager()
      ..configure(feedKind: TemplateFeedKind.mixed);

    for (var index = 0; index < 5; index++) {
      manager.updateCardVisibility(
        cardId: 'card-$index',
        templateId: 'template-$index',
        isVideoTemplate: true,
        hasAnimatedPreview: true,
        visibleFraction: 0.9 - index * 0.05,
      );
    }

    expect(manager.currentVideoPreviewBudget, 2);
    expect(manager.autoplayMode, TemplateFeedAutoplayMode.balanced);
    expect(manager.activeVideoControllersCount, 2);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 2);
    expect(
      manager.snapshotFor('card-0').displayLevel,
      TemplateFeedDisplayLevel.videoPreview,
    );
    expect(
      manager.snapshotFor('card-3').displayLevel,
      TemplateFeedDisplayLevel.animatedPreview,
    );
  });

  test('video-only feed has richer budget than mixed feed on wifi', () {
    final mixed = TemplateFeedPlaybackManager()
      ..configure(feedKind: TemplateFeedKind.mixed);
    final videoOnly = TemplateFeedPlaybackManager()
      ..configure(feedKind: TemplateFeedKind.videoOnly);

    expect(
      videoOnly.currentVideoPreviewBudget,
      greaterThan(mixed.currentVideoPreviewBudget),
    );
  });

  test('visibility changes reassign released video budget to top cards', () {
    final manager = TemplateFeedPlaybackManager()
      ..configure(feedKind: TemplateFeedKind.mixed);

    manager
      ..updateCardVisibility(
        cardId: 'card-a',
        templateId: 'template-a',
        isVideoTemplate: true,
        hasAnimatedPreview: true,
        visibleFraction: 0.9,
      )
      ..updateCardVisibility(
        cardId: 'card-b',
        templateId: 'template-b',
        isVideoTemplate: true,
        hasAnimatedPreview: true,
        visibleFraction: 0.85,
      )
      ..updateCardVisibility(
        cardId: 'card-c',
        templateId: 'template-c',
        isVideoTemplate: true,
        hasAnimatedPreview: true,
        visibleFraction: 0.7,
      );

    expect(manager.activeVideoControllersCount, 2);
    expect(
      manager.snapshotFor('card-c').displayLevel,
      TemplateFeedDisplayLevel.animatedPreview,
    );

    manager.updateCardVisibility(
      cardId: 'card-c',
      templateId: 'template-c',
      isVideoTemplate: true,
      hasAnimatedPreview: true,
      visibleFraction: 1,
    );

    expect(manager.activeVideoControllersCount, 2);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 2);
    expect(
      manager.snapshotFor('card-c').displayLevel,
      TemplateFeedDisplayLevel.videoPreview,
    );
    expect(
      manager.snapshotFor('card-b').displayLevel,
      TemplateFeedDisplayLevel.animatedPreview,
    );
  });

  test('fast scroll prevents new video preview grants', () {
    final manager = TemplateFeedPlaybackManager()
      ..configure(feedKind: TemplateFeedKind.videoOnly)
      ..updateScrollVelocity(
        TemplateFeedPlaybackManager.defaultFastScrollVelocityThreshold + 100,
      );

    manager.updateCardVisibility(
      cardId: 'card-fast',
      templateId: 'template-fast',
      isVideoTemplate: true,
      hasAnimatedPreview: false,
      visibleFraction: 1,
    );

    expect(manager.currentVideoPreviewBudget, 0);
    expect(manager.activeVideoControllersCount, 0);
    expect(
      manager.snapshotFor('card-fast').displayLevel,
      TemplateFeedDisplayLevel.thumbnail,
    );
  });

  test(
    'data saver disables video preview while slow video feed stays light',
    () {
      final mixed = TemplateFeedPlaybackManager()
        ..configure(
          feedKind: TemplateFeedKind.mixed,
          environment: const TemplateFeedPlaybackEnvironment(
            networkClass: TemplateFeedNetworkClass.slow,
            dataSaverEnabled: true,
          ),
        );
      final videoOnly = TemplateFeedPlaybackManager()
        ..configure(
          feedKind: TemplateFeedKind.videoOnly,
          environment: const TemplateFeedPlaybackEnvironment(
            networkClass: TemplateFeedNetworkClass.slow,
            dataSaverEnabled: true,
          ),
        );

      expect(mixed.currentVideoPreviewBudget, 0);
      expect(mixed.autoplayMode, TemplateFeedAutoplayMode.off);
      expect(videoOnly.currentVideoPreviewBudget, 0);
      expect(videoOnly.autoplayMode, TemplateFeedAutoplayMode.off);

      final slowVideoOnly = TemplateFeedPlaybackManager()
        ..configure(
          feedKind: TemplateFeedKind.videoOnly,
          environment: const TemplateFeedPlaybackEnvironment(
            networkClass: TemplateFeedNetworkClass.slow,
          ),
        );

      expect(slowVideoOnly.currentVideoPreviewBudget, 1);
      expect(slowVideoOnly.autoplayMode, TemplateFeedAutoplayMode.light);
    },
  );

  test('adaptive quality chooses medium on wifi and low on cellular', () {
    final manager = TemplateFeedPlaybackManager()
      ..configure(
        feedKind: TemplateFeedKind.mixed,
        environment: const TemplateFeedPlaybackEnvironment(
          networkClass: TemplateFeedNetworkClass.wifi,
        ),
      );

    manager.updateCardVisibility(
      cardId: 'card-adaptive',
      templateId: 'template-adaptive',
      isVideoTemplate: true,
      hasAnimatedPreview: true,
      visibleFraction: 1,
      feedLoopLowUrl: 'https://cdn.example.com/low.mp4',
      feedLoopMediumUrl: 'https://cdn.example.com/medium.mp4',
      fallbackPreviewUrl: 'https://cdn.example.com/fallback.mp4',
      mediaVersion: 7,
    );

    var snapshot = manager.snapshotFor('card-adaptive');
    expect(snapshot.videoPreviewUrl, 'https://cdn.example.com/medium.mp4');
    expect(snapshot.mediaVersion, 7);

    manager.configure(
      environment: const TemplateFeedPlaybackEnvironment(
        networkClass: TemplateFeedNetworkClass.cellular,
      ),
    );

    snapshot = manager.snapshotFor('card-adaptive');
    expect(snapshot.videoPreviewUrl, 'https://cdn.example.com/low.mp4');
  });

  test('video preload queue only preloads granted candidates', () async {
    final fetched = <String>[];
    final queue = TemplateFeedMediaPreloadQueue(
      previewCacheLookup: (_, {mediaVersion}) async => null,
      previewFetch: (url, {mediaVersion}) async {
        fetched.add('$url@$mediaVersion');
        return File('template-feed-preload-test-missing-file');
      },
    );
    final manager = TemplateFeedPlaybackManager(mediaPreloadQueue: queue)
      ..configure(feedKind: TemplateFeedKind.videoOnly);

    for (var index = 0; index < 5; index++) {
      manager.updateCardVisibility(
        cardId: 'card-$index',
        templateId: 'template-$index',
        isVideoTemplate: true,
        hasAnimatedPreview: true,
        visibleFraction: 1 - index * 0.05,
        feedLoopMediumUrl: 'https://cdn.example.com/video-$index.mp4',
        mediaVersion: index + 1,
      );
    }

    await Future<void>.delayed(Duration.zero);

    expect(fetched, [
      'https://cdn.example.com/video-0.mp4@1',
      'https://cdn.example.com/video-1.mp4@2',
    ]);
    expect(manager.activeVideoControllersCount, 3);
  });

  test('video preload queue stops fetching after traffic budget', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-feed-preload-budget-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final downloadedFile = File(
      '${tempDir.path}${Platform.pathSeparator}v.mp4',
    );
    await downloadedFile.writeAsBytes(List<int>.filled(12, 1));
    final fetched = <String>[];
    final queue = TemplateFeedMediaPreloadQueue(
      maxVideoPreloads: 1,
      maxTrafficBytesPerFeedSession: 10,
      previewCacheLookup: (_, {mediaVersion}) async => null,
      previewFetch: (url, {mediaVersion}) async {
        fetched.add(url);
        return downloadedFile;
      },
    );

    queue.preloadVideoCandidates(const [
      TemplateFeedMediaPreloadCandidate(
        templateId: 'template-heavy-1',
        url: 'https://cdn.example.com/heavy-1.mp4',
      ),
    ], reason: 'test_first');
    await _waitUntil(() => queue.trafficBytesThisFeedSession == 12);

    queue.preloadVideoCandidates(const [
      TemplateFeedMediaPreloadCandidate(
        templateId: 'template-heavy-2',
        url: 'https://cdn.example.com/heavy-2.mp4',
      ),
    ], reason: 'test_second');
    await Future<void>.delayed(Duration.zero);

    expect(fetched, ['https://cdn.example.com/heavy-1.mp4']);
    expect(queue.trafficBytesThisFeedSession, 12);
  });

  test('feed scope change cancels active video preloads', () async {
    final queue = TemplateFeedMediaPreloadQueue(
      previewCacheLookup: (_, {mediaVersion}) async => null,
      previewFetch: (_, {mediaVersion}) => Completer<File>().future,
    );
    final manager = TemplateFeedPlaybackManager(mediaPreloadQueue: queue)
      ..configure(feedKind: TemplateFeedKind.mixed, feedScopeKey: 'cats');

    manager.updateCardVisibility(
      cardId: 'card-cancel',
      templateId: 'template-cancel',
      isVideoTemplate: true,
      hasAnimatedPreview: true,
      visibleFraction: 1,
      feedLoopMediumUrl: 'https://cdn.example.com/cancel.mp4',
      mediaVersion: 1,
    );
    await Future<void>.delayed(Duration.zero);

    expect(queue.activePreloadCount, 1);

    manager.configure(feedScopeKey: 'dogs');

    expect(queue.activePreloadCount, 0);
    expect(queue.videoPreloadCancellations, greaterThanOrEqualTo(1));
  });

  test('card leaving viewport releases its active video slot immediately', () {
    final manager = TemplateFeedPlaybackManager()
      ..updateCardVisibility(
        cardId: 'card-visible',
        templateId: 'template-visible',
        isVideoTemplate: true,
        hasAnimatedPreview: false,
        visibleFraction: 1,
      );

    expect(manager.activeVideoControllersCount, 1);

    manager.updateCardVisibility(
      cardId: 'card-visible',
      templateId: 'template-visible',
      isVideoTemplate: true,
      hasAnimatedPreview: false,
      visibleFraction: 0,
    );

    expect(manager.activeVideoControllersCount, 0);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
  });

  test('card leaving viewport grants released slot to next candidate', () {
    final manager = TemplateFeedPlaybackManager()
      ..configure(feedKind: TemplateFeedKind.mixed);

    for (var index = 0; index < 3; index++) {
      manager.updateCardVisibility(
        cardId: 'card-$index',
        templateId: 'template-$index',
        isVideoTemplate: true,
        hasAnimatedPreview: true,
        visibleFraction: 1 - index * 0.05,
      );
    }

    expect(manager.activeVideoControllersCount, 2);
    expect(
      manager.snapshotFor('card-2').displayLevel,
      TemplateFeedDisplayLevel.animatedPreview,
    );

    manager.updateCardVisibility(
      cardId: 'card-0',
      templateId: 'template-0',
      isVideoTemplate: true,
      hasAnimatedPreview: true,
      visibleFraction: 0,
    );

    expect(manager.activeVideoControllersCount, 2);
    expect(
      manager.snapshotFor('card-2').displayLevel,
      TemplateFeedDisplayLevel.videoPreview,
    );
    expect(MediaLifecyclePolicy.activeVideoPreviews, 2);
  });

  test('dispose releases every active video slot without leaking budget', () {
    final manager = TemplateFeedPlaybackManager()
      ..configure(feedKind: TemplateFeedKind.videoOnly);
    for (var index = 0; index < 3; index++) {
      manager.updateCardVisibility(
        cardId: 'card-$index',
        templateId: 'template-$index',
        isVideoTemplate: true,
        hasAnimatedPreview: false,
        visibleFraction: 1,
      );
    }

    expect(manager.activeVideoControllersCount, 3);
    manager.dispose();

    expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
  });

  test('feed media telemetry stays debug-only in release builds', () async {
    final preloadSource = await File(
      'lib/features/templates/presentation/template_feed_media_preload_queue.dart',
    ).readAsString();
    final playbackSource = await File(
      'lib/features/templates/presentation/template_feed_playback_manager.dart',
    ).readAsString();

    expect(preloadSource, contains('operation: \'media_cache_hit_rate\''));
    expect(preloadSource, contains('operation: \'traffic_per_feed_session\''));
    expect(preloadSource, contains('operation: \'traffic_budget_skip\''));
    expect(
      playbackSource,
      contains('operation: \'active_video_controllers_count\''),
    );
    expect(preloadSource, isNot(contains('AppLogger.info(')));
    expect(playbackSource, isNot(contains('AppLogger.info(')));
    expect(
      preloadSource,
      contains(
        "AppLogger.warn(\n        feature: 'Templates.FeedMediaPreload',",
      ),
    );
  });
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
