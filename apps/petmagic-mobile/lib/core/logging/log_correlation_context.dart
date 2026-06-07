import 'dart:async';

abstract final class LogCorrelationContext {
  static final Object _correlationIdZoneKey = Object();

  static String? get currentCorrelationId {
    final value = Zone.current[_correlationIdZoneKey];
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static R runWithCorrelationId<R>(String? correlationId, R Function() body) {
    final trimmed = correlationId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return body();
    }

    return runZoned(body, zoneValues: {_correlationIdZoneKey: trimmed});
  }
}
