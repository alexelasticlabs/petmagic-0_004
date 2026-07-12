import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings version default stays aligned with the package version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final appConfig = File(
      'lib/core/config/app_config.dart',
    ).readAsStringSync();
    final settingsContent = File(
      'lib/features/profile/presentation/profile_settings_page_content.part.dart',
    ).readAsStringSync();
    final packageVersion = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(packageVersion, isNotNull);
    expect(appConfig, contains("defaultValue: '$packageVersion'"));
    expect(
      settingsContent,
      contains('text.profileSettingsVersionLabel(AppConfig.appVersion)'),
    );
  });
}
