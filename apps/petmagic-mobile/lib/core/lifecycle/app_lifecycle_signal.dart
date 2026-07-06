import 'package:flutter/widgets.dart';

class AppLifecycleSignal extends ChangeNotifier with WidgetsBindingObserver {
  AppLifecycleSignal._();

  static final AppLifecycleSignal instance = AppLifecycleSignal._();

  bool _isAttached = false;
  AppLifecycleState _state = AppLifecycleState.resumed;

  AppLifecycleState get state {
    _ensureAttached();
    return _state;
  }

  bool get isResumed => state == AppLifecycleState.resumed;

  @override
  void addListener(VoidCallback listener) {
    _ensureAttached();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _detach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _ensureAttached() {
    if (_isAttached) {
      return;
    }

    _state =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _isAttached = true;
  }

  void _detach() {
    if (!_isAttached) {
      return;
    }

    WidgetsBinding.instance.removeObserver(this);
    _isAttached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_state == state) {
      return;
    }

    _state = state;
    notifyListeners();
  }
}
