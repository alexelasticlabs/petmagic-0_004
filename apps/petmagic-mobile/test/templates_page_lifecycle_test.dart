import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  testWidgets('templates page does not reload when tab is hidden and shown', (
    tester,
  ) async {
    final controller = _FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: const _TemplatesTickerModeHost(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controller.loadInitialCalls, [false]);

    final hostState = tester.state<_TemplatesTickerModeHostState>(
      find.byType(_TemplatesTickerModeHost),
    );

    hostState.setEnabled(false);
    await tester.pump();
    await tester.pump();

    hostState.setEnabled(true);
    await tester.pump();
    await tester.pump();

    expect(controller.loadInitialCalls, [false]);
    expect(controller.setScreenVisibleCalls, [true, false, true]);
  });

  testWidgets('templates page keeps guest browsing UI without auth gate', (
    tester,
  ) async {
    final controller = _FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _UnauthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(find.text(text.createMagicTitle), findsOneWidget);
    expect(find.byType(ProtectedAuthGate), findsNothing);
    expect(find.text(text.authSignInRequired), findsNothing);
  });
}

class _TemplatesTickerModeHost extends StatefulWidget {
  const _TemplatesTickerModeHost();

  @override
  State<_TemplatesTickerModeHost> createState() =>
      _TemplatesTickerModeHostState();
}

class _TemplatesTickerModeHostState extends State<_TemplatesTickerModeHost> {
  bool _enabled = true;

  void setEnabled(bool enabled) {
    setState(() {
      _enabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _enabled,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: TemplatesPage()),
      ),
    );
  }
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _UnauthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _FakeTemplatesController extends TemplatesController {
  final List<bool> loadInitialCalls = <bool>[];
  final List<bool> setScreenVisibleCalls = <bool>[];

  @override
  TemplatesState build() {
    return const TemplatesState();
  }

  @override
  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {
    loadInitialCalls.add(forceRefresh);
    state = TemplatesState(
      items: [
        TemplateItem(
          templateId: 'template-1',
          templateType: TemplateType.image,
          title: 'Template 1',
          shortDescription: 'Template 1',
          petPhotoRequirements: const ['Clear photo'],
          category: 'Portrait',
          tags: const ['pet'],
          isPremium: false,
          tokenCost: 1,
        ),
      ],
      isLoading: false,
      isRefreshing: false,
    );
  }

  @override
  void setScreenVisible(bool visible) {
    setScreenVisibleCalls.add(visible);
    super.setScreenVisible(visible);
  }
}
