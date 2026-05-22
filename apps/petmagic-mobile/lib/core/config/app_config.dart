import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const appVersion = String.fromEnvironment(
    'PETMAGIC_APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const enablePerformanceOverlay = bool.fromEnvironment(
    'PETMAGIC_PROFILE_OVERLAY',
  );
  static const enableCheckerboardRasterCacheImages = bool.fromEnvironment(
    'PETMAGIC_PROFILE_CHECKERBOARD_RASTER_CACHE',
  );
  static const enableCheckerboardOffscreenLayers = bool.fromEnvironment(
    'PETMAGIC_PROFILE_CHECKERBOARD_OFFSCREEN_LAYERS',
  );
  static const enableFrameTelemetry = bool.fromEnvironment(
    'PETMAGIC_PROFILE_FRAME_LOGS',
  );
  static const enableImageCacheTelemetry = bool.fromEnvironment(
    'PETMAGIC_PROFILE_IMAGE_CACHE_LOGS',
  );
  static const targetFrameBudgetMs = int.fromEnvironment(
    'PETMAGIC_TARGET_FRAME_BUDGET_MS',
    defaultValue: 8,
  );
  static const imageCacheTelemetryIntervalSeconds = int.fromEnvironment(
    'PETMAGIC_IMAGE_CACHE_LOG_INTERVAL_SECONDS',
    defaultValue: 8,
  );

  static List<String> get apiBaseUrls {
    if (configuredApiBaseUrl.isNotEmpty) {
      return [configuredApiBaseUrl];
    }

    if (!kIsWeb && Platform.isAndroid) {
      return const [
        'http://10.0.2.2:5000',
        'http://host.docker.internal:5000',
        'http://10.0.3.2:5000',
        'http://127.0.0.1:5000',
        'http://localhost:5000',
      ];
    }

    return const ['http://localhost:5000', 'http://127.0.0.1:5000'];
  }

  static String get apiBaseUrl {
    return apiBaseUrls.first;
  }
}
