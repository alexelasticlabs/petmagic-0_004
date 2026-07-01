import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'template flow balance hint normalizes wrapped insufficient balance key',
    () {
      final source = File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
      ).readAsStringSync();

      expect(source, contains('normalizeTemplateErrorKey(errorMessage) =='));
      expect(
        source,
        isNot(contains("errorMessage == 'templates.insufficient_balance'")),
      );
    },
  );
}
