import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'template_card_test_support.dart';

void main() {
  late VideoPlayerPlatform originalPlatform;
  late List<_TrackingController> controllers;
  Future<VideoPlayerController> factory(String url) async {
    final controller = _TrackingController(url);
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    MediaLifecyclePolicy.reset();
    controllers = [];
  });
  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    MediaLifecyclePolicy.reset();
  });

  testWidgets(
    'active preview resumes on slot release after prolonged starvation',
    (tester) async {
      _reserve(4);
      await _mount(tester, _host(factory));
      expect(controllers, hasLength(1));
      expect(controllers.single.initializeCalls, 0);
      expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(controllers, hasLength(1));
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      MediaLifecyclePolicy.releaseVideoPreviewSlot();
      await _until(
        tester,
        () => find.byType(VideoPlayer).evaluate().isNotEmpty,
      );
      expect(controllers, hasLength(2));
      expect(controllers.last.value.isPlaying, isTrue);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 4);
      expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 0);
      await _remove(tester, externalSlots: 3);
    },
  );

  testWidgets('warm neighbour preserves the final slot for the active page', (
    tester,
  ) async {
    _reserve(3);
    await _mount(tester, _host(factory, active: false, prepareOffscreen: true));
    expect(controllers.single.initializeCalls, 0);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 3);
    expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 1);
    await tester.pumpWidget(_host(factory, prepareOffscreen: true));
    await _until(tester, () => find.byType(VideoPlayer).evaluate().isNotEmpty);
    expect(controllers.last.initializeCalls, 1);
    expect(controllers.last.value.isPlaying, isTrue);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 4);
    expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 0);
    await _remove(tester, externalSlots: 3);
  });

  for (final background in [false, true]) {
    testWidgets(
      '${background ? 'background' : 'offscreen'} cancels slot wait before release',
      (tester) async {
        _reserve(4);
        await _mount(tester, _host(factory));
        expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 1);
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          hideTemplateCard(tester, size: const Size(320, 480));
        }
        await tester.pump();
        expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 0);
        MediaLifecyclePolicy.releaseVideoPreviewSlot();
        await tester.pump(const Duration(seconds: 2));
        expect(controllers, hasLength(1));
        expect(controllers.single.initializeCalls, 0);
        await _remove(tester, externalSlots: 3);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      },
    );
  }

  testWidgets('disposing a waiting preview removes its sole slot listener', (
    tester,
  ) async {
    _reserve(4);
    await _mount(tester, _host(factory));
    for (var index = 0; index < 3; index++) {
      await tester.pumpWidget(_host(factory));
      await tester.pump();
      expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 1);
      expect(controllers, hasLength(1));
    }
    final requestsBeforeDispose = controllers.length;
    await _remove(tester, externalSlots: 4);
    await tester.pump();
    expect(controllers, hasLength(requestsBeforeDispose));
    expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 0);
  });
}

void _reserve(int count) {
  for (var index = 0; index < count; index++) {
    expect(MediaLifecyclePolicy.tryAcquireVideoPreviewSlot(), isTrue);
  }
}

Widget _host(
  Future<VideoPlayerController> Function(String) factory, {
  bool active = true,
  bool prepareOffscreen = false,
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
          template: videoTemplate(),
          controllerFactory: factory,
          expand: true,
          isActive: active,
          prepareOffscreen: prepareOffscreen,
          allowDetailUpgrade: false,
        ),
      ),
    ),
  ),
);

Future<void> _mount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  showTemplateCard(tester, size: const Size(320, 480));
  await tester.pump();
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var index = 0; index < 40 && !condition(); index++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

Future<void> _remove(WidgetTester tester, {required int externalSlots}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _until(
    tester,
    () => MediaLifecyclePolicy.activeVideoPreviews == externalSlots,
  );
  expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 0);
  for (var index = 0; index < externalSlots; index++) {
    MediaLifecyclePolicy.releaseVideoPreviewSlot();
  }
  await tester.pump();
  expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
  expect(tester.takeException(), isNull);
}

class _TrackingController extends VideoPlayerController {
  _TrackingController(String url) : super.networkUrl(Uri.parse(url));
  int initializeCalls = 0;
  @override
  Future<void> initialize() {
    initializeCalls++;
    return super.initialize();
  }
}
