import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

const _localDebugHosts = <String>{
  'localhost',
  '127.0.0.1',
  '10.0.2.2',
  '10.0.3.2',
  'host.docker.internal',
};

Uri? parseSafeExternalUri(
  String? rawValue, {
  Set<String>? allowedHttpsHosts,
  bool allowLocalHttp = kDebugMode,
}) {
  final trimmed = rawValue?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }

  return isAllowedExternalUri(
        uri,
        allowedHttpsHosts: allowedHttpsHosts,
        allowLocalHttp: allowLocalHttp,
      )
      ? uri
      : null;
}

Uri? parseSafeSupportExternalUri(String? rawValue) {
  return parseSafeExternalUri(
    rawValue,
    allowedHttpsHosts: supportExternalAllowedHosts(),
  );
}

Uri? parseSafeGenerationMediaUri(String? rawValue) {
  if (kDebugMode) {
    return parseSafeExternalUri(rawValue);
  }

  return parseSafeExternalUri(
    rawValue,
    allowedHttpsHosts: generationMediaAllowedHosts(),
    allowLocalHttp: AppConfig.allowLocalMediaHttp,
  );
}

Uri? parseSafeGenerationShareUri(String? rawValue) {
  return parseSafeExternalUri(
    rawValue,
    allowedHttpsHosts: generationShareAllowedHosts(),
    allowLocalHttp: kDebugMode || AppConfig.allowLocalMediaHttp,
  );
}

Uri? parseSafeProfileAvatarUri(String? rawValue) {
  return parseSafeExternalUri(
    rawValue,
    allowedHttpsHosts: profileAvatarAllowedHosts(),
  );
}

Uri? parseSafePremiumExternalUri(String? rawValue) {
  return parseSafeExternalUri(
    rawValue,
    allowedHttpsHosts: premiumExternalAllowedHosts(),
  );
}

bool isAllowedExternalUri(
  Uri uri, {
  Set<String>? allowedHttpsHosts,
  bool allowLocalHttp = kDebugMode,
}) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (host.isEmpty) {
    return false;
  }

  if (uri.userInfo.isNotEmpty) {
    return false;
  }

  if (scheme == 'https') {
    final normalizedAllowedHosts = allowedHttpsHosts
        ?.map((value) => value.toLowerCase())
        .toSet();
    if (normalizedAllowedHosts == null || normalizedAllowedHosts.isEmpty) {
      return true;
    }

    return normalizedAllowedHosts.any(
      (allowedHost) => host == allowedHost || host.endsWith('.$allowedHost'),
    );
  }

  if (scheme != 'http' || !allowLocalHttp) {
    return false;
  }

  return _localDebugHosts.contains(host) || _isPrivateIpv4Host(host);
}

Set<String> premiumExternalAllowedHosts() {
  final result = <String>{
    'petmagic.app',
    'www.petmagic.app',
    'api.petmagic.app',
    'billing.stripe.com',
    'checkout.stripe.com',
    'dashboard.stripe.com',
  };

  final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBaseUri != null && apiBaseUri.host.isNotEmpty) {
    result.add(apiBaseUri.host.toLowerCase());
  }

  return result;
}

Set<String> supportExternalAllowedHosts() {
  final result = <String>{
    'petmagic.app',
    'www.petmagic.app',
    'api.petmagic.app',
    'cdn.petmagic.app',
    'cdn.petmagic.ai',
  };

  final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBaseUri != null && apiBaseUri.host.isNotEmpty) {
    result.add(apiBaseUri.host.toLowerCase());
  }

  return result;
}

Set<String> generationMediaAllowedHosts() {
  final result = <String>{
    'api.petmagic.app',
    'cdn.petmagic.app',
    'cdn.petmagic.ai',
    'r2.dev',
    'r2.cloudflarestorage.com',
  };

  final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBaseUri != null && apiBaseUri.host.isNotEmpty) {
    result.add(apiBaseUri.host.toLowerCase());
  }

  return result;
}

Set<String> generationShareAllowedHosts() {
  final result = <String>{
    'petmagic.app',
    'www.petmagic.app',
    'app.petmagic.app',
    'api.petmagic.app',
    'cdn.petmagic.app',
  };

  final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBaseUri != null && apiBaseUri.host.isNotEmpty) {
    result.add(apiBaseUri.host.toLowerCase());
  }

  return result;
}

Set<String> profileAvatarAllowedHosts() {
  final result = <String>{
    'api.petmagic.app',
    'cdn.petmagic.app',
    'cdn.petmagic.ai',
    'r2.dev',
    'r2.cloudflarestorage.com',
  };

  final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBaseUri != null && apiBaseUri.host.isNotEmpty) {
    result.add(apiBaseUri.host.toLowerCase());
  }

  return result;
}

bool _isPrivateIpv4Host(String host) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return false;
  }

  final octets = parts.map(int.tryParse).toList(growable: false);
  if (octets.any((value) => value == null || value < 0 || value > 255)) {
    return false;
  }

  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}
