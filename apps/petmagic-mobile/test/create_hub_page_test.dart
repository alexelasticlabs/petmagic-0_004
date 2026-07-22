import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/create/presentation/create_hub_page.dart';

import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  for (final configuration in const [
    _GoldenConfiguration('compact', Size(320, 568)),
    _GoldenConfiguration('phone', Size(390, 844)),
    _GoldenConfiguration('tablet', Size(834, 1194)),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'create hub ${configuration.name} ${brightness.name} visual baseline',
        (tester) async {
          tester.view.physicalSize = configuration.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          await _pumpCreateHub(
            tester,
            navigator: _RecordingNavigator(),
            authenticated: false,
            brightness: brightness,
          );
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/create_hub_${configuration.name}_${brightness.name}.png',
            ),
          );
        },
      );
    }
  }

  testWidgets('create hub preserves guest pet intent through auth', (
    tester,
  ) async {
    final navigator = _RecordingNavigator();
    await _pumpCreateHub(tester, navigator: navigator, authenticated: false);

    final text = AppLocalizations.of(
      tester.element(find.byType(CreateHubPage)),
    );
    expect(find.text(text.createHubTitle), findsOneWidget);
    expect(find.text(text.createHubGuestHint), findsOneWidget);

    await tester.tap(find.text(text.createHubPetsAction));
    await tester.pump();

    final destination = navigator.lastGo;
    expect(destination, isA<AuthDestination>());
    expect(
      (destination! as AuthDestination).redirectPath,
      '/create?source=pets',
    );
  });

  testWidgets('create hub routes authenticated pet owners to My Pets', (
    tester,
  ) async {
    final navigator = _RecordingNavigator();
    await _pumpCreateHub(tester, navigator: navigator, authenticated: true);
    final text = AppLocalizations.of(
      tester.element(find.byType(CreateHubPage)),
    );

    await tester.tap(find.text(text.createHubPetsAction));
    await tester.pump();

    expect(navigator.lastPush, isA<PetsDestination>());
  });

  testWidgets('create hub stays accessible on a compact 200 percent viewport', (
    tester,
  ) async {
    final navigator = _RecordingNavigator();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await _pumpCreateHub(tester, navigator: navigator, authenticated: false);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(tester.takeException(), isNull);

    final semantics = tester.ensureSemantics();
    final text = AppLocalizations.of(
      tester.element(find.byType(CreateHubPage)),
    );
    expect(
      tester.getSemantics(find.text(text.createHubBrowseAction)),
      matchesSemantics(label: text.createHubBrowseAction, isButton: true),
    );
    semantics.dispose();
  });
}

Future<void> _pumpCreateHub(
  WidgetTester tester, {
  required _RecordingNavigator navigator,
  required bool authenticated,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          () => _FixedAppLaunchController(authenticated),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: AppNavigationScope(
          navigator: navigator,
          child: const Scaffold(body: CreateHubPage()),
        ),
      ),
    ),
  );
  await pumpTestFrames(tester);
}

class _GoldenConfiguration {
  const _GoldenConfiguration(this.name, this.size);

  final String name;
  final Size size;
}

class _FixedAppLaunchController extends AppLaunchController {
  _FixedAppLaunchController(this.authenticated);

  final bool authenticated;

  @override
  AppLaunchState build() => AppLaunchState(
    isLoading: false,
    isAuthenticated: authenticated,
    requiresLegalAcceptance: false,
    hasSeenOnboarding: true,
    guestSessionReady: true,
  );

  @override
  Future<void> initialize() async {}
}

class _RecordingNavigator implements AppNavigator {
  AppDestination? lastGo;
  AppDestination? lastPush;

  @override
  bool canPop() => false;

  @override
  void go(AppDestination destination) => lastGo = destination;

  @override
  void pop<T extends Object?>([T? result]) {}

  @override
  Future<T?> push<T>(AppDestination destination) async {
    lastPush = destination;
    return null;
  }

  @override
  void replace(AppDestination destination) => lastGo = destination;
}
