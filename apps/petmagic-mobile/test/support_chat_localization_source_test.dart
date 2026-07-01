import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support chat preview and message formatting use active locale', () {
    final previewSource = File(
      'lib/features/support/presentation/widgets/support_chat_actions_preview.part.dart',
    ).readAsStringSync();
    final messagesSource = File(
      'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
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
        'NumberFormat.decimalPatternDigits(\n      locale: localeTag,\n      decimalDigits: 1,',
      ),
    );
  });
}
