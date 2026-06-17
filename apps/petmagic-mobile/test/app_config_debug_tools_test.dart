import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    final shell = File(
      'lib/shared/navigation/petmagic_shell.dart',
    ).readAsStringSync();
    final templatesPage = File(
      'lib/features/templates/presentation/templates_page.dart',
    ).readAsStringSync();

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

  test('Android app Gradle config uses Flutter built-in Kotlin support', () {
    final properties = File('android/gradle.properties').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(properties, contains('android.builtInKotlin=true'));
    expect(gradle, isNot(contains('id("kotlin-android")')));
    expect(gradle, isNot(contains('id("org.jetbrains.kotlin.android")')));
    expect(gradle, isNot(contains('kotlinOptions')));
    expect(gradle, contains('kotlin {\n    compilerOptions {'));
    expect(
      gradle,
      contains('jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17'),
    );
  });
}
