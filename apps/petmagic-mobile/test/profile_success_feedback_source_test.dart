import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile success flows normalize wrapped success keys', () {
    final passwordResetSource = File(
      'lib/features/profile/presentation/password_reset_page.dart',
    ).readAsStringSync();
    final passwordChangeSource = File(
      'lib/features/profile/presentation/password_change_page.dart',
    ).readAsStringSync();
    final profilePageSource = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();

    expect(
      passwordResetSource,
      contains('normalizeProfileSuccessKey(nextState.successMessage)'),
    );
    expect(
      passwordChangeSource,
      contains('normalizeProfileSuccessKey(nextState.successMessage)'),
    );
    expect(profilePageSource, contains('mapProfileSuccessMessage('));
    expect(
      passwordResetSource,
      isNot(
        contains("nextState.successMessage == 'auth.password_reset_success'"),
      ),
    );
    expect(
      passwordChangeSource,
      isNot(
        contains("nextState.successMessage == 'auth.password_reset_success'"),
      ),
    );
    expect(
      profilePageSource,
      isNot(contains("next.successMessage == 'logout'")),
    );
  });
}
