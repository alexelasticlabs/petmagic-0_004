import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery history error mapper does not echo raw details', () {
    final source = File(
      'lib/features/templates/presentation/generations_gallery_page_states.dart',
    ).readAsStringSync();

    final body = _functionBody(source, '_galleryHistoryErrorText');

    expect(body, contains('mapCommonAuthFeedbackMessage(text, raw)'));
    expect(body, contains('normalizeTemplateErrorKey(raw)'));
    expect(body, contains('text.templatesRequestFailedError'));
    expect(body, isNot(contains('=> raw')));
    expect(body, isNot(contains('return raw;')));
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
