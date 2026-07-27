import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';

import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  testWidgets('compact welcome visual baseline', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GuestWelcomePage(),
        ),
      ),
    );
    await pumpTestFrames(tester, count: 20);

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/welcome_compact.png'),
    );
  });
}
