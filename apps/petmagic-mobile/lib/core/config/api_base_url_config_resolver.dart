import 'dart:io';

typedef ReleaseBaseUrlNormalizer =
    String? Function(String rawUrl, {required String environment});

List<String> resolveConfiguredApiBaseUrls({
  required String configuredBaseUrl,
  required bool isDebugBuild,
  required bool isReleaseBuild,
  required bool isWebBuild,
  required String appEnvironment,
  required String productionBaseUrl,
  required ReleaseBaseUrlNormalizer normalizeReleaseBaseUrl,
  bool? isAndroidDevice,
}) {
  if (configuredBaseUrl.isNotEmpty) {
    if (isReleaseBuild) {
      final releaseBaseUrl = normalizeReleaseBaseUrl(
        configuredBaseUrl,
        environment: appEnvironment,
      );
      return releaseBaseUrl == null ? [productionBaseUrl] : [releaseBaseUrl];
    }

    final android = isAndroidDevice ?? (!isWebBuild && Platform.isAndroid);
    if (isDebugBuild &&
        !isWebBuild &&
        android &&
        _isLoopbackBaseUrl(configuredBaseUrl)) {
      return _orderedUniqueUrls([configuredBaseUrl, ..._androidDebugBaseUrls]);
    }

    return [configuredBaseUrl];
  }

  final android = isAndroidDevice ?? (!isWebBuild && Platform.isAndroid);
  if (isDebugBuild && !isWebBuild && android) {
    return _androidDebugBaseUrls;
  }

  if (isDebugBuild) {
    return _desktopDebugBaseUrls;
  }

  return [productionBaseUrl];
}

const _androidDebugBaseUrls = [
  'http://10.0.2.2:5000',
  'http://10.0.2.2:5001',
  'http://host.docker.internal:5000',
  'http://host.docker.internal:5001',
  'http://10.0.3.2:5000',
  'http://10.0.3.2:5001',
  'http://127.0.0.1:5000',
  'http://127.0.0.1:5001',
  'http://localhost:5000',
  'http://localhost:5001',
];

const _desktopDebugBaseUrls = [
  'http://localhost:5000',
  'http://localhost:5001',
  'http://127.0.0.1:5000',
  'http://127.0.0.1:5001',
];

bool _isLoopbackBaseUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) {
    return false;
  }

  final host = uri.host;
  return host == 'localhost' || host == '127.0.0.1';
}

List<String> _orderedUniqueUrls(Iterable<String> rawUrls) {
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
