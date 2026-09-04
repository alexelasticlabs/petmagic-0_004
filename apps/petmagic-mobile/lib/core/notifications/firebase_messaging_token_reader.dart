import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

typedef FirebaseMessagingTokenRead = Future<String?> Function();
typedef FirebaseMessagingPollDelay = Future<void> Function(Duration duration);
typedef FirebaseMessagingTokenReadGuard = bool Function();

final firebaseMessagingTokenReader = FirebaseMessagingTokenReader();

/// Reads an FCM token only after Apple has supplied its prerequisite APNs
/// token. The Apple wait is bounded so a platform failure cannot stall the
/// authenticated startup lifecycle forever.
final class FirebaseMessagingTokenReader {
  FirebaseMessagingTokenReader({
    bool? requiresApnsToken,
    FirebaseMessagingTokenRead? readApnsToken,
    FirebaseMessagingTokenRead? readFcmToken,
    FirebaseMessagingPollDelay? delay,
    this.maxApnsTokenAttempts = 40,
    this.apnsTokenPollInterval = const Duration(milliseconds: 250),
  }) : _requiresApnsToken =
           requiresApnsToken ?? (Platform.isIOS || Platform.isMacOS),
       _readApnsToken =
           readApnsToken ?? (() => FirebaseMessaging.instance.getAPNSToken()),
       _readFcmToken =
           readFcmToken ?? (() => FirebaseMessaging.instance.getToken()),
       _delay = delay ?? ((duration) => Future<void>.delayed(duration)) {
    if (maxApnsTokenAttempts <= 0) {
      throw ArgumentError.value(
        maxApnsTokenAttempts,
        'maxApnsTokenAttempts',
        'Must be greater than zero.',
      );
    }
    if (apnsTokenPollInterval.isNegative) {
      throw ArgumentError.value(
        apnsTokenPollInterval,
        'apnsTokenPollInterval',
        'Must not be negative.',
      );
    }
  }

  final bool _requiresApnsToken;
  final FirebaseMessagingTokenRead _readApnsToken;
  final FirebaseMessagingTokenRead _readFcmToken;
  final FirebaseMessagingPollDelay _delay;
  final int maxApnsTokenAttempts;
  final Duration apnsTokenPollInterval;

  Future<String?> readToken({
    FirebaseMessagingTokenReadGuard? canContinue,
  }) async {
    if (!_canContinue(canContinue)) {
      return null;
    }

    if (_requiresApnsToken && !await _waitForApnsToken(canContinue)) {
      return null;
    }

    if (!_canContinue(canContinue)) {
      return null;
    }
    return _normalize(await _readFcmToken());
  }

  Future<bool> _waitForApnsToken(
    FirebaseMessagingTokenReadGuard? canContinue,
  ) async {
    for (var attempt = 0; attempt < maxApnsTokenAttempts; attempt++) {
      if (!_canContinue(canContinue)) {
        return false;
      }
      if (_normalize(await _readApnsToken()) != null) {
        return _canContinue(canContinue);
      }

      if (attempt + 1 < maxApnsTokenAttempts) {
        await _delay(apnsTokenPollInterval);
      }
    }

    return false;
  }

  static bool _canContinue(FirebaseMessagingTokenReadGuard? guard) {
    return guard == null || guard();
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
