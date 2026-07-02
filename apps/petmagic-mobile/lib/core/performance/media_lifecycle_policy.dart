class MediaLifecyclePolicy {
  MediaLifecyclePolicy._();

  static const int _maxConcurrentVideoPreviews = 4;
  static int _activeVideoPreviews = 0;

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
  }

  static void reset() {
    _activeVideoPreviews = 0;
  }

  static int get activeVideoPreviews => _activeVideoPreviews;
}
