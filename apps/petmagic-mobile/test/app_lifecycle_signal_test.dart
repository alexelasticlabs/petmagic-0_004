import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AppLifecycleSignal detaches binding observer when listeners are gone',
    () {
      final source = File(
        'lib/core/lifecycle/app_lifecycle_signal.dart',
      ).readAsStringSync();

      expect(source, contains('WidgetsBinding.instance.addObserver(this);'));
      expect(source, contains('void removeListener(VoidCallback listener)'));
      expect(source, contains('if (!hasListeners)'));
      expect(source, contains('void _detach()'));
      expect(source, contains('WidgetsBinding.instance.removeObserver(this);'));
      expect(source, contains('void dispose()'));
      expect(source, contains('_detach();'));
    },
  );
}
