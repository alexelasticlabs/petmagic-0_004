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
      normalizedHost.endsWith('.localhost') ||
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
  final bytes = _parseIpv4HostBytes(host);
  return bytes != null && _isUnsafeIpv4Bytes(bytes.$1, bytes.$2);
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

(int, int)? _parseIpv4HostBytes(String host) {
  final parts = host.split('.');
  if (parts.isEmpty ||
      parts.length > 4 ||
      parts.any((part) => part.isEmpty)) {
    return null;
  }

  final values = parts.map(_parseLegacyIpv4Part).toList(growable: false);
  if (values.any((value) => value == null || value < 0)) {
    return null;
  }

  final numeric = values.cast<int>().toList(growable: false);
  final lastMax = 1 << (8 * (5 - numeric.length));
  if (numeric.take(numeric.length - 1).any((value) => value > 0xff) ||
      numeric.last >= lastMax) {
    return null;
  }

  var address = 0;
  for (var index = 0; index < numeric.length - 1; index++) {
    address = (address << 8) | numeric[index];
  }

  address = (address << (8 * (5 - numeric.length))) | numeric.last;
  return ((address >> 24) & 0xff, (address >> 16) & 0xff);
}

int? _parseLegacyIpv4Part(String value) {
  if (value.isEmpty) {
    return null;
  }

  if (value.startsWith('0x')) {
    final hex = value.substring(2);
    return RegExp(r'^[0-9a-f]+$').hasMatch(hex)
        ? int.tryParse(hex, radix: 16)
        : null;
  }

  if (value.length > 1 && value.startsWith('0')) {
    return RegExp(r'^[0-7]+$').hasMatch(value)
        ? int.tryParse(value, radix: 8)
        : null;
  }

  return RegExp(r'^[0-9]+$').hasMatch(value) ? int.tryParse(value) : null;
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
      _isExpandedIpv6AnyOrLoopback(host) ||
      _isUnsafeIpv6Prefix(host)) {
    return true;
  }

  final mappedIpv4Bytes = _parseIpv4MappedOrCompatibleIpv6Bytes(host);
  if (mappedIpv4Bytes == null) {
    return false;
  }

  return _isUnsafeIpv4Bytes(mappedIpv4Bytes.$1, mappedIpv4Bytes.$2);
}

bool _isUnsafeIpv6Prefix(String host) {
  final firstGroup = host.split(':').first;
  if (!RegExp(r'^[0-9a-f]{1,4}$').hasMatch(firstGroup)) {
    return false;
  }

  final firstWord = int.parse(firstGroup, radix: 16);
  return (firstWord >= 0xfc00 && firstWord <= 0xfdff) ||
      (firstWord >= 0xfe80 && firstWord <= 0xfeff) ||
      firstWord >= 0xff00;
}

bool _isExpandedIpv6AnyOrLoopback(String host) {
  final groups = host.split(':');
  return groups.length == 8 &&
      groups.take(7).every(_isZeroIpv6Group) &&
      (groups[7] == '0' || groups[7] == '1');
}

// Covers both IPv4-mapped (::ffff:127.0.0.1) and IPv4-compatible
// (::127.0.0.1) encodings so local/private targets cannot bypass URL guards.
(int, int)? _parseIpv4MappedOrCompatibleIpv6Bytes(String host) {
  const mappedPrefix = '::ffff:';
  if (host.startsWith(mappedPrefix)) {
    return _parseMappedIpv4Suffix(host.substring(mappedPrefix.length));
  }

  const compatiblePrefix = '::';
  if (host.startsWith(compatiblePrefix)) {
    return _parseMappedIpv4Suffix(host.substring(compatiblePrefix.length));
  }

  final groups = host.split(':');
  if ((groups.length != 7 && groups.length != 8) ||
      !groups.take(5).every(_isZeroIpv6Group)) {
    return null;
  }

  if (groups[5] == 'ffff') {
    return _parseMappedIpv4Suffix(groups.skip(6).join(':'));
  }

  if (_isZeroIpv6Group(groups[5])) {
    return _parseMappedIpv4Suffix(groups.skip(6).join(':'));
  }

  return null;
}

(int, int)? _parseMappedIpv4Suffix(String mapped) {
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

bool _isZeroIpv6Group(String group) {
  return RegExp(r'^[0]{1,4}$').hasMatch(group);
}
