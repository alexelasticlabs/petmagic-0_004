import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth success mappers do not expose raw backend strings', () {
    final files = [
      File('lib/features/profile/presentation/auth_entry_page.dart'),
      File('lib/features/profile/presentation/password_reset_page.dart'),
      File('lib/features/profile/presentation/password_change_page.dart'),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('return raw;')), reason: file.path);
    }
  });

  test('password success toasts skip unknown success keys', () {
    final resetSource = File(
      'lib/features/profile/presentation/password_reset_page.dart',
    ).readAsStringSync();
    final changeSource = File(
      'lib/features/profile/presentation/password_change_page.dart',
    ).readAsStringSync();

    for (final source in [resetSource, changeSource]) {
      expect(
        source,
        contains('final successMessage = _mapSuccessMessage'),
      );
      expect(source, contains('if (successMessage != null)'));
      expect(source, contains('String? _mapSuccessMessage'));
    }
  });
}
