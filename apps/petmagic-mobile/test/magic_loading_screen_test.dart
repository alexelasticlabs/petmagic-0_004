import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';

void main() {
  testWidgets('renders localized copy and paw progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: MagicLoadingScreen()),
      ),
    );

    expect(find.text('Preparing the magic...'), findsOneWidget);
    for (var index = 0; index < 5; index++) {
      expect(find.byKey(ValueKey('magic-loading-paw-$index')), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
