import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/shared/network/unsafe_remote_host.dart';

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
    if (isUnsafeRemoteHost(host)) {
      return false;
    }

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

  return isLocalOrPrivateDebugHost(host);
}

Set<String> premiumExternalAllowedHosts() {
  final result = <String>{
    'petgpt.app',
    'www.petgpt.app',
    'api.petgpt.app',
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
    'petgpt.app',
    'www.petgpt.app',
    'api.petgpt.app',
    'cdn.petgpt.app',
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
    'api.petgpt.app',
    'cdn.petgpt.app',
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
    'petgpt.app',
    'www.petgpt.app',
    'app.petgpt.app',
    'api.petgpt.app',
    'cdn.petgpt.app',
  };

  final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBaseUri != null && apiBaseUri.host.isNotEmpty) {
    result.add(apiBaseUri.host.toLowerCase());
  }

  return result;
}

Set<String> profileAvatarAllowedHosts() {
  final result = <String>{
    'api.petgpt.app',
    'cdn.petgpt.app',
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
