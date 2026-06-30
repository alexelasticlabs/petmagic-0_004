import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy support settings route redirects to canonical support home', () {
    final source = File(
      'lib/app/router/app_router.dart',
    ).readAsStringSync();

    expect(source, contains('path: ProfileSettingsDetailPage.routePath,'));
    expect(
      source,
      contains('if (kind == ProfileSettingsDetailKind.support) {'),
    );
    expect(source, contains('return SupportHomePage.routePath;'));
  });
}
