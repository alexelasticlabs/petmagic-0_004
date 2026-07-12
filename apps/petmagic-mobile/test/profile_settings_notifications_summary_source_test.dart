import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification settings entry does not misstate email preference as all notifications',
    () {
      final source = File(
        'lib/features/profile/presentation/'
        'profile_settings_page_content.part.dart',
      ).readAsStringSync();
      final entryStart = source.indexOf(
        'title: text.profileSettingsNotificationsTitle',
      );
      final entryEnd = source.indexOf('showDivider: false,', entryStart);

      expect(entryStart, greaterThanOrEqualTo(0));
      expect(entryEnd, greaterThan(entryStart));
      expect(
        source.substring(entryStart, entryEnd),
        isNot(contains('marketingEmailsEnabled')),
      );
    },
  );
}
