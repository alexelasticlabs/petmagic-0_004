String stripQuery(String value) {
  final queryIndex = value.indexOf('?');
  if (queryIndex < 0) {
    return value;
  }

  return value.substring(0, queryIndex);
}

bool isPrivateIpv4(String address) {
  final octets = address.split('.');
  if (octets.length != 4) {
    return false;
  }

  final bytes = octets
      .map((octet) {
        if (octet.isEmpty || !RegExp(r'^\d{1,3}$').hasMatch(octet)) {
          return null;
        }

        final value = int.tryParse(octet);
        return value != null && value >= 0 && value <= 255 ? value : null;
      })
      .toList(growable: false);

  if (bytes.any((value) => value == null)) {
    return false;
  }

  final first = bytes[0]!;
  final second = bytes[1]!;

  return first == 0 ||
      first == 10 ||
      first == 127 ||
      (first == 100 && second >= 64 && second <= 127) ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168) ||
      first >= 224;
}
