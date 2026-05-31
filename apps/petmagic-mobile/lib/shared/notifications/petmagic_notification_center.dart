import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_types.dart';

final class PetMagicNotificationCenter extends ChangeNotifier {
  PetMagicNotificationCenter._();

  static final PetMagicNotificationCenter instance =
      PetMagicNotificationCenter._();

  static const Duration _dedupeWindow = Duration(milliseconds: 1200);

  final Queue<PetMagicNotification> _queue = Queue<PetMagicNotification>();
  final Map<String, DateTime> _recentSignatures = <String, DateTime>{};

  PetMagicNotification? _current;
  Timer? _dismissTimer;
  bool _isDisposed = false;
  int _sequence = 0;

  PetMagicNotification? get current => _current;

  int get queueLength => _queue.length;

  void enqueue(
    String message, {
    String? title,
    PetMagicToastTone tone = PetMagicToastTone.info,
    Duration duration = const Duration(seconds: 3),
    PetMagicNotificationAction? action,
    String? dedupeKey,
  }) {
    if (_isDisposed) {
      return;
    }

    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    final normalizedTitle = title?.trim();
    final notification = PetMagicNotification(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}',
      title: normalizedTitle == null || normalizedTitle.isEmpty
          ? null
          : normalizedTitle,
      message: normalizedMessage,
      tone: tone,
      duration: duration,
      action: action,
      dedupeKey: dedupeKey,
      createdAt: DateTime.now(),
    );

    final signature = notification.signature;
    final now = DateTime.now();
    final recentShownAt = _recentSignatures[signature];
    if (recentShownAt != null &&
        now.difference(recentShownAt) <= _dedupeWindow) {
      return;
    }

    if (_current?.signature == signature) {
      return;
    }

    if (_queue.any((item) => item.signature == signature)) {
      return;
    }

    _recentSignatures[signature] = now;
    _pruneRecentSignatures(now);
    _queue.add(notification);
    _pump();
  }

  Future<void> dismissCurrent() async {
    if (_isDisposed) {
      return;
    }

    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_current != null) {
      _current = null;
      notifyListeners();
    }

    _pump();
  }

  Future<void> clearQueue() async {
    if (_isDisposed) {
      return;
    }

    _dismissTimer?.cancel();
    _dismissTimer = null;
    _queue.clear();
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _queue.clear();
    _recentSignatures.clear();
    super.dispose();
  }

  void _pump() {
    if (_isDisposed || _current != null || _queue.isEmpty) {
      return;
    }

    _current = _queue.removeFirst();
    notifyListeners();
    _scheduleDismiss(_current!);
  }

  void _scheduleDismiss(PetMagicNotification notification) {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(notification.duration, () {
      if (_isDisposed) {
        return;
      }

      if (_current?.id != notification.id) {
        return;
      }

      unawaited(dismissCurrent());
    });
  }

  void _pruneRecentSignatures(DateTime now) {
    final expiredKeys = <String>[];
    for (final entry in _recentSignatures.entries) {
      if (now.difference(entry.value) > _dedupeWindow) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _recentSignatures.remove(key);
    }
  }
}
