import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support chat user-facing error mapper does not echo raw details', () {
    final source = File(
      'lib/features/support/presentation/widgets/support_chat_models.part.dart',
    ).readAsStringSync();

    final body = _functionBody(source, '_mapSupportError');

    expect(body, isNot(contains('return raw;')));
    expect(body, contains('text.supportChatUnavailableError'));
    expect(body, contains('text.supportChatAttachmentTooLargeError'));
    expect(body, contains('text.supportChatAttachmentUnsupportedFormatError'));
    expect(body, contains('support.attachment_file_required'));
    expect(body, contains('support.attachment_file_name_required'));
    expect(body, contains('support.attachment_content_type_too_long'));
    expect(body, contains('support.message_body_too_long'));
    expect(body, contains('support.reply_target_invalid'));
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
