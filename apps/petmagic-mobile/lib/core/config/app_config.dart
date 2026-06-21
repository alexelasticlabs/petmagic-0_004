import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const productionApiBaseUrl = 'https://api.petmagic.app';
  static const _productionApiHosts = {'api.petmagic.app'};

  static const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const appVersion = String.fromEnvironment(
    'PETMAGIC_APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const _enablePerformanceOverlay = bool.fromEnvironment(
    'PETMAGIC_PROFILE_OVERLAY',
  );
  static const _enableCheckerboardRasterCacheImages = bool.fromEnvironment(
    'PETMAGIC_PROFILE_CHECKERBOARD_RASTER_CACHE',
  );
  static const _enableCheckerboardOffscreenLayers = bool.fromEnvironment(
    'PETMAGIC_PROFILE_CHECKERBOARD_OFFSCREEN_LAYERS',
  );
  static const _enableFrameTelemetry = bool.fromEnvironment(
    'PETMAGIC_PROFILE_FRAME_LOGS',
  );
  static const targetFrameBudgetMs = int.fromEnvironment(
    'PETMAGIC_TARGET_FRAME_BUDGET_MS',
    defaultValue: 8,
  );

  static const mediaCacheMaxBytes = int.fromEnvironment(
    'PETMAGIC_MEDIA_CACHE_MAX_BYTES',
    defaultValue: 120 * 1024 * 1024,
  );
  static const mediaCacheStalePeriodHours = int.fromEnvironment(
    'PETMAGIC_MEDIA_CACHE_STALE_HOURS',
    defaultValue: 24,
  );
  static const mediaTempFileTtlHours = int.fromEnvironment(
    'PETMAGIC_MEDIA_TEMP_FILE_TTL_HOURS',
    defaultValue: 24,
  );
  static const decodedImageCacheMaxObjects = int.fromEnvironment(
    'PETMAGIC_DECODED_IMAGE_CACHE_MAX_OBJECTS',
    defaultValue: 200,
  );
  static const decodedImageCacheMaxBytes = int.fromEnvironment(
    'PETMAGIC_DECODED_IMAGE_CACHE_MAX_BYTES',
    defaultValue: 48 * 1024 * 1024,
  );
  static const allowLocalMediaHttp = bool.fromEnvironment(
    'PETMAGIC_ALLOW_LOCAL_MEDIA_HTTP',
  );

  static Duration get mediaCacheStalePeriod {
    final safeHours = mediaCacheStalePeriodHours <= 0
        ? 24
        : mediaCacheStalePeriodHours;
    return Duration(hours: safeHours);
  }

  static Duration get mediaTempFileTtl {
    final safeHours = mediaTempFileTtlHours <= 0 ? 24 : mediaTempFileTtlHours;
    return Duration(hours: safeHours);
  }

  static int get mediaCacheMaxBytesSafe {
    if (mediaCacheMaxBytes <= 0) {
      return 120 * 1024 * 1024;
    }

    return mediaCacheMaxBytes;
  }

  static int get decodedImageCacheMaxObjectsSafe {
    if (decodedImageCacheMaxObjects <= 0) {
      return 200;
    }

    return decodedImageCacheMaxObjects;
  }

  static int get decodedImageCacheMaxBytesSafe {
    if (decodedImageCacheMaxBytes <= 0) {
      return 48 * 1024 * 1024;
    }

    return decodedImageCacheMaxBytes;
  }

  static bool get enablePerformanceOverlay {
    return kDebugMode && _enablePerformanceOverlay;
  }

  static bool get enableCheckerboardRasterCacheImages {
    return kDebugMode && _enableCheckerboardRasterCacheImages;
  }

  static bool get enableCheckerboardOffscreenLayers {
    return kDebugMode && _enableCheckerboardOffscreenLayers;
  }

  static bool get enableFrameTelemetry {
    return (kDebugMode || kProfileMode) && _enableFrameTelemetry;
  }

  static List<String> get apiBaseUrls {
    if (configuredApiBaseUrl.isNotEmpty) {
      if (!kDebugMode) {
        final productionBaseUrl = normalizeProductionBaseUrl(
          configuredApiBaseUrl,
        );
        return productionBaseUrl == null
            ? const [productionApiBaseUrl]
            : [productionBaseUrl];
      }

      if (kDebugMode &&
          !kIsWeb &&
          Platform.isAndroid &&
          _isConfiguredLoopbackBaseUrl) {
        return _orderedUniqueUrls([
          configuredApiBaseUrl,
          'http://10.0.2.2:5001',
          'http://host.docker.internal:5001',
          'http://10.0.3.2:5001',
          'http://127.0.0.1:5001',
          'http://localhost:5001',
          'http://10.0.2.2:5000',
          'http://host.docker.internal:5000',
          'http://10.0.3.2:5000',
          'http://127.0.0.1:5000',
          'http://localhost:5000',
        ]);
      }

      return [configuredApiBaseUrl];
    }

    if (kDebugMode && !kIsWeb && Platform.isAndroid) {
      return const [
        'http://10.0.2.2:5001',
        'http://host.docker.internal:5001',
        'http://10.0.3.2:5001',
        'http://127.0.0.1:5001',
        'http://localhost:5001',
        'http://10.0.2.2:5000',
        'http://host.docker.internal:5000',
        'http://10.0.3.2:5000',
        'http://127.0.0.1:5000',
        'http://localhost:5000',
      ];
    }

    if (kDebugMode) {
      return const [
        'http://localhost:5001',
        'http://127.0.0.1:5001',
        'http://localhost:5000',
        'http://127.0.0.1:5000',
      ];
    }

    return const [productionApiBaseUrl];
  }

  static String get apiBaseUrl {
    return apiBaseUrls.first;
  }

  static bool get _isConfiguredLoopbackBaseUrl {
    final uri = Uri.tryParse(configuredApiBaseUrl.trim());
    if (uri == null) {
      return false;
    }

    final host = uri.host;
    return host == 'localhost' || host == '127.0.0.1';
  }

  static bool isProductionSafeBaseUrl(String rawUrl) {
    return normalizeProductionBaseUrl(rawUrl) != null;
  }

  static String? normalizeProductionBaseUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasAuthority) {
      return null;
    }

    if (uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }

    if (!uri.isScheme('https')) {
      return null;
    }

    if (uri.hasPort && uri.port != 443) {
      return null;
    }

    final host = uri.host.toLowerCase();
    if (!_productionApiHosts.contains(host)) {
      return null;
    }

    return 'https://$host';
  }

  static List<String> _orderedUniqueUrls(Iterable<String> rawUrls) {
    final unique = <String>{};
    final ordered = <String>[];
    for (final rawUrl in rawUrls) {
      final value = rawUrl.trim();
      if (value.isEmpty) {
        continue;
      }
      if (unique.add(value)) {
        ordered.add(value);
      }
    }
    return ordered;
  }
}
