import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiBaseUrlResolverProvider = Provider<ApiBaseUrlResolver>((ref) {
  final resolver = ApiBaseUrlResolver();
  ref.onDispose(resolver.dispose);
  return resolver;
});

typedef BaseUrlHealthProbe = Future<bool> Function(String baseUrl);
typedef LocalSubnetCandidatesProvider = Future<List<String>> Function();

class ApiBaseUrlResolver {
  ApiBaseUrlResolver({
    SharedPreferencesAsync? preferences,
    BaseUrlHealthProbe? healthProbe,
    LocalSubnetCandidatesProvider? localSubnetCandidatesProvider,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _healthProbe = healthProbe,
       _localSubnetCandidatesProvider = localSubnetCandidatesProvider;

  static const _persistedBaseUrlKey = 'petmagic_mobile_last_api_base_url';
  static const _healthPath = '/health';
  static const _defaultApiPort = 5001;
  static const _probeConnectTimeout = Duration(milliseconds: 350);
  static const _probeReadTimeout = Duration(milliseconds: 650);
  static const _probeWorkers = 24;
  static const _probeBudget = Duration(seconds: 8);

  final SharedPreferencesAsync _preferences;
  final BaseUrlHealthProbe? _healthProbe;
  final LocalSubnetCandidatesProvider? _localSubnetCandidatesProvider;

  String? _activeBaseUrl;
  Completer<String>? _resolveInFlight;
  bool _backgroundRefreshInFlight = false;
  bool _disposed = false;

  String? get activeBaseUrl => _activeBaseUrl;

  Future<String> resolveBaseUrl({bool forceRefresh = false}) async {
    if (_disposed) {
      return _activeBaseUrl ?? AppConfig.apiBaseUrl;
    }

    if (forceRefresh) {
      return _resolveWithProbe();
    }

    final activeBaseUrl = _activeBaseUrl;
    if (activeBaseUrl != null) {
      _refreshInBackground();
      return activeBaseUrl;
    }

    final persisted = await _readPersistedBaseUrl();
    if (persisted != null) {
      _activeBaseUrl = persisted;
      _refreshInBackground();
      return persisted;
    }

    if (kDebugMode) {
      return _resolveWithProbe();
    }

    _activeBaseUrl = AppConfig.apiBaseUrl;
    _refreshInBackground();
    return _activeBaseUrl!;
  }

  Future<String> _resolveWithProbe() async {
    if (_disposed) {
      return _activeBaseUrl ?? AppConfig.apiBaseUrl;
    }

    final inFlight = _resolveInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<String>();
    _resolveInFlight = completer;
    try {
      final candidates = await prioritizedCandidates();
      final reachableBaseUrl = await _findReachableBaseUrl(candidates);
      if (_disposed) {
        final fallback = _activeBaseUrl ?? AppConfig.apiBaseUrl;
        completer.complete(fallback);
        return completer.future;
      }

      if (reachableBaseUrl != null) {
        await markSuccessful(reachableBaseUrl);
        completer.complete(reachableBaseUrl);
        return completer.future;
      }

      final fallback = _activeBaseUrl ?? AppConfig.apiBaseUrl;
      _activeBaseUrl = fallback;
      completer.complete(fallback);
      return completer.future;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      return completer.future;
    } finally {
      if (identical(_resolveInFlight, completer)) {
        _resolveInFlight = null;
      }
    }
  }

  void _refreshInBackground() {
    if (_disposed || _backgroundRefreshInFlight) {
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

  Future<List<String>> prioritizedCandidates() async {
    if (_disposed) {
      return const [];
    }

    final candidates = <String>{};

    void addCandidate(String? raw) {
      final normalized = _normalizeBaseUrl(raw);
      if (normalized != null) {
        candidates.add(normalized);
      }
    }

    addCandidate(_activeBaseUrl);
    addCandidate(await _readPersistedBaseUrl());

    for (final baseUrl in AppConfig.apiBaseUrls) {
      addCandidate(baseUrl);
    }

    if (kDebugMode && !kIsWeb) {
      final subnetCandidates = await _readLocalSubnetCandidates();
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

    final normalized = _normalizeBaseUrl(baseUrl);
    if (normalized == null) {
      return;
    }

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

    final normalized = _normalizeBaseUrl(baseUrl);
    if (normalized == null) {
      return;
    }

    if (_activeBaseUrl == normalized) {
      _activeBaseUrl = null;
    }

    final persisted = await _readPersistedBaseUrl();
    if (persisted == normalized) {
      await _preferences.remove(_persistedBaseUrlKey);
    }
  }

  void dispose() {
    _disposed = true;
    _backgroundRefreshInFlight = false;
    _resolveInFlight = null;
  }

  Future<String?> _findReachableBaseUrl(List<String> candidates) async {
    if (candidates.isEmpty) {
      return null;
    }

    final queue = Queue<String>.from(candidates);
    final completer = Completer<String?>();
    var runningWorkers = 0;

    Future<void> runWorker() async {
      try {
        while (!completer.isCompleted) {
          if (queue.isEmpty) {
            return;
          }

          final candidate = queue.removeFirst();
          final isHealthy = await _probe(candidate);
          if (isHealthy && !completer.isCompleted) {
            completer.complete(candidate);
            return;
          }
        }
      } finally {
        runningWorkers--;
        if (runningWorkers == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    final workers = candidates.length < _probeWorkers
        ? candidates.length
        : _probeWorkers;
    runningWorkers = workers;
    for (var index = 0; index < workers; index++) {
      unawaited(runWorker());
    }

    return completer.future.timeout(_probeBudget, onTimeout: () => null);
  }

  Future<bool> _probe(String baseUrl) {
    final healthProbe = _healthProbe;
    if (healthProbe != null) {
      return healthProbe(baseUrl);
    }

    return _probeViaHttp(baseUrl);
  }

  Future<bool> _probeViaHttp(String baseUrl) async {
    final httpClient = HttpClient()..connectionTimeout = _probeConnectTimeout;

    try {
      final request = await httpClient.getUrl(
        Uri.parse('$baseUrl$_healthPath'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-PetMagic-Client', 'mobile-flutter');
      if (kDebugMode) {
        request.headers.set('ngrok-skip-browser-warning', 'true');
        request.headers.set('Bypass-Tunnel-Reminder', 'true');
      }

      final response = await request.close().timeout(_probeReadTimeout);
      await response.drain<void>();

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (error, stackTrace) {
      final normalized = _normalizeBaseUrl(baseUrl);
      if (normalized != null && normalized == _activeBaseUrl) {
        _logResolverFailure(
          'probe_active_base_url',
          error,
          stackTrace,
          context: {'base_url': normalized},
        );
      }
      return false;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<List<String>> _readLocalSubnetCandidates() async {
    if (!kDebugMode) {
      return const [];
    }

    try {
      final overrideProvider = _localSubnetCandidatesProvider;
      if (overrideProvider != null) {
        return await overrideProvider();
      }

      if (!Platform.isAndroid && !Platform.isIOS) {
        return const [];
      }

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final prefixes = <String>{};
      final ownAddresses = <String>{};
      final ownHostOctets = <int>{};

      for (final networkInterface in interfaces) {
        for (final address in networkInterface.addresses) {
          if (!_isPrivateIpv4(address)) {
            continue;
          }

          ownAddresses.add(address.address);

          final octets = address.address.split('.');
          prefixes.add('${octets[0]}.${octets[1]}.${octets[2]}');
          ownHostOctets.add(int.parse(octets[3]));
        }
      }

      if (prefixes.isEmpty) {
        return const [];
      }

      final hostOrder = _buildHostProbeOrder(ownHostOctets);
      final candidates = <String>[];

      for (final prefix in prefixes) {
        for (final host in hostOrder) {
          final hostAddress = '$prefix.$host';
          if (ownAddresses.contains(hostAddress)) {
            continue;
          }

          candidates.add('http://$hostAddress:$_defaultApiPort');
        }
      }

      return candidates;
    } catch (error, stackTrace) {
      _logResolverFailure('read_local_subnet_candidates', error, stackTrace);
      return const [];
    }
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

  List<int> _buildHostProbeOrder(Set<int> ownHostOctets) {
    final orderedHosts = <int>[];
    final used = <int>{};

    void addHost(int host) {
      if (host < 1 || host > 254) {
        return;
      }

      if (used.add(host)) {
        orderedHosts.add(host);
      }
    }

    const preferredHosts = [
      1,
      2,
      10,
      20,
      30,
      40,
      50,
      60,
      70,
      80,
      90,
      100,
      101,
      110,
      120,
      130,
      140,
      150,
      160,
      170,
      180,
      190,
      200,
      210,
      220,
      230,
      240,
      250,
    ];

    for (final host in preferredHosts) {
      addHost(host);
    }

    for (final ownHost in ownHostOctets) {
      for (var offset = 1; offset <= 50; offset++) {
        addHost(ownHost - offset);
        addHost(ownHost + offset);
      }
    }

    for (var host = 1; host <= 254; host++) {
      addHost(host);
    }

    return orderedHosts;
  }

  bool _isPrivateIpv4(InternetAddress address) {
    return isPrivateIpv4(address.address);
  }

  Future<String?> _readPersistedBaseUrl() async {
    final persisted = await _preferences.getString(_persistedBaseUrlKey);
    final normalized = _normalizeBaseUrl(persisted);
    if (persisted != null &&
        persisted.trim().isNotEmpty &&
        normalized == null) {
      await _preferences.remove(_persistedBaseUrlKey);
    }

    return normalized;
  }

  String? _normalizeBaseUrl(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    if (!kDebugMode && scheme != 'https') {
      return null;
    }

    if (!kDebugMode) {
      return AppConfig.normalizeProductionBaseUrl(trimmed);
    }

    final authority = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    final normalized = '$scheme://$authority';
    return normalized;
  }
}
