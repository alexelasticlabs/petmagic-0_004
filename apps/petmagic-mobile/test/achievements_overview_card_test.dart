import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievements_overview_card.dart';

void main() {
  testWidgets('achievements overview shows unlocked count before total', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: AchievementsOverviewCard(
            unlocked: 4,
            total: 15,
            streak: null,
            challengesCount: 3,
          ),
        ),
      ),
    );

    expect(find.text('4 / 15 разблокировано'), findsOneWidget);
    expect(find.text('15 / 4 разблокировано'), findsNothing);
  });
}
