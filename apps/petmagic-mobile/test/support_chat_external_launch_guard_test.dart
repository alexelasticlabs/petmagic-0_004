import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'support chat external launches are guarded behind safe fallback UX',
    () {
      final pageSource = File(
        'lib/features/support/presentation/support_chat_page.dart',
      ).readAsStringSync();
      final mediaSource = File(
        'lib/features/support/presentation/widgets/'
        'support_chat_external_media.part.dart',
      ).readAsStringSync();
      final messagesSource = File(
        'lib/features/support/presentation/widgets/'
        'support_chat_messages.part.dart',
      ).readAsStringSync();
      final sectionsSource = File(
        'lib/features/support/presentation/widgets/'
        'support_chat_sections.part.dart',
      ).readAsStringSync();

      final openBody = _methodBody(
        mediaSource,
        'Future<void> _openAttachmentExternallyImpl(String value)',
      );

      expect(
        mediaSource,
        contains('void _showExternalAttachmentUnavailableWarning()'),
      );
      expect(openBody, contains('final didLaunch = await launchUrl('));
      expect(openBody, contains('if (!didLaunch)'));
      expect(openBody, contains('on Object'));
      expect(
        openBody,
        contains('_showExternalAttachmentUnavailableWarning();'),
      );

      expect(
        pageSource,
        contains('onOpenAttachment: _openAttachmentExternallyImpl,'),
      );
      expect(
        sectionsSource,
        contains('final Future<void> Function(String value) onOpenAttachment;'),
      );
      expect(messagesSource, contains('this.onOpenAttachment,'));
      expect(messagesSource, contains('onOpenAttachment == null'));
      expect(messagesSource, contains('primaryAttachment!.fileUrl,'));
      expect(messagesSource, isNot(contains('await launchUrl(')));
    },
  );
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'Missing method: $signature');

  final braceStart = source.indexOf('{', start);
  expect(braceStart, isNonNegative, reason: 'Missing method body: $signature');

  var depth = 0;
  for (var index = braceStart; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(braceStart, index + 1);
      }
    }
  }

  fail('Unclosed method body: $signature');
}
