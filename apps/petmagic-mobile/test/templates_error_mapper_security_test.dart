import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template user-facing error mappers do not echo raw details', () {
    final templatesPage = File(
      'lib/features/templates/presentation/templates_page.dart',
    ).readAsStringSync();
    final templateFlowSheets = File(
      'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
    ).readAsStringSync();

    expect(
      _functionBody(templatesPage, '_mapTemplatesError'),
      isNot(contains('return raw;')),
    );
    expect(
      _functionBody(templatesPage, '_generationStartErrorText'),
      isNot(contains('return raw;')),
    );
    expect(
      _functionBody(templateFlowSheets, '_generationErrorText'),
      isNot(contains('return raw;')),
    );

    expect(
      _functionBody(templatesPage, '_mapTemplatesError'),
      contains('text.templatesRequestFailedError'),
    );
    expect(
      _functionBody(templatesPage, '_generationStartErrorText'),
      contains('text.templateFlowStartFailedError'),
    );
    expect(
      _functionBody(templateFlowSheets, '_generationErrorText'),
      contains('text.templateFlowStartFailedError'),
    );
  });
}

String _functionBody(String source, String functionName) {
  final start = source.indexOf('String $functionName(');
  expect(start, isNonNegative, reason: '$functionName not found');

  final bodyStart = source.indexOf('{', start);
  expect(bodyStart, isNonNegative, reason: '$functionName body not found');

  var depth = 0;
  for (var index = bodyStart; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }

  fail('$functionName body did not close');
}
