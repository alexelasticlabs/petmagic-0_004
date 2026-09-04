import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';

import 'templates_page_lifecycle_test_support.dart';

void main() {
  testWidgets('search mode back pops before falling back to Discover', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final navigator = _RecordingNavigator()..canPopValue = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            UnauthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(FakeTemplatesController.new),
          generationHistoryControllerProvider.overrideWith(
            IdleTemplatesGenerationHistoryController.new,
          ),
          networkStatusControllerProvider.overrideWith(
            () =>
                TestTemplatesNetworkStatusController(initialHasInternet: true),
          ),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppNavigationScope(
            navigator: navigator,
            child: const Scaffold(body: TemplatesPage(autofocusSearch: true)),
          ),
        ),
      ),
    );

    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey('templates-search-mode-header'))
          .evaluate()
          .isNotEmpty,
    );

    final backButton = find.byKey(
      const ValueKey('templates-category-back-button'),
    );
    expect(backButton, findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('templates-search-field')),
          )
          .autofocus,
      isTrue,
    );

    await tester.tap(backButton);
    await tester.pump();
    expect(navigator.popCalls, 1);
    expect(navigator.goes, isEmpty);

    navigator.canPopValue = false;
    await tester.tap(backButton);
    await tester.pump();
    expect(navigator.popCalls, 1);
    expect(navigator.goes, hasLength(1));
    expect(navigator.goes.single, isA<DiscoverDestination>());
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (condition()) {
      return;
    }
  }
  fail('Timed out waiting for TemplatesPage search mode.');
}

final class _RecordingNavigator implements AppNavigator {
  bool canPopValue = false;
  int popCalls = 0;
  final List<AppDestination> goes = <AppDestination>[];

  @override
  bool canPop() => canPopValue;

  @override
  void go(AppDestination destination) => goes.add(destination);

  @override
  void pop<T extends Object?>([T? result]) {
    popCalls++;
  }

  @override
  Future<T?> push<T>(AppDestination destination) async => null;

  @override
  void replace(AppDestination destination) {}
}
