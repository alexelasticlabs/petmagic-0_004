import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'template_flow_sheets_test_source.dart';

void main() {
  test('template user-facing error mappers do not echo raw details', () {
    final templatesPage = _readTemplatesPageLibrarySource();
    final templateFlowSheets = readTemplateFlowSheetsLibrarySource();

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

String _readTemplatesPageLibrarySource() {
  const files = [
    'lib/features/templates/presentation/templates_page.dart',
    'lib/features/templates/presentation/templates_page_feed.part.dart',
    'lib/features/templates/presentation/templates_page_generation_flow.part.dart',
    'lib/features/templates/presentation/templates_page_lifecycle.part.dart',
    'lib/features/templates/presentation/templates_page_template_actions.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}
