import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';

void main() {
  test('keeps magic loading canvas painter outside the widget file', () {
    final widgetSource = File(
      'lib/shared/loading/magic_loading_screen.dart',
    ).readAsStringSync();
    final painterSource = File(
      'lib/shared/loading/magic_loading_background_painter.part.dart',
    ).readAsStringSync();
    final foregroundSource = File(
      'lib/shared/loading/magic_loading_foreground.part.dart',
    ).readAsStringSync();

    expect(
      widgetSource,
      contains("part 'magic_loading_background_painter.part.dart';"),
    );
    expect(
      widgetSource,
      contains("part 'magic_loading_foreground.part.dart';"),
    );
    expect(widgetSource, isNot(contains('enum _ParticleKind')));
    expect(widgetSource, isNot(contains('class _ParticleSeed')));
    expect(widgetSource, isNot(contains('class _MagicPortal')));
    expect(widgetSource, isNot(contains('class _PawProgress')));
    expect(widgetSource.split('\n').length, lessThan(300));
    expect(painterSource, contains("part of 'magic_loading_screen.dart';"));
    expect(painterSource, contains('class _MagicBackgroundPainter'));
    expect(painterSource, contains('enum _ParticleKind'));
    expect(foregroundSource, contains("part of 'magic_loading_screen.dart';"));
    expect(foregroundSource, contains('class _MagicPortal'));
    expect(foregroundSource, contains('class _PawProgress'));
  });

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
