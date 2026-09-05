import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/shell/petmagic_shell.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';

import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();
  setUpAll(() async {
    final fonts = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent.uri.resolve('material_fonts/');
    await (FontLoader('Roboto')..addFont(
          File.fromUri(
            fonts.resolve('roboto-regular.ttf'),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  for (final brightness in Brightness.values) {
    for (final authenticated in [true, false]) {
      final session = authenticated ? 'member' : 'guest';
      testWidgets('$session navigation in ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLaunchControllerProvider.overrideWith(
                () => _LaunchController(authenticated),
              ),
              generationHistoryControllerProvider.overrideWith(
                _HistoryController.new,
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('ru'),
              theme: brightness == Brightness.light
                  ? AppTheme.light()
                  : AppTheme.dark(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const PetMagicShell(
                location: '/discover',
                child: _PreviewFeed(),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/rewards/profile-premium-dog.png'),
            tester.element(find.byType(PetMagicShell)),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/navigation_${session}_${brightness.name}.png',
          ),
        );
        final surface = find.byKey(const ValueKey('bottom-nav-surface'));
        final colors = PetMagicPalettes.forBrightness(brightness);
        for (final label in tester.widgetList<Text>(
          find.descendant(of: surface, matching: find.byType(Text)),
        )) {
          expect(
            PetMagicPalettes.contrastRatio(
              label.style!.color!,
              colors.surfaceGlass,
            ),
            greaterThanOrEqualTo(4.5),
          );
        }
        // Start the gesture inside the fade, just above the navigation.
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        await tester.dragFrom(
          Offset(195, tester.getTopLeft(surface).dy - 4),
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, greaterThan(0));
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.byType(Image).last).dy,
          lessThanOrEqualTo(tester.getTopLeft(surface).dy - 18),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _LaunchController extends AppLaunchController {
  _LaunchController(this.authenticated);
  final bool authenticated;
  @override
  AppLaunchState build() => AppLaunchState(
    isLoading: false,
    isAuthenticated: authenticated,
    requiresLegalAcceptance: false,
    hasSeenOnboarding: true,
    guestSessionReady: true,
  );
}

class _HistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() => const GenerationHistoryState();
}

// Local media keeps the shell render deterministic while exercising a busy,
// scrolling background all the way through the home-indicator area.
class _PreviewFeed extends StatelessWidget {
  const _PreviewFeed();
  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.backgroundBottom,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          56,
          20,
          petMagicBottomNavInset(context),
        ),
        children: [
          Text(
            'PetMagic',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Немного магии для вашего питомца',
            style: TextStyle(color: colors.textSoft),
          ),
          for (final title in [
            'В центре внимания',
            'Новый образ',
            'Ещё больше магии',
          ]) ...[
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textStrong,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/rewards/profile-premium-dog.png',
                height: 242,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
