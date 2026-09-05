import 'dart:async';

import 'package:flutter/foundation.dart';

class MediaLifecyclePolicy {
  MediaLifecyclePolicy._();

  static const int _maxConcurrentVideoPreviews = 4;
  static int _activeVideoPreviews = 0;
  static final Set<VoidCallback> _slotListeners = {};
  static bool _notificationPending = false;

  /// Waiting previews register once and unregister on preparation or disposal.
  static void addVideoPreviewSlotListener(VoidCallback listener) =>
      _slotListeners.add(listener);

  static void removeVideoPreviewSlotListener(VoidCallback listener) =>
      _slotListeners.remove(listener);

  static bool hasVideoPreviewSlot({bool reserveForActive = false}) =>
      _activeVideoPreviews <
      _maxConcurrentVideoPreviews - (reserveForActive ? 1 : 0);

  static bool tryAcquireVideoPreviewSlot({int? maxConcurrent}) {
    final budget = maxConcurrent ?? _maxConcurrentVideoPreviews;
    if (_activeVideoPreviews >= budget) {
      return false;
    }
    _activeVideoPreviews += 1;
    return true;
  }

  static void releaseVideoPreviewSlot() {
    if (_activeVideoPreviews <= 0) {
      return;
    }
    _activeVideoPreviews -= 1;
    if (_notificationPending || _slotListeners.isEmpty) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      for (final listener in List<VoidCallback>.of(_slotListeners)) {
        if (_slotListeners.contains(listener)) listener();
      }
    });
  }

  static void reset() {
    _activeVideoPreviews = 0;
    _slotListeners.clear();
  }

  static int get activeVideoPreviews => _activeVideoPreviews;

  @visibleForTesting
  static int get waitingVideoPreviewListeners => _slotListeners.length;
}
