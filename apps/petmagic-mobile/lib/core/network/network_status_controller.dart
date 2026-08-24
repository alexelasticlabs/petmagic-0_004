import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/api_base_url_health_checker.dart';

enum NetworkBannerPhase { hidden, offline, restored }

class NetworkStatusState {
  const NetworkStatusState({
    this.bannerPhase = NetworkBannerPhase.hidden,
    this.hasInternet = true,
  });

  final NetworkBannerPhase bannerPhase;
  final bool hasInternet;

  NetworkStatusState copyWith({
    NetworkBannerPhase? bannerPhase,
    bool? hasInternet,
  }) {
    return NetworkStatusState(
      bannerPhase: bannerPhase ?? this.bannerPhase,
      hasInternet: hasInternet ?? this.hasInternet,
    );
  }
}

final networkStatusControllerProvider =
    NotifierProvider<NetworkStatusController, NetworkStatusState>(
      NetworkStatusController.new,
    );

class NetworkStatusController extends Notifier<NetworkStatusState> {
  static const Duration _recoveredBannerDuration = Duration(seconds: 3);
  static const Duration _offlineProbeInterval = Duration(seconds: 5);
  static const Duration _offlineProbeMaxInterval = Duration(seconds: 30);
  static const Duration _internetProbeTimeout = Duration(seconds: 2);
  static const Duration _probeDebounceWindow = Duration(seconds: 5);

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineProbeTimer;
  Timer? _restoreBannerTimer;
  bool _lastKnownInternet = true;
  bool _started = false;
  bool? _lastProbeResult;
  DateTime? _lastProbeTime;
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

    if (!_hasAnyNetworkRoute(results)) {
      _applyConnectionState(hasInternet: false, source: source);
      return;
    }

    final hasInternet = await _probeInternet();
    if (!ref.mounted) {
      return;
    }

    _applyConnectionState(hasInternet: hasInternet, source: source);
  }

  void _applyConnectionState({
    required bool hasInternet,
    required String source,
  }) {
    if (!ref.mounted) {
      return;
    }

    if (hasInternet == _lastKnownInternet) {
      return;
    }

    final wasOffline = !_lastKnownInternet;
    _lastKnownInternet = hasInternet;

    if (!hasInternet) {
      _restoreBannerTimer?.cancel();
      _restoreBannerTimer = null;
      _currentOfflineProbeInterval = _offlineProbeInterval;
      _startOfflineProbe();
      state = state.copyWith(
        hasInternet: false,
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
      bannerPhase: wasOffline
          ? NetworkBannerPhase.restored
          : NetworkBannerPhase.hidden,
    );

    if (wasOffline) {
      AppLogger.info(
        feature: 'Network',
        operation: 'connection_restored',
        message: 'Internet connection restored',
        context: {'source': source},
      );
      _scheduleRestoreBannerHide();
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
    if (_lastProbeResult != null &&
        _lastProbeTime != null &&
        DateTime.now().difference(_lastProbeTime!) < _probeDebounceWindow) {
      return _lastProbeResult!;
    }

    final reachableBaseUrl = await const ApiBaseUrlHealthChecker(
      probeBudget: _internetProbeTimeout,
      connectTimeout: Duration(milliseconds: 700),
      readTimeout: Duration(milliseconds: 1100),
    ).findReachable(AppConfig.apiBaseUrls);
    final result = reachableBaseUrl != null;
    _lastProbeResult = result;
    _lastProbeTime = DateTime.now();
    return result;
  }
}
