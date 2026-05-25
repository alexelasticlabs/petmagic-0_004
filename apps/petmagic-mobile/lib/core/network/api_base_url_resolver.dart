import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
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
  static const _defaultApiPort = 5000;
  static const _probeConnectTimeout = Duration(milliseconds: 350);
  static const _probeReadTimeout = Duration(milliseconds: 650);
  static const _probeWorkers = 24;
  static const _probeBudget = Duration(seconds: 8);

  final SharedPreferencesAsync _preferences;
  final BaseUrlHealthProbe? _healthProbe;
  final LocalSubnetCandidatesProvider? _localSubnetCandidatesProvider;

  String? _activeBaseUrl;
  Completer<String>? _resolveInFlight;

  String? get activeBaseUrl => _activeBaseUrl;

  Future<String> resolveBaseUrl({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final activeBaseUrl = _activeBaseUrl;
      if (activeBaseUrl != null) {
        return activeBaseUrl;
      }
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

      if (reachableBaseUrl != null) {
        await markSuccessful(reachableBaseUrl);
        completer.complete(reachableBaseUrl);
        return completer.future;
      }

      final fallback = candidates.isNotEmpty
          ? candidates.first
          : AppConfig.apiBaseUrl;
      _activeBaseUrl = fallback;
      completer.complete(fallback);
      return completer.future;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      if (identical(_resolveInFlight, completer)) {
        _resolveInFlight = null;
      }
    }
  }

  Future<List<String>> prioritizedCandidates() async {
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

    if (AppConfig.configuredApiBaseUrl.isEmpty && !kIsWeb) {
      final subnetCandidates = await _readLocalSubnetCandidates();
      for (final baseUrl in subnetCandidates) {
        addCandidate(baseUrl);
      }
    }

    return candidates.toList(growable: false);
  }

  Future<void> markSuccessful(String baseUrl) async {
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

  void dispose() {}

  Future<String?> _findReachableBaseUrl(List<String> candidates) async {
    if (candidates.isEmpty) {
      return null;
    }

    final queue = Queue<String>.from(candidates);
    final completer = Completer<String?>();
    var runningWorkers = 0;

    Future<void> runWorker() async {
      while (!completer.isCompleted) {
        if (queue.isEmpty) {
          break;
        }

        final candidate = queue.removeFirst();
        final isHealthy = await _probe(candidate);
        if (isHealthy) {
          completer.complete(candidate);
          return;
        }
      }

      runningWorkers--;
      if (runningWorkers == 0 && !completer.isCompleted) {
        completer.complete(null);
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

      final response = await request.close().timeout(_probeReadTimeout);
      await response.drain<void>();

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<List<String>> _readLocalSubnetCandidates() async {
    final overrideProvider = _localSubnetCandidatesProvider;
    if (overrideProvider != null) {
      return overrideProvider();
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return const [];
    }

    try {
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
    } catch (_) {
      return const [];
    }
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
    final octets = address.address.split('.');
    if (octets.length != 4) {
      return false;
    }

    final first = int.tryParse(octets[0]);
    final second = int.tryParse(octets[1]);
    if (first == null || second == null) {
      return false;
    }

    final isClassA = first == 10;
    final isClassB = first == 172 && second >= 16 && second <= 31;
    final isClassC = first == 192 && second == 168;

    return isClassA || isClassB || isClassC;
  }

  Future<String?> _readPersistedBaseUrl() async {
    final persisted = await _preferences.getString(_persistedBaseUrlKey);
    return _normalizeBaseUrl(persisted);
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

    final authority = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    return '$scheme://$authority';
  }
}
