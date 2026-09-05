import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/shell/petmagic_shell.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';

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
          appLaunchControllerProvider.overrideWith(_SessionController.new),
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
    for (final (index, path, label) in [
      (1, '/creations', 'Creations branch'),
      (2, '/rewards', 'Rewards branch'),
      (3, '/profile', 'Profile branch'),
    ]) {
      await tester.tap(find.byKey(ValueKey('bottom-nav-item-$index')));
      await tester.pumpAndSettle();
      expect(shellLocation, path);
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest gates preserve the current tab and auth destination', (
    tester,
  ) async {
    final navigator = _RecordingNavigator();
    await _pumpShell(tester, authenticated: false, navigator: navigator);
    final semantics = tester.ensureSemantics();
    final text = AppLocalizations.of(
      tester.element(find.byType(PetMagicShell)),
    );
    expect(find.text(text.profileSignInAction), findsOneWidget);
    expect(find.text(text.navProfile), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    for (final (index, path) in [(1, '/creations'), (2, '/rewards')]) {
      expect(
        tester
            .getSemantics(find.byKey(ValueKey('bottom-nav-item-$index')))
            .hint,
        text.authSignInRequired,
      );
      await tester.tap(find.byKey(ValueKey('bottom-nav-item-$index')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Current page'), findsOneWidget);
      await tester.tap(find.text(text.authRequiredContinueBrowsing));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(navigator.destination, isNull);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('bottom-nav-item-0')))
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(ValueKey('bottom-nav-item-$index')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, text.profileSignInAction),
      );
      await tester.pumpAndSettle();
      expect(navigator.destination, isA<AuthDestination>());
      expect((navigator.destination! as AuthDestination).redirectPath, path);
      navigator.destination = null;
    }
    await tester.tap(find.byKey(const ValueKey('bottom-nav-item-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, text.authSignUpAction),
    );
    await tester.pumpAndSettle();
    expect(
      (navigator.destination! as RegisterDestination).redirectPath,
      '/rewards',
    );
    await tester.tap(find.byKey(const ValueKey('bottom-nav-item-3')));
    await tester.pumpAndSettle();
    expect(
      (navigator.destination! as AuthDestination).redirectPath,
      '/profile',
    );
    expect(navigator.lastWasPush, isTrue);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'login and logout update labels and suppress stale guest badges',
    (tester) async {
      final container = await _pumpShell(tester, authenticated: false);
      expect(container.exists(generationHistoryControllerProvider), isFalse);
      expect(find.byKey(const ValueKey('bottom-nav-unread')), findsNothing);
      final session =
          container.read(appLaunchControllerProvider.notifier)
              as _SessionController;
      session.setAuthenticated(true);
      await tester.pumpAndSettle();
      final text = AppLocalizations.of(
        tester.element(find.byType(PetMagicShell)),
      );
      expect(find.text(text.navProfile), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byKey(const ValueKey('bottom-nav-unread')), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('bottom-nav-item-1')))
            .label,
        '${text.navCreations}, ${text.generationStatusUnreadCount(3)}',
      );
      semantics.dispose();
      session.setAuthenticated(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bottom-nav-unread')), findsNothing);
      expect(find.text(text.profileSignInAction), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['ru', 'en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('$locale navigation fits 320dp at 200 percent text', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        locale: Locale(locale),
      );
      for (var index = 0; index < 4; index++) {
        final target = find.byKey(ValueKey('bottom-nav-item-$index'));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      }
      final context = tester.element(find.byType(PetMagicShell));
      final surface = find.byKey(const ValueKey('bottom-nav-surface'));
      expect(tester.getSize(surface).height, petMagicBottomNavHeight(context));
      expect(
        tester.getBottomRight(surface).dy,
        568 - 34 - kPetMagicBottomNavOuterGap,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard hides the navigation and its bottom fade', (
    tester,
  ) async {
    await _pumpShell(tester);
    expect(find.byKey(const ValueKey('bottom-nav-backdrop')), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bottom-nav-surface')), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-backdrop')), findsNothing);
  });

  testWidgets(
    'tablet navigation stays centered with comfortable touch targets',
    (tester) async {
      await _pumpShell(tester, size: const Size(1024, 768));
      final surface = find.byKey(const ValueKey('bottom-nav-surface'));
      expect(tester.getSize(surface).width, 480);
      expect(tester.getCenter(surface).dx, 512);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  bool authenticated = true,
  AppNavigator? navigator,
  Size size = const Size(390, 844),
  double textScale = 1,
  Locale locale = const Locale('ru'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(bottom: 34);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      appLaunchControllerProvider.overrideWith(
        () => _SessionController(authenticated),
      ),
      generationHistoryControllerProvider.overrideWith(
        _UnreadHistoryController.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: AppNavigationScope(
        navigator: navigator ?? _RecordingNavigator(),
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const PetMagicShell(
            location: '/discover',
            child: _RouteMarker(label: 'Current page'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _SessionController extends AppLaunchController {
  _SessionController([this.authenticated = true]);
  final bool authenticated;
  @override
  AppLaunchState build() => AppLaunchState(
    isLoading: false,
    isAuthenticated: authenticated,
    requiresLegalAcceptance: false,
    hasSeenOnboarding: true,
    guestSessionReady: true,
  );
  void setAuthenticated(bool value) =>
      state = state.copyWith(isAuthenticated: value);
}

class _UnreadHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() =>
      const GenerationHistoryState(unreadCount: 3);
}

class _RecordingNavigator implements AppNavigator {
  AppDestination? destination;
  bool lastWasPush = false;
  @override
  void go(AppDestination destination) {
    this.destination = destination;
    lastWasPush = false;
  }

  @override
  Future<T?> push<T>(AppDestination destination) async {
    this.destination = destination;
    lastWasPush = true;
    return null;
  }

  @override
  void replace(AppDestination destination) => go(destination);
  @override
  bool canPop() => false;
  @override
  void pop<T extends Object?>([T? result]) {}
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
