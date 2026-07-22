part of 'push_token_registrar.dart';

abstract final class _PushTokenFailureLogger {
  static void _logNonBlockingFailure({
    required String operation,
    required String stage,
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.warn(
      feature: 'notifications',
      operation: operation,
      message: 'Non-blocking push token cleanup failed.',
      context: {'stage': stage},
      error: error,
      stackTrace: stackTrace,
    );
  }
}

abstract final class _PushTokenIdentityPolicy {
  static bool _canContinue(bool Function()? canContinue) {
    return canContinue == null || canContinue();
  }

  static String _registrationKey({
    required String token,
    required String accountScope,
    required String platform,
    required String locale,
    String? appVersion,
    String? deviceId,
  }) {
    final payload = jsonEncode([
      token,
      accountScope,
      platform.trim(),
      locale.trim(),
      _nonEmpty(appVersion) ?? AppConfig.appVersion,
      _nonEmpty(deviceId) ?? '',
    ]);
    return '$pushTokenRegistrationFingerprintPrefix${sha256.convert(utf8.encode(payload))}';
  }

  static String _unregistrationKey({
    required String token,
    required bool clearRegistrationState,
  }) {
    final payload = jsonEncode([token, clearRegistrationState]);
    return '$pushTokenRegistrationFingerprintPrefix${sha256.convert(utf8.encode(payload))}';
  }

  static String _normalizePlatform(String platform) {
    return platform.trim().toLowerCase();
  }

  static String _normalizeLocale(String locale) {
    final normalized = locale.trim().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return normalized;
    }

    final parts = normalized
        .split('-')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '';
    }

    final canonical = <String>[parts.first.toLowerCase()];
    for (final rawPart in parts.skip(1)) {
      final part = rawPart.trim();
      if (part.length == 4) {
        canonical.add(
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        );
        continue;
      }

      if (_localeRegionSegmentPattern.hasMatch(part)) {
        canonical.add(part.toUpperCase());
        continue;
      }

      canonical.add(part.toLowerCase());
    }

    return canonical.join('-');
  }

  static final RegExp _localeRegionSegmentPattern = RegExp(
    r'^[A-Za-z]{2}$|^[0-9]{3}$',
  );

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}

abstract final class _PushTokenRegistrationMemoryState {
  static void _invalidateTokenInMemory(String token) {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    if (PushTokenRegistrar._lastCompletedRegistrationToken == normalizedToken) {
      final currentKey = PushTokenRegistrar._lastCompletedRegistrationKey;
      PushTokenRegistrar._lastCompletedRegistrationKey = null;
      PushTokenRegistrar._lastCompletedRegistrationToken = null;
      PushTokenRegistrar._inFlightRegistrations.removeWhere(
        (key, _) => key == currentKey,
      );
    }
    PushTokenRegistrar._inFlightUnregistrations.removeWhere(
      (key, _) =>
          key ==
              _PushTokenIdentityPolicy._unregistrationKey(
                token: normalizedToken,
                clearRegistrationState: true,
              ) ||
          key ==
              _PushTokenIdentityPolicy._unregistrationKey(
                token: normalizedToken,
                clearRegistrationState: false,
              ),
    );
  }
}
