import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account role pills use localized labels for supported backend roles', () {
    final source = File(
      'lib/features/profile/presentation/profile_account_info_content.part.dart',
    ).readAsStringSync();
    final russianLocalizations = File('lib/l10n/app_ru.arb').readAsStringSync();

    expect(
      source,
      contains('_localizedProfileRole(text, profile.roles.first)'),
    );
    expect(source, contains("'user' => text.profileAccountRoleUser"));
    expect(source, contains("'moderator' => text.profileAccountRoleModerator"));
    expect(source, contains("'admin' => text.profileAccountRoleAdmin"));
    expect(
      russianLocalizations,
      contains('"profileAccountRoleUser": "Пользователь"'),
    );
  });
}
