import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/shell/petmagic_shell.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';

void main() {
  testWidgets('reselecting Discover returns its branch to initial location', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var shellLocation = '';
    final router = GoRouter(
      initialLocation: '/templates',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shellLocation = state.uri.path;
            return PetMagicShell(
              location: shellLocation,
              navigationShell: navigationShell,
            );
          },
          branches: [
            StatefulShellBranch(
              initialLocation: '/discover',
              routes: [
                GoRoute(
                  path: '/discover',
                  builder: (context, state) => const _RouteMarker(
                    label: 'Discover branch initial location',
                  ),
                ),
                GoRoute(
                  path: '/templates',
                  builder: (context, state) =>
                      const _RouteMarker(label: 'Nested templates location'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/creations',
                  builder: (context, state) =>
                      const _RouteMarker(label: 'Creations branch'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/rewards',
                  builder: (context, state) =>
                      const _RouteMarker(label: 'Rewards branch'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      const _RouteMarker(label: 'Profile branch'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(shellLocation, '/templates');
    expect(find.text('Nested templates location'), findsOneWidget);
    final text = AppLocalizations.of(
      tester.element(find.byType(PetMagicShell)),
    );

    await tester.tap(find.text(text.navDiscover));
    await tester.pumpAndSettle();

    expect(shellLocation, '/discover');
    expect(find.text('Discover branch initial location'), findsOneWidget);
    expect(find.text('Nested templates location'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _RouteMarker extends StatelessWidget {
  const _RouteMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(child: Text(label)),
    );
  }
}

final class _IdleGenerationHistoryController
    extends GenerationHistoryController {
  @override
  GenerationHistoryState build() => const GenerationHistoryState();

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {}
}
