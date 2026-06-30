import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

void main() {
  test(
    'debug and profiling tools are guarded out of production builds',
    () async {
      final source = await File(
        'lib/core/config/app_config.dart',
      ).readAsString();
      final main = await File('lib/main.dart').readAsString();
      final router = await File(
        'lib/app/router/app_router.dart',
      ).readAsString();

      expect(
        source,
        contains('return kDebugMode && _enablePerformanceOverlay;'),
      );
      expect(
        source,
        contains('return kDebugMode && _enableCheckerboardRasterCacheImages;'),
      );
      expect(
        source,
        contains('return kDebugMode && _enableCheckerboardOffscreenLayers;'),
      );
      expect(
        source,
        contains(
          'return (kDebugMode || kProfileMode) && _enableFrameTelemetry;',
        ),
      );
      expect(
        main,
        contains('GoogleFonts.config.allowRuntimeFetching = false;'),
      );
      expect(
        File('lib/app/app.dart').readAsStringSync(),
        contains('debugShowCheckedModeBanner: false,'),
      );
      expect(router, isNot(contains('/debug/')));
    },
  );

  test('global rebuild hot paths use scoped subscriptions', () {
    final app = File('lib/app/app.dart').readAsStringSync();
    final shell = _readShellLibrarySource();
    final templatesPage = _readTemplatesPageLibrarySource();

    expect(app, isNot(contains('ref.watch(networkStatusControllerProvider);')));
    expect(shell, contains('class _ActiveGenerationBannerSlot'));
    expect(shell, contains('PerformanceGuard.isDegradedMode(context)'));
    expect(shell, contains('AppPerformanceTrace.setRouteLabel(location);'));
    expect(templatesPage, contains('ref.listen<String?>('));
    expect(
      templatesPage,
      isNot(contains('_syncSearchFieldWithQuery(state.query.search);')),
    );
    expect(templatesPage, contains('SliverLayoutBuilder('));
    expect(
      templatesPage,
      contains('templateCardImageCacheWidthForLogicalWidth('),
    );
  });

  test('release Android signing cannot silently fall back to debug keystore', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('hasReleaseSigningConfig'));
    expect(gradle, contains('isReleaseTaskRequested'));
    expect(gradle, contains('allowInsecureReleaseSigning'));
    expect(gradle, contains('throw GradleException('));
    expect(gradle, contains('Release signing is not configured.'));
    expect(
      gradle,
      contains(
        'set -PallowInsecureReleaseSigning=true only for local temporary builds.',
      ),
    );
    expect(gradle, contains('isMinifyEnabled = true'));
    expect(gradle, contains('isShrinkResources = true'));
    expect(
      gradle,
      contains('getDefaultProguardFile("proguard-android-optimize.txt"),'),
    );
  });

  test(
    'Android app Gradle config follows the current Flutter Kotlin DSL path',
    () {
      final properties = File('android/gradle.properties').readAsStringSync();
      final settings = File('android/settings.gradle.kts').readAsStringSync();
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(properties, contains('android.newDsl=false'));
      expect(properties, contains('android.builtInKotlin=false'));
      expect(settings, contains('id("org.jetbrains.kotlin.android") version '));
      expect(gradle, isNot(contains('id("kotlin-android")')));
      expect(gradle, isNot(contains('id("org.jetbrains.kotlin.android")')));
      expect(gradle, isNot(contains('kotlinOptions')));
      expect(gradle, contains('kotlin {'));
      expect(gradle, contains('sourceCompatibility = JavaVersion.VERSION_17'));
      expect(gradle, contains('targetCompatibility = JavaVersion.VERSION_17'));
    },
  );

  test(
    'Android debug loopback hint is only exposed for localhost-style URLs',
    () {
      final loopback = AppConfig.androidLoopbackBackendHintConfig(
        configuredBaseUrl: 'http://127.0.0.1:5000',
        isDebugBuild: true,
        isWeb: false,
        isAndroidDevice: true,
      );
      final lan = AppConfig.androidLoopbackBackendHintConfig(
        configuredBaseUrl: 'http://192.168.1.50:5000',
        isDebugBuild: true,
        isWeb: false,
        isAndroidDevice: true,
      );
      final achievementsPage = File(
        'lib/features/gamification/presentation/achievements_page.dart',
      ).readAsStringSync();
      final profileGamification = File(
        'lib/features/profile/presentation/profile_page_gamification.part.dart',
      ).readAsStringSync();

      expect(loopback?.baseUrl, 'http://127.0.0.1:5000');
      expect(loopback?.port, 5000);
      expect(lan, isNull);
      expect(
        achievementsPage,
        contains('AndroidLoopbackBackendHint(config: loopbackHintConfig)'),
      );
      expect(profileGamification, contains('AndroidLoopbackBackendHint('));
    },
  );
}

String _readShellLibrarySource() {
  const files = [
    'lib/shared/navigation/petmagic_shell.dart',
    'lib/shared/navigation/petmagic_shell_active_generation.part.dart',
    'lib/shared/navigation/petmagic_shell_backdrop.part.dart',
    'lib/shared/navigation/petmagic_shell_navigation.part.dart',
    'lib/shared/navigation/petmagic_shell_transition.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}

String _readTemplatesPageLibrarySource() {
  const files = [
    'lib/features/templates/presentation/templates_page.dart',
    'lib/features/templates/presentation/templates_page_feed.part.dart',
    'lib/features/templates/presentation/templates_page_generation_flow.part.dart',
    'lib/features/templates/presentation/templates_page_lifecycle.part.dart',
    'lib/features/templates/presentation/templates_page_template_actions.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}
