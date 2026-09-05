import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:video_player/video_player.dart';

const _enabled = bool.fromEnvironment('PETMAGIC_RUN_LOCAL_PREVIEW_FIXTURE');
const _origin = String.fromEnvironment(
  'PETMAGIC_FIXTURE_ORIGIN',
  defaultValue: 'http://127.0.0.1:8787',
);

// Separate entrypoint: deliberately does not call app.main(), initialize auth,
// or reset SharedPreferences. Only QA-specific cache paths are changed below.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native low preview plays during throttled distinct HQ and reopens on disk',
    (tester) async {
      expect(AppConfig.allowLocalMediaHttp, isTrue);
      final origin = Uri.parse(_origin);
      expect(origin.scheme, 'http');
      expect(origin.host, anyOf('127.0.0.1', 'localhost'));
      final run = 'native-${DateTime.now().microsecondsSinceEpoch}';
      final originalPaths = PathProviderPlatform.instance;
      final temporary = await originalPaths.getTemporaryPath();
      final support = await originalPaths.getApplicationSupportPath();
      expect(temporary, isNotNull);
      expect(support, isNotNull);
      PathProviderPlatform.instance = _FixturePaths(
        temporary: '$temporary/petmagic-preview-fixture/$run',
        support: '$support/petmagic-preview-fixture/$run',
      );
      MediaLifecyclePolicy.reset();
      var maxObservedSlots = 0;
      void sampleSlots() {
        final current = MediaLifecyclePolicy.activeVideoPreviews;
        if (current > maxObservedSlots) maxObservedSlots = current;
      }

      final slotSampler = Timer.periodic(
        const Duration(milliseconds: 5),
        (_) => sampleSlots(),
      );
      final frames = <ui.FrameTiming>[];
      void collectFrames(List<ui.FrameTiming> batch) {
        if (frames.length < 10000) frames.addAll(batch);
      }

      binding.addTimingsCallback(collectFrames);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await _until(
          tester,
          () => MediaLifecyclePolicy.activeVideoPreviews == 0,
        );
        binding.removeTimingsCallback(collectFrames);
        // Managers were first created after the QA path override. This never
        // clears the normal staging cache or SharedPreferences directories.
        await TemplateMediaCache.clearAll();
        PathProviderPlatform.instance = originalPaths;
        MediaLifecyclePolicy.reset();
      });

      final template = _template(run);
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(_host(template));
      await _until(tester, () => _playingController(tester, 360) != null);
      final lowReadyMs = stopwatch.elapsedMilliseconds;
      final low = _playingController(tester, 360)!;
      await _untilAsync(tester, () async {
        final events = await _serverEvents(run);
        return events.any(
          (event) => event['event'] == 'start' && event['variant'] == 'hq',
        );
      });
      final before = low.value.position;
      await tester.pump(const Duration(milliseconds: 1000));
      expect(low.value.isPlaying, isTrue);
      expect(low.value.position, greaterThan(before));
      final during = await _serverEvents(run);
      expect(
        during.where(
          (event) => event['event'] == 'finish' && event['variant'] == 'hq',
        ),
        isEmpty,
        reason: 'Low must keep playing before the throttled HQ transfer ends',
      );
      await _until(
        tester,
        () => _playingController(tester, 1080) != null,
        timeout: const Duration(seconds: 45),
      );
      final hqReadyMs = stopwatch.elapsedMilliseconds;
      expect(hqReadyMs, greaterThan(lowReadyMs + 1000));
      // Native HQ can start before asynchronous disposal of the low decoder
      // releases its lease. Check the settled state rather than that instant.
      await _until(tester, () => MediaLifecyclePolicy.activeVideoPreviews == 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await _until(tester, () => MediaLifecyclePolicy.activeVideoPreviews == 0);
      slotSampler.cancel();
      TemplateMediaCache.releaseMemoryReferences();
      final beforeReopen = await _serverEvents(run);
      final getsBeforeReopen = _starts(beforeReopen);
      expect(getsBeforeReopen.where((e) => e['variant'] == 'low').length, 1);
      expect(getsBeforeReopen.where((e) => e['variant'] == 'hq').length, 1);
      expect(getsBeforeReopen.where((e) => e['variant'] == 'medium'), isEmpty);
      final reopen = Stopwatch()..start();
      await tester.pumpWidget(_host(template));
      await _until(tester, () => _playingController(tester, 1080) != null);
      final reopenReadyMs = reopen.elapsedMilliseconds;
      await tester.pump(const Duration(milliseconds: 1000));
      final afterReopen = await _serverEvents(run);
      expect(_starts(afterReopen).length, getsBeforeReopen.length);
      sampleSlots();
      expect(maxObservedSlots, lessThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'scenario': 'native_distinct_low_hq_throttled_cache_reopen',
        'run': run,
        'low_initialized_playing_ms': lowReadyMs,
        'hq_initialized_playing_ms': hqReadyMs,
        'disk_reopen_initialized_playing_ms': reopenReadyMs,
        'frame_count': frames.length,
        'max_observed_active_video_slots': maxObservedSlots,
        'slot_sampling_interval_ms': 5,
        'slot_measurement_scope':
            'Observed maximum at 5 ms polling; transient shorter peaks may be missed',
        'build_p95_ms': _p95(frames.map((f) => f.buildDuration)),
        'raster_p95_ms': _p95(frames.map((f) => f.rasterDuration)),
        'http_events': afterReopen,
        'cache_isolation': 'QA-specific temporary and support directories',
        'timing_scope':
            'Initialized and playing state, not presented first-frame latency',
      };
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

TemplateItem _template(String run) => TemplateItem(
  templateId: 'fixture-$run',
  templateType: TemplateType.video,
  title: 'Synthetic native preview fixture',
  shortDescription: '360p feed to throttled 1080p HQ',
  petPhotoRequirements: const [],
  category: 'QA',
  tags: const [],
  isPremium: false,
  tokenCost: 0,
  mediaKind: 'video',
  mediaVersion: 1,
  feedLoopLowUrl: '$_origin/$run/slow/low.mp4',
  feedLoopMediumUrl: '$_origin/$run/slow/medium.mp4',
  detailPreviewUrl: '$_origin/$run/slow/hq.mp4',
  previewAsset: TemplateAsset(
    url: '$_origin/$run/slow/low.mp4',
    fileName: 'low.mp4',
    contentType: 'video/mp4',
  ),
);

Widget _host(TemplateItem template) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: TemplateMediaFrame(
      template: template,
      expand: true,
      immersive: true,
      playWhenActive: true,
      muted: true,
    ),
  ),
);

VideoPlayerController? _playingController(WidgetTester tester, double width) {
  for (final element in find.byType(VideoPlayer).evaluate()) {
    final controller = (element.widget as VideoPlayer).controller;
    if (controller.value.isInitialized &&
        controller.value.isPlaying &&
        controller.value.size.width == width) {
      return controller;
    }
  }
  return null;
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: 'Native preview wait exceeded $timeout');
}

Future<void> _untilAsync(
  WidgetTester tester,
  Future<bool> Function() condition,
) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < const Duration(seconds: 10)) {
    if (await condition()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Fixture HQ request did not start within ten seconds');
}

Future<List<Map<String, dynamic>>> _serverEvents(String run) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.getUrl(Uri.parse('$_origin/status/$run'));
    final response = await request.close().timeout(const Duration(seconds: 3));
    expect(response.statusCode, 200);
    final data =
        jsonDecode(
              await utf8.decoder
                  .bind(response)
                  .join()
                  .timeout(const Duration(seconds: 3)),
            )
            as Map;
    return (data['events'] as List).cast<Map<String, dynamic>>();
  } finally {
    client.close(force: true);
  }
}

List<Map<String, dynamic>> _starts(List<Map<String, dynamic>> events) =>
    events.where((event) => event['event'] == 'start').toList();

double? _p95(Iterable<Duration> durations) {
  final values = durations.map((d) => d.inMicroseconds / 1000).toList()..sort();
  return values.isEmpty ? null : values[(values.length * .95).ceil() - 1];
}

class _FixturePaths extends PathProviderPlatform {
  _FixturePaths({required this.temporary, required this.support});

  final String temporary;
  final String support;

  @override
  Future<String?> getTemporaryPath() async =>
      (await Directory(temporary).create(recursive: true)).path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      (await Directory(support).create(recursive: true)).path;
}
