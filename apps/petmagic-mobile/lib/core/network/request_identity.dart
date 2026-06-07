import 'dart:math';

abstract final class RequestIdentity {
  static final Random _defaultRandom = _createDefaultRandom();

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
    } catch (_) {
      return Random();
    }
  }
}
