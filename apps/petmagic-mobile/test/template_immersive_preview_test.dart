import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'template_card_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VideoPlayerPlatform original;
  late FakeVideoPlayerPlatform platform;
  setUp(() {
    original = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    MediaLifecyclePolicy.reset();
  });
  tearDown(() {
    VideoPlayerPlatform.instance = original;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    MediaLifecyclePolicy.reset();
  });

  testWidgets(
    'immersive image fills the viewport without a blurred letterbox',
    (tester) async {
      await tester.pumpWidget(
        _host(
          TemplateMediaFrame(
            template: imageTemplate(),
            expand: true,
            immersive: true,
          ),
        ),
      );
      final images = tester.widgetList<TemplatePreviewImage>(
        find.byType(TemplatePreviewImage),
      );
      expect(images, hasLength(1));
      expect(images.single.fit, BoxFit.cover);
      expect(find.byType(ImageFiltered), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('expanded non-immersive sheets still contain the whole image', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(TemplateMediaFrame(template: imageTemplate(), expand: true)),
    );
    expect(
      tester
          .widgetList<TemplatePreviewImage>(find.byType(TemplatePreviewImage))
          .any((image) => image.fit == BoxFit.contain),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'incoming video prepares silently, then starts without a second decoder',
    (tester) async {
      var active = false;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TemplateMediaFrame(
                template: videoTemplate(),
                expand: true,
                immersive: true,
                isActive: active,
                muted: false,
                controllerFactory: (url) async =>
                    VideoPlayerController.networkUrl(Uri.parse(url)),
              );
            },
          ),
        ),
      );
      showTemplateCard(tester, size: const Size(430, 932));
      await pumpUntil(
        tester,
        () => find.byType(VideoPlayer).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 1),
      );
      expect(platform.createCalls, 1);
      expect(platform.playCalls, 0);
      expect(platform.volumeValues, everyElement(0));
      update(() => active = true);
      await tester.pumpAndSettle();
      expect(platform.createCalls, 1);
      expect(platform.playCalls, greaterThan(0));
      expect(platform.volumeValues.last, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await pumpUntil(
        tester,
        () => MediaLifecyclePolicy.activeVideoPreviews == 0,
        timeout: const Duration(seconds: 1),
      );
      expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'audible full-screen video has top controls and retains mute after deactivation',
    (tester) async {
      var muted = false;
      var active = true;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TemplateMediaFrame(
                template: videoTemplate(),
                expand: true,
                immersive: true,
                isActive: active,
                muted: muted,
                onMutedChanged: (value) => setState(() => muted = value),
                controllerFactory: (url) async =>
                    VideoPlayerController.networkUrl(Uri.parse(url)),
              );
            },
          ),
        ),
      );
      showTemplateCard(tester, size: const Size(430, 932));
      await pumpUntil(
        tester,
        () => platform.playCalls > 0,
        timeout: const Duration(seconds: 1),
      );
      await tester.pump();
      expect(platform.volumeValues.last, 1);
      final videoFit = tester.widget<FittedBox>(
        find.ancestor(
          of: find.byType(VideoPlayer),
          matching: find.byType(FittedBox),
        ),
      );
      expect(videoFit.fit, BoxFit.cover);
      final mute = find.byKey(const ValueKey('template-preview-mute'));
      final playback = find.byKey(const ValueKey('template-preview-playback'));
      expect(tester.getTopLeft(mute).dy, lessThan(64));
      expect(tester.getTopLeft(playback).dy, tester.getTopLeft(mute).dy);
      await tester.tap(mute);
      await tester.pumpAndSettle();
      expect(muted, isTrue);
      expect(platform.volumeValues.last, 0);
      expect(platform.createCalls, 1);
      await tester.tap(playback);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller
            .value
            .isPlaying,
        isFalse,
      );
      await tester.tap(playback);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller
            .value
            .isPlaying,
        isTrue,
      );
      update(() => active = false);
      await tester.pump();
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await pumpUntil(
        tester,
        () => platform.volumeValues.last == 0,
        timeout: const Duration(seconds: 1),
      );
      expect(
        MediaLifecyclePolicy.activeVideoPreviews,
        1,
        reason: platform.operations.join(', '),
      );
      update(() => active = true);
      await tester.pump();
      await pumpUntil(
        tester,
        () =>
            platform.createCalls == 1 &&
            find.byType(VideoPlayer).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 1),
      );
      expect(platform.volumeValues.last, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
    },
  );
}

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 430, height: 932, child: child)),
);
