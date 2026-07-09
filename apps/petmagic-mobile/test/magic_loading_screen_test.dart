import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

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
    expect(widgetSource, isNot(contains('Timer.periodic')));
    expect(widgetSource, contains('shouldAnimateRepeatingEffects(context)'));
    expect(widgetSource, contains('shouldAnimateLoadingIndicators(context)'));
    expect(widgetSource, contains('void _scheduleNextMessageTick()'));
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

  testWidgets('keeps loading signal animated on dense Android phones', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(390, 844), devicePixelRatio: 3),
          child: Scaffold(body: MagicLoadingScreen()),
        ),
      ),
    );

    expect(find.text('Preparing the magic...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Finding the cutest angle...'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('respects disabled system animations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: MagicLoadingScreen()),
        ),
      ),
    );

    expect(find.text('Preparing the magic...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Preparing the magic...'), findsOneWidget);
    expect(find.text('Finding the cutest angle...'), findsNothing);
  });
}
