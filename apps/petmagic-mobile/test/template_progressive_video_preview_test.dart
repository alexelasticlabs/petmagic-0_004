import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'template_card_test_support.dart';

const _fastUrl = 'https://cdn.example.com/fast.mp4';
const _detailUrl = 'https://cdn.example.com/detail.mp4';

void main() {
  late VideoPlayerPlatform originalPlatform;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    MediaLifecyclePolicy.reset();
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    MediaLifecyclePolicy.reset();
  });

  testWidgets(
    'fast preview keeps playing while HQ waits without another slot',
    (tester) async {
      final fast = _TrackingController(_fastUrl);
      final detail = _TrackingController(_detailUrl);
      final gate = Completer<VideoPlayerController>();
      final requests = <String>[];
      Future<VideoPlayerController> factory(String url) async {
        requests.add(url);
        return url == _fastUrl ? fast : gate.future;
      }

      await _mount(tester, _host(factory));
      expect(fast.value.isPlaying, isTrue);
      expect(fast.value.volume, 1);
      expect(requests, [_fastUrl]);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
      await tester.pump(const Duration(milliseconds: 700));
      expect(requests, [_fastUrl, _detailUrl]);
      expect(fast.value.isPlaying, isTrue);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        fast,
      );

      gate.complete(detail);
      await _pumpUntil(tester, () => fast.disposeCalls == 1);
      await _flushDisposals(tester);
      expect(detail.value.isPlaying, isTrue);
      expect(detail.value.volume, 1);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
      await _remove(tester);
    },
  );

  testWidgets('detail decoder waits until the swipe has finished', (
    tester,
  ) async {
    final requests = <String>[];
    Future<VideoPlayerController> factory(String url) async {
      requests.add(url);
      return _TrackingController(url);
    }

    await _mount(tester, _host(factory, allowUpgrade: false));
    await tester.pump(const Duration(seconds: 1));
    expect(requests, [_fastUrl]);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
    await tester.pumpWidget(_host(factory));
    await tester.pump(const Duration(milliseconds: 700));
    await _pumpUntil(tester, () => requests.length == 2);
    expect(requests, [_fastUrl, _detailUrl]);
    await _remove(tester);
  });

  testWidgets(
    'HQ swap preserves manual pause, position and current mute choice',
    (tester) async {
      final fast = _TrackingController(_fastUrl);
      final detail = _TrackingController(_detailUrl);
      final gate = Completer<VideoPlayerController>();
      Future<VideoPlayerController> factory(String url) async =>
          url == _fastUrl ? fast : gate.future;

      await _mount(tester, _host(factory));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('template-preview-playback')));
      await tester.pump();
      expect(fast.value.isPlaying, isFalse);
      await fast.seekTo(const Duration(seconds: 3));
      await tester.pumpWidget(_host(factory, muted: true));
      gate.complete(detail);
      await _pumpUntil(tester, () => fast.disposeCalls == 1);
      await _flushDisposals(tester);
      expect(detail.seeks, contains(const Duration(seconds: 3)));
      expect(detail.value.isPlaying, isFalse);
      expect(detail.value.volume, 0);
      expect(detail.playCalls, 0);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        detail,
      );
      await _remove(tester);
    },
  );

  for (final background in [false, true]) {
    testWidgets(
      '${background ? 'background' : 'inactive'} during HQ download cannot resurrect playback',
      (tester) async {
        final fast = _TrackingController(_fastUrl);
        final stale = _TrackingController(_detailUrl);
        final gate = Completer<VideoPlayerController>();
        Future<VideoPlayerController> factory(String url) async =>
            url == _fastUrl ? fast : gate.future;

        await _mount(tester, _host(factory));
        await tester.pump(const Duration(milliseconds: 700));
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          await tester.pumpWidget(_host(factory, active: false));
        }
        await tester.pump();
        gate.complete(stale);
        await _pumpUntil(tester, () => stale.disposeCalls == 1);
        await _flushDisposals(tester);
        expect(stale.initializeCalls, 0);
        expect(stale.playCalls, 0);
        expect(fast.value.isPlaying, isFalse);
        if (background) expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
        await _remove(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      },
    );
  }

  testWidgets(
    'hydration and becoming inactive together silence the old preview',
    (tester) async {
      final fast = _TrackingController(_fastUrl);
      final requests = <String>[];
      Future<VideoPlayerController> factory(String url) async {
        requests.add(url);
        return fast;
      }

      await _mount(tester, _host(factory, detail: false));
      expect(fast.value.isPlaying, isTrue);
      expect(fast.value.volume, 1);
      await tester.pumpWidget(_host(factory, active: false));
      await tester.pump();
      expect(fast.value.isPlaying, isFalse);
      expect(fast.value.volume, 0);
      await tester.pump(const Duration(milliseconds: 800));
      expect(requests, [_fastUrl]);
      await _remove(tester);
    },
  );

  testWidgets(
    'sync during delayed handover pause cannot restart the old player',
    (tester) async {
      final fast = _TrackingController(_fastUrl);
      final detail = _TrackingController(_detailUrl);
      Future<VideoPlayerController> factory(String url) async =>
          url == _fastUrl ? fast : detail;
      await _mount(tester, _host(factory));
      final pauseGate = Completer<void>();
      fast.pauseGate = pauseGate;
      final initialPlayCalls = fast.playCalls;
      await tester.pump(const Duration(milliseconds: 700));
      await _pumpUntil(tester, () => fast.gatedPauseCalls == 1);
      expect(fast.value.isPlaying, isFalse);
      expect(fast.value.volume, 0);
      await tester.pumpWidget(_host(factory, muted: true));
      await tester.pump();
      await tester.pumpWidget(_host(factory, muted: false));
      await tester.pump();
      expect(fast.playCalls, initialPlayCalls);
      expect(fast.value.volume, 0);
      expect(detail.playCalls, 0);
      pauseGate.complete();
      await _pumpUntil(tester, () => fast.disposeCalls == 1);
      await _flushDisposals(tester);
      expect(detail.value.isPlaying, isTrue);
      expect(detail.value.volume, 1);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
      await _remove(tester);
    },
  );

  testWidgets(
    'old handover completion cannot restart playback during a newer handover',
    (tester) async {
      const replacementUrl = 'https://cdn.example.com/replacement.mp4';
      final fast = _TrackingController(_fastUrl);
      final oldDetail = _TrackingController(_detailUrl);
      final replacement = _TrackingController(replacementUrl);
      Future<VideoPlayerController> factory(String url) async => switch (url) {
        _fastUrl => fast,
        _detailUrl => oldDetail,
        _ => replacement,
      };

      await _mount(tester, _host(factory));
      final firstPause = Completer<void>();
      final secondPause = Completer<void>();
      fast.pauseGate = firstPause;
      final initialPlayCalls = fast.playCalls;
      await tester.pump(const Duration(milliseconds: 700));
      await _pumpUntil(tester, () => fast.gatedPauseCalls == 1);

      // Hydration replaces HQ while the original player is still pausing.
      await tester.pumpWidget(_host(factory, detailUrl: replacementUrl));
      await _flushDisposals(tester);
      expect(oldDetail.disposeCalls, 1);
      fast.pauseGate = secondPause;
      await tester.pump(const Duration(milliseconds: 700));
      await _pumpUntil(tester, () => fast.gatedPauseCalls == 2);
      expect(replacement.value.isInitialized, isTrue);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 2);

      // Completing the obsolete pause must leave the newer handover silent.
      firstPause.complete();
      await tester.pump();
      await _flushDisposals(tester);
      expect(fast.playCalls, initialPlayCalls);
      expect(fast.value.volume, 0);
      expect(replacement.playCalls, 0);
      expect(oldDetail.disposeCalls, 1);

      secondPause.complete();
      await _pumpUntil(tester, () => fast.disposeCalls == 1);
      await _flushDisposals(tester);
      expect(replacement.value.isPlaying, isTrue);
      expect(replacement.value.volume, 1);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
      await _remove(tester);
    },
  );
}

Widget _host(
  Future<VideoPlayerController> Function(String) factory, {
  bool active = true,
  bool muted = false,
  bool detail = true,
  bool allowUpgrade = true,
  String detailUrl = _detailUrl,
}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        height: 480,
        child: TemplateMediaFrame(
          key: const ValueKey('progressive-frame'),
          template: TemplateItem(
            templateId: 'progressive-video',
            templateType: TemplateType.video,
            title: 'Video',
            shortDescription: '',
            petPhotoRequirements: const [],
            category: '',
            tags: const [],
            isPremium: false,
            tokenCost: 1,
            mediaKind: 'video',
            mediaVersion: 4,
            feedLoopLowUrl: _fastUrl,
            detailPreviewUrl: detail ? detailUrl : null,
            previewAsset: const TemplateAsset(
              url: _fastUrl,
              fileName: 'fast.mp4',
              contentType: 'video/mp4',
            ),
          ),
          controllerFactory: factory,
          expand: true,
          immersive: true,
          isActive: active,
          allowDetailUpgrade: allowUpgrade,
          muted: muted,
        ),
      ),
    ),
  ),
);

Future<void> _mount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  showTemplateCard(tester, size: const Size(320, 480));
  await _pumpUntil(
    tester,
    () => find.byType(VideoPlayer).evaluate().isNotEmpty,
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 40 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Async preview operation did not settle');
}

Future<void> _remove(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _flushDisposals(tester);
  await tester.pump(const Duration(seconds: 1));
  expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
  expect(tester.takeException(), isNull);
}

Future<void> _flushDisposals(WidgetTester tester) async {
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

class _TrackingController extends VideoPlayerController {
  _TrackingController(String url) : super.networkUrl(Uri.parse(url));

  int initializeCalls = 0;
  int disposeCalls = 0;
  int playCalls = 0;
  int gatedPauseCalls = 0;
  final List<Duration> seeks = [];
  Completer<void>? pauseGate;

  @override
  Future<void> initialize() {
    initializeCalls++;
    return super.initialize();
  }

  @override
  Future<void> play() {
    playCalls++;
    return super.play();
  }

  @override
  Future<void> pause() async {
    final gate = pauseGate;
    pauseGate = null;
    if (gate != null) {
      gatedPauseCalls++;
      value = value.copyWith(isPlaying: false);
      await gate.future;
    }
    await super.pause();
  }

  @override
  Future<void> seekTo(Duration position) {
    seeks.add(position);
    return super.seekTo(position);
  }

  @override
  Future<void> dispose() {
    disposeCalls++;
    return super.dispose();
  }
}
