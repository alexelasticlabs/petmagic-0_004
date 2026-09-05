import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/api_base_url_health_checker.dart';

enum NetworkBannerPhase { hidden, offline, restored }

enum NetworkTransportKind {
  unknown,
  wifi,
  ethernet,
  cellular,
  constrained,
  offline,
}

class NetworkStatusState {
  const NetworkStatusState({
    this.bannerPhase = NetworkBannerPhase.hidden,
    this.hasInternet = true,
    this.transport = NetworkTransportKind.unknown,
  });

  final NetworkBannerPhase bannerPhase;
  final bool hasInternet;
  final NetworkTransportKind transport;

  NetworkStatusState copyWith({
    NetworkBannerPhase? bannerPhase,
    bool? hasInternet,
    NetworkTransportKind? transport,
  }) {
    return NetworkStatusState(
      bannerPhase: bannerPhase ?? this.bannerPhase,
      hasInternet: hasInternet ?? this.hasInternet,
      transport: transport ?? this.transport,
    );
  }
}

NetworkTransportKind classifyNetworkTransport(
  List<ConnectivityResult> results, {
  required bool hasInternet,
}) {
  if (!hasInternet) {
    return NetworkTransportKind.offline;
  }

  final transports = results
      .where((result) => result != ConnectivityResult.none)
      .toSet();
  if (transports.isEmpty) {
    // The reachability probe can succeed while the platform briefly reports
    // no route. Do not assume that such an unconfirmed route is unmetered.
    return NetworkTransportKind.unknown;
  }

  // Prefer the most constrained reported route. connectivity_plus can expose
  // multiple transports at once (for example mobile + satellite or Wi-Fi +
  // VPN), so a mobile/constrained route must never be promoted to Wi-Fi.
  if (transports.contains(ConnectivityResult.satellite) ||
      transports.contains(ConnectivityResult.bluetooth)) {
    return NetworkTransportKind.constrained;
  }
  if (transports.contains(ConnectivityResult.mobile)) {
    return NetworkTransportKind.cellular;
  }
  if (transports.contains(ConnectivityResult.wifi)) {
    return NetworkTransportKind.wifi;
  }
  if (transports.contains(ConnectivityResult.ethernet)) {
    return NetworkTransportKind.ethernet;
  }

  // VPN and other do not reveal whether the underlying route is metered.
  return NetworkTransportKind.unknown;
}

final networkStatusControllerProvider =
    NotifierProvider<NetworkStatusController, NetworkStatusState>(
      NetworkStatusController.new,
    );

class NetworkStatusController extends Notifier<NetworkStatusState> {
  static const Duration _recoveredBannerDuration = Duration(seconds: 3);
  static const Duration _offlineProbeInterval = Duration(seconds: 5);
  static const Duration _offlineProbeMaxInterval = Duration(seconds: 30);
  static const Duration _internetProbeTimeout = Duration(seconds: 6);

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineProbeTimer;
  Timer? _restoreBannerTimer;
  bool _lastKnownInternet = true;
  NetworkTransportKind _lastKnownTransport = NetworkTransportKind.unknown;
  bool _started = false;
  int _connectivityEvaluationGeneration = 0;
  Duration _currentOfflineProbeInterval = _offlineProbeInterval;

  @override
  NetworkStatusState build() {
    if (!_started) {
      _started = true;
      Future.microtask(_bootstrapSafely);
    }
    ref.onDispose(() {
      _started = false;
      _subscription?.cancel();
      _subscription = null;
      _stopOfflineProbe();
      _restoreBannerTimer?.cancel();
      _restoreBannerTimer = null;
    });
    return const NetworkStatusState();
  }

  Future<void> _bootstrapSafely() async {
    if (!ref.mounted) {
      return;
    }

    try {
      _bootstrap();
    } on MissingPluginException catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Network',
        operation: 'connectivity_plugin_missing',
        message:
            'Connectivity plugin is unavailable. Network banner is disabled.',
        error: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Network',
        operation: 'connectivity_bootstrap_failed',
        message: 'Network status bootstrap failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _bootstrap() {
    if (!ref.mounted) {
      return;
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (!ref.mounted) {
          return;
        }

        unawaited(_onConnectivityChanged(results, source: 'stream'));
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.warn(
          feature: 'Network',
          operation: 'connectivity_stream_error',
          message: 'Connectivity stream failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    unawaited(_refreshFromCurrentConnectivity(source: 'bootstrap'));
  }

  Future<void> _refreshFromCurrentConnectivity({required String source}) async {
    if (!ref.mounted) {
      return;
    }

    try {
      final results = await _connectivity.checkConnectivity();
      if (!ref.mounted) {
        return;
      }

      await _onConnectivityChanged(results, source: source);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Network',
        operation: 'check_connectivity_failed',
        message: 'Failed to read connectivity status',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results, {
    required String source,
  }) async {
    if (!ref.mounted) {
      return;
    }

    final evaluationGeneration = ++_connectivityEvaluationGeneration;
    final hasReportedRoute = _hasAnyNetworkRoute(results);
    final hasInternet = await _probeInternet();
    if (!ref.mounted ||
        evaluationGeneration != _connectivityEvaluationGeneration) {
      return;
    }

    _applyConnectionState(
      hasInternet: hasInternet,
      transport: classifyNetworkTransport(results, hasInternet: hasInternet),
      source: hasReportedRoute ? source : '${source}_route_unconfirmed',
    );
  }

  void _applyConnectionState({
    required bool hasInternet,
    required NetworkTransportKind transport,
    required String source,
  }) {
    if (!ref.mounted) {
      return;
    }

    final internetChanged = hasInternet != _lastKnownInternet;
    final transportChanged = transport != _lastKnownTransport;
    if (!internetChanged && !transportChanged) {
      return;
    }

    final wasOffline = !_lastKnownInternet;
    _lastKnownInternet = hasInternet;
    _lastKnownTransport = transport;

    if (!hasInternet) {
      _restoreBannerTimer?.cancel();
      _restoreBannerTimer = null;
      _currentOfflineProbeInterval = _offlineProbeInterval;
      _startOfflineProbe();
      state = state.copyWith(
        hasInternet: false,
        transport: NetworkTransportKind.offline,
        bannerPhase: NetworkBannerPhase.offline,
      );
      AppLogger.warn(
        feature: 'Network',
        operation: 'connection_lost',
        message: 'Internet connection lost',
        context: {'source': source},
      );
      return;
    }

    _stopOfflineProbe();
    state = state.copyWith(
      hasInternet: true,
      transport: transport,
      bannerPhase: wasOffline ? NetworkBannerPhase.restored : state.bannerPhase,
    );

    if (wasOffline) {
      AppLogger.info(
        feature: 'Network',
        operation: 'connection_restored',
        message: 'Internet connection restored',
        context: {'source': source},
      );
      _scheduleRestoreBannerHide();
    } else if (transportChanged) {
      AppLogger.debug(
        feature: 'Network',
        operation: 'transport_changed',
        message: 'Active network transport changed.',
        context: {'source': source, 'transport': transport.name},
      );
    }
  }

  void _startOfflineProbe() {
    _scheduleNextOfflineProbe(_currentOfflineProbeInterval);
  }

  void _scheduleNextOfflineProbe(Duration delay) {
    _offlineProbeTimer?.cancel();
    _offlineProbeTimer = Timer(delay, () async {
      if (!ref.mounted) {
        return;
      }

      await _refreshFromCurrentConnectivity(source: 'offline_probe');
      if (!ref.mounted || state.hasInternet) {
        return;
      }

      final nextSeconds = (_currentOfflineProbeInterval.inSeconds * 2).clamp(
        _offlineProbeInterval.inSeconds,
        _offlineProbeMaxInterval.inSeconds,
      );
      _currentOfflineProbeInterval = Duration(seconds: nextSeconds);
      _scheduleNextOfflineProbe(_currentOfflineProbeInterval);
    });
  }

  void _stopOfflineProbe() {
    _offlineProbeTimer?.cancel();
    _offlineProbeTimer = null;
    _currentOfflineProbeInterval = _offlineProbeInterval;
  }

  void _scheduleRestoreBannerHide() {
    _restoreBannerTimer?.cancel();
    _restoreBannerTimer = Timer(_recoveredBannerDuration, () {
      if (!ref.mounted) {
        return;
      }

      if (!state.hasInternet) {
        return;
      }

      state = state.copyWith(bannerPhase: NetworkBannerPhase.hidden);
    });
  }

  bool _hasAnyNetworkRoute(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return false;
    }
    return results.any((item) => item != ConnectivityResult.none);
  }

  Future<bool> _probeInternet() async {
    final reachableBaseUrl = await const ApiBaseUrlHealthChecker(
      probeBudget: _internetProbeTimeout,
      connectTimeout: Duration(seconds: 2),
      readTimeout: Duration(seconds: 3),
    ).findReachable(AppConfig.apiBaseUrls);
    return reachableBaseUrl != null;
  }
}
