import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';

abstract final class RequestIdentity {
  static final Random _defaultRandom = _createDefaultRandom();
  static bool _reportedInsecureRandomFallback = false;

  static String createRequestId({Random? random}) {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = (random ?? _defaultRandom)
        .nextInt(1 << 20)
        .toRadixString(16)
        .padLeft(5, '0');
    return 'm-$now-$suffix';
  }

  static String createCorrelationId({Random? random}) {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = (random ?? _defaultRandom)
        .nextInt(1 << 24)
        .toRadixString(16)
        .padLeft(6, '0');
    return 'flow-$now-$suffix';
  }

  static Random _createDefaultRandom() {
    try {
      return Random.secure();
    } catch (error, stackTrace) {
      _reportSecureRandomFallback(error, stackTrace);
      return Random();
    }
  }

  static void _reportSecureRandomFallback(Object error, StackTrace stackTrace) {
    if (_reportedInsecureRandomFallback) {
      return;
    }

    _reportedInsecureRandomFallback = true;
    developer.log(
      'Secure random unavailable; falling back to Random.',
      name: 'PetMagic.RequestIdentity',
      level: 900,
      error: kDebugMode ? error : error.runtimeType.toString(),
      stackTrace: kDebugMode ? stackTrace : null,
    );
  }
}
