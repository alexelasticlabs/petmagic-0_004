import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/network/network_utils.dart';

typedef LocalSubnetCandidatesProvider = Future<List<String>> Function();
typedef LocalSubnetDiscoveryFailure =
    void Function(Object error, StackTrace stackTrace);

/// Debug-only discovery for physical devices running against a local API.
/// Production endpoint policy remains outside this service.
final class LocalSubnetApiCandidateDiscovery {
  const LocalSubnetApiCandidateDiscovery({
    this.overrideProvider,
    this.apiPort = 5000,
    this.onFailure,
  });

  final LocalSubnetCandidatesProvider? overrideProvider;
  final int apiPort;
  final LocalSubnetDiscoveryFailure? onFailure;

  Future<List<String>> discover() async {
    if (!kDebugMode) {
      return const [];
    }

    try {
      final provider = overrideProvider;
      if (provider != null) {
        return await provider();
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
          if (!isPrivateIpv4(address.address)) {
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
      return [
        for (final prefix in prefixes)
          for (final host in hostOrder)
            if (!ownAddresses.contains('$prefix.$host'))
              'http://$prefix.$host:$apiPort',
      ];
    } catch (error, stackTrace) {
      onFailure?.call(error, stackTrace);
      return const [];
    }
  }

  List<int> _buildHostProbeOrder(Set<int> ownHostOctets) {
    final orderedHosts = <int>[];
    final used = <int>{};

    void addHost(int host) {
      if (host >= 1 && host <= 254 && used.add(host)) {
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
}
