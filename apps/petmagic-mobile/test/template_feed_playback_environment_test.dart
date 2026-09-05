import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_discovery_page.dart';

void main() {
  group('network transport classification', () {
    test('legacy state construction defaults to an unknown transport', () {
      const status = NetworkStatusState(hasInternet: true);

      expect(status.transport, NetworkTransportKind.unknown);
    });

    test('offline reachability wins over a reported platform route', () {
      expect(
        classifyNetworkTransport(const [
          ConnectivityResult.wifi,
        ], hasInternet: false),
        NetworkTransportKind.offline,
      );
    });

    test('mobile wins over Wi-Fi so mixed routes remain metered', () {
      expect(
        classifyNetworkTransport(const [
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ], hasInternet: true),
        NetworkTransportKind.cellular,
      );
    });

    test('satellite and Bluetooth routes are classified as constrained', () {
      expect(
        classifyNetworkTransport(const [
          ConnectivityResult.mobile,
          ConnectivityResult.satellite,
        ], hasInternet: true),
        NetworkTransportKind.constrained,
      );
      expect(
        classifyNetworkTransport(const [
          ConnectivityResult.wifi,
          ConnectivityResult.bluetooth,
        ], hasInternet: true),
        NetworkTransportKind.constrained,
      );
    });

    test('known unmetered routes and opaque routes stay distinct', () {
      expect(
        classifyNetworkTransport(const [
          ConnectivityResult.wifi,
          ConnectivityResult.vpn,
        ], hasInternet: true),
        NetworkTransportKind.wifi,
      );
      expect(
        classifyNetworkTransport(const [
          ConnectivityResult.ethernet,
        ], hasInternet: true),
        NetworkTransportKind.ethernet,
      );
      expect(
        classifyNetworkTransport(const [
          ConnectivityResult.vpn,
        ], hasInternet: true),
        NetworkTransportKind.unknown,
      );
      expect(
        classifyNetworkTransport(const [], hasInternet: true),
        NetworkTransportKind.unknown,
      );
    });
  });

  test('playback environment provider follows transport changes', () {
    final networkController = _TestNetworkStatusController(
      const NetworkStatusState(
        hasInternet: true,
        transport: NetworkTransportKind.wifi,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        networkStatusControllerProvider.overrideWith(() => networkController),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(templateFeedPlaybackEnvironmentProvider).networkClass,
      TemplateFeedNetworkClass.wifi,
    );

    networkController.setStatus(
      const NetworkStatusState(
        hasInternet: true,
        transport: NetworkTransportKind.cellular,
      ),
    );
    expect(
      container.read(templateFeedPlaybackEnvironmentProvider).networkClass,
      TemplateFeedNetworkClass.cellular,
    );

    networkController.setStatus(
      const NetworkStatusState(
        hasInternet: true,
        transport: NetworkTransportKind.constrained,
      ),
    );
    expect(
      container.read(templateFeedPlaybackEnvironmentProvider).networkClass,
      TemplateFeedNetworkClass.slow,
    );

    networkController.setStatus(
      const NetworkStatusState(
        hasInternet: false,
        transport: NetworkTransportKind.wifi,
      ),
    );
    expect(
      container.read(templateFeedPlaybackEnvironmentProvider).networkClass,
      TemplateFeedNetworkClass.offline,
    );
  });

  test('discovery and catalog use isolated playback managers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final discoveryManager = container.read(
      templateDiscoveryPlaybackManagerProvider,
    );
    final catalogManager = container.read(templateFeedPlaybackManagerProvider);

    expect(identical(discoveryManager, catalogManager), isFalse);
    discoveryManager.configure(
      feedKind: TemplateFeedKind.mixed,
      environment: const TemplateFeedPlaybackEnvironment(
        networkClass: TemplateFeedNetworkClass.slow,
      ),
    );
    catalogManager.configure(
      feedKind: TemplateFeedKind.videoOnly,
      environment: const TemplateFeedPlaybackEnvironment(
        networkClass: TemplateFeedNetworkClass.slow,
      ),
    );

    expect(discoveryManager.currentVideoPreviewBudget, 0);
    expect(catalogManager.currentVideoPreviewBudget, 1);
  });
}

final class _TestNetworkStatusController extends NetworkStatusController {
  _TestNetworkStatusController(this.initialState);

  final NetworkStatusState initialState;

  @override
  NetworkStatusState build() => initialState;

  void setStatus(NetworkStatusState next) {
    state = next;
  }
}
