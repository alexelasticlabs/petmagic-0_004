const _localDebugHosts = <String>{
  'localhost',
  '127.0.0.1',
  '::1',
  '10.0.2.2',
  '10.0.3.2',
  'host.docker.internal',
};

bool isLocalOrPrivateDebugHost(String host) {
  final normalizedHost = _normalizeRemoteHost(host);
  return _localDebugHosts.contains(normalizedHost) ||
      _isDebugPrivateIpv4Host(normalizedHost);
}

bool isUnsafeRemoteHost(String host) {
  final normalizedHost = _normalizeRemoteHost(host);
  return isLocalOrPrivateDebugHost(normalizedHost) ||
      _isUnsafeIpv4Host(normalizedHost) ||
      _isUnsafeIpv6Host(normalizedHost) ||
      normalizedHost == '0.0.0.0';
}

String _normalizeRemoteHost(String host) {
  return host
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^\['), '')
      .replaceFirst(RegExp(r'\]$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

bool _isDebugPrivateIpv4Host(String host) {
  return _readIpv4Prefix(host, _isDebugPrivateIpv4Bytes);
}

bool _isUnsafeIpv4Host(String host) {
  return _readIpv4Prefix(host, _isUnsafeIpv4Bytes);
}

bool _readIpv4Prefix(String host, bool Function(int first, int second) test) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return false;
  }

  final octets = parts.map(int.tryParse).toList(growable: false);
  if (octets.any((value) => value == null || value < 0 || value > 255)) {
    return false;
  }

  return test(octets[0]!, octets[1]!);
}

bool _isDebugPrivateIpv4Bytes(int first, int second) {
  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

bool _isUnsafeIpv4Bytes(int first, int second) {
  return _isDebugPrivateIpv4Bytes(first, second) ||
      first == 127 ||
      first == 0 ||
      (first == 100 && second >= 64 && second <= 127) ||
      (first == 169 && second == 254) ||
      first >= 224;
}

bool _isUnsafeIpv6Host(String host) {
  if (!host.contains(':')) {
    return false;
  }

  if (host == '::' ||
      host.startsWith('fc') ||
      host.startsWith('fd') ||
      host.startsWith('fe80:')) {
    return true;
  }

  final mappedIpv4Bytes = _parseIpv4MappedIpv6Bytes(host);
  if (mappedIpv4Bytes == null) {
    return false;
  }

  return _isUnsafeIpv4Bytes(mappedIpv4Bytes.$1, mappedIpv4Bytes.$2);
}

(int, int)? _parseIpv4MappedIpv6Bytes(String host) {
  const prefix = '::ffff:';
  if (!host.startsWith(prefix)) {
    return null;
  }

  final mapped = host.substring(prefix.length);
  if (mapped.contains('.')) {
    final parts = mapped.split('.');
    if (parts.length != 4) {
      return null;
    }

    final octets = parts.map(int.tryParse).toList(growable: false);
    if (octets.any((value) => value == null || value < 0 || value > 255)) {
      return null;
    }

    return (octets[0]!, octets[1]!);
  }

  final groups = mapped.split(':');
  if (groups.length != 2) {
    return null;
  }

  final words = groups
      .map((group) => int.tryParse(group, radix: 16))
      .toList(growable: false);
  if (words.any((value) => value == null || value < 0 || value > 0xffff)) {
    return null;
  }

  final high = words[0]!;
  return (high >> 8, high & 0xff);
}
