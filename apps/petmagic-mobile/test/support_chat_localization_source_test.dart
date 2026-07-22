import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support chat preview and message formatting use active locale', () {
    final previewSource = File(
      'lib/features/support/presentation/widgets/support_chat_actions_preview.part.dart',
    ).readAsStringSync();
    final messagesSource = [
      'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
      'lib/features/support/presentation/widgets/support_chat_message_bubbles.part.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final headerSource = File(
      'lib/features/support/presentation/widgets/support_chat_header.part.dart',
    ).readAsStringSync();
    final mediaSource = File(
      'lib/features/support/presentation/widgets/support_chat_message_media.part.dart',
    ).readAsStringSync();
    final metaSource = File(
      'lib/features/support/presentation/widgets/support_chat_messages_meta.part.dart',
    ).readAsStringSync();

    expect(
      previewSource,
      contains(
        "DateFormat(\n      'MMM d',\n      Localizations.localeOf(context).toLanguageTag(),",
      ),
    );
    expect(
      messagesSource,
      contains(
        'DateFormat.Hm(\n      Localizations.localeOf(context).toLanguageTag(),',
      ),
    );
    expect(
      messagesSource,
      contains(
        'NumberFormat.decimalPatternDigits(\n    locale: localeTag,\n    decimalDigits: 1,',
      ),
    );
    expect(
      messagesSource,
      contains('final userBubbleForeground = colors.on(userBubbleColor);'),
    );
    expect(messagesSource, contains(': userBubbleForeground;'));
    expect(
      messagesSource,
      contains(': userBubbleForeground.withValues(alpha: 0.82);'),
    );
    expect(
      messagesSource,
      isNot(
        contains(
          'final textColor = message.isFromAdmin ? colors.textStrong : Colors.white;',
        ),
      ),
    );
    expect(
      messagesSource,
      isNot(contains(': Colors.white.withValues(alpha: 0.82);')),
    );
    expect(headerSource, contains('final mutedColor = colors.textMuted;'));
    expect(mediaSource, contains('final warningColor = colors.gold;'));
    expect(metaSource, contains('color: colors.danger'));
    expect(
      headerSource,
      isNot(contains('const mutedColor = Color(0xFF8A94A6)')),
    );
    expect(
      mediaSource,
      isNot(contains('const warningColor = Color(0xFFE7A126)')),
    );
    expect(metaSource, isNot(contains('const Color(0xFFFF6B6B)')));
  });
}
