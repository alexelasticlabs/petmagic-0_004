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

void main() {
  late VideoPlayerPlatform original;
  late FakeVideoPlayerPlatform platform;
  late TemplatePreviewPlaybackRegistry registry;

  setUp(() {
    original = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    registry = TemplatePreviewPlaybackRegistry();
    MediaLifecyclePolicy.reset();
    // Keep the real detector delay: selection must not wait for its next tick.
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });
  tearDown(() {
    registry.dispose();
    VideoPlayerPlatform.instance = original;
    MediaLifecyclePolicy.reset();
  });

  testWidgets(
    'known selected page starts before delayed visibility notification',
    (tester) async {
      await tester.pumpWidget(
        _host(
          TemplateMediaFrame(
            template: videoTemplate(),
            expand: true,
            immersive: true,
            playWhenActive: true,
            muted: false,
            controllerFactory: (url) async =>
                VideoPlayerController.networkUrl(Uri.parse(url)),
          ),
        ),
      );
      await _ready(tester, () => platform.playCalls == 1);
      await tester.pump();
      expect(platform.createCalls, 1);
      expect(platform.volumeValues.last, 1);
      expect(find.byType(VideoPlayer), findsOneWidget);
      await _remove(tester);
    },
  );

  testWidgets(
    'warm pages and thumbnails share three decoders across repeated reversals',
    (tester) async {
      var selected = 1;
      var muted = false;
      late StateSetter update;
      final items = List.generate(3, (index) => videoTemplate(id: '$index'));
      // A fourth lease may belong to another surface during route handover.
      expect(MediaLifecyclePolicy.tryAcquireVideoPreviewSlot(), isTrue);
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _surfaces(items, registry, selected, muted: muted);
            },
          ),
        ),
      );
      await _ready(
        tester,
        () => find.byType(VideoPlayer).evaluate().length == 6,
      );
      final controllers = List.generate(
        3,
        (index) => _thumbnail(tester, index),
      );
      expect(platform.createCalls, 3);
      expect(MediaLifecyclePolicy.activeVideoPreviews, 4);
      for (var index = 0; index < 3; index++) {
        expect(_frame(tester, index), same(controllers[index]));
        expect(controllers[index].value.isPlaying, index == selected);
        expect(controllers[index].value.volume, index == selected ? 1 : 0);
      }

      for (final next in [0, 1, 2, 1, 0, 1]) {
        update(() => selected = next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        // Neither native initialization nor a 500 ms visibility tick is needed.
        expect(platform.createCalls, 3);
        expect(platform.disposeCalls, 0);
        expect(find.byType(VideoPlayer), findsNWidgets(6));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        for (var index = 0; index < 3; index++) {
          expect(_thumbnail(tester, index), same(controllers[index]));
          expect(controllers[index].value.isPlaying, index == next);
          expect(controllers[index].value.volume, index == next ? 1 : 0);
        }
      }

      update(() => muted = true);
      await tester.pump();
      update(() => selected = 2);
      await tester.pump();
      expect(controllers.map((c) => c.value.volume), everyElement(0));
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
      await _remove(tester);
    },
  );

  testWidgets('background withdraws shared textures and releases every lease', (
    tester,
  ) async {
    final items = List.generate(3, (index) => videoTemplate(id: '$index'));
    await tester.pumpWidget(_host(_surfaces(items, registry, 1)));
    await _ready(tester, () => find.byType(VideoPlayer).evaluate().length == 6);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _flush(tester);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
    expect(find.byType(VideoPlayer), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _ready(tester, () => find.byType(VideoPlayer).evaluate().length == 6);
    expect(platform.createCalls, 6);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 3);
    await _remove(tester);
  });

  testWidgets('new media version cannot keep a stale thumbnail texture', (
    tester,
  ) async {
    var version = 1;
    late StateSetter update;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return _surfaces(
              [videoTemplate(id: 'same', mediaVersion: version)],
              registry,
              0,
            );
          },
        ),
      ),
    );
    await _ready(tester, () => find.byType(VideoPlayer).evaluate().length == 2);
    final previous = _thumbnail(tester, 0);
    update(() => version = 2);
    await tester.pump();
    await _flush(tester);
    await _ready(tester, () => find.byType(VideoPlayer).evaluate().length == 2);
    expect(_thumbnail(tester, 0), isNot(same(previous)));
    expect(_thumbnail(tester, 0), same(_frame(tester, 0)));
    expect(platform.disposeCalls, 1);
    expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
    expect(tester.takeException(), isNull);
    await _remove(tester);
  });
}

Widget _surfaces(
  List<TemplateItem> items,
  TemplatePreviewPlaybackRegistry registry,
  int selected, {
  bool muted = false,
}) => Column(
  children: [
    Row(
      children: [
        for (var index = 0; index < items.length; index++)
          SizedBox(
            width: 100,
            height: 150,
            child: TemplateMediaFrame(
              key: ValueKey('frame:$index'),
              template: items[index],
              expand: true,
              immersive: true,
              prepareOffscreen: true,
              playWhenActive: true,
              allowDetailUpgrade: false,
              isActive: index == selected,
              muted: muted,
              playbackRegistry: registry,
              controllerFactory: (url) async =>
                  VideoPlayerController.networkUrl(Uri.parse(url)),
            ),
          ),
      ],
    ),
    Row(
      children: [
        for (var index = 0; index < items.length; index++)
          SizedBox(
            width: 62,
            height: 78,
            child: TemplateVideoThumbnail(
              key: ValueKey('thumb:$index'),
              template: items[index],
              isActive: index == selected,
              playbackRegistry: registry,
              placeholder: const ColoredBox(color: Colors.black),
              controllerFactory: (_) =>
                  throw StateError('Thumbnail allocated a decoder'),
            ),
          ),
      ],
    ),
  ],
);

VideoPlayerController _player(WidgetTester tester, String key) => tester
    .widget<VideoPlayer>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(VideoPlayer),
      ),
    )
    .controller;
VideoPlayerController _thumbnail(WidgetTester tester, int index) =>
    _player(tester, 'thumb:$index');
VideoPlayerController _frame(WidgetTester tester, int index) =>
    _player(tester, 'frame:$index');

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Future<void> _ready(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 30 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

Future<void> _flush(WidgetTester tester) async {
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

Future<void> _remove(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _flush(tester);
  await tester.pump(const Duration(seconds: 1));
  expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
  expect(tester.takeException(), isNull);
}
