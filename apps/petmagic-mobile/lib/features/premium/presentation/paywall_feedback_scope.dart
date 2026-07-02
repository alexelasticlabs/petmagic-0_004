import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';

const paywallFeedbackLastShownStorageKeyPrefix =
    'feedback_paywall_last_shown_utc_v2';

String buildPaywallFeedbackLastShownStorageKey(String scopeKey) {
  return '$paywallFeedbackLastShownStorageKeyPrefix:'
      '${_paywallFeedbackScopeFingerprint(scopeKey)}';
}

String buildLegacyPaywallFeedbackLastShownStorageKey(String scopeKey) {
  return '$paywallFeedbackLastShownStorageKeyPrefix:$scopeKey';
}

String _paywallFeedbackScopeFingerprint(String scopeKey) {
  final normalized = scopeKey.trim().toLowerCase();
  return sha256.convert(utf8.encode(normalized)).toString();
}

class PaywallFeedbackScopeResolver {
  PaywallFeedbackScopeResolver({required AuthSessionStorage sessionStorage})
    : _sessionStorage = sessionStorage;

  final AuthSessionStorage _sessionStorage;

  Future<String?> resolve({
    required bool isAuthenticated,
    String? profileUserId,
  }) async {
    if (!isAuthenticated) {
      return 'guest';
    }

    final normalizedProfileUserId = normalizePaywallFeedbackScope(
      profileUserId,
    );
    if (normalizedProfileUserId != null) {
      return normalizedProfileUserId;
    }

    final session = await _sessionStorage.read();
    return normalizePaywallFeedbackScope(session?.user.userId);
  }
}

String? normalizePaywallFeedbackScope(String? rawValue) {
  final normalized = rawValue?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}
