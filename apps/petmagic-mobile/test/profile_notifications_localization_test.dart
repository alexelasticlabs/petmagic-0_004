import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile notification device labels use localized copy', () async {
    final source = await File(
      'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
    ).readAsString();

    expect(source, contains('text.profileNotificationsDeviceMicrophone'));
    expect(
      source,
      isNot(contains("AppPermissionType.microphone => 'Microphone'")),
    );
  });

  test(
    'profile notification device microphone key exists in every supported locale',
    () async {
      const arbFiles = <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        expect(
          source,
          contains('"profileNotificationsDeviceMicrophone"'),
          reason: '$path is missing profileNotificationsDeviceMicrophone',
        );
      }
    },
  );
}
