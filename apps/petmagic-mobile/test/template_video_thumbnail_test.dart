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
    'legacy MP4 thumbnail plays a silent loop and releases its decoder',
    (tester) async {
      const url = 'https://cdn.example.com/legacy-thumbnail.mp4';
      await tester.pumpWidget(_host(url));
      showTemplateCard(tester, size: const Size(64, 76));
      await pumpUntil(
        tester,
        () => find.byType(VideoPlayer).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 1),
      );
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.createdUris, [url]);
      expect(platform.playCalls, greaterThan(0));
      expect(platform.volumeValues, everyElement(0));
      expect(find.byType(IconButton), findsNothing);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);

      await tester.pumpWidget(_host(url, active: false));
      await tester.runAsync(() async {
        // The platform subscription cancellation completes outside the fake clock.
        await Future<void>.delayed(Duration.zero);
      });
      await pumpUntil(
        tester,
        () => MediaLifecyclePolicy.activeVideoPreviews == 0,
        timeout: const Duration(seconds: 1),
      );
      await tester.pump();
      expect(find.byType(VideoPlayer), findsNothing);
      expect(
        MediaLifecyclePolicy.activeVideoPreviews,
        0,
        reason: platform.operations.join(', '),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inactive thumbnail never allocates a decoder', (tester) async {
    await tester.pumpWidget(
      _host('https://cdn.example.com/inactive.mp4', active: false),
    );
    showTemplateCard(tester, size: const Size(64, 76));
    await tester.pump(const Duration(milliseconds: 300));
    expect(platform.createCalls, 0);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'thumbnail releases its decoder in background and reloads on resume',
    (tester) async {
      await tester.pumpWidget(_host('https://cdn.example.com/lifecycle.mp4'));
      showTemplateCard(tester, size: const Size(64, 76));
      await pumpUntil(
        tester,
        () => find.byType(VideoPlayer).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 1),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await pumpUntil(
        tester,
        () => MediaLifecyclePolicy.activeVideoPreviews == 0,
        timeout: const Duration(seconds: 1),
      );
      expect(
        MediaLifecyclePolicy.activeVideoPreviews,
        0,
        reason: platform.operations.join(', '),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpUntil(
        tester,
        () => platform.createCalls == 2,
        timeout: const Duration(seconds: 1),
      );
      expect(platform.createCalls, 2);
      expect(platform.playCalls, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
    },
  );
}

Widget _host(String url, {bool active = true}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 64,
        height: 76,
        child: TemplateVideoThumbnail(
          template: videoTemplate(thumbnailUrl: url, feedLoopLowUrl: url),
          isActive: active,
          placeholder: const ColoredBox(color: Colors.black),
          controllerFactory: (url) async =>
              VideoPlayerController.networkUrl(Uri.parse(url)),
        ),
      ),
    ),
  ),
);
