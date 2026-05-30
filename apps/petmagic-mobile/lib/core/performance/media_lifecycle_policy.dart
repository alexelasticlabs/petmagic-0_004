class MediaLifecyclePolicy {
  MediaLifecyclePolicy._();

  static const int _maxConcurrentVideoPreviews = 4;
  static int _activeVideoPreviews = 0;

  static bool tryAcquireVideoPreviewSlot() {
    if (_activeVideoPreviews >= _maxConcurrentVideoPreviews) {
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

  static int get activeVideoPreviews => _activeVideoPreviews;
}
