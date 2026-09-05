import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'template_card_test_support.dart';
import 'template_media_performance_test_support.dart';

const _low = 'https://cdn.example.com/low.mp4';
const _medium = 'https://cdn.example.com/medium.mp4';
const _detail = 'https://cdn.example.com/detail.mp4';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cacheRoot;
  late PathProviderPlatform savedPaths;
  setUpAll(() async {
    savedPaths = PathProviderPlatform.instance;
    cacheRoot = await Directory.systemTemp.createTemp(
      'petmagic-video-recovery-',
    );
    PathProviderPlatform.instance = FakeTemplateMediaPathProviderPlatform(
      cacheRoot,
    );
  });
  tearDownAll(() async {
    await TemplateMediaCache.clearAll();
    await TemplateMediaCache.previewVideoCache.dispose();
    await TemplateMediaCache.thumbnailCache.dispose();
    PathProviderPlatform.instance = savedPaths;
    for (var attempt = 0; ; attempt++) {
      try {
        await cacheRoot.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        // Windows can briefly retain a directory handle after cache IO settles.
        if (error.osError?.errorCode != 32 || attempt >= 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });
  late VideoPlayerPlatform originalPlatform;
  late _DecodeFailurePlatform platform;

  setUp(() async {
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _DecodeFailurePlatform();
    VideoPlayerPlatform.instance = platform;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    MediaLifecyclePolicy.reset();
    await TemplateMediaCache.clearAll();
  });
  tearDown(() async {
    VideoPlayerPlatform.instance = originalPlatform;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    MediaLifecyclePolicy.reset();
    await TemplateMediaCache.clearAll();
  });

  for (final failedUrl in [_low, _detail]) {
    testWidgets(
      'native decode failure evicts only $failedUrl and plays cached alternative',
      (tester) async {
        final alternate = failedUrl == _low ? _medium : _low;
        final broken = (await tester.runAsync(() => _seed(failedUrl, 4)))!;
        await tester.runAsync(() => _seed(alternate, 4));
        final newer = (await tester.runAsync(() => _seed(failedUrl, 5)))!;
        platform.badUris.add(broken.uri.toString());

        await _mount(tester, _host());
        await _until(
          tester,
          () =>
              platform.createCalls == 2 &&
              find.byType(VideoPlayer).evaluate().isNotEmpty,
        );
        final player = tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller;
        expect(player.value.isPlaying, isTrue);
        expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
        expect(
          await tester.runAsync(
            () => TemplateMediaCache.getCachedPreviewFile(
              failedUrl,
              mediaVersion: 4,
            ),
          ),
          isNull,
        );
        expect(
          (await tester.runAsync(
            () => TemplateMediaCache.getCachedPreviewFile(
              failedUrl,
              mediaVersion: 5,
            ),
          ))?.path,
          newer.path,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(platform.createCalls, 2);
        await _remove(tester);
      },
    );
  }

  testWidgets('all corrupt variants stop after one native attempt per source', (
    tester,
  ) async {
    for (final url in [_detail, _low, _medium]) {
      final file = (await tester.runAsync(() => _seed(url, 4)))!;
      platform.badUris.add(file.uri.toString());
    }
    await _mount(tester, _host());
    await _until(
      tester,
      () => find.byIcon(Icons.refresh_rounded).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(platform.createCalls, 3);
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    await _remove(tester);
  });

  testWidgets(
    'failed HQ upgrade retains the playing fast controller without retry loop',
    (tester) async {
      await tester.runAsync(() => _seed(_low, 4));
      await _mount(tester, _host());
      await _until(
        tester,
        () => find.byType(VideoPlayer).evaluate().isNotEmpty,
      );
      final fast = tester
          .widget<VideoPlayer>(find.byType(VideoPlayer))
          .controller;
      final broken = (await tester.runAsync(() => _seed(_detail, 4)))!;
      platform.badUris.add(broken.uri.toString());
      await tester.pumpWidget(_host(allowDetailUpgrade: true));
      await tester.pump(const Duration(milliseconds: 700));
      await _until(
        tester,
        () =>
            platform.createCalls == 2 &&
            MediaLifecyclePolicy.activeVideoPreviews == 1,
      );
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(fast),
      );
      expect(fast.value.isPlaying, isTrue);
      expect(
        await tester.runAsync(
          () =>
              TemplateMediaCache.getCachedPreviewFile(_detail, mediaVersion: 4),
        ),
        isNull,
      );
      await tester.pumpWidget(_host(allowDetailUpgrade: true));
      await tester.pump(const Duration(seconds: 2));
      expect(platform.createCalls, 2);
      await _remove(tester);
    },
  );

  testWidgets('volume setup failure leaves the cached file intact', (
    tester,
  ) async {
    final file = (await tester.runAsync(() => _seed(_low, 4)))!;
    await _mount(
      tester,
      _host(factory: (_) async => _VolumeFailureController(file)),
    );
    await _until(
      tester,
      () => find.byIcon(Icons.refresh_rounded).evaluate().isNotEmpty,
    );
    expect(platform.createCalls, 0);
    expect(
      (await tester.runAsync(
        () => TemplateMediaCache.getCachedPreviewFile(_low, mediaVersion: 4),
      ))?.path,
      file.path,
    );
    expect(MediaLifecyclePolicy.activeVideoPreviews, 0);
    await _remove(tester);
  });

  testWidgets(
    'late native failure after media version changes cannot evict either version',
    (tester) async {
      final oldFile = (await tester.runAsync(() => _seed(_detail, 4)))!;
      final currentFile = (await tester.runAsync(() => _seed(_detail, 5)))!;
      final gate = Completer<void>();
      platform.badUris.add(oldFile.uri.toString());
      platform.gates[oldFile.uri.toString()] = gate;
      await _mount(tester, _host());
      await _until(tester, () => platform.createCalls == 1);
      await tester.pumpWidget(_host(version: 5));
      gate.complete();
      await _until(
        tester,
        () =>
            platform.createCalls == 2 &&
            find.byType(VideoPlayer).evaluate().isNotEmpty,
      );
      expect(
        (await tester.runAsync(
          () =>
              TemplateMediaCache.getCachedPreviewFile(_detail, mediaVersion: 4),
        ))?.path,
        oldFile.path,
      );
      expect(
        (await tester.runAsync(
          () =>
              TemplateMediaCache.getCachedPreviewFile(_detail, mediaVersion: 5),
        ))?.path,
        currentFile.path,
      );
      expect(MediaLifecyclePolicy.activeVideoPreviews, 1);
      await _remove(tester);
    },
  );

  testWidgets('background during native failure cancels fallback preparation', (
    tester,
  ) async {
    final file = (await tester.runAsync(() => _seed(_detail, 4)))!;
    await tester.runAsync(() => _seed(_low, 4));
    final gate = Completer<void>();
    platform.badUris.add(file.uri.toString());
    platform.gates[file.uri.toString()] = gate;
    await _mount(tester, _host());
    await _until(tester, () => platform.createCalls == 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    gate.complete();
    await _until(tester, () => MediaLifecyclePolicy.activeVideoPreviews == 0);
    expect(platform.createCalls, 1);
    expect(MediaLifecyclePolicy.waitingVideoPreviewListeners, 0);
    await _remove(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}

Future<File> _seed(String url, int version) =>
    TemplateMediaCache.previewVideoCache.putFile(
      url,
      Uint8List.fromList([1, 2, 3]),
      key: TemplateMediaCache.cacheKeyForMedia(url, mediaVersion: version),
      fileExtension: 'mp4',
      maxAge: const Duration(hours: 1),
    );

Widget _host({
  int version = 4,
  bool allowDetailUpgrade = false,
  Future<VideoPlayerController> Function(String)? factory,
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
          template: TemplateItem(
            templateId: 'recovery',
            templateType: TemplateType.video,
            title: 'Video',
            shortDescription: '',
            petPhotoRequirements: const [],
            category: '',
            tags: const [],
            isPremium: false,
            tokenCost: 1,
            mediaKind: 'video',
            mediaVersion: version,
            feedLoopLowUrl: _low,
            feedLoopMediumUrl: _medium,
            detailPreviewUrl: _detail,
          ),
          expand: true,
          immersive: true,
          allowDetailUpgrade: allowDetailUpgrade,
          controllerFactory: factory,
        ),
      ),
    ),
  ),
);

Future<void> _mount(WidgetTester tester, Widget host) async {
  await tester.pumpWidget(host);
  showTemplateCard(tester, size: const Size(320, 480));
  await tester.pump();
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Preview operation did not settle');
}

Future<void> _remove(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _until(tester, () => MediaLifecyclePolicy.activeVideoPreviews == 0);
  await tester.pump(const Duration(seconds: 4));
  // Directory scans perform several OS IO steps whose continuations use the
  // widget's fake-async zone. Let those finish before that zone is torn down.
  for (var index = 0; index < 12; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 4));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

class _DecodeFailurePlatform extends FakeVideoPlayerPlatform {
  final Set<String> badUris = {};
  final Map<String, Completer<void>> gates = {};
  final Map<int, String?> sources = {};

  @override
  Future<int?> create(DataSource source) async {
    final id = await super.create(source);
    sources[id!] = source.uri;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      super.videoEventsFor(playerId).asyncMap((event) async {
        final uri = sources[playerId];
        if (event.eventType == VideoEventType.initialized &&
            badUris.contains(uri)) {
          await gates[uri]?.future;
          throw PlatformException(
            code: 'VideoError',
            message: 'Unrecognized input format: corrupt cached media',
          );
        }
        return event;
      });
}

class _VolumeFailureController extends VideoPlayerController {
  _VolumeFailureController(super.file) : super.file();

  @override
  Future<void> setVolume(double volume) async =>
      throw StateError('volume channel unavailable');
}
