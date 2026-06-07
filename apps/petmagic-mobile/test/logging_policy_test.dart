import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app and tool sources do not use noisy print logging', () {
    final violations = <String>[];
    for (final root in [Directory('lib'), Directory('tool')]) {
      if (!root.existsSync()) {
        continue;
      }

      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final source = entity.readAsStringSync();
        if (RegExp(r'\b(?:print|debugPrint)\s*\(').hasMatch(source)) {
          violations.add(entity.path);
        }
      }
    }

    expect(violations, isEmpty);
  });
}
