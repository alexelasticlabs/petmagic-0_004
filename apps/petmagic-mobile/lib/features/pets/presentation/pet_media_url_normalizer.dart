import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

String? normalizePetMediaUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final sanitized = Uri.encodeFull(trimmed.replaceAll('\\', '/'));
  final parsed = Uri.tryParse(sanitized);
  final Uri candidate;
  if (parsed?.hasScheme == true) {
    candidate = parsed!;
  } else if (sanitized.startsWith('//')) {
    final baseUri = _petMediaBaseUri();
    final scheme = (baseUri?.scheme.isNotEmpty ?? false)
        ? baseUri!.scheme
        : 'http';
    final schemeRelative = Uri.tryParse('$scheme:$sanitized');
    if (schemeRelative == null) {
      return null;
    }
    candidate = schemeRelative;
  } else {
    final baseUri = _petMediaBaseUri();
    if (baseUri == null) {
      return null;
    }

    final relativePath = sanitized.startsWith('/') ? sanitized : '/$sanitized';
    candidate = baseUri.resolve(relativePath);
  }

  final reachableCandidate = _rewriteLocalBackendMediaUri(candidate);
  return parseSafeProfileAvatarUri(reachableCandidate.toString())?.toString();
}

Uri _rewriteLocalBackendMediaUri(Uri uri) {
  if (!_isLocalBackendHost(uri.host)) {
    return uri;
  }

  // The first configured URL is the endpoint that the API client is using.
  // Do not replace it with an emulator-only fallback such as 10.0.2.2: a
  // physical Android device reaches a loopback backend through adb reverse.
  final baseUri = _petMediaBaseUri();
  if (baseUri == null || baseUri.host.isEmpty) {
    return uri;
  }

  if (baseUri.host == uri.host && baseUri.scheme == uri.scheme) {
    return uri;
  }

  return uri.replace(
    scheme: baseUri.scheme.isEmpty ? uri.scheme : baseUri.scheme,
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
  );
}

Uri? _petMediaBaseUri() {
  final parsed = AppConfig.apiBaseUrls
      .map((value) => Uri.tryParse(value.trim()))
      .whereType<Uri>()
      .where((uri) => uri.hasScheme && uri.host.isNotEmpty)
      .toList(growable: false);
  if (parsed.isEmpty) {
    return null;
  }

  return parsed.first;
}

bool _isLocalBackendHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '0.0.0.0' ||
      normalized == 'host.docker.internal';
}
