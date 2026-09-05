import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'templates_page_lifecycle_test_support.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() async {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets('cancelled discovery preview returns to discovery exactly once', (
    tester,
  ) async {
    final navigator = _DiscoveryBridgeNavigator(previewResult: null);

    await _pumpDiscoveryBridge(tester, navigator: navigator);
    await _pumpUntil(tester, () => navigator.discoveryGoCalls == 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(navigator.previewPushCalls, 1);
    expect(navigator.discoveryGoCalls, 1);
    expect(navigator.popCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelled discovery preview pops the local bridge and preserves origin',
    (tester) async {
      final navigator = _DiscoveryBridgeNavigator(previewResult: null);

      await _pumpDiscoveryBridge(
        tester,
        navigator: navigator,
        useLocalBranchNavigator: true,
      );
      await _pumpUntil(
        tester,
        () => find.byKey(_discoveryOriginKey).evaluate().isNotEmpty,
      );

      expect(navigator.previewPushCalls, 1);
      expect(navigator.discoveryGoCalls, 0);
      expect(navigator.popCalls, 0);
      expect(find.byKey(_discoveryOriginKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('continued discovery preview keeps the bridge active', (
    tester,
  ) async {
    final template = templateFixture('discovery-template', 'Discovery');
    final navigator = _DiscoveryBridgeNavigator(
      previewResult: TemplatePreviewResult(
        action: TemplateDetailAction.upload,
        selectedTemplate: template,
      ),
    );

    await _pumpDiscoveryBridge(
      tester,
      navigator: navigator,
      template: template,
    );
    await _pumpUntil(
      tester,
      () => find.text('Continue browsing').evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Continue browsing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(navigator.previewPushCalls, 1);
    expect(navigator.discoveryGoCalls, 0);
    expect(navigator.popCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDiscoveryBridge(
  WidgetTester tester, {
  required _DiscoveryBridgeNavigator navigator,
  TemplateItem? template,
  bool useLocalBranchNavigator = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final initialTemplate =
      template ?? templateFixture('discovery-template', 'Discovery');
  final controller = FakeTemplatesController(items: [initialTemplate]);

  final bridge = TemplatesPage(
    initialPreviewSession: TemplatePreviewSession.single(
      initialTemplate,
      source: TemplatePreviewSource.discovery,
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          UnauthenticatedAppLaunchController.new,
        ),
        walletControllerProvider.overrideWith(IdleWalletController.new),
        profileControllerProvider.overrideWith(FakeProfileController.new),
        networkStatusControllerProvider.overrideWith(
          () => TestTemplatesNetworkStatusController(initialHasInternet: true),
        ),
        templatesControllerProvider.overrideWith(() => controller),
        templatesRepositoryProvider.overrideWithValue(
          RandomTemplatesRepository(items: [initialTemplate]),
        ),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
      ],
      child: AppNavigationScope(
        navigator: navigator,
        child: buildTemplatesPageApp(
          child: useLocalBranchNavigator
              ? _DiscoveryBranchNavigator(bridge: bridge)
              : bridge,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

const _discoveryOriginKey = ValueKey<String>('discovery-origin');

class _DiscoveryBranchNavigator extends StatelessWidget {
  const _DiscoveryBranchNavigator({required this.bridge});

  final Widget bridge;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateInitialRoutes: (navigator, initialRoute) => [
        MaterialPageRoute<void>(
          builder: (context) =>
              const ColoredBox(key: _discoveryOriginKey, color: Colors.white),
        ),
        MaterialPageRoute<void>(builder: (context) => bridge),
      ],
      onGenerateRoute: (settings) => null,
    );
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Condition was not reached before the test timeout.');
}

class _DiscoveryBridgeNavigator implements AppNavigator {
  _DiscoveryBridgeNavigator({required this.previewResult});

  final Object? previewResult;
  int previewPushCalls = 0;
  int discoveryGoCalls = 0;
  int popCalls = 0;

  @override
  bool canPop() => true;

  @override
  void go(AppDestination destination) {
    expect(destination, isA<DiscoverDestination>());
    discoveryGoCalls++;
  }

  @override
  void pop<T extends Object?>([T? result]) {
    popCalls++;
  }

  @override
  Future<T?> push<T>(AppDestination destination) async {
    expect(destination, isA<TemplatePreviewDestination>());
    final previewDestination = destination as TemplatePreviewDestination;
    expect(previewDestination.templateId, 'discovery-template');
    final args = previewDestination.extra! as TemplatePreviewRouteArgs;
    expect(args.session?.source, TemplatePreviewSource.discovery);
    previewPushCalls++;
    return previewResult as T?;
  }

  @override
  void replace(AppDestination destination) {}
}
