import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

String? persistentSafeGenerationMediaUrl(String? rawValue) {
  final uri = parseSafeGenerationMediaUri(rawValue);
  if (uri == null) {
    return null;
  }

  return persistentSafeMediaUri(uri);
}

String? persistentSafeSupportMediaUrl(String? rawValue) {
  final uri = parseSafeSupportExternalUri(rawValue);
  if (uri == null) {
    return null;
  }

  return persistentSafeMediaUri(uri);
}

String? persistentSafeProfileAvatarUrl(String? rawValue) {
  final uri = parseSafeProfileAvatarUri(rawValue);
  if (uri == null) {
    return null;
  }

  return persistentSafeMediaUri(uri);
}

String persistentSafeMediaCacheKeyUrl(String rawValue) {
  final normalized = rawValue.trim();
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return normalized;
  }

  return persistentSafeMediaUri(uri);
}

String persistentSafeMediaFileName(String rawValue) {
  final queryStart = rawValue.indexOf('?');
  final fragmentStart = rawValue.indexOf('#');
  final cutPoints = [
    if (queryStart >= 0) queryStart,
    if (fragmentStart >= 0) fragmentStart,
  ];
  if (cutPoints.isEmpty) {
    return rawValue;
  }

  cutPoints.sort();
  return rawValue.substring(0, cutPoints.first);
}

String persistentSafeMediaUri(Uri uri) {
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}
