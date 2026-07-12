import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('help center offers a direct route to the support chat', () {
    final pageSource = File(
      'lib/features/profile/presentation/profile_settings_detail_page.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/features/profile/presentation/'
      'profile_settings_detail_generic_content.part.dart',
    ).readAsStringSync();

    expect(pageSource, contains("context.push(SupportChatPage.routePath)"));
    expect(contentSource, contains('if (onOpenSupport != null)'));
    expect(contentSource, contains('text.supportHomeOpenChatAction'));
  });
}
