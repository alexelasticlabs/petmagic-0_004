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

  void _ensureAttached() {
    if (_isAttached) {
      return;
    }

    _state =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _isAttached = true;
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
