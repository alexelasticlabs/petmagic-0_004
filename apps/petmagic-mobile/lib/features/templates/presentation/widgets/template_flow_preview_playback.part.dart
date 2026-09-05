part of 'template_flow_sheets.dart';

/// Shares a page's texture with its rail thumbnail, not a second decoder.
/// Pages remain the sole owners of their bounded controller leases.
class TemplatePreviewPlaybackRegistry extends ChangeNotifier {
  final Map<(String, int?), VideoPlayerController> _controllers = {};
  bool _disposed = false;
  bool _notificationPending = false;

  VideoPlayerController? _read(String identity, int? version) =>
      _controllers[(identity, version)];

  void _publish(
    String identity,
    int? version,
    VideoPlayerController controller,
  ) {
    if (_disposed || identical(_read(identity, version), controller)) return;
    _controllers[(identity, version)] = controller;
    _notifyChanged();
  }

  void _withdraw(
    String identity,
    int? version,
    VideoPlayerController? controller,
  ) {
    if (_disposed || !identical(_read(identity, version), controller)) return;
    if (_controllers.remove((identity, version)) != null) _notifyChanged();
  }

  void _notifyChanged() {
    // A page can release its lease while PageView is rebuilding. Notify the
    // sibling rail after that frame, never from another widget's build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationPending) return;
      _notificationPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationPending = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controllers.clear();
    super.dispose();
  }
}
