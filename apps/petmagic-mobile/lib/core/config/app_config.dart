import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/config/api_base_url_config_resolver.dart';

@immutable
class AndroidLoopbackBackendHintConfig {
  const AndroidLoopbackBackendHintConfig({
    required this.baseUrl,
    required this.port,
  });

  final String baseUrl;
  final int port;
}

class AppConfig {
  const AppConfig._();

  static const stagingApiBaseUrl = 'https://api.staging.petgpt.app';
  static const productionApiBaseUrl = 'https://api.petgpt.app';
  static const stagingDeepLinkScheme = 'petmagic-staging';
  static const productionDeepLinkScheme = 'petmagic';
  static const stagingStripeRedirectScheme = 'petmagicstripe-staging';
  static const productionStripeRedirectScheme = 'petmagicstripe';
  static const appEnvironment = String.fromEnvironment('APP_ENVIRONMENT');
  static const appPackageName = String.fromEnvironment(
    'APP_PACKAGE_NAME',
    defaultValue: String.fromEnvironment(
      'PETMAGIC_ANDROID_PACKAGE_NAME',
      defaultValue: 'com.petmagic.app',
    ),
  );
  static const androidPackageName = String.fromEnvironment(
    'APP_PACKAGE_NAME',
    defaultValue: String.fromEnvironment(
      'PETMAGIC_ANDROID_PACKAGE_NAME',
      defaultValue: 'com.petmagic.app',
    ),
  );

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
    defaultValue: 64 * 1024 * 1024,
  );
  static const previewVideoCacheMaxBytes = int.fromEnvironment(
    'PETMAGIC_PREVIEW_VIDEO_CACHE_MAX_BYTES',
    defaultValue: 192 * 1024 * 1024,
  );
  static const mediaCacheStalePeriodHours = int.fromEnvironment(
    'PETMAGIC_MEDIA_CACHE_STALE_HOURS',
    defaultValue: 24,
  );
  static const mediaTempFileTtlHours = int.fromEnvironment(
    'PETMAGIC_MEDIA_TEMP_FILE_TTL_HOURS',
    defaultValue: 24,
  );
  static const generationCacheTtlHours = int.fromEnvironment(
    'PETMAGIC_GENERATION_CACHE_TTL_HOURS',
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

  static Duration get generationCacheTtl {
    final safeHours = generationCacheTtlHours <= 0
        ? 24
        : generationCacheTtlHours;
    return Duration(hours: safeHours);
  }

  static int get mediaCacheMaxBytesSafe {
    if (mediaCacheMaxBytes <= 0) {
      return 64 * 1024 * 1024;
    }

    return mediaCacheMaxBytes;
  }

  static int get previewVideoCacheMaxBytesSafe {
    if (previewVideoCacheMaxBytes <= 0) {
      return 192 * 1024 * 1024;
    }

    return previewVideoCacheMaxBytes;
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
    return resolveApiBaseUrls(
      configuredBaseUrl: configuredApiBaseUrl,
      isDebugBuild: kDebugMode,
      isReleaseBuild: kReleaseMode,
      isWebBuild: kIsWeb,
    );
  }

  static List<String> resolveApiBaseUrls({
    required String configuredBaseUrl,
    required bool isDebugBuild,
    required bool isReleaseBuild,
    required bool isWebBuild,
    bool? isAndroidDevice,
  }) {
    return resolveConfiguredApiBaseUrls(
      configuredBaseUrl: configuredBaseUrl,
      isDebugBuild: isDebugBuild,
      isReleaseBuild: isReleaseBuild,
      isWebBuild: isWebBuild,
      isAndroidDevice: isAndroidDevice,
      appEnvironment: appEnvironment,
      productionBaseUrl: productionApiBaseUrl,
      normalizeReleaseBaseUrl: normalizeReleaseBaseUrl,
    );
  }

  static String get apiBaseUrl {
    return apiBaseUrls.first;
  }

  static String get deepLinkScheme {
    return deepLinkSchemeForEnvironment(appEnvironment) ??
        productionDeepLinkScheme;
  }

  static String get stripeRedirectScheme {
    return stripeRedirectSchemeForEnvironment(appEnvironment) ??
        productionStripeRedirectScheme;
  }

  static String? stripeRedirectSchemeForEnvironment(String environment) {
    return switch (environment.trim().toLowerCase()) {
      'staging' => stagingStripeRedirectScheme,
      '' || 'development' || 'production' => productionStripeRedirectScheme,
      _ => null,
    };
  }

  static String? deepLinkSchemeForEnvironment(String environment) {
    return switch (environment.trim().toLowerCase()) {
      'staging' => stagingDeepLinkScheme,
      '' || 'development' || 'production' => productionDeepLinkScheme,
      _ => null,
    };
  }

  static bool isExpectedDeepLinkScheme(
    String scheme, {
    String environment = appEnvironment,
  }) {
    final expectedScheme = deepLinkSchemeForEnvironment(environment);
    return expectedScheme != null &&
        scheme.trim().toLowerCase() == expectedScheme;
  }

  static bool isProductionSafeBaseUrl(String rawUrl) {
    return normalizeProductionBaseUrl(rawUrl) != null;
  }

  static void validateReleaseConfiguration({
    bool isReleaseBuild = kReleaseMode,
    String environment = appEnvironment,
    String apiBaseUrl = configuredApiBaseUrl,
    String packageName = appPackageName,
  }) {
    if (!isReleaseBuild) {
      return;
    }

    final normalizedEnvironment = environment.trim().toLowerCase();
    final expected = switch (normalizedEnvironment) {
      'staging' => (
        apiBaseUrl: stagingApiBaseUrl,
        packageName: 'com.petmagic.app.staging',
      ),
      'production' => (
        apiBaseUrl: productionApiBaseUrl,
        packageName: 'com.petmagic.app',
      ),
      _ => throw StateError(
        'APP_ENVIRONMENT must be staging or production for release builds.',
      ),
    };

    final normalizedApiBaseUrl = normalizeReleaseBaseUrl(
      apiBaseUrl,
      environment: normalizedEnvironment,
    );
    if (normalizedApiBaseUrl != expected.apiBaseUrl) {
      throw StateError(
        'API_BASE_URL does not match APP_ENVIRONMENT=$normalizedEnvironment.',
      );
    }
    if (packageName.trim() != expected.packageName) {
      throw StateError(
        'APP_PACKAGE_NAME does not match APP_ENVIRONMENT=$normalizedEnvironment.',
      );
    }
  }

  static AndroidLoopbackBackendHintConfig? androidLoopbackBackendHintConfig({
    String configuredBaseUrl = configuredApiBaseUrl,
    bool isDebugBuild = kDebugMode,
    bool isWeb = kIsWeb,
    bool? isAndroidDevice,
  }) {
    if (!isDebugBuild || isWeb) {
      return null;
    }

    final android = isAndroidDevice ?? (!kIsWeb && Platform.isAndroid);
    if (!android) {
      return null;
    }

    final trimmed = configuredBaseUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') {
      return null;
    }

    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return AndroidLoopbackBackendHintConfig(baseUrl: trimmed, port: port);
  }

  static String? normalizeProductionBaseUrl(String rawUrl) {
    return normalizeReleaseBaseUrl(rawUrl, environment: 'production');
  }

  static String? normalizeReleaseBaseUrl(
    String rawUrl, {
    required String environment,
  }) {
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

    final expectedHost = switch (environment.trim().toLowerCase()) {
      'staging' => 'api.staging.petgpt.app',
      'production' => 'api.petgpt.app',
      _ => null,
    };
    final host = uri.host.toLowerCase();
    if (expectedHost == null || host != expectedHost) {
      return null;
    }

    return 'https://$host';
  }
}
