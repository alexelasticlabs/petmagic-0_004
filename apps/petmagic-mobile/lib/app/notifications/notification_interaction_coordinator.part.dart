part of 'notification_coordinator.dart';

mixin _NotificationInteractionCoordinator on _NotificationCoordinatorBase {
  void handleForegroundMessage(RemoteMessage message) {
    if (_isDisposed || !_shouldDisplayForeground(message)) {
      return;
    }

    final type = message.data['type'] as String?;
    final title = _fallbackTitle(type);
    final messageText = _fallbackBody(type);
    final dedupeKey =
        _safeExternalDedupeKey(message.data['dedupe_key']) ??
        _safeExternalDedupeKey(message.data['dedupeKey']) ??
        _safeExternalDedupeKey(message.messageId) ??
        '${type ?? 'update'}:${messageText.hashCode}:$title';
    final route = _routeFromMap(message.data);

    PetMagicToast.show(
      null,
      title: title,
      message: messageText,
      tone: _foregroundMessageTone(message),
      action: route == null
          ? null
          : PetMagicNotificationAction(
              label: _openActionLabel(),
              onPressed: () => _onRouteRequested(route),
            ),
      dedupeKey: dedupeKey,
    );
  }

  void _handleRemoteMessageRoute(RemoteMessage message) {
    if (!_markInteractionHandled(message)) {
      return;
    }

    final route = _routeFromMap(message.data);
    if (route != null) {
      _onRouteRequested(route);
    }
  }

  bool _markInteractionHandled(RemoteMessage message) {
    final key = _interactionDedupeKey(message);
    final now = DateTime.now();
    _pruneHandledInteractions(now);

    final handledAt = _handledInteractions[key];
    if (handledAt != null &&
        now.difference(handledAt) <=
            _NotificationCoordinatorBase._handledInteractionWindow) {
      return false;
    }

    _handledInteractions[key] = now;
    _trimHandledInteractionsToLimit();
    return true;
  }

  String _interactionDedupeKey(RemoteMessage message) {
    return _safeExternalDedupeKey(message.data['dedupe_key']) ??
        _safeExternalDedupeKey(message.data['dedupeKey']) ??
        _safeExternalDedupeKey(message.messageId) ??
        _routeFromMap(message.data) ??
        _fingerprintNotificationData(message.data);
  }

  void _pruneHandledInteractions(DateTime now) {
    final expiredKeys = <String>[];
    for (final entry in _handledInteractions.entries) {
      if (now.difference(entry.value) >
          _NotificationCoordinatorBase._handledInteractionWindow) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _handledInteractions.remove(key);
    }
  }

  void _trimHandledInteractionsToLimit() {
    while (_handledInteractions.length >
        _NotificationCoordinatorBase._maxHandledInteractions) {
      _handledInteractions.remove(_handledInteractions.keys.first);
    }
  }

  static String? _safeExternalDedupeKey(Object? raw) {
    if (raw is! String) {
      return null;
    }

    final value = raw.trim();
    if (value.isEmpty ||
        _NotificationCoordinatorBase._routeControlCharacters.hasMatch(value)) {
      return null;
    }

    if (value.length <=
        _NotificationCoordinatorBase._maxExternalDedupeKeyLength) {
      return value;
    }

    return _fingerprintString(value);
  }

  static String _fingerprintNotificationData(Map<String, dynamic> payload) {
    final sanitized = <String, String>{};
    final keys = payload.keys.map((key) => key.toString()).toList()..sort();
    for (final key in keys) {
      sanitized[key] = payload[key].toString();
    }

    return _fingerprintString(jsonEncode(sanitized));
  }

  static String _fingerprintString(String value) {
    return 'sha256:${sha256.convert(utf8.encode(value))}';
  }

  String? _routeFromMap(Map<String, dynamic> payload) {
    return _routeResolver.routeFromMap(payload);
  }

  bool _shouldDisplayForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == 'support_chat') {
      return true;
    }

    if (type == 'template_generation') {
      final status = (message.data['status'] as String?)?.toLowerCase();
      return status == 'completed' || status == 'failed';
    }

    if (type == 'wallet') {
      final status = (message.data['status'] as String?)?.toLowerCase();
      return status == 'succeeded' ||
          status == 'success' ||
          status == 'completed' ||
          status == 'pending' ||
          status == 'failed' ||
          status == 'error';
    }

    if (type == 'premium') {
      final status = (message.data['status'] as String?)?.toLowerCase();
      return status == 'active' ||
          status == 'inactive' ||
          status == 'expired' ||
          status == 'failed' ||
          status == 'error';
    }

    return false;
  }

  PetMagicToastTone _foregroundMessageTone(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == 'support_chat') {
      return PetMagicToastTone.info;
    }

    final status = (message.data['status'] as String?)?.toLowerCase();
    if (type == 'premium' && status == 'active') {
      return PetMagicToastTone.success;
    }
    if (status == 'succeeded' || status == 'success' || status == 'completed') {
      return PetMagicToastTone.success;
    }
    if (status == 'failed' || status == 'error') {
      return PetMagicToastTone.warning;
    }

    return PetMagicToastTone.info;
  }

  String _fallbackTitle(String? type) {
    return NotificationForegroundCopy.titleForType(
      PlatformDispatcher.instance.locale,
      type,
    );
  }

  String _fallbackBody(String? type) {
    return NotificationForegroundCopy.bodyForType(
      PlatformDispatcher.instance.locale,
      type,
    );
  }

  String _openActionLabel() {
    return NotificationForegroundCopy.openActionForLocale(
      PlatformDispatcher.instance.locale,
    );
  }

  void _logNotificationFailure(
    String stage,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object>{'stage': stage};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        payload[entry.key] = value.toString();
      }
    }

    AppLogger.error(
      feature: 'Notifications',
      operation: stage,
      message: 'Notification coordinator operation failed',
      error: error,
      stackTrace: stackTrace,
      context: payload,
    );
  }
}
