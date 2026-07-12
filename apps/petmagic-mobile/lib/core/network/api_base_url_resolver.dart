import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/api_base_url_health_checker.dart';
import 'package:petmagic_mobile/core/network/api_base_url_policy.dart';
import 'package:petmagic_mobile/core/network/local_subnet_api_candidate_discovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:petmagic_mobile/core/network/api_base_url_health_checker.dart'
    show BaseUrlHealthProbe;
export 'package:petmagic_mobile/core/network/local_subnet_api_candidate_discovery.dart'
    show LocalSubnetCandidatesProvider;

final apiBaseUrlResolverProvider = Provider<ApiBaseUrlResolver>((ref) {
  final resolver = ApiBaseUrlResolver();
  ref.onDispose(resolver.dispose);
  return resolver;
});

class ApiBaseUrlResolver {
  ApiBaseUrlResolver({
    SharedPreferencesAsync? preferences,
    BaseUrlHealthProbe? healthProbe,
    LocalSubnetCandidatesProvider? localSubnetCandidatesProvider,
    List<String>? baseUrls,
    bool? preferConfiguredBaseUrls,
    Duration? backgroundRefreshInterval,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _baseUrls = baseUrls ?? AppConfig.apiBaseUrls,
       _preferConfiguredBaseUrls =
           preferConfiguredBaseUrls ??
           AppConfig.configuredApiBaseUrl.trim().isNotEmpty,
       _backgroundRefreshInterval =
           backgroundRefreshInterval ?? const Duration(minutes: 5),
       _now = now ?? DateTime.now,
       _policy = ApiBaseUrlPolicy(baseUrls ?? AppConfig.apiBaseUrls) {
    _healthChecker = ApiBaseUrlHealthChecker(
      healthProbe: healthProbe,
      onProbeFailure: _handleProbeFailure,
    );
    _localSubnetDiscovery = LocalSubnetApiCandidateDiscovery(
      overrideProvider: localSubnetCandidatesProvider,
      onFailure: (error, stackTrace) => _logResolverFailure(
        'read_local_subnet_candidates',
        error,
        stackTrace,
      ),
    );
  }

  static const _persistedBaseUrlKey = 'petmagic_mobile_last_api_base_url';
  final SharedPreferencesAsync _preferences;
  final List<String> _baseUrls;
  final bool _preferConfiguredBaseUrls;
  final Duration _backgroundRefreshInterval;
  final DateTime Function() _now;
  final ApiBaseUrlPolicy _policy;
  late final ApiBaseUrlHealthChecker _healthChecker;
  late final LocalSubnetApiCandidateDiscovery _localSubnetDiscovery;

  String? _activeBaseUrl;
  Completer<String>? _resolveInFlight;
  bool _backgroundRefreshInFlight = false;
  bool _disposed = false;
  DateTime? _lastSuccessfulConnectionAt;

  String? get activeBaseUrl => _activeBaseUrl;

  Future<String> resolveBaseUrl({bool forceRefresh = false}) async {
    if (_disposed) {
      return _activeBaseUrl ?? AppConfig.apiBaseUrl;
    }

    if (forceRefresh) {
      return _resolveWithProbe();
    }

    final activeBaseUrl = _activeBaseUrl;
    if (activeBaseUrl != null &&
        (!_preferConfiguredBaseUrls ||
            _policy.isConfiguredCandidate(activeBaseUrl))) {
      _refreshInBackgroundIfStale();
      return activeBaseUrl;
    }

    if (_preferConfiguredBaseUrls) {
      if (kDebugMode) {
        return _resolveWithProbe();
      }

      _activeBaseUrl = _policy.configuredFallback();
      _refreshInBackgroundIfStale();
      return _activeBaseUrl!;
    }

    final persisted = await _readPersistedBaseUrl();
    if (persisted != null) {
      _activeBaseUrl = persisted;
      _refreshInBackgroundIfStale();
      return persisted;
    }

    if (kDebugMode) {
      return _resolveWithProbe();
    }

    _activeBaseUrl = AppConfig.apiBaseUrl;
    _refreshInBackgroundIfStale();
    return _activeBaseUrl!;
  }

  Future<String> _resolveWithProbe() {
    if (_disposed) {
      return Future.value(_activeBaseUrl ?? AppConfig.apiBaseUrl);
    }

    final inFlight = _resolveInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<String>();
    _resolveInFlight = completer;
    unawaited(_completeResolveWithProbe(completer));
    return completer.future;
  }

  Future<void> _completeResolveWithProbe(Completer<String> completer) async {
    try {
      final candidates = await prioritizedCandidates();
      final reachableBaseUrl = await _healthChecker.findReachable(candidates);
      if (_disposed) {
        final fallback = _activeBaseUrl ?? AppConfig.apiBaseUrl;
        _completeResolve(completer, fallback);
        return;
      }

      if (reachableBaseUrl != null) {
        await markSuccessful(reachableBaseUrl);
        _completeResolve(completer, reachableBaseUrl);
        return;
      }

      final fallback = _activeBaseUrl ?? AppConfig.apiBaseUrl;
      _activeBaseUrl = fallback;
      _lastSuccessfulConnectionAt = null;
      _completeResolve(completer, fallback);
    } catch (error, stackTrace) {
      _completeResolveError(completer, error, stackTrace);
    } finally {
      if (identical(_resolveInFlight, completer)) {
        _resolveInFlight = null;
      }
    }
  }

  void _refreshInBackgroundIfStale() {
    if (!_shouldRefreshInBackground()) {
      return;
    }

    _backgroundRefreshInFlight = true;
    unawaited(
      _resolveWithProbe()
          .catchError((Object error, StackTrace stackTrace) {
            _logResolverFailure('background_refresh', error, stackTrace);
            return _activeBaseUrl ?? AppConfig.apiBaseUrl;
          })
          .whenComplete(() {
            if (_disposed) {
              return;
            }
            _backgroundRefreshInFlight = false;
          }),
    );
  }

  bool _shouldRefreshInBackground() {
    if (_disposed || _backgroundRefreshInFlight) {
      return false;
    }

    final lastSuccessfulConnectionAt = _lastSuccessfulConnectionAt;
    if (lastSuccessfulConnectionAt == null) {
      return true;
    }

    return _now().difference(lastSuccessfulConnectionAt) >=
        _backgroundRefreshInterval;
  }

  Future<List<String>> prioritizedCandidates() async {
    if (_disposed) {
      return const [];
    }

    final candidates = <String>{};

    void addCandidate(String? raw) {
      final normalized = _policy.normalize(raw);
      if (normalized != null) {
        candidates.add(normalized);
      }
    }

    if (_preferConfiguredBaseUrls) {
      for (final baseUrl in _baseUrls) {
        addCandidate(baseUrl);
      }

      if (candidates.isEmpty) {
        addCandidate(AppConfig.apiBaseUrl);
      }

      return candidates.toList(growable: false);
    }

    addCandidate(_activeBaseUrl);
    addCandidate(await _readPersistedBaseUrl());

    for (final baseUrl in _baseUrls) {
      addCandidate(baseUrl);
    }

    if (kDebugMode && !kIsWeb) {
      final subnetCandidates = await _localSubnetDiscovery.discover();
      for (final baseUrl in subnetCandidates) {
        addCandidate(baseUrl);
      }
    }

    return candidates.toList(growable: false);
  }

  Future<void> markSuccessful(String baseUrl) async {
    if (_disposed) {
      return;
    }

    final normalized = _policy.normalize(baseUrl);
    if (normalized == null) {
      return;
    }

    _lastSuccessfulConnectionAt = _now();
    if (_activeBaseUrl == normalized) {
      return;
    }

    _activeBaseUrl = normalized;
    await _preferences.setString(_persistedBaseUrlKey, normalized);
  }

  Future<void> invalidate(String baseUrl) async {
    if (_disposed) {
      return;
    }

    final normalized = _policy.normalize(baseUrl);
    if (normalized == null) {
      return;
    }

    if (_activeBaseUrl == normalized) {
      _activeBaseUrl = null;
      _lastSuccessfulConnectionAt = null;
    }

    final persisted = await _readPersistedBaseUrl();
    if (persisted == normalized) {
      await _preferences.remove(_persistedBaseUrlKey);
      _lastSuccessfulConnectionAt = null;
    }
  }

  void dispose() {
    _disposed = true;
    _backgroundRefreshInFlight = false;
    final inFlight = _resolveInFlight;
    _resolveInFlight = null;
    if (inFlight != null) {
      _completeResolve(inFlight, _activeBaseUrl ?? AppConfig.apiBaseUrl);
    }
  }

  void _completeResolve(Completer<String> completer, String value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _completeResolveError(
    Completer<String> completer,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  void _handleProbeFailure(
    String baseUrl,
    Object error,
    StackTrace stackTrace,
  ) {
    final normalized = _policy.normalize(baseUrl);
    if (normalized == null || normalized != _activeBaseUrl) {
      return;
    }
    _logResolverFailure(
      'probe_active_base_url',
      error,
      stackTrace,
      context: {'base_url_origin': _policy.logSafeOrigin(normalized)},
    );
  }

  void _logResolverFailure(
    String stage,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object>{'stage': stage};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        payload[entry.key] = value.toString();
      }
    }

    AppLogger.warn(
      feature: 'Network.BaseUrlResolver',
      operation: stage,
      message: 'API base URL resolver step failed',
      context: payload,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<String?> _readPersistedBaseUrl() async {
    final persisted = await _preferences.getString(_persistedBaseUrlKey);
    final normalized = _policy.normalize(persisted);
    if (persisted != null && persisted.trim().isNotEmpty) {
      if (normalized == null) {
        await _preferences.remove(_persistedBaseUrlKey);
      } else if (persisted.trim() != normalized) {
        await _preferences.setString(_persistedBaseUrlKey, normalized);
      }
    }

    return normalized;
  }
}
